// firestore.rules for succession, contact details, the directory and CR
// volunteers (ARCHITECTURE.md §13.4, §13.5, §16.3 fixes 8 and 16).
import { describe, test } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  Timestamp,
  collection,
  deleteField,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';
import {
  ADMIN, NEVER, OTHER, OWNER, PRES, STUDENT,
  appoint, as, bump, days, name, putBumped, seed, useEmulator,
} from './helpers.mjs';

useEmulator();

const mine = `dept|goa|ELEC|${PRES}`;
const theirs = `dept|goa|ELEC|${STUDENT}`;

function audit(b, db, path) {
  const a = doc(collection(db, 'audit'));
  b.set(a, {
    actor: { email: PRES, name: name(PRES), role: 'president' },
    action: 'grant', path, campus: 'goa', at: serverTimestamp(),
  });
  return a.id;
}

/// The handover batch the app writes; [ends] is the outgoing expiry.
function handOver(ends, { to = STUDENT, extend, secretary } = {}) {
  const db = as(PRES);
  const b = writeBatch(db);
  const next = `dept|goa|ELEC|${to}`;
  b.set(doc(db, 'grants', next), {
    role: 'dept', campus: 'goa', scope: 'ELEC', programme: 'A3', email: to,
    name: name(to), active: true, expiresAt: days(300),
    grantedBy: { email: PRES, name: name(PRES) }, grantedAt: serverTimestamp(),
    auditId: audit(b, db, `grants/${next}`),
  });
  b.set(doc(db, 'staff', to), {
    email: to, name: name(to), campus: 'goa', owner: false, admin: false,
    presidentOf: ['ELEC'], courses: [], expiresAt: days(300), lastGrant: next,
  });
  b.update(doc(db, 'grants', mine), {
    expiresAt: ends, handedTo: to, expiresBefore: extend ?? days(100),
    auditId: audit(b, db, `grants/${mine}`),
  });
  b.set(doc(db, 'staff', PRES), {
    email: PRES, campus: 'goa', owner: false, admin: false,
    presidentOf: ['ELEC'], courses: [], expiresAt: days(100), lastGrant: mine,
  });
  if (secretary) {
    const sec = `dept|goa|ELEC|${secretary}`;
    b.set(doc(db, 'grants', sec), {
      role: 'dept', campus: 'goa', scope: 'ELEC', programme: 'A3', email: secretary, secretary: true,
      name: name(secretary), active: true, expiresAt: days(300),
      grantedBy: { email: PRES, name: name(PRES) }, grantedAt: serverTimestamp(),
      auditId: audit(b, db, `grants/${sec}`),
    });
    b.set(doc(db, 'staff', secretary), {
      email: secretary, name: name(secretary), campus: 'goa', owner: false, admin: false,
      presidentOf: ['ELEC'], courses: [], expiresAt: days(300), lastGrant: sec,
    });
  }
  bump(b, db, 'goa', 'grants');
  return b.commit();
}

