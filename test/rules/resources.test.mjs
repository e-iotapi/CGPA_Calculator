// firestore.rules for resources, their version marker, reports and flags
// (ARCHITECTURE.md §6, §16.3 fixes 3 and 17).
import { createHash } from 'node:crypto';
import { describe, test } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { collection, doc, getDoc, getDocs, query, serverTimestamp, setDoc, where, writeBatch } from 'firebase/firestore';
import { ADMIN, OTHER, OWNER, PRES, STUDENT, as, bump as mark, days, name, seed, useEmulator } from './helpers.mjs';

useEmulator();

const CR = 'f20240010@goa.bits-pilani.ac.in';
const hash = (uid, rid) => createHash('sha256').update(uid + rid).digest('hex');

async function withCr() {
  await seed(async (db) => {
    await setDoc(doc(db, 'grants', `course|goa|EEE F211|${CR}`), {
      role: 'course', campus: 'goa', scope: 'EEE F211', email: CR, name: name(CR), active: true, expiresAt: days(100),
    });
    await setDoc(doc(db, 'staff', CR), {
      email: CR, campus: 'goa', admin: false, presidentOf: [], courses: ['EEE F211'], owner: false, expiresAt: days(100),
    });
  });
}

function base(extra = {}) {
  return {
    title: 'Tutorial sheets',
    url: 'https://drive.google.com/drive/folders/abc',
    host: 'drive.google.com',
    kind: 'folder',
    campus: 'goa',
    department: 'ELEC',
    scope: 'department',
    courseIds: [],
    pinnedToDepartment: false,
    removed: false,
    actingFor: '',
    ...extra,
  };
}

/// A resource write the way the app makes it: resource, audit, version bump.
async function put(db, actor, id, data, { update = false, bump = true, auditPath, link, campus = data.campus ?? 'goa' } = {}) {
  const b = writeBatch(db);
  const a = doc(collection(db, 'audit'));
  const ref = doc(db, 'resources', id);
  if (update) {
    b.update(ref, { ...data, auditId: a.id });
  } else {
    b.set(ref, {
      ...data,
      addedBy: { email: actor, name: name(actor) },
      addedAt: serverTimestamp(),
      auditId: a.id,
    });
  }
  b.set(a, {
    actor: { email: actor, name: name(actor), role: 'test' },
    action: 'resource', path: auditPath ?? `resources/${id}`, campus, at: serverTimestamp(),
  });
  mark(b, db, campus, 'resources');
  if (bump) {
    const v = (await getDoc(doc(db, 'resourceVersions', campus))).data()?.v ?? 0;
    const copy = link ?? (update ? null : (({ title, url, department, scope, courseIds, pinnedToDepartment }) =>
      ({ title, url, department, scope, courseIds, pinnedToDepartment }))(data));
    b.set(doc(db, 'resourceVersions', campus),
      copy ? { v: v + 1, k: id, links: { [id]: copy } } : { v: v + 1 }, { merge: true });
  }
  return b.commit();
}

async function existing(id, data) {
  await seed(async (db) => {
    await setDoc(doc(db, 'resources', id), {
      ...base(data), addedBy: { email: PRES, name: name(PRES) }, addedAt: new Date(), auditId: 'x',
    });
    await setDoc(doc(db, 'resourceVersions', 'goa'), { v: 5 });
  });
}

function report(db, uid, rid, count, reason = 'broken') {
  const b = writeBatch(db);
  b.set(doc(db, 'resourceReports', rid, 'entries', hash(uid, rid)), {
    reason, campus: 'goa', createdAt: serverTimestamp(),
  });
  b.set(doc(db, 'resourceFlags', rid), {
    campus: 'goa', department: 'ELEC', courseIds: [], open: true, count, reasons: { [reason]: count }, lastAt: serverTimestamp(),
  });
  return b.commit();
}

