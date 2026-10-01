// firestore.rules for reviews: hashed ids, counters checked by delta, votes,
// reports and hide-only moderation (ARCHITECTURE.md §10.3, fixes 4–6).
import { createHash } from 'node:crypto';
import { describe, test } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  collection, collectionGroup, deleteDoc, deleteField, doc, getDoc, getDocs, increment, limit, orderBy, query, serverTimestamp, setDoc, where, writeBatch,
} from 'firebase/firestore';
import { OTHER, PRES, STUDENT, as, bump, env, name, seed, useEmulator } from './helpers.mjs';

useEmulator();

const C = 'EEE F211';
const S2 = 'f20230999@goa.bits-pilani.ac.in';
const hash = (uid, key) => createHash('sha256').update(uid + key).digest('hex');

async function offering(professors = ['p1']) {
  await seed((db) => setDoc(doc(db, 'courses', C, 'offerings', 'goa_2025-26-2'), { professors }));
}

function count(b, db, reviewId, d, dc, ds, dr, ix = true) {
  for (const p of [null, d.professorId].filter((x, i) => i == 0 || x)) {
    b.set(doc(db, 'courses', C, 'stats', p ? `goa_${p}` : 'goa'), {
      count: increment(dc), starSum: increment(ds), recommendCount: increment(dr),
      campus: 'goa', courseId: C, scope: p ? 'professor' : 'course', professorId: p, touchedBy: reviewId,
    }, { merge: true });
  }
  if (ix) index(b, db, dc, ds, dr);
}

function index(b, db, dc, ds, dr, course = C) {
  b.set(doc(db, 'reviewIndex', 'goa'), {
    k: course,
    c: { [course]: { count: increment(dc), starSum: increment(ds), recommendCount: increment(dr) } },
  }, { merge: true });
  bump(b, db, 'goa', 'reviews');
}

function mirror(b, db, id, entry) {
  b.set(doc(db, 'reviews', C, 'campus', 'goa'), { k: id, r: { [id]: entry } }, { merge: true });
  bump(b, db, 'goa', `reviews/${C}`);
}

function post(db, who, extra = {}, { dc = 1, ds, dr, m = {} } = {}) {
  const id = hash(who, C);
  const d = {
    courseId: C, department: 'ELEC', stars: 4, recommend: true, text: 'Good', campus: 'goa', term: '2025-26-2',
    professorId: 'p1', hidden: false, helpful: 0, reports: 0, createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    ...extra,
  };
  const b = writeBatch(db);
  b.set(doc(db, 'reviews', C, 'entries', id), d);
  count(b, db, id, d, dc, ds ?? d.stars, dr ?? (d.recommend ? 1 : 0));
  if (m) {
    const { stars, recommend, text, term, professorId, helpful, createdAt, updatedAt } = d;
    mirror(b, db, id, { stars, recommend, text, term, professorId, helpful, createdAt, updatedAt, ...m });
  }
  return b.commit();
}

