// firestore.rules for GEN (the electives department) and courseClaims (B2).
import { test } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { collection, doc, getDoc, serverTimestamp, setDoc, writeBatch } from 'firebase/firestore';
import { ADMIN, OWNER, PRES, STUDENT, appoint, as, bump, name, seed, useEmulator } from './helpers.mjs';

useEmulator();

const GEN = { role: 'dept', campus: 'goa', scope: 'GEN', email: STUDENT };
const GENSTAFF = { presidentOf: ['GEN'] };
const COURSE = 'BITS F225';
const cid = `goa|${COURSE}`;
const AT = Date.now() - 100000; // when the seeded claim was made

const claim = (db, actor, { dept = 'ELEC', course = COURSE, audit = true, marker = true } = {}) => {
  const b = writeBatch(db);
  const a = doc(collection(db, 'audit'));
  b.set(doc(db, 'courseClaims', `goa|${course}`), {
    campus: 'goa', courseId: course, dept, by: { email: actor, name: name(actor) },
    at: serverTimestamp(), auditId: a.id,
  });
  if (audit) {
    b.set(a, {
      actor: { email: actor, name: name(actor), role: 'test' }, action: 'claim',
      path: `courseClaims/goa|${course}`, campus: 'goa', before: null, after: dept, at: serverTimestamp(),
    });
  }
  if (marker) bump(b, db, 'goa', 'courseClaims');
  return b.commit();
};

const unclaim = async (db, actor, { marker = true } = {}) => {
  const b = writeBatch(db);
  b.set(doc(db, 'audit', `del|${cid}|${AT}`), {
    actor: { email: actor, name: name(actor), role: 'test' }, action: 'unclaim',
    path: `courseClaims/${cid}`, campus: 'goa', before: 'ELEC', after: null, at: serverTimestamp(),
  });
  b.delete(doc(db, 'courseClaims', cid));
  if (marker) bump(b, db, 'goa', 'courseClaims');
  return { b };
};

const seedClaim = (dept = 'ELEC') =>
  seed((db) => setDoc(doc(db, 'courseClaims', cid), {
    campus: 'goa', courseId: COURSE, dept, by: { email: PRES, name: name(PRES) },
    at: { seconds: 1000, nanoseconds: 0 }, auditId: 'x',
  }));

test('owner and admin appoint an Elective Contributor; a president or student cannot', async () => {
  await assertSucceeds(appoint(as(OWNER), OWNER, GEN, GENSTAFF));
  await assertFails(appoint(as(PRES), PRES, GEN, GENSTAFF));
  await assertFails(appoint(as(STUDENT), STUDENT, GEN, GENSTAFF));
});

test('an admin appoints an Elective Contributor too', async () => {
  await assertSucceeds(appoint(as(ADMIN), ADMIN, GEN, GENSTAFF));
});

test('a GEN grant takes no programme', async () => {
  await assertFails(appoint(as(OWNER), OWNER, { ...GEN, programme: 'A3' }, GENSTAFF));
});

test('a department president claims a GEN course, audited and marked', async () => {
  await assertSucceeds(claim(as(PRES), PRES));
});

test('claims need the audit, the marker, a GEN-prefix course and a real department', async () => {
  await assertFails(claim(as(PRES), PRES, { audit: false }));
  await assertFails(claim(as(PRES), PRES, { marker: false }));
  await assertFails(claim(as(PRES), PRES, { course: 'EEE F111' }));
  // deptOf reads the prefix trimmed and upper-cased, as the app does (#9).
  await assertFails(claim(as(PRES), PRES, { course: 'eee F111' }));
  await assertFails(claim(as(PRES), PRES, { course: ' EEE F111' }));
  await assertFails(claim(as(PRES), PRES, { dept: 'GEN' }));
  await assertFails(claim(as(PRES), PRES, { dept: 'CS' })); // not their department
});

test('students and a GEN contributor cannot claim', async () => {
  await assertFails(claim(as(STUDENT), STUDENT));
  await appoint(as(OWNER), OWNER, GEN, GENSTAFF);
  await assertFails(claim(as(STUDENT), STUDENT, { dept: 'GEN' }));
});

test('a claim is read by signed-in people, never edited', async () => {
  await seedClaim();
  await assertSucceeds(getDoc(doc(as(STUDENT), 'courseClaims', cid)));
  await assertFails(setDoc(doc(as(PRES), 'courseClaims', cid), { dept: 'CS' }, { merge: true }));
});

test('the claiming department unclaims with a derived audit id', async () => {
  await seed((db) => setDoc(doc(db, 'courseClaims', cid), {
    campus: 'goa', courseId: COURSE, dept: 'ELEC', by: { email: PRES, name: name(PRES) },
    at: new Date(AT), auditId: 'x',
  }));
  const { b } = await unclaim(as(PRES), PRES);
  await assertSucceeds(b.commit());
});

test('unclaim needs the marker; another department cannot unclaim', async () => {
  await seed((db) => setDoc(doc(db, 'courseClaims', cid), {
    campus: 'goa', courseId: COURSE, dept: 'ELEC', by: { email: PRES, name: name(PRES) },
    at: new Date(AT), auditId: 'x',
  }));
  await assertFails((await unclaim(as(PRES), PRES, { marker: false })).b.commit());
  await assertFails((await unclaim(as(STUDENT), STUDENT)).b.commit());
});

test('the claimant, not GEN, manages the claimed course', async () => {
  // A president of the claimant may now appoint a CR for it; before, only GEN.
  const cr = { role: 'course', campus: 'goa', scope: COURSE, email: STUDENT };
  const staff = { courses: [COURSE] };
  await assertFails(appoint(as(PRES), PRES, cr, staff));
  await seedClaim('ELEC');
  await assertSucceeds(appoint(as(PRES), PRES, cr, staff));
});
