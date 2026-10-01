// firestore.rules: every shared write moves its path's marker on the campus
// head by exactly one, in the same batch (DATA_SYNC_PLAN Stage 1).
// Each collection: the write with its bump succeeds, without it fails.
import { createHash } from 'node:crypto';
import { describe, test } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { collection, doc, increment, serverTimestamp, setDoc, updateDoc, writeBatch } from 'firebase/firestore';
import {
  ADMIN, OTHER, OWNER, PRES, STUDENT,
  appoint, as, bump, days, name, seed, useEmulator,
} from './helpers.mjs';

useEmulator();

const C = 'EEE F211';
const hash = (uid, key) => createHash('sha256').update(uid + key).digest('hex');
const auditEntry = (db, actor, path, campus = 'goa') => {
  const a = doc(collection(db, 'audit'));
  return [a, {
    actor: { email: actor, name: name(actor), role: 'test' }, action: 'x', path, campus, at: serverTimestamp(),
  }];
};

describe('the head rule', () => {
  const heads = (db, campus, v) => setDoc(doc(db, 'heads', campus), { v }, { merge: true });
  const inc = (...paths) => Object.fromEntries(paths.map((p) => [p, increment(1)]));

  test('a student moves markers on their own campus, up to four at once', async () => {
    await assertSucceeds(heads(as(STUDENT), 'goa', inc('a', 'b', 'c', 'd')));
    await assertFails(heads(as(STUDENT), 'goa', inc('e', 'f', 'g', 'h', 'i')));
    await assertFails(heads(as(STUDENT), 'hyderabad', inc('a')));
    await assertSucceeds(heads(as(OTHER), 'hyderabad', inc('a')));
  });

  test('only the v map, and only as a map', async () => {
    await assertFails(setDoc(doc(as(STUDENT), 'heads', 'goa'), { v: 3 }, { merge: true }));
    await assertFails(setDoc(doc(as(STUDENT), 'heads', 'goa'),
      { v: inc('a'), catalog: 9 }, { merge: true }));
    await assertFails(setDoc(doc(as(STUDENT), 'heads', 'goa'),
      { v: inc('a'), offerings: { x: increment(1) } }, { merge: true }));
  });

  test('owners and admins reach any campus', async () => {
    await assertSucceeds(heads(as(OWNER), 'dubai', inc('a')));
    await assertSucceeds(heads(as(ADMIN), 'pilani', inc('a')));
  });
});

