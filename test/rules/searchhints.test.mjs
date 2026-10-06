// searchHints/{campus}: students on a campus vote one pair +1 at a time;
// nobody rewrites the counts.
import { describe, test } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, getDoc, increment, setDoc } from 'firebase/firestore';
import { OTHER, OWNER, STUDENT, as, seed, useEmulator } from './helpers.mjs';

useEmulator();

const vote = (db, campus, k, t, by = increment(1)) =>
  setDoc(doc(db, 'searchHints', campus), { q: { [k]: { [t]: by } }, k, t }, { merge: true });

describe('searchHints', () => {
  test('a student votes a pair on their campus, +1 only', async () => {
    await assertSucceeds(vote(as(STUDENT), 'goa', 'pyq', 'previous year questions'));
    await assertSucceeds(vote(as(STUDENT), 'goa', 'pyq', 'previous year questions'));
    await assertFails(vote(as(STUDENT), 'goa', 'pyq', 'previous year questions', increment(5)));
    await assertFails(vote(as(STUDENT), 'goa', 'pyq', 'notes', 9));
    await assertFails(vote(as(OTHER), 'goa', 'pyq', 'notes'));
    await assertFails(vote(as(STUDENT), 'goa', 'PYQ!', 'notes'));
    await assertFails(vote(as(STUDENT), 'goa', 'notes', 'notes'));
  });

  test('a vote names the pair it moves', async () => {
    await assertFails(setDoc(doc(as(STUDENT), 'searchHints', 'goa'),
      { q: { lab: { practical: increment(1) } }, k: 'lab', t: 'tut' }, { merge: true }));
  });

  test('a campus reads its own hints', async () => {
    await seed((db) => setDoc(doc(db, 'searchHints', 'goa'), { q: {} }));
    await assertSucceeds(getDoc(doc(as(STUDENT), 'searchHints', 'goa')));
    await assertFails(getDoc(doc(as(OTHER), 'searchHints', 'goa')));
    await assertSucceeds(getDoc(doc(as(OWNER), 'searchHints', 'goa')));
  });
});
