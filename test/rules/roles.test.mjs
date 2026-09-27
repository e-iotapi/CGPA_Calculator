// firestore.rules for owners, grants, the staff index, the audit log, people
// and config (ARCHITECTURE.md §4, §9 step 5), against the emulator.
//   cd test/rules && npm install && npm test
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Timestamp,
  collection,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

const OWNER = 'owner@gmail.com';
const ADMIN = 'f20200001@pilani.bits-pilani.ac.in';
const PRES = 'f20230802@goa.bits-pilani.ac.in'; // ELEC president, Goa
const STUDENT = 'f20230456@goa.bits-pilani.ac.in';
const OTHER = 'f20230119@hyderabad.bits-pilani.ac.in';
const FACULTY = 'rmenon@goa.bits-pilani.ac.in';
const NEVER = 'f20239999@goa.bits-pilani.ac.in'; // never signed in

let env;
const days = (n) => Timestamp.fromMillis(Date.now() + n * 864e5);
const name = (email) => `Name of ${email.split('@')[0]}`;

function as(email) {
  return env
    .authenticatedContext(email, { email, email_verified: true, name: name(email) })
    .firestore();
}

async function seed(fn) {
  await env.withSecurityRulesDisabled((c) => fn(c.firestore()));
}

const grantId = (g) => `${g.role}|${g.campus}|${g.scope}|${g.email}`;

