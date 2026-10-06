// +2 points for a review (owner, 2026-10-06): only in the batch that
// creates the writer's own review, never for an edit or someone else.
import { createHash } from 'node:crypto';
import { describe, test } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, increment, serverTimestamp, setDoc, writeBatch } from 'firebase/firestore';
import { STUDENT, as, bump, seed, useEmulator } from './helpers.mjs';

useEmulator();

const C = 'EEE F211';
const hash = (uid, key) => createHash('sha256').update(uid + key).digest('hex');

// The app's whole review batch: entry, counters, index, mirror, points and
// the leaderboard row.
function review(db, who, { points, username, entry = true, by = 2, course = C } = {}) {
  const id = hash(who, course);
  const d = {
    courseId: course, department: 'ELEC', stars: 4, recommend: true, campus: 'goa', term: '2025-26-2',
    professorId: null, hidden: false, helpful: 0, reports: 0, createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  };
  const b = writeBatch(db);
  if (entry) {
    b.set(doc(db, 'reviews', course, 'entries', id), d);
    b.set(doc(db, 'courses', course, 'stats', 'goa'), {
      count: increment(1), starSum: increment(4), recommendCount: increment(1),
      campus: 'goa', courseId: course, scope: 'course', professorId: null, touchedBy: id,
    }, { merge: true });
    b.set(doc(db, 'reviewIndex', 'goa'), {
      k: course, c: { [course]: { count: increment(1), starSum: increment(4), recommendCount: increment(1) } },
    }, { merge: true });
    bump(b, db, 'goa', 'reviews');
    b.set(doc(db, 'reviews', course, 'campus', 'goa'), {
      k: id, r: { [id]: { stars: 4, recommend: true, term: d.term, professorId: null, helpful: 0, createdAt: d.createdAt, updatedAt: d.updatedAt } },
    }, { merge: true });
    bump(b, db, 'goa', `reviews/${course}`);
  }
  const ref = doc(db, 'contributors', who);
  const n = (points ?? 0) + by;
  if (points == null) b.set(ref, { campus: 'goa', points: n, lastReview: course });
  else b.update(ref, { points: n, lastReview: course });
  if (username) {
    b.set(doc(db, 'leaderboard', 'goa'), { p: { [username]: n }, k: username }, { merge: true });
    bump(b, db, 'goa', 'leaderboard');
  }
  return b.commit();
}

describe('review points', () => {
  test('a first review earns 2, with the review only', async () => {
    await assertFails(review(as(STUDENT), STUDENT, { entry: false }));
    await assertFails(review(as(STUDENT), STUDENT, { by: 4 }));
    await assertSucceeds(review(as(STUDENT), STUDENT));
  });

  test('a named contributor moves their leaderboard row too', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'contributors', STUDENT), { campus: 'goa', points: 4, username: 'cee' });
      await setDoc(doc(db, 'usernames', 'goa|cee'), { email: STUDENT });
      await setDoc(doc(db, 'leaderboard', 'goa'), { p: { cee: 4 }, tags: {} });
    });
    await assertSucceeds(review(as(STUDENT), STUDENT, { points: 4, username: 'cee', course: 'EEE F212' }));
  });
});