describe('resources', () => {
  test('a president adds to their department; any http(s) website', async () => {
    await assertSucceeds(put(as(PRES), PRES, 'r1', base()));
    await assertSucceeds(put(as(PRES), PRES, 'r2', base({ url: 'https://en.wikipedia.org/wiki/X' })));
    await assertSucceeds(put(as(PRES), PRES, 'r3', base({ url: 'http://example.edu/notes.pdf' })));
    await assertFails(put(as(PRES), PRES, 'r6', base({ url: 'javascript:alert(1)' })));
    await assertFails(put(as(PRES), PRES, 'r7', base({ url: 'https://localhost/x' })));
    await assertFails(put(as(PRES), PRES, 'r8', base({ url: 'ftp://files.example.com/x' })));
    await assertFails(put(as(PRES), PRES, 'r4', base({ department: 'CS' })));
    await assertFails(put(as(STUDENT), STUDENT, 'r5', base()));
  });

  test('every write moves the campus version and is audited', async () => {
    await assertFails(put(as(PRES), PRES, 'r1', base(), { bump: false }));
    await assertFails(put(as(PRES), PRES, 'r1', base(), { auditPath: 'resources/other' }));
  });

  test('the campus copy of a link matches the link', async () => {
    const b = base();
    await assertFails(put(as(PRES), PRES, 'r1', b, { link: { ...b, url: 'https://evil.example.com/' } }));
    await assertSucceeds(put(as(PRES), PRES, 'r1', b));
    const v = await getDoc(doc(as(STUDENT), 'resourceVersions', 'goa'));
    if (v.data().links.r1.url !== b.url) throw new Error('no copy');
  });

  test('a CR adds course links for their own course only', async () => {
    await withCr();
    const course = { scope: 'course', courseIds: ['EEE F211'], actingFor: 'EEE F211', pinnedToDepartment: true };
    await assertSucceeds(put(as(CR), CR, 'c1', base(course)));
    await assertFails(put(as(CR), CR, 'c2', base({ ...course, courseIds: ['EEE F212'], actingFor: 'EEE F212' })));
    await assertFails(put(as(CR), CR, 'c3', base()));
  });

  test('a CR picks a department link without editing it', async () => {
    await withCr();
    await existing('d1', {});
    await assertSucceeds(put(as(CR), CR, 'd1', { courseIds: ['EEE F211'], actingFor: 'EEE F211' }, { update: true }));
    await assertFails(put(as(CR), CR, 'd1', { title: 'Mine now', actingFor: 'EEE F211' }, { update: true }));
  });

  test('an admin adds and edits links on their own campus only', async () => {
    const pilani = base({ campus: 'pilani' });
    await assertSucceeds(put(as(ADMIN), ADMIN, 'a1', pilani));
    await assertSucceeds(put(as(ADMIN), ADMIN, 'a1', { title: 'Renamed' }, { update: true, campus: 'pilani' }));
    await assertFails(put(as(ADMIN), ADMIN, 'a2', base()));
    await existing('d1', {});
    await assertFails(put(as(ADMIN), ADMIN, 'd1', { title: 'Renamed' }, { update: true }));
  });

  test('read on the same campus only', async () => {
    await existing('d1', {});
    await assertSucceeds(getDocs(query(collection(as(STUDENT), 'resources'), where('campus', '==', 'goa'), where('department', '==', 'ELEC'))));
    await assertFails(getDoc(doc(as(OTHER), 'resources', 'd1')));
  });
});

describe('reports', () => {
  test('one report per person, pseudonymous, counted by one', async () => {
    await existing('d1', {});
    await assertSucceeds(report(as(STUDENT), STUDENT, 'd1', 1));
    await assertFails(report(as(STUDENT), STUDENT, 'd1', 2));
    await assertFails(report(as(CR), CR, 'd1', 5));
    await assertSucceeds(report(as(CR), CR, 'd1', 2));
    await assertFails(report(as(OTHER), OTHER, 'd1', 3));
  });

  test('the fixers list and dismiss; students do not', async () => {
    await existing('d1', {});
    await report(as(STUDENT), STUDENT, 'd1', 1);
    const open = (db) => getDocs(query(collection(db, 'resourceFlags'),
      where('campus', '==', 'goa'), where('department', '==', 'ELEC'), where('open', '==', true)));
    await assertSucceeds(open(as(PRES)));
    await assertFails(open(as(STUDENT)));

    const dismiss = (db, actor) => {
      const b = writeBatch(db);
      const a = doc(collection(db, 'audit'));
      b.update(doc(db, 'resourceFlags', 'd1'), { open: false, auditId: a.id });
      b.set(a, { actor: { email: actor, name: name(actor), role: 'test' }, action: 'dismiss', path: 'resourceFlags/d1', campus: 'goa', at: serverTimestamp() });
      return b.commit();
    };
    await assertFails(dismiss(as(STUDENT), STUDENT));
    await assertSucceeds(dismiss(as(PRES), PRES));
  });
});
