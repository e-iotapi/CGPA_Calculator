// firestore.rules for site analytics: a ping moves its own campus by one;
// owners alone read the day docs and count people.
import { describe, test } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { collection, doc, getCountFromServer, getDoc, increment, setDoc } from 'firebase/firestore';
import { OTHER, OWNER, STUDENT, as, useEmulator } from './helpers.mjs';

useEmulator();

const DAY = '2026-09-29';
const ping = (who, campus, { dau = 1, h = 1, hour = '13' } = {}) =>
  setDoc(doc(as(who), 'analytics', DAY), {
    sample: 20,
    [campus]: { ...(dau ? { dau: increment(dau) } : {}), h: { [hour]: increment(h) }, at: hour },
  }, { merge: true });

describe('analytics', () => {
  test('a ping adds one to its own campus, day and hour', async () => {
    await assertSucceeds(ping(STUDENT, 'goa'));
    await assertSucceeds(ping(STUDENT, 'goa', { dau: 0, hour: '14' }));
    await assertFails(ping(STUDENT, 'goa', { dau: 5 }));
    await assertFails(ping(STUDENT, 'goa', { h: 3 }));
    await assertFails(ping(STUDENT, 'hyderabad'));
    await assertSucceeds(ping(OTHER, 'hyderabad'));
  });

  test('owners read the days and count people; nobody else', async () => {
    await ping(STUDENT, 'goa');
    await assertFails(getDoc(doc(as(STUDENT), 'analytics', DAY)));
    await assertSucceeds(getDoc(doc(as(OWNER), 'analytics', DAY)));
    await assertSucceeds(getCountFromServer(collection(as(OWNER), 'people')));
    await assertFails(getCountFromServer(collection(as(STUDENT), 'people')));
  });
});
