// Shared setup for the rules tests: the emulator, the seeded people and
// grants, and an appointment written the way the app writes it.
import { readFileSync } from 'node:fs';
import { after, before, beforeEach } from 'node:test';
import { initializeTestEnvironment } from '@firebase/rules-unit-testing';
import {
  Timestamp,
  collection,
  doc,
  getDoc,
  getDocs,
  increment,
  query,
  serverTimestamp,
  setDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

export const OWNER = 'owner@gmail.com';
export const ADMIN = 'f20200001@pilani.bits-pilani.ac.in';
export const PRES = 'f20230802@goa.bits-pilani.ac.in'; // ELEC president, Goa
export const STUDENT = 'f20230456@goa.bits-pilani.ac.in';
export const OTHER = 'f20230119@hyderabad.bits-pilani.ac.in';
export const FACULTY = 'rmenon@goa.bits-pilani.ac.in';
export const NEVER = 'f20239999@goa.bits-pilani.ac.in'; // never signed in

export let env;
export const days = (n) => Timestamp.fromMillis(Date.now() + n * 864e5);
export const name = (email) => `Name of ${email.split('@')[0]}`;

export function as(email) {
  return env
    .authenticatedContext(email, { email, email_verified: true, name: name(email) })
    .firestore();
}

export async function seed(fn) {
  await env.withSecurityRulesDisabled((c) => fn(c.firestore()));
}

/// In a batch: moves [path]'s marker on [campus]'s head by one (the app's
/// bumpPath). Campus 'all' is the goa head, where the rules check owners,
/// terms and admin grants; the app bumps every head.
export function bump(b, db, campus, path, by = 1) {
  b.set(doc(db, 'heads', campus === 'all' ? 'goa' : campus), { v: { [path]: increment(by) } }, { merge: true });
}

/// One doc written with its marker bump, in one batch.
export function putBumped(db, campus, path, ref, data) {
  const b = writeBatch(db);
  b.set(ref, data);
  bump(b, db, campus, path);
  return b.commit();
}

export const grantId = (g) => `${g.role}|${g.campus}|${g.scope}|${g.email}`;

/// One appointment: the grant, the staff index and the audit entry, in one
/// batch — the shape the app writes.
export function appoint(db, actor, g, staff, { audit = true, auditPath, marker = true } = {}) {
  const id = grantId(g);
  const b = writeBatch(db);
  if (marker) bump(b, db, g.campus, 'grants');
  const a = doc(collection(db, 'audit'));
  b.set(doc(db, 'grants', id), {
    name: name(g.email),
    active: true,
    expiresAt: days(100),
    grantedBy: { email: actor, name: name(actor) },
    grantedAt: serverTimestamp(),
    auditId: a.id,
    ...g,
  });
  if (staff !== null) {
    b.set(doc(db, 'staff', g.email), {
      name: name(g.email),
      email: g.email,
      campus: g.campus,
      owner: false,
      admin: false,
      presidentOf: [],
      courses: [],
      expiresAt: days(100),
      lastGrant: id,
      ...staff,
    });
  }
  if (audit) {
    b.set(a, {
      actor: { email: actor, name: name(actor), role: 'test' },
      action: 'grant',
      path: auditPath ?? `grants/${id}`,
      campus: g.campus,
      before: null,
      after: g.role,
      at: serverTimestamp(),
    });
  }
  return b.commit();
}

/// Registers the emulator hooks and the seed every test starts from.
export function useEmulator() {
before(async () => {
  env = await initializeTestEnvironment({
    projectId: process.env.RULES_PROJECT ?? 'demo-pointer', // warm runs use their own, sparing up.sh's seed
    firestore: {
      rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'),
      host: '127.0.0.1',
      port: Number(process.env.RULES_PORT ?? 8085),
    },
  });
});

after(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await seed(async (db) => {
    await setDoc(doc(db, 'owners', OWNER), { email: OWNER, name: name(OWNER), active: true });
    await setDoc(doc(db, 'config', 'grantTerms'), { crDays: 183, presidentDays: 365, adminDays: 730 });
    for (const e of [ADMIN, PRES, STUDENT, OTHER, FACULTY]) {
      await setDoc(doc(db, 'people', e), { name: name(e), campus: e.split('@')[1].split('.')[0], firstSignIn: 1 });
    }
    const live = { active: true, expiresAt: days(100) };
    await setDoc(doc(db, 'grants', `admin|all|all|${ADMIN}`), {
      role: 'admin', campus: 'all', scope: 'all', email: ADMIN, name: name(ADMIN), ...live,
    });
    await setDoc(doc(db, 'staff', ADMIN), {
      email: ADMIN, campus: 'all', admin: true, presidentOf: [], courses: [], owner: false, expiresAt: days(100),
    });
    await setDoc(doc(db, 'grants', `dept|goa|ELEC|${PRES}`), {
      role: 'dept', campus: 'goa', scope: 'ELEC', programme: 'A3', email: PRES, name: name(PRES), ...live,
    });
    await setDoc(doc(db, 'staff', PRES), {
      email: PRES, campus: 'goa', admin: false, presidentOf: ['ELEC'], courses: [], owner: false, expiresAt: days(100),
    });
  });
});
}