describe('a marker moves by exactly one, on the right path', () => {
  const link = {
    title: 'T', url: 'https://example.com/a', host: 'example.com', kind: 'folder', campus: 'goa',
    department: 'ELEC', scope: 'department', courseIds: [], pinnedToDepartment: false, removed: false, actingFor: '',
  };

  test('resources', async () => {
    const put = async (by, path = 'resources') => {
      const db = as(PRES);
      const b = writeBatch(db);
      const [a, ad] = auditEntry(db, PRES, 'resources/r1');
      b.set(doc(db, 'resources', 'r1'), { ...link, addedBy: { email: PRES, name: name(PRES) }, addedAt: serverTimestamp(), auditId: a.id });
      b.set(a, ad);
      b.set(doc(db, 'resourceVersions', 'goa'), { v: 1, k: 'r1', links: { r1: {
        title: link.title, url: link.url, department: 'ELEC', scope: 'department', courseIds: [], pinnedToDepartment: false,
      } } });
      if (by) bump(b, db, 'goa', path, by);
      return b.commit();
    };
    await assertFails(put(0));
    await assertFails(put(2));
    await assertFails(put(1, 'reps'));
    await assertSucceeds(put(1));
    // An update, too.
    const upd = (marker) => {
      const db = as(PRES);
      const b = writeBatch(db);
      const [a, ad] = auditEntry(db, PRES, 'resources/r1');
      b.update(doc(db, 'resources', 'r1'), { title: 'T2', auditId: a.id });
      b.set(a, ad);
      b.set(doc(db, 'resourceVersions', 'goa'), { v: 2 }, { merge: true });
      if (marker) bump(b, db, 'goa', 'resources');
      return b.commit();
    };
    await assertFails(upd(false));
    await assertSucceeds(upd(true));
  });

  test('professors, by department', async () => {
    const add = (id, dept, marker) => {
      const db = as(ADMIN);
      const b = writeBatch(db);
      const [a, ad] = auditEntry(db, ADMIN, `professors/${id}`);
      b.set(a, ad);
      b.set(doc(db, 'professors', id), {
        name: 'Dr. R. Menon', campus: 'goa', department: dept, aliases: [], nameTokens: [], mergedIds: [], active: true,
        updatedBy: { email: ADMIN, name: name(ADMIN) }, updatedAt: serverTimestamp(), auditId: a.id,
      });
      if (marker) bump(b, db, 'goa', marker);
      return b.commit();
    };
    await assertFails(add('p1', 'ELEC', null));
    await assertFails(add('p1', 'ELEC', 'professors/CS'));
    await assertSucceeds(add('p1', 'ELEC', 'professors/ELEC'));
    // An edit.
    const edit = (marker) => {
      const db = as(PRES);
      const b = writeBatch(db);
      const [a, ad] = auditEntry(db, PRES, 'professors/p1');
      b.set(a, ad);
      b.update(doc(db, 'professors', 'p1'), {
        name: 'Ramesh Menon', updatedBy: { email: PRES, name: name(PRES) }, updatedAt: serverTimestamp(), auditId: a.id,
      });
      if (marker) bump(b, db, 'goa', 'professors/ELEC');
      return b.commit();
    };
    await assertFails(edit(false));
    await assertSucceeds(edit(true));
  });

  test('grants (admin grants count on the goa head)', async () => {
    const cr = { role: 'course', campus: 'goa', scope: C, email: STUDENT };
    await assertFails(appoint(as(PRES), PRES, cr, { courses: [C] }, { marker: false }));
    await assertSucceeds(appoint(as(PRES), PRES, cr, { courses: [C] }));
    const admin = { role: 'admin', campus: 'all', scope: 'all', email: STUDENT };
    await assertFails(appoint(as(OWNER), OWNER, admin, { admin: true }, { marker: false }));
    await assertSucceeds(appoint(as(OWNER), OWNER, admin, { admin: true }));
  });

  test('volunteers, by department', async () => {
    const offer = { name: name(STUDENT), email: STUDENT, campus: 'goa', courseId: C, dept: 'ELEC', term: '2026-27-1', open: true, createdAt: serverTimestamp() };
    const id = `goa|${C}|${STUDENT}`;
    const make = (path) => {
      const db = as(STUDENT);
      const b = writeBatch(db);
      b.set(doc(db, 'volunteers', id), offer);
      if (path) bump(b, db, 'goa', path);
      return b.commit();
    };
    await assertFails(make(null));
    await assertFails(make('volunteers/CS'));
    await assertSucceeds(make('volunteers/ELEC'));
    const close = (who, campus, path) => {
      const db = as(who);
      const b = writeBatch(db);
      b.update(doc(db, 'volunteers', id), { open: false });
      if (path) bump(b, db, campus, path);
      return b.commit();
    };
    await assertFails(close(STUDENT, 'goa', null));
    await assertSucceeds(close(STUDENT, 'goa', 'volunteers/ELEC'));
    await seed((db) => updateDoc(doc(db, 'volunteers', id), { open: true }));
    const dismiss = (marker) => {
      const db = as(PRES);
      const b = writeBatch(db);
      b.update(doc(db, 'volunteers', id), { open: false, closedBy: { email: PRES, name: 'P' } });
      if (marker) bump(b, db, 'goa', 'volunteers/ELEC');
      return b.commit();
    };
    await assertFails(dismiss(false));
    await assertSucceeds(dismiss(true));
  });

  test('staffContacts and the directory share the staff marker', async () => {
    const save = (who, marker) => {
      const db = as(who);
      const b = writeBatch(db);
      b.set(doc(db, 'staffContacts', who), { name: 'P', phone: '+91 98765 43210', email: who, updatedAt: serverTimestamp() });
      if (marker) bump(b, db, 'goa', 'staff');
      return b.commit();
    };
    await assertFails(save(PRES, false));
    await assertSucceeds(save(PRES, true));
    // An owner has no campus of their own: the goa head carries it.
    await assertFails(save(OWNER, false));
    await assertSucceeds(save(OWNER, true));

    const until = days(100);
    await seed((db) => updateDoc(doc(db, 'grants', `dept|goa|ELEC|${PRES}`), { expiresAt: until }));
    const e = {
      name: 'P', campus: 'goa', updatedAt: serverTimestamp(), email: PRES,
      roles: [{ role: 'dept', scope: 'ELEC', programme: 'A3', until }],
    };
    const dir = (marker) => {
      const db = as(PRES);
      const b = writeBatch(db);
      b.set(doc(db, 'directory', PRES), e);
      if (marker) bump(b, db, 'goa', 'staff');
      return b.commit();
    };
    await assertFails(dir(false));
    await assertSucceeds(dir(true));
  });

  test('repIndex moves reps, beside the directory entry moving staff', async () => {
    const until = days(100);
    await seed((db) => updateDoc(doc(db, 'grants', `dept|goa|ELEC|${PRES}`), { expiresAt: until }));
    const e = {
      name: 'P', campus: 'goa', updatedAt: serverTimestamp(), email: PRES,
      roles: [{ role: 'dept', scope: 'ELEC', programme: 'A3', until }],
    };
    const save = (paths, together = false) => {
      const db = as(PRES);
      const b = writeBatch(db);
      b.set(doc(db, 'directory', PRES), e);
      b.set(doc(db, 'repIndex', 'goa'), { k: PRES, p: { [PRES]: e } }, { merge: true });
      if (together) {
        b.set(doc(db, 'heads', 'goa'), { v: Object.fromEntries(paths.map((p) => [p, increment(1)])) }, { merge: true });
      } else {
        for (const p of paths) bump(b, db, 'goa', p);
      }
      return b.commit();
    };
    await assertFails(save(['staff']));
    await assertFails(save(['reps']));
    await assertSucceeds(save(['staff', 'reps'], true));
  });

  // What the app's bumpPath does: one set per path, same head, same batch.
  test('two bumps on one head in one batch count together', async () => {
    const until = days(100);
    await seed((db) => updateDoc(doc(db, 'grants', `dept|goa|ELEC|${PRES}`), { expiresAt: until }));
    const e = {
      name: 'P', campus: 'goa', updatedAt: serverTimestamp(), email: PRES,
      roles: [{ role: 'dept', scope: 'ELEC', programme: 'A3', until }],
    };
    const db = as(PRES);
    const b = writeBatch(db);
    b.set(doc(db, 'directory', PRES), e);
    b.set(doc(db, 'repIndex', 'goa'), { k: PRES, p: { [PRES]: e } }, { merge: true });
    bump(b, db, 'goa', 'staff');
    bump(b, db, 'goa', 'reps');
    await assertSucceeds(b.commit());
  });

  test('reviewIndex moves reviews; the campus copy moves reviews/<course>', async () => {
    await seed((db) => setDoc(doc(db, 'courses', C, 'offerings', 'goa_2025-26-2'), { professors: ['p1'] }));
    const id = hash(STUDENT, C);
    const post = (paths) => {
      const db = as(STUDENT);
      const b = writeBatch(db);
      const d = {
        courseId: C, department: 'ELEC', stars: 4, recommend: true, text: 'Good', campus: 'goa', term: '2025-26-2',
        professorId: 'p1', hidden: false, helpful: 0, reports: 0, createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
      };
      b.set(doc(db, 'reviews', C, 'entries', id), d);
      for (const p of [null, 'p1']) {
        b.set(doc(db, 'courses', C, 'stats', p ? `goa_${p}` : 'goa'), {
          count: increment(1), starSum: increment(4), recommendCount: increment(1),
          campus: 'goa', courseId: C, scope: p ? 'professor' : 'course', professorId: p, touchedBy: id,
        }, { merge: true });
      }
      b.set(doc(db, 'reviewIndex', 'goa'), {
        k: C, c: { [C]: { count: increment(1), starSum: increment(4), recommendCount: increment(1) } },
      }, { merge: true });
      const { stars, recommend, text, term, professorId, helpful, createdAt, updatedAt } = d;
      b.set(doc(db, 'reviews', C, 'campus', 'goa'), {
        k: id, r: { [id]: { stars, recommend, text, term, professorId, helpful, createdAt, updatedAt } },
      }, { merge: true });
      b.set(doc(db, 'heads', 'goa'), { v: Object.fromEntries(paths.map((p) => [p, increment(1)])) }, { merge: true });
      return b.commit();
    };
    await assertFails(post(['reviews']));
    await assertFails(post([`reviews/${C}`]));
    await assertSucceeds(post(['reviews', `reviews/${C}`]));
  });

  test('owners and terms: the goa head, which the app moves with the others', async () => {
    const addOwner = (marker) => {
      const db = as(OWNER);
      const b = writeBatch(db);
      const [a, ad] = auditEntry(db, OWNER, 'owners/two@gmail.com', 'all');
      b.set(doc(db, 'owners', 'two@gmail.com'), {
        email: 'two@gmail.com', name: 'Two', active: true, addedBy: { email: OWNER, name: name(OWNER) },
        addedAt: serverTimestamp(), auditId: a.id,
      });
      b.set(a, ad);
      if (marker) for (const c of ['goa', 'hyderabad', 'pilani', 'dubai']) bump(b, db, c, 'owners');
      return b.commit();
    };
    await assertFails(addOwner(false));
    await assertSucceeds(addOwner(true));
    const terms = (who, marker) => {
      const db = as(who);
      const b = writeBatch(db);
      const [a, ad] = auditEntry(db, who, 'config/grantTerms', 'all');
      b.set(doc(db, 'config', 'grantTerms'), { crDays: 150, presidentDays: 365, adminDays: 730, auditId: a.id });
      b.set(a, ad);
      if (marker) for (const c of ['goa', 'hyderabad', 'pilani', 'dubai']) bump(b, db, c, 'terms');
      return b.commit();
    };
    await assertFails(terms(ADMIN, false));
    await assertSucceeds(terms(ADMIN, true));
    await assertFails(terms(OWNER, false));
    await assertSucceeds(terms(OWNER, true));
  });
});
