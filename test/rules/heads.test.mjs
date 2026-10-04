// heads/{campus} (PERF_TEST_PLAN.md §A): campus-readable; offering versions
// move only by staff of that campus; the catalogue and contact fields only
// alongside the documents they mirror.
import { describe, test } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, getDoc, increment, setDoc } from 'firebase/firestore';
import { OTHER, PRES, STUDENT, as, seed, useEmulator } from './helpers.mjs';

useEmulator();

const bump = (db, campus, key) =>
  setDoc(doc(db, 'heads', campus), { offerings: { [key]: increment(1) } }, { merge: true });

describe('heads', () => {
  test('staff of a campus move its offering versions; nobody else does', async () => {
    await assertSucceeds(bump(as(PRES), 'goa', 'EEE F211|2026-27-1'));
    await assertFails(bump(as(PRES), 'hyderabad', 'EEE F211|2026-27-1'));
    await assertFails(bump(as(STUDENT), 'goa', 'EEE F211|2026-27-1'));
  });

  test('staff cannot set the catalogue or contact fields', async () => {
    await assertFails(setDoc(doc(as(PRES), 'heads', 'goa'), { catalog: 99 }, { merge: true }));
    await assertFails(setDoc(doc(as(PRES), 'heads', 'goa'),
      { contact: { contactEnabled: true, contactTarget: 'x' } }, { merge: true }));
  });

  test('a campus reads its own head only', async () => {
    await seed((db) => setDoc(doc(db, 'heads', 'goa'), { offerings: {} }));
    await assertSucceeds(getDoc(doc(as(STUDENT), 'heads', 'goa')));
    await assertFails(getDoc(doc(as(OTHER), 'heads', 'goa')));
  });
});