describe('succession', () => {
  test('a secretary never hands over', async () => {
    const before = days(100);
    await seed((db) => setDoc(doc(db, 'grants', mine), {
      role: 'dept', campus: 'goa', scope: 'ELEC', email: PRES, name: name(PRES),
      active: true, expiresAt: before, secretary: true,
    }));
    await assertFails(handOver(days(19.9), { extend: before }));
  });

  test('a president hands over with twenty days of overlap', async () => {
    // expiresBefore must match the grant; seed it exactly.
    const before = days(100);
    await seed((db) => updateDoc(doc(db, 'grants', mine), { expiresAt: before }));
    await assertSucceeds(handOver(days(19.9), { extend: before }));
    const g = (await getDoc(doc(as(PRES), 'grants', theirs))).data();
    if (g.active !== true) throw new Error('successor not live');
  });

  test('a handover names the next secretary in the same batch', async () => {
    const before = days(100);
    const S3 = 'f20230777@goa.bits-pilani.ac.in';
    await seed(async (db) => {
      await updateDoc(doc(db, 'grants', mine), { expiresAt: before });
      await setDoc(doc(db, 'people', S3), { name: name(S3), campus: 'goa', firstSignIn: 1 });
    });
    await assertSucceeds(handOver(days(19.9), { extend: before, secretary: S3 }));
  });

  test('the overlap never extends a term, and one runs at a time', async () => {
    const before = days(100);
    await seed((db) => updateDoc(doc(db, 'grants', mine), { expiresAt: before }));
    await assertFails(handOver(days(25), { extend: before }));
    await assertSucceeds(handOver(days(19.9), { extend: before }));
    await assertFails(handOver(days(19), { to: `f20230111@goa.bits-pilani.ac.in` }));
  });

  test('a lapsing president cannot buy more time', async () => {
    const soon = days(5);
    await seed((db) => updateDoc(doc(db, 'grants', mine), { expiresAt: soon }));
    await assertFails(handOver(days(19.9), { extend: soon }));
    await assertSucceeds(handOver(soon, { extend: soon }));
  });

  test('a student cannot hand over what they do not hold', async () => {
    const db = as(STUDENT);
    const b = writeBatch(db);
    b.set(doc(db, 'grants', `dept|goa|ELEC|${STUDENT}`), {
      role: 'dept', campus: 'goa', scope: 'ELEC', programme: 'A3', email: STUDENT,
      name: name(STUDENT), active: true, expiresAt: days(300),
      grantedBy: { email: STUDENT, name: name(STUDENT) }, grantedAt: serverTimestamp(),
    });
    await assertFails(b.commit());
  });

  test('the outgoing president cancels while the overlap runs', async () => {
    const before = days(100);
    await seed((db) => updateDoc(doc(db, 'grants', mine), { expiresAt: before }));
    await handOver(days(19.9), { extend: before });
    const db = as(PRES);
    const b = writeBatch(db);
    b.update(doc(db, 'grants', theirs), {
      active: false, auditId: audit(b, db, `grants/${theirs}`),
    });
    b.set(doc(db, 'staff', STUDENT), {
      email: STUDENT, name: name(STUDENT), campus: 'goa', owner: false, admin: false,
      presidentOf: [], courses: [], expiresAt: days(300), lastGrant: theirs,
    });
    b.update(doc(db, 'grants', mine), {
      expiresAt: before, handedTo: deleteField(), expiresBefore: deleteField(),
      auditId: audit(b, db, `grants/${mine}`),
    });
    b.set(doc(db, 'staff', PRES), {
      email: PRES, campus: 'goa', owner: false, admin: false,
      presidentOf: ['ELEC'], courses: [], expiresAt: days(100), lastGrant: mine,
    });
    bump(b, db, 'goa', 'grants');
    await assertSucceeds(b.commit());
  });

  test('a president may look up someone with no staff entry yet', async () => {
    await assertSucceeds(getDoc(doc(as(PRES), 'staff', STUDENT)));
    await assertFails(getDoc(doc(as(STUDENT), 'staff', OTHER)));
  });

  // RoleStore._relist() get()s the handing-over president's own directory
  // entry to keep its listed expiry in step; most presidents have never
  // filled one in, so the doc does not exist. A get() on a not-yet-existing
  // doc must not error (BUG-49: it used to, because the old rule
  // dereferenced resource.data unconditionally).
  test('a handover reads a not-yet-existing directory entry without erroring', async () => {
    const before = days(100);
    await seed((db) => updateDoc(doc(db, 'grants', mine), { expiresAt: before }));
    await assertSucceeds(getDoc(doc(as(PRES), 'directory', PRES)));
    await assertSucceeds(handOver(days(19.9), { extend: before }));
  });
});

