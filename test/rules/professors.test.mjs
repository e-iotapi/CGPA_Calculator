// firestore.rules for professors: add, rename and merge by pointer
// (ARCHITECTURE.md §10.1, §16.3 fix 7).
import { describe, test } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { deleteDoc, deleteField, collection, collectionGroup, doc, getDoc, getDocs, query, serverTimestamp, setDoc, where, writeBatch } from 'firebase/firestore';
import { ADMIN, OTHER, PRES, STUDENT, as, bump, days, name, seed, useEmulator } from './helpers.mjs';

useEmulator();

const CR = 'f20240010@goa.bits-pilani.ac.in';

function stamp(actor, auditId) {
  return { updatedBy: { email: actor, name: name(actor) }, updatedAt: serverTimestamp(), auditId };
}

function audit(b, db, actor, path) {
  const a = doc(collection(db, 'audit'));
  b.set(a, { actor: { email: actor, name: name(actor), role: 'test' }, action: 'prof', path, campus: 'goa', at: serverTimestamp() });
  return a.id;
}

function add(db, actor, id, fields = {}) {
  const b = writeBatch(db);
  const a = audit(b, db, actor, `professors/${id}`);
  b.set(doc(db, 'professors', id), {
    name: 'Dr. R. Menon', campus: 'goa', department: 'ELEC', aliases: [], nameTokens: ['r', 'm', 'me'],
    mergedIds: [], active: true, ...stamp(actor, a), ...fields,
  });
  bump(b, db, 'goa', `professors/${fields.department ?? 'ELEC'}`);
  return b.commit();
}

async function two() {
  await seed(async (db) => {
    const base = { campus: 'goa', department: 'ELEC', aliases: [], nameTokens: [], mergedIds: [], active: true };
    await setDoc(doc(db, 'professors', 'p1'), { name: 'Ramesh Menon', ...base });
    await setDoc(doc(db, 'professors', 'p2'), { name: 'Dr. R. Menon', ...base });
  });
}

function merge(db, actor, keep, gone, { tieAudit = true } = {}) {
  const b = writeBatch(db);
  const a = audit(b, db, actor, `professors/${gone}`);
  b.update(doc(db, 'professors', gone), { mergedInto: keep, active: false, ...stamp(actor, a) });
  b.update(doc(db, 'professors', keep), {
    mergedIds: [gone], aliases: ['Dr. R. Menon'], ...stamp(actor, tieAudit ? a : 'other'),
  });
  bump(b, db, 'goa', 'professors/ELEC');
  return b.commit();
}

describe('professors', () => {
  test('presidents in scope and admins add; CRs and students do not', async () => {
    await seed((db) => setDoc(doc(db, 'grants', `course|goa|EEE F211|${CR}`), {
      role: 'course', campus: 'goa', scope: 'EEE F211', email: CR, name: name(CR), active: true, expiresAt: days(100),
    }));
    await assertSucceeds(add(as(PRES), PRES, 'a'));
    await assertSucceeds(add(as(ADMIN), ADMIN, 'b', { department: 'CS' }));
    await assertFails(add(as(PRES), PRES, 'c', { department: 'CS' }));
    await assertFails(add(as(CR), CR, 'd'));
    await assertFails(add(as(STUDENT), STUDENT, 'e'));
    await assertFails(add(as(PRES), PRES, 'f', { mergedInto: 'a' }));
  });

  test('read by the same campus', async () => {
    await two();
    await assertSucceeds(getDoc(doc(as(STUDENT), 'professors', 'p1')));
    await assertFails(getDoc(doc(as(OTHER), 'professors', 'p1')));
  });

  // Review counters can outlive their professor: the Reviews screen reads
  // each one named and must see "absent", not a refusal.
  test('a get of a missing professor answers absent', async () => {
    const d = await assertSucceeds(getDoc(doc(as(STUDENT), 'professors', 'gone')));
    if (d.exists()) throw new Error('expected no document');
  });

  test('a merge is one audited batch, by pointer', async () => {
    await two();
    await assertFails(merge(as(STUDENT), STUDENT, 'p1', 'p2'));
    await assertFails(merge(as(PRES), PRES, 'p1', 'p2', { tieAudit: false }));
    await assertSucceeds(merge(as(PRES), PRES, 'p1', 'p2'));
    // The absorbed one stays absorbed.
    const db = as(PRES);
    const b = writeBatch(db);
    const a = audit(b, db, PRES, 'professors/p2');
    b.update(doc(db, 'professors', 'p2'), { name: 'Back', ...stamp(PRES, a) });
    bump(b, db, 'goa', 'professors/ELEC');
    await assertFails(b.commit());
  });
});