describe('reviews', () => {
  test('one per person, on a real offering, counters moved exactly', async () => {
    await offering();
    await assertFails(post(as(STUDENT), STUDENT, {}, { ds: 5 }));
    await assertFails(post(as(STUDENT), STUDENT, { professorId: 'p9' }));
    await assertFails(post(as(STUDENT), STUDENT, { term: '2024-25-1' }));
    await assertFails(post(as(OTHER), OTHER, { campus: 'goa' }));
    await assertSucceeds(post(as(STUDENT), STUDENT));
    await assertFails(post(as(STUDENT), STUDENT));
    const s = await getDoc(doc(as(STUDENT), 'courses', C, 'stats', 'goa'));
    if (s.data().count !== 1 || s.data().starSum !== 4) throw new Error('bad counter');
  });

  test('no professor on the offering: null, counted for the course only', async () => {
    await offering([]);
    await assertFails(post(as(STUDENT), STUDENT));
    await assertSucceeds(post(as(STUDENT), STUDENT, { professorId: null }));
  });

  test('the campus index moves with the course counter, never alone', async () => {
    await offering();
    await assertSucceeds(post(as(STUDENT), STUDENT));
    const ix = await getDoc(doc(as(STUDENT), 'reviewIndex', 'goa'));
    if (ix.data().c[C].count !== 1 || ix.data().c[C].starSum !== 4) throw new Error('bad index');
    const db = as(STUDENT);
    const alone = writeBatch(db);
    index(alone, db, 5, 20, 5);
    await assertFails(alone.commit());
    await assertFails(getDoc(doc(as(OTHER), 'reviewIndex', 'goa')));
  });

  test('the index entry must match its own course', async () => {
    await offering();
    const db = as(STUDENT);
    const id = hash(STUDENT, C);
    const b = writeBatch(db);
    const d = {
      courseId: C, department: 'ELEC', stars: 4, recommend: true, campus: 'goa', term: '2025-26-2',
      professorId: 'p1', hidden: false, helpful: 0, reports: 0, createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    };
    b.set(doc(db, 'reviews', C, 'entries', id), d);
    count(b, db, id, d, 1, 4, 1, false);
    index(b, db, 1, 4, 1, 'CS F111');
    await assertFails(b.commit());
  });

  test('the campus copy mirrors the review exactly, only there', async () => {
    await offering();
    await assertFails(post(as(STUDENT), STUDENT, {}, { m: { stars: 5 } }));
    await assertFails(post(as(STUDENT), STUDENT, {}, { m: { helpful: 3 } }));
    await assertSucceeds(post(as(STUDENT), STUDENT));
    const db = as(S2);
    const b = writeBatch(db);
    mirror(b, db, hash(STUDENT, C), { stars: 1 });
    await assertFails(b.commit());
    await assertSucceeds(getDoc(doc(as(S2), 'reviews', C, 'campus', 'goa')));
    await assertFails(getDoc(doc(as(OTHER), 'reviews', C, 'campus', 'goa')));
  });

  test('counters cannot be written on their own', async () => {
    await assertFails(setDoc(doc(as(STUDENT), 'courses', C, 'stats', 'goa'), {
      count: 100, starSum: 500, recommendCount: 100, campus: 'goa', courseId: C, scope: 'course', professorId: null, touchedBy: 'x',
    }));
  });

  test('edit by difference; nobody deletes, the author included', async () => {
    await offering();
    await post(as(STUDENT), STUDENT);
    const db = as(STUDENT);
    const id = hash(STUDENT, C);
    const edit = (ds) => {
      const b = writeBatch(db);
      b.update(doc(db, 'reviews', C, 'entries', id), { stars: 2, updatedAt: serverTimestamp() });
      count(b, db, id, { professorId: 'p1' }, 0, ds, 0);
      return b.commit();
    };
    await assertFails(edit(-1));
    await assertSucceeds(edit(-2));
    const del = (dc) => {
      const b = writeBatch(db);
      b.delete(doc(db, 'reviews', C, 'entries', id));
      count(b, db, id, { professorId: 'p1' }, dc, -2, -1);
      return b.commit();
    };
    await assertFails(del(0));
    await assertFails(del(-1));
  });

  test('helpful once per person; hidden reviews stay hidden from students', async () => {
    await offering();
    await post(as(STUDENT), STUDENT);
    const id = hash(STUDENT, C);
    const vote = (who, by = 1) => {
      const db = as(who);
      const b = writeBatch(db);
      b.set(doc(db, 'reviews', C, 'entries', id, 'votes', hash(who, id)), { createdAt: serverTimestamp() });
      b.update(doc(db, 'reviews', C, 'entries', id), { helpful: increment(by) });
      mirror(b, db, id, { helpful: increment(by) });
      return b.commit();
    };
    await assertFails(vote(S2, 5));
    await assertSucceeds(vote(S2));
    await assertFails(vote(S2));

    const listed = (who) => getDocs(query(collection(as(who), 'reviews', C, 'entries'),
      where('campus', '==', 'goa'), where('hidden', '==', false)));
    await assertSucceeds(listed(S2));
    await assertFails(getDocs(query(collection(as(S2), 'reviews', C, 'entries'), where('campus', '==', 'goa'))));
  });

  test('a president in scope hides with a reason, logged; counters come off', async () => {
    await offering();
    await post(as(STUDENT), STUDENT);
    const id = hash(STUDENT, C);
    const hide = (who, { reason = 'Names a person', dc = -1 } = {}) => {
      const db = as(who);
      const b = writeBatch(db);
      const a = doc(collection(db, 'audit'));
      b.update(doc(db, 'reviews', C, 'entries', id), {
        hidden: true, reason, hiddenBy: { email: who, name: name(who) }, auditId: a.id, moderatedAt: serverTimestamp(),
      });
      b.set(a, { actor: { email: who, name: name(who), role: 'test' }, action: 'hide', path: `reviews/${C}/entries/${id}`, campus: 'goa', at: serverTimestamp() });
      count(b, db, id, { professorId: 'p1' }, dc, -4 * -dc, -1 * -dc);
      mirror(b, db, id, deleteField());
      return b.commit();
    };
    await assertFails(hide(S2));
    await assertFails(hide(PRES, { reason: '' }));
    await assertFails(hide(PRES, { dc: 0 }));
    await assertSucceeds(hide(PRES));
    const m = await getDoc(doc(as(S2), 'reviews', C, 'campus', 'goa'));
    if (id in m.data().r) throw new Error('hidden review still mirrored');
    await assertFails(getDoc(doc(as(S2), 'reviews', C, 'entries', id)));
    // The author can still read their own, hidden or not.
    await assertSucceeds(getDoc(doc(as(STUDENT), 'reviews', C, 'entries', id)));
    // Never a delete by a moderator.
    await assertFails(deleteDoc(doc(as(PRES), 'reviews', C, 'entries', id)));
  });
});

describe('review counters across courses', () => {
  test('anyone signed in lists a campus\'s most reviewed', async () => {
    const q = (db) => query(collectionGroup(db, 'stats'),
      where('campus', '==', 'goa'), where('scope', '==', 'course'),
      orderBy('count', 'desc'), limit(10));
    await assertSucceeds(getDocs(q(as(STUDENT))));
    await assertFails(getDocs(q(env.unauthenticatedContext().firestore())));
  });
});
