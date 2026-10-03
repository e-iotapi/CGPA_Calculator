// firestore.rules for activity/{campus}: when staff last made a meaningful
// edit (Last updated, B4).
import { test } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { Timestamp, doc, getDoc, serverTimestamp, setDoc } from 'firebase/firestore';
import { ADMIN, PRES, STUDENT, as, useEmulator } from './helpers.mjs';

useEmulator();

const touch = (db, { course, dept, at = serverTimestamp(), extra = {} } = {}) =>
  setDoc(doc(db, 'activity', 'goa'), {
    ...(course ? { course: { [course]: at } } : {}),
    ...(dept ? { dept: { [dept]: at } } : {}),
    c: course ?? '', d: dept ?? '', ...extra,
  }, { merge: true });

test('staff stamp a course and department with the server time', async () => {
  await assertSucceeds(touch(as(PRES), { course: 'EEE F111', dept: 'ELEC' }));
  await assertSucceeds(touch(as(ADMIN), { dept: 'ECON' }));
  await assertSucceeds(getDoc(doc(as(STUDENT), 'activity', 'goa')));
});

test('students, client times, unhinted keys and extra fields are denied', async () => {
  await assertFails(touch(as(STUDENT), { course: 'EEE F111', dept: 'ELEC' }));
  await assertFails(touch(as(PRES), { dept: 'ELEC', at: Timestamp.fromMillis(Date.now()) }));
  await assertFails(setDoc(doc(as(PRES), 'activity', 'goa'), {
    dept: { ELEC: serverTimestamp(), CS: serverTimestamp() }, c: '', d: 'ELEC',
  }, { merge: true }));
  await assertFails(touch(as(PRES), { dept: 'ELEC', extra: { note: 'x' } }));
});