describe('staff contacts', () => {
  const c = (email) => ({ name: 'P', phone: '+91 98765 43210', email, updatedAt: serverTimestamp() });
  const put = (who, data) => {
    const db = as(who);
    return putBumped(db, 'goa', 'staff', doc(db, 'staffContacts', who), data);
  };

  test('privileged roles write their own and read each other', async () => {
    await assertSucceeds(put(PRES, c(PRES)));
    await assertSucceeds(put(OWNER, c(OWNER)));
    await assertSucceeds(getDoc(doc(as(ADMIN), 'staffContacts', PRES)));
    await assertFails(getDoc(doc(as(STUDENT), 'staffContacts', PRES)));
    await assertFails(put(STUDENT, c(STUDENT)));
  });

  test('the roster lists every phone; students cannot', async () => {
    await put(PRES, c(PRES));
    await assertSucceeds(getDocs(collection(as(ADMIN), 'staffContacts')));
    await assertSucceeds(getDocs(collection(as(PRES), 'staffContacts')));
    await assertFails(getDocs(collection(as(STUDENT), 'staffContacts')));
  });

  test('a non-student BITS address counts its contact on goa', async () => {
    // Faculty on pilani: an owner may hold a staff contact; the bump is goa's.
    const fac = 'rmenon@pilani.bits-pilani.ac.in';
    await seed((db) => setDoc(doc(db, 'owners', fac), { email: fac, name: name(fac), active: true }));
    const db = as(fac);
    const data = { name: 'R', phone: '+91 98765 43210', email: fac, updatedAt: serverTimestamp() };
    await assertFails(putBumped(db, 'pilani', 'staff', doc(db, 'staffContacts', fac), data));
    await assertSucceeds(putBumped(db, 'goa', 'staff', doc(db, 'staffContacts', fac), data));
  });

  test('a phone is required', async () => {
    await assertFails(put(PRES, { ...c(PRES), phone: '' }));
    await assertFails(put(PRES, { ...c(PRES), phone: 'call me' }));
  });
});

describe('directory', () => {
  const entry = (extra) => ({
    name: 'P', campus: 'goa', updatedAt: serverTimestamp(),
    roles: [{ role: 'dept', scope: 'ELEC', until: days(100) }], ...extra,
  });

  const dir = (who, data) => {
    const db = as(who);
    return putBumped(db, 'goa', 'staff', doc(db, 'directory', who), data);
  };

  async function exactUntil() {
    const until = days(100);
    await seed((db) => updateDoc(doc(db, 'grants', mine), { expiresAt: until }));
    return until;
  }

  test('a president lists a live role with one way to reach them', async () => {
    const until = await exactUntil();
    const roles = [{ role: 'dept', scope: 'ELEC', programme: 'A3', until }];
    await assertFails(dir(PRES, entry({ roles })));
    // A president lists only the branch they were appointed for.
    const wrong = [{ ...roles[0], programme: 'A8' }];
    await assertFails(dir(PRES, entry({ roles: wrong, email: PRES })));
    await assertSucceeds(dir(PRES, entry({ roles, email: PRES })));
    await assertFails(dir(PRES, entry({ roles, email: STUDENT })));
    await assertSucceeds(getDocs(query(collection(as(STUDENT), 'directory'), where('campus', '==', 'goa'))));
    await assertFails(getDocs(query(collection(as(OTHER), 'directory'), where('campus', '==', 'goa'))));
  });

  test('the campus index holds my own entry, exactly', async () => {
    const until = await exactUntil();
    const e = entry({ roles: [{ role: 'dept', scope: 'ELEC', programme: 'A3', until }], email: PRES });
    const save = (copy, who = PRES) => {
      const db = as(who);
      const b = writeBatch(db);
      b.set(doc(db, 'directory', PRES), e);
      b.set(doc(db, 'repIndex', 'goa'), { k: who, p: { [who]: copy } }, { merge: true });
      bump(b, db, 'goa', 'staff');
      bump(b, db, 'goa', 'reps');
      return b.commit();
    };
    await assertFails(save({ ...e, name: 'Someone else' }));
    await assertSucceeds(save(e));
    await assertSucceeds(getDoc(doc(as(STUDENT), 'repIndex', 'goa')));
    await assertFails(getDoc(doc(as(OTHER), 'repIndex', 'goa')));
    const db = as(STUDENT);
    const forge = (data) => {
      const b = writeBatch(db);
      b.set(doc(db, 'repIndex', 'goa'), data, { merge: true });
      bump(b, db, 'goa', 'reps');
      return b.commit();
    };
    await assertFails(forge({ k: PRES, p: { [PRES]: { name: 'x' } } }));
    await assertFails(forge({ k: STUDENT, p: { [PRES]: { name: 'x' } } }));
  });

  test('the secretary flag must match the grant', async () => {
    const until = await exactUntil();
    await assertFails(dir(PRES, entry({
      email: PRES, roles: [{ role: 'dept', scope: 'ELEC', until, secretary: true }],
    })));
  });

  test('a role not held is refused', async () => {
    const until = await exactUntil();
    await assertFails(dir(PRES, entry({
      email: PRES,
      roles: [{ role: 'dept', scope: 'ELEC', until }, { role: 'dept', scope: 'CS', until }],
    })));
    await assertFails(dir(STUDENT, entry({ email: STUDENT })));
  });
});

