// users/{uid}: the sync document (PERF_TEST_PLAN.md §A.4). A push is a plain
// update the rules accept only as rev + 1; a pull check is a one-document
// query that returns nothing when the server copy has not moved.
import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  collection, doc, getDoc, getDocs, query, setDoc, updateDoc, where,
} from 'firebase/firestore';
import { STUDENT, OTHER, env, useEmulator } from './helpers.mjs';

useEmulator();

const me = () =>
  env.authenticatedContext('uid-student', { email: STUDENT, email_verified: true }).firestore();
const other = () =>
  env.authenticatedContext('uid-other', { email: OTHER, email_verified: true }).firestore();

describe('users', () => {
  test('the first push creates the doc; later pushes move rev by exactly one', async () => {
    const ref = doc(me(), 'users/uid-student');
    await assertSucceeds(setDoc(ref, { rev: 1, data: '{}', uid: 'uid-student' }));
    await assertSucceeds(updateDoc(ref, { rev: 2, data: '{"a":1}' }));
    await assertFails(updateDoc(ref, { rev: 2, data: '{"a":2}' }));
    await assertFails(updateDoc(ref, { rev: 5, data: '{"a":3}' }));
    await assertFails(updateDoc(ref, { rev: 3, uid: 'uid-other' }));
  });

  test('the pull check sees only a newer copy of its own doc', async () => {
    await assertSucceeds(setDoc(doc(me(), 'users/uid-student'), { rev: 1, data: '{}', uid: 'uid-student' }));
    const mine = (rev) => query(
      collection(me(), 'users'),
      where('uid', '==', 'uid-student'),
      where('rev', '>', rev),
    );
    assert.equal((await assertSucceeds(getDocs(mine(1)))).size, 0);
    assert.equal((await assertSucceeds(getDocs(mine(0)))).size, 1);
    await assertFails(getDocs(query(
      collection(other(), 'users'),
      where('uid', '==', 'uid-student'),
      where('rev', '>', 0),
    )));
  });
  // B1: prefs ride on the sync doc; owner-only, two bool flags, no rev needed.
  describe('prefs', () => {
    const seedDoc = (extra = {}) => assertSucceeds(
      setDoc(doc(me(), 'users/uid-student'), { rev: 1, data: '{}', uid: 'uid-student', ...extra }));

    test('the owner sets the flags with a prefs-only update', async () => {
      await seedDoc();
      const ref = doc(me(), 'users/uid-student');
      await assertSucceeds(updateDoc(ref, { 'prefs.offshootHidden': true }));
      await assertSucceeds(updateDoc(ref, { 'prefs.tourSeen': false }));
      await assertSucceeds(updateDoc(ref, { prefs: { offshootHidden: false, tourSeen: true } }));
    });

    test('another uid cannot write them', async () => {
      await seedDoc();
      await assertFails(updateDoc(doc(other(), 'users/uid-student'), { 'prefs.offshootHidden': true }));
    });

    test('an unknown key or a non-bool value is refused', async () => {
      await seedDoc();
      const ref = doc(me(), 'users/uid-student');
      await assertFails(updateDoc(ref, { 'prefs.theme': true }));
      await assertFails(updateDoc(ref, { 'prefs.offshootHidden': 'yes' }));
      await assertFails(updateDoc(ref, { prefs: 'x' }));
    });

    test('prefs with data but no rev bump is refused; a rev + 1 push may carry them', async () => {
      await seedDoc();
      const ref = doc(me(), 'users/uid-student');
      await assertFails(updateDoc(ref, { 'prefs.tourSeen': true, data: '{"a":1}' }));
      await assertSucceeds(updateDoc(ref, { 'prefs.tourSeen': true }));
      await assertSucceeds(updateDoc(ref, { rev: 2, data: '{"a":1}' }));
      assert.equal((await assertSucceeds(getDoc(ref))).data().prefs.tourSeen, true);
    });

    test('a doc that carries prefs still takes normal pushes and still needs rev + 1', async () => {
      await seedDoc({ prefs: { offshootHidden: true } });
      const ref = doc(me(), 'users/uid-student');
      await assertSucceeds(updateDoc(ref, { rev: 2, data: '{"a":1}' }));
      await assertFails(updateDoc(ref, { rev: 2, data: '{"a":2}' }));
    });
  });
});
