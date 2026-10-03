// firestore.rules for the broadcast timetable (B8b): meta, chunks and the
// current pointer, written by the owner/admin script in one audited batch.
import { describe, test } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { collection, doc, getDoc, serverTimestamp, setDoc, writeBatch } from 'firebase/firestore';
import { ADMIN, OWNER, PRES, STUDENT, as, bump, name, seed, useEmulator } from './helpers.mjs';

useEmulator();

const base = 'goa|2026-1';

/** The script's batch; `opts` bend one thing at a time. */
function publish(db, actor, { chunks = 2, marker = 1, auditActor = actor, auditPath = `timetable/${base}`, bumpHead = true, chunkAudit = true } = {}) {
  const b = writeBatch(db);
  const a = doc(collection(db, 'audit'));
  b.set(a, { actor: { email: auditActor, name: name(auditActor), role: 'test' }, action: 'publish timetable', path: auditPath, campus: 'goa', at: serverTimestamp() });
  b.set(doc(db, 'timetable', base), {
    v: 1, sem: '2026-1', campus: 'goa', hours: { 1: [480, 540] }, examSlots: { FN: [570, 750] }, events: [],
    chunks, publishedAt: serverTimestamp(), marker, auditId: a.id,
  });
  for (let n = 0; n < chunks; n++) b.set(doc(db, 'timetable', `${base}|${n}`), { n, courses: { [`AAA F10${n}`]: { t: 'x', sec: [] } } });
  b.set(doc(db, 'timetable', 'goa|current'), { sem: '2026-1', marker });
  if (bumpHead) bump(b, db, 'goa', 'timetable');
  return b.commit();
}

describe('timetable', () => {
  test('owner and admin publish the whole set in one batch', async () => {
    await assertSucceeds(publish(as(OWNER), OWNER));
    await seed(async (db) => { await setDoc(doc(db, 'heads', 'goa'), { v: { timetable: 1 } }); });
    await assertSucceeds(publish(as(ADMIN), ADMIN, { marker: 2 }));
  });

  test('students, presidents and others cannot write', async () => {
    await assertFails(publish(as(STUDENT), STUDENT));
    await assertFails(publish(as(PRES), PRES));
  });

  test('audit must be by the writer and name the meta doc', async () => {
    await assertFails(publish(as(OWNER), OWNER, { auditActor: ADMIN }));
    await assertFails(publish(as(OWNER), OWNER, { auditPath: 'timetable/goa|other' }));
  });

  test('the marker moves exactly once, and meta and pointer carry it', async () => {
    await assertFails(publish(as(OWNER), OWNER, { bumpHead: false }));
    await assertFails(publish(as(OWNER), OWNER, { marker: 5 }));
  });

  test('a chunk must be within meta.chunks and carry no stray fields', async () => {
    await assertFails(publish(as(OWNER), OWNER, { chunks: 0 }));
    const db = as(OWNER);
    const b = writeBatch(db);
    const a = doc(collection(db, 'audit'));
    b.set(a, { actor: { email: OWNER, name: 'o', role: 'test' }, path: `timetable/${base}`, campus: 'goa', at: serverTimestamp() });
    b.set(doc(db, 'timetable', base), {
      v: 1, sem: '2026-1', campus: 'goa', hours: {}, examSlots: {}, events: [], chunks: 1,
      publishedAt: serverTimestamp(), marker: 1, auditId: a.id,
    });
    b.set(doc(db, 'timetable', `${base}|1`), { n: 1, courses: {} });
    b.set(doc(db, 'timetable', 'goa|current'), { sem: '2026-1', marker: 1 });
    bump(b, db, 'goa', 'timetable');
    await assertFails(b.commit());
  });

  test('a chunk alone, without a matching meta audit, fails', async () => {
    await assertFails(setDoc(doc(as(OWNER), 'timetable', `${base}|0`), { n: 0, courses: {} }));
  });

  test('everyone signed in reads; nobody deletes', async () => {
    await seed(async (db) => { await setDoc(doc(db, 'timetable', 'goa|current'), { sem: '2026-1', marker: 1 }); });
    await assertSucceeds(getDoc(doc(as(STUDENT), 'timetable', 'goa|current')));
    await assertFails(setDoc(doc(as(OWNER), 'timetable', 'goa|current'), { sem: 'x', marker: 9 }));
    const o = as(OWNER);
    await assertFails(writeBatch(o).delete(doc(o, 'timetable', 'goa|current')).commit());
  });
});
