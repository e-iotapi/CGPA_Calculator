// firestore.rules for signInLog: signed-out people add small entries; only
// owners read them.
import { describe, test } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { addDoc, collection, getDocs, serverTimestamp, updateDoc } from 'firebase/firestore';
import { OWNER, STUDENT, anon, as, useEmulator } from './helpers.mjs';

useEmulator();

const entry = (extra = {}) => ({
  outcome: 'failed', stage: 'popup', code: 'popup-closed-by-user', message: 'Firebase: Error.',
  attempt: 1, ms: 12000, ua: 'Mozilla/5.0', device: 'android', browser: 'chrome',
  standalone: false, path: '/calculator/', at: serverTimestamp(), ...extra,
});

describe('signInLog', () => {
  test('a signed-out person adds one entry of the exact shape', async () => {
    const c = collection(anon(), 'signInLog');
    await assertSucceeds(addDoc(c, entry()));
    await assertFails(addDoc(c, entry({ email: 'f20260001@goa.bits-pilani.ac.in' })));
    await assertFails(addDoc(c, entry({ message: 'x'.repeat(301) })));
    await assertFails(addDoc(c, entry({ outcome: 'other' })));
    await assertFails(addDoc(c, entry({ at: new Date(0) })));
  });

  test('only owners read; nobody edits', async () => {
    const ref = await addDoc(collection(anon(), 'signInLog'), entry());
    await assertFails(getDocs(collection(as(STUDENT), 'signInLog')));
    await assertSucceeds(getDocs(collection(as(OWNER), 'signInLog')));
    await assertFails(updateDoc(ref, { code: 'x' }));
  });
});