describe('professor soft delete', () => {
  function setRemoved(db, actor, id, removed, { audited = true, bumped = true, at = serverTimestamp() } = {}) {
    const b = writeBatch(db);
    const a = audited ? audit(b, db, actor, `professors/${id}`) : 'none';
    b.update(doc(db, 'professors', id), removed
      ? { removed: true, removedBy: { email: actor, name: name(actor) }, removedAt: at, ...stamp(actor, a) }
      : { removed: false, removedBy: deleteField(), removedAt: deleteField(), ...stamp(actor, a) });
    if (bumped) bump(b, db, 'goa', 'professors/ELEC');
    return b.commit();
  }

  test('president, admin remove; others, unaudited, unbumped do not', async () => {
    await two();
    await assertFails(setRemoved(as(STUDENT), STUDENT, 'p1', true));
    await assertFails(setRemoved(as(PRES), PRES, 'p1', true, { audited: false }));
    await assertFails(setRemoved(as(PRES), PRES, 'p1', true, { bumped: false }));
    await assertFails(setRemoved(as(PRES), PRES, 'p1', true, { at: new Date(0) }));
    await assertSucceeds(setRemoved(as(PRES), PRES, 'p1', true));
    await assertSucceeds(setRemoved(as(ADMIN), ADMIN, 'p2', true));
  });

  test("another department's president cannot remove", async () => {
    await seed((db) => setDoc(doc(db, 'professors', 'c1'), {
      name: 'Some One', campus: 'goa', department: 'CS', aliases: [], nameTokens: [], mergedIds: [], active: true,
    }));
    await assertFails(setRemoved(as(PRES), PRES, 'c1', true));
  });

  test('a removed doc is frozen until restored; no hard delete', async () => {
    await two();
    await assertSucceeds(setRemoved(as(PRES), PRES, 'p1', true));
    const db = as(PRES);
    const b = writeBatch(db);
    const a = audit(b, db, PRES, 'professors/p1');
    b.update(doc(db, 'professors', 'p1'), { name: 'Renamed', ...stamp(PRES, a) });
    bump(b, db, 'goa', 'professors/ELEC');
    await assertFails(b.commit());
    await assertFails(deleteDoc(doc(as(PRES), 'professors', 'p1')));
    await assertSucceeds(setRemoved(as(PRES), PRES, 'p1', false));
    await assertSucceeds(add(as(PRES), PRES, 'n'));
  });
});

describe('Reviews search by professor', () => {
  test('names are searched on the reader\'s campus only', async () => {
    const q = (db, campus) => query(collection(db, 'professors'),
      where('campus', '==', campus), where('nameTokens', 'array-contains', 'men'));
    await assertSucceeds(getDocs(q(as(STUDENT), 'goa')));
    await assertFails(getDocs(q(as(OTHER), 'goa')));
  });

  test('the courses a professor taught, across courses, same campus', async () => {
    await seed((db) => setDoc(doc(db, 'courses', 'EEE F211', 'offerings', 'goa_2025-26-1'), {
      courseId: 'EEE F211', campus: 'goa', term: '2025-26-1', professors: ['p1'], components: [],
    }));
    const q = (db, campus) => query(collectionGroup(db, 'offerings'),
      where('campus', '==', campus), where('professors', 'array-contains-any', ['p1']));
    const r = await assertSucceeds(getDocs(q(as(STUDENT), 'goa')));
    if (r.size !== 1) throw new Error(`expected 1 offering, got ${r.size}`);
    await assertFails(getDocs(q(as(OTHER), 'goa')));
  });
});