/// One appointment: the grant, the staff index and the audit entry, in one
/// batch — the shape the app writes.
function appoint(db, actor, g, staff, { audit = true, auditPath } = {}) {
  const id = grantId(g);
  const b = writeBatch(db);
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

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-pointer',
    firestore: {
      rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'),
      host: '127.0.0.1',
      port: 8085,
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

describe('people', () => {
  test('a user writes only their own entry', async () => {
    await assertSucceeds(setDoc(doc(as(NEVER), 'people', NEVER), { name: 'Me', campus: 'goa', firstSignIn: 1 }));
    await assertFails(setDoc(doc(as(STUDENT), 'people', NEVER), { name: 'Me', campus: 'goa', firstSignIn: 1 }));
    await assertFails(setDoc(doc(as(NEVER), 'people', NEVER), { name: 'Me', campus: 'pilani', firstSignIn: 1 }));
  });

  test('checked by owners, admins and presidents; never browsed', async () => {
    await assertSucceeds(getDoc(doc(as(OWNER), 'people', STUDENT)));
    await assertSucceeds(getDoc(doc(as(PRES), 'people', STUDENT)));
    await assertFails(getDoc(doc(as(STUDENT), 'people', OTHER)));
    await assertFails(getDocs(collection(as(OWNER), 'people')));
  });
});

describe('grants', () => {
  const cr = { role: 'course', campus: 'goa', scope: 'EEE F211', email: STUDENT };
  const pres = { role: 'dept', campus: 'goa', scope: 'CS', programme: 'A7', email: STUDENT };

  test('a president appoints a CR in their department, with index and audit', async () => {
    await assertSucceeds(appoint(as(PRES), PRES, cr, { courses: ['EEE F211'] }));
    // INSTR is ELEC too.
    await assertSucceeds(
      appoint(as(PRES), PRES, { ...cr, scope: 'INSTR F311' }, { courses: ['EEE F211', 'INSTR F311'] }),
    );
  });

  test('without the audit entry, or the index, or an agreeing index: refused', async () => {
    await assertFails(appoint(as(PRES), PRES, cr, { courses: ['EEE F211'] }, { audit: false }));
    await assertFails(appoint(as(PRES), PRES, cr, null));
    await assertFails(appoint(as(PRES), PRES, cr, { courses: [] }));
    await assertFails(appoint(as(PRES), PRES, cr, { courses: ['EEE F211', 'CS F211'] }));
    await assertFails(appoint(as(PRES), PRES, cr, { courses: ['EEE F211'] }, { auditPath: 'grants/x' }));
  });

  test('a president stays in their department, campus and tier', async () => {
    await assertFails(appoint(as(PRES), PRES, { ...cr, scope: 'CS F211' }, { courses: ['CS F211'] }));
    await assertFails(
      appoint(as(PRES), PRES, { ...cr, campus: 'hyderabad', email: OTHER }, { courses: ['EEE F211'] }),
    );
    await assertFails(appoint(as(PRES), PRES, pres, { presidentOf: ['CS'] }));
  });

  test('only students on the grant\'s campus, who have signed in', async () => {
    await assertFails(appoint(as(PRES), PRES, { ...cr, email: FACULTY }, { courses: ['EEE F211'] }));
    await assertFails(appoint(as(PRES), PRES, { ...cr, email: NEVER }, { courses: ['EEE F211'] }));
    await assertFails(appoint(as(OWNER), OWNER, { ...pres, campus: 'hyderabad' }, { presidentOf: ['CS'] }));
  });

  test('admins appoint presidents; only owners appoint admins', async () => {
    await assertSucceeds(appoint(as(ADMIN), ADMIN, pres, { presidentOf: ['CS'] }));
    const admin = { role: 'admin', campus: 'all', scope: 'all', email: STUDENT };
    await assertFails(appoint(as(ADMIN), ADMIN, admin, { admin: true }));
    await assertSucceeds(appoint(as(OWNER), OWNER, admin, { admin: true }));
  });

  test('a grant cannot outlast its term', async () => {
    const db = as(PRES);
    const id = grantId(cr);
    const b = writeBatch(db);
    const a = doc(collection(db, 'audit'));
    b.set(doc(db, 'grants', id), {
      ...cr, name: name(STUDENT), active: true, expiresAt: days(200),
      grantedBy: { email: PRES }, grantedAt: serverTimestamp(), auditId: a.id,
    });
    b.set(doc(db, 'staff', STUDENT), {
      email: STUDENT, campus: 'goa', owner: false, admin: false, presidentOf: [], courses: ['EEE F211'],
      expiresAt: days(200), lastGrant: id,
    });
    b.set(a, {
      actor: { email: PRES, name: name(PRES), role: 'president' }, action: 'grant',
      path: `grants/${id}`, campus: 'goa', at: serverTimestamp(),
    });
    await assertFails(b.commit());
  });

  test('an expired president can no longer appoint', async () => {
    await seed((db) => setDoc(doc(db, 'grants', `dept|goa|ELEC|${PRES}`), { expiresAt: days(-1) }, { merge: true }));
    await assertFails(appoint(as(PRES), PRES, cr, { courses: ['EEE F211'] }));
  });

  test('a president revokes a CR, and cannot revoke a president', async () => {
    await appoint(as(PRES), PRES, cr, { courses: ['EEE F211'] });
    const revoke = (db, actor, g, staff) => {
      const id = grantId(g);
      const b = writeBatch(db);
      const a = doc(collection(db, 'audit'));
      b.update(doc(db, 'grants', id), { active: false, auditId: a.id });
      b.update(doc(db, 'staff', g.email), { ...staff, lastGrant: id });
      b.set(a, {
        actor: { email: actor, name: name(actor), role: 'x' }, action: 'revoke',
        path: `grants/${id}`, campus: g.campus, at: serverTimestamp(),
      });
      return b.commit();
    };
    await assertFails(revoke(as(PRES), PRES, cr, { courses: ['EEE F211'] }));
    await assertSucceeds(revoke(as(PRES), PRES, cr, { courses: [] }));
    const self = { role: 'dept', campus: 'goa', scope: 'ELEC', email: PRES };
    await assertFails(revoke(as(PRES), PRES, self, { presidentOf: [] }));
    await assertSucceeds(revoke(as(ADMIN), ADMIN, self, { presidentOf: [] }));
  });

  test('nobody writes their own staff index to look like a president', async () => {
    await assertFails(
      setDoc(doc(as(STUDENT), 'staff', STUDENT), {
        email: STUDENT, campus: 'goa', presidentOf: ['ELEC'], courses: [], admin: false, owner: false,
        expiresAt: days(10), lastGrant: `dept|goa|ELEC|${PRES}`,
      }),
    );
  });
});

describe('the roster and the audit log', () => {
  test('presidents read their campus; students and other campuses do not', async () => {
    await appoint(as(PRES), PRES, { role: 'course', campus: 'goa', scope: 'EEE F211', email: STUDENT }, { courses: ['EEE F211'] });
    const goa = (db) => query(collection(db, 'grants'), where('campus', '==', 'goa'));
    await assertSucceeds(getDocs(goa(as(PRES))));
    await assertSucceeds(getDocs(goa(as(ADMIN))));
    await assertFails(getDocs(goa(as(STUDENT))));
    await assertFails(getDocs(goa(as(OTHER))));
    const hyd = query(collection(as(PRES), 'grants'), where('campus', '==', 'hyderabad'));
    await assertFails(getDocs(hyd));
    const mine = query(collection(as(STUDENT), 'grants'), where('email', '==', STUDENT));
    await assertSucceeds(getDocs(mine));
    await assertSucceeds(getDocs(query(collection(as(PRES), 'audit'), where('campus', '==', 'goa'))));
    await assertFails(getDocs(query(collection(as(STUDENT), 'audit'), where('campus', '==', 'goa'))));
  });

  test('audit entries cannot be forged or orphaned', async () => {
    const db = as(PRES);
    await assertFails(
      setDoc(doc(db, 'audit', 'x'), {
        actor: { email: OWNER, name: name(OWNER) }, action: 'x', path: 'config/public', campus: 'goa', at: serverTimestamp(),
      }),
    );
    await assertFails(
      setDoc(doc(db, 'audit', 'y'), {
        actor: { email: PRES, name: name(PRES) }, action: 'x', path: 'config/public', campus: 'goa', at: serverTimestamp(),
      }),
    );
  });
});

describe('owners', () => {
  const addOwner = (db, actor, email, data) => {
    const b = writeBatch(db);
    const a = doc(collection(db, 'audit'));
    b.set(doc(db, 'owners', email), { auditId: a.id, ...data });
    b.set(a, {
      actor: { email: actor, name: name(actor), role: 'owner' }, action: 'owner',
      path: `owners/${email}`, campus: 'all', at: serverTimestamp(),
    });
    return b.commit();
  };

  test('an owner adds an owner; nobody else can', async () => {
    const data = { email: 'two@gmail.com', name: 'Two', active: true, addedBy: { email: OWNER, name: name(OWNER) }, addedAt: serverTimestamp() };
    await assertSucceeds(addOwner(as(OWNER), OWNER, 'two@gmail.com', data));
    await assertFails(addOwner(as(ADMIN), ADMIN, 'three@gmail.com', { ...data, email: 'three@gmail.com', addedBy: { email: ADMIN } }));
  });

  test('an owner never deactivates themselves', async () => {
    const off = (db, actor, email) => {
      const b = writeBatch(db);
      const a = doc(collection(db, 'audit'));
      b.update(doc(db, 'owners', email), { active: false, auditId: a.id });
      b.set(a, {
        actor: { email: actor, name: name(actor), role: 'owner' }, action: 'owner',
        path: `owners/${email}`, campus: 'all', at: serverTimestamp(),
      });
      return b.commit();
    };
    await assertFails(off(as(OWNER), OWNER, OWNER));
    await seed((db) => setDoc(doc(db, 'owners', 'two@gmail.com'), { email: 'two@gmail.com', active: true }));
    await assertSucceeds(off(as(OWNER), OWNER, 'two@gmail.com'));
  });
});

describe('config', () => {
  const write = (db, actor, id, data) => {
    const b = writeBatch(db);
    const a = doc(collection(db, 'audit'));
    b.set(doc(db, 'config', id), { ...data, auditId: a.id });
    b.set(a, {
      actor: { email: actor, name: name(actor), role: 'x' }, action: 'config',
      path: `config/${id}`, campus: 'all', at: serverTimestamp(),
    });
    return b.commit();
  };

  test('admins change CR and president terms, not the admin term', async () => {
    await assertSucceeds(write(as(ADMIN), ADMIN, 'grantTerms', { crDays: 150, presidentDays: 365, adminDays: 730 }));
    await assertFails(write(as(ADMIN), ADMIN, 'grantTerms', { crDays: 150, presidentDays: 365, adminDays: 900 }));
    await assertSucceeds(write(as(OWNER), OWNER, 'grantTerms', { crDays: 150, presidentDays: 365, adminDays: 900 }));
    await assertFails(write(as(PRES), PRES, 'grantTerms', { crDays: 150, presidentDays: 365, adminDays: 730 }));
  });

  test('public contact: owners and admins', async () => {
    const c = { contactName: 'S', contactMethod: 'whatsapp', contactTarget: '+91', contactEnabled: true };
    await assertSucceeds(write(as(ADMIN), ADMIN, 'public', c));
    await assertFails(write(as(PRES), PRES, 'public', c));
    await assertSucceeds(getDoc(doc(as(STUDENT), 'config', 'public')));
  });
});
