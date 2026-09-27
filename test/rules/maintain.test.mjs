// firestore.rules for maintainer writes: offerings, course drafts and the
// catalogue publish (ARCHITECTURE.md §9 step 6, §13.2, §11).
import { describe, test } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { collection, doc, serverTimestamp, setDoc, writeBatch } from 'firebase/firestore';
import { OWNER, PRES, STUDENT, as, days, name, seed, useEmulator } from './helpers.mjs';

useEmulator();

const CR = 'f20240010@goa.bits-pilani.ac.in';

/// An offering written the way the app writes it: with its audit entry.
function writeOffering(db, actor, course, off, { audit = true, auditPath, extra = {} } = {}) {
  const b = writeBatch(db);
  const a = doc(collection(db, 'audit'));
  const path = `courses/${course}/offerings/${off}`;
  const [campus, term] = off.split('_');
  b.set(doc(db, path), {
    courseId: course,
    campus,
    term,
    weighted: true,
    totalMarks: 100,
    components: [{ id: 'c1', name: 'Quiz', weight: 10, parts: [{ name: '', outOf: 20 }], countBest: 0 }],
    professors: [],
    updatedBy: { email: actor, name: name(actor) },
    updatedAt: serverTimestamp(),
    auditId: a.id,
    ...extra,
  });
  if (audit) {
    b.set(a, {
      actor: { email: actor, name: name(actor), role: 'test' },
      action: 'scheme',
      path: auditPath ?? path,
      campus,
      at: serverTimestamp(),
    });
  }
  return b.commit();
}

async function crGrant() {
  await seed(async (db) => {
    await setDoc(doc(db, 'grants', `course|goa|CS F301|${CR}`), {
      role: 'course', campus: 'goa', scope: 'CS F301', email: CR, name: name(CR), active: true, expiresAt: days(100),
    });
  });
}

describe('offerings', () => {
  test('a president writes in their department on their campus', async () => {
    await assertSucceeds(writeOffering(as(PRES), PRES, 'EEE F111', 'goa_2026-27-1'));
    await assertSucceeds(writeOffering(as(PRES), PRES, 'INSTR F211', 'goa_2026-27-1'));
    await assertFails(writeOffering(as(PRES), PRES, 'CS F301', 'goa_2026-27-1'));
    await assertFails(writeOffering(as(PRES), PRES, 'EEE F111', 'pilani_2026-27-1'));
  });

  test('a CR writes their own course only', async () => {
    await crGrant();
    await assertSucceeds(writeOffering(as(CR), CR, 'CS F301', 'goa_2026-27-1'));
    await assertFails(writeOffering(as(CR), CR, 'CS F211', 'goa_2026-27-1'));
  });

  test('a student, or a write without its audit entry, is refused', async () => {
    await assertFails(writeOffering(as(STUDENT), STUDENT, 'CS F301', 'goa_2026-27-1'));
    await assertFails(writeOffering(as(PRES), PRES, 'EEE F111', 'goa_2026-27-1', { audit: false }));
    await assertFails(
      writeOffering(as(PRES), PRES, 'EEE F111', 'goa_2026-27-1', { auditPath: 'courses/EEE F111/offerings/goa_x' }),
    );
  });

  test('the id must match the campus and term inside', async () => {
    await assertFails(
      writeOffering(as(PRES), PRES, 'EEE F111', 'goa_2026-27-1', { extra: { term: '2026-27-2' } }),
    );
    await assertFails(
      writeOffering(as(PRES), PRES, 'EEE F111', 'goa_2026-27-1', { extra: { updatedBy: { email: OWNER, name: 'x' } } }),
    );
  });

  test('a lapsed grant writes nothing', async () => {
    await seed((db) => setDoc(doc(db, 'grants', `dept|goa|ELEC|${PRES}`), {
      role: 'dept', campus: 'goa', scope: 'ELEC', email: PRES, name: name(PRES), active: true, expiresAt: days(-1),
    }));
    await assertFails(writeOffering(as(PRES), PRES, 'EEE F111', 'goa_2026-27-1'));
  });
});

function draft(db, actor, id, fields) {
  const b = writeBatch(db);
  const a = doc(collection(db, 'audit'));
  b.set(doc(db, 'courses', id), {
    id, ...fields, draft: true, auditId: a.id,
    updatedBy: { email: actor, name: name(actor) }, updatedAt: serverTimestamp(),
  });
  b.set(a, {
    actor: { email: actor, name: name(actor), role: 'test' },
    action: 'draft', path: `courses/${id}`, campus: 'goa', at: serverTimestamp(),
  });
  return b.commit();
}

function publish(db, actor, version) {
  const b = writeBatch(db);
  const a = doc(collection(db, 'audit'));
  b.set(doc(db, 'catalog', `v${version}`), { version, schema: 1, json: '{}' });
  b.set(doc(db, 'catalog', 'marker'), { version, schema: 1, auditId: a.id });
  b.set(a, {
    actor: { email: actor, name: name(actor), role: 'owner' },
    action: 'publish', path: 'catalog/marker', campus: 'all', at: serverTimestamp(),
  });
  return b.commit();
}

describe('catalogue', () => {
  test('owners draft anything; presidents their own department', async () => {
    await assertSucceeds(draft(as(OWNER), OWNER, 'CS F211', { credits: 4 }));
    await assertSucceeds(draft(as(PRES), PRES, 'EEE F111', { title: 'Electrical Sciences' }));
    await assertFails(draft(as(PRES), PRES, 'CS F211', { credits: 3 }));
    await assertFails(draft(as(STUDENT), STUDENT, 'CS F211', { credits: 3 }));
  });

  test('only an owner publishes, and the marker names the new version', async () => {
    await seed((db) => setDoc(doc(db, 'catalog', 'marker'), { version: 3, schema: 1 }));
    await assertFails(publish(as(PRES), PRES, 4));
    await assertSucceeds(publish(as(OWNER), OWNER, 4));
    // A published version is never rewritten.
    await assertFails(setDoc(doc(as(OWNER), 'catalog', 'v4'), { version: 4, schema: 1, json: '[]' }));
  });
});
