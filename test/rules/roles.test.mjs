// firestore.rules for owners, grants, the staff index, the audit log, people
// and config (ARCHITECTURE.md §4, §9 step 5), against the emulator.
//   cd test/rules && npm install && npm test
import { describe, test } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
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
import {
  ADMIN, FACULTY, NEVER, OTHER, OWNER, PRES, STUDENT,
  appoint, as, days, grantId, name, seed, useEmulator,
} from './helpers.mjs';

useEmulator();

describe('people', () => {
  test('a faculty address is refused a read and a write; student and owner pass', async () => {
    const F = 'testfaculty@goa.bits-pilani.ac.in';
    await assertFails(setDoc(doc(as(F), 'people', F), { name: 'Me', campus: 'goa', firstSignIn: 1 }));
    await assertFails(getDoc(doc(as(FACULTY), 'config', 'grantTerms')));
    await assertSucceeds(getDoc(doc(as(STUDENT), 'config', 'grantTerms')));
    await assertSucceeds(getDoc(doc(as(OWNER), 'config', 'grantTerms')));
  });

  test('a user writes only their own entry', async () => {
    await assertSucceeds(setDoc(doc(as(NEVER), 'people', NEVER), { name: 'Me', campus: 'goa', firstSignIn: 1 }));
    await assertFails(setDoc(doc(as(STUDENT), 'people', NEVER), { name: 'Me', campus: 'goa', firstSignIn: 1 }));
    await assertFails(setDoc(doc(as(NEVER), 'people', NEVER), { name: 'Me', campus: 'pilani', firstSignIn: 1 }));
  });

  test('checked by owners, admins and presidents; browsed by owners only', async () => {
    await assertSucceeds(getDoc(doc(as(OWNER), 'config', 'grantTerms')));
    await assertSucceeds(getDoc(doc(as(PRES), 'people', STUDENT)));
    await assertFails(getDoc(doc(as(STUDENT), 'people', OTHER)));
    // Owners list people for site analytics' count(), which rules treat
    // as a listing; nobody else browses.
    await assertSucceeds(getDocs(collection(as(OWNER), 'people')));
    await assertFails(getDocs(collection(as(ADMIN), 'people')));
    await assertFails(getDocs(collection(as(PRES), 'people')));
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

  test('a president appoints a secretary, who cannot appoint another', async () => {
    const S3 = 'f20230777@goa.bits-pilani.ac.in';
    await seed((db) => setDoc(doc(db, 'people', S3), { name: name(S3), campus: 'goa', firstSignIn: 1 }));
    const sec = { role: 'dept', campus: 'goa', scope: 'ELEC', email: STUDENT, secretary: true };
    await assertFails(appoint(as(PRES), PRES, { ...sec, programme: 'A3' }, { presidentOf: ['ELEC'] }));
    await assertFails(appoint(as(PRES), PRES, { ...sec, scope: 'CS' }, { presidentOf: ['CS'] }));
    await assertSucceeds(appoint(as(PRES), PRES, sec, { presidentOf: ['ELEC'] }));
    // The secretary appoints CRs like a president, never a secretary.
    const cr = { role: 'course', campus: 'goa', scope: 'EEE F211', email: S3 };
    await assertSucceeds(appoint(as(STUDENT), STUDENT, cr, { courses: ['EEE F211'] }));
    await assertFails(appoint(as(STUDENT), STUDENT, { ...sec, email: S3 }, { presidentOf: ['ELEC'] }));
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

  // RoleStore.appoint() first get()s the grant doc to tell a fresh
  // appointment from a renewal; that doc does not exist yet for a first
  // appointment. A get() on a not-yet-existing grant must not error
  // (BUG-02/BUG-49: readsRoster() used to dereference resource.data
  // unconditionally, so any non-owner/admin appointer's pre-read failed).
  test('a get() on a not-yet-existing grant does not error', async () => {
    const id = `course|goa|EEE F211|${STUDENT}`;
    await assertSucceeds(getDoc(doc(as(PRES), 'grants', id)));
    await assertSucceeds(getDoc(doc(as(ADMIN), 'grants', id)));
    // Nothing to leak when there is no document: any mayUse() reader may
    // see that it is absent.
    await assertSucceeds(getDoc(doc(as(OTHER), 'grants', id)));
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