describe('volunteers', () => {
  const offer = (email = STUDENT, course = 'EEE F211') => ({
    name: name(email), email, campus: 'goa', courseId: course, dept: 'ELEC',
    term: '2026-27-1', open: true, createdAt: serverTimestamp(),
  });
  const id = (email = STUDENT, course = 'EEE F211') => `goa|${course}|${email}`;
  const offered = (who, docId, data) => {
    const db = as(who);
    return putBumped(db, 'goa', 'volunteers/ELEC', doc(db, 'volunteers', docId), data);
  };
  const closed = (db, docId, data) => {
    const b = writeBatch(db);
    b.update(doc(db, 'volunteers', docId), data);
    bump(b, db, 'goa', 'volunteers/ELEC');
    return b.commit();
  };

  test('a student offers for themselves, on their campus', async () => {
    await assertSucceeds(offered(STUDENT, id(), offer()));
    await assertFails(offered(STUDENT, id(NEVER), offer(NEVER)));
    await assertFails(offered(STUDENT, id(), { ...offer(), dept: 'CS' }));
    await assertFails(offered(OTHER, `goa|EEE F211|${OTHER}`, offer(OTHER)));
  });

  test('the department president reads and dismisses; others cannot', async () => {
    await offered(STUDENT, id(), offer());
    const q = (db) => query(collection(db, 'volunteers'),
      where('campus', '==', 'goa'), where('dept', '==', 'ELEC'), where('open', '==', true));
    await assertSucceeds(getDocs(q(as(PRES))));
    await assertSucceeds(getDocs(q(as(ADMIN))));
    await assertFails(getDocs(q(as(NEVER))));
    await assertFails(closed(as(NEVER), id(), { open: false }));
    await assertSucceeds(closed(as(PRES), id(), {
      open: false, closedBy: { email: PRES, name: 'P' },
    }));
  });

  test('the student withdraws their own', async () => {
    await offered(STUDENT, id(), offer());
    await assertSucceeds(closed(as(STUDENT), id(), { open: false }));
    await assertSucceeds(getDoc(doc(as(STUDENT), 'volunteers', id())));
  });

  test('an appointment closes the offers in its batch', async () => {
    await offered(STUDENT, id(), offer());
    const db = as(PRES);
    await assertSucceeds(appoint(db, PRES,
      { role: 'course', campus: 'goa', scope: 'EEE F211', email: STUDENT },
      { courses: ['EEE F211'] }));
    await assertSucceeds(closed(db, id(), {
      open: false, closedBy: { email: PRES, name: 'P' },
    }));
  });
});
