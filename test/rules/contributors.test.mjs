// firestore.rules for contributors (B7): requests, the grant, unapproved
// links and their pending index, approval with +4, usernames, leaderboard.
import { describe, test } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  Timestamp, collection, deleteField, doc, getDoc, increment, serverTimestamp, setDoc, writeBatch,
} from 'firebase/firestore';
import { ADMIN, OTHER, OWNER, PRES, STUDENT, as, days, name, seed, useEmulator } from './helpers.mjs';

useEmulator();

const C = 'f20230777@goa.bits-pilani.ac.in'; // contributor
const C2 = 'f20230888@goa.bits-pilani.ac.in';
const SENTINEL = Timestamp.fromDate(new Date('2100-01-01T00:00:00Z'));
const reqId = (e, dept = 'ELEC') => `goa|${dept}|${e}`;
const gid = (e) => `contributor|goa|goa|${e}`;
const URL = 'https://drive.google.com/x';

function bumps(b, db, paths) {
  b.set(doc(db, 'heads', 'goa'), { v: Object.fromEntries(paths.map((p) => [p, increment(1)])) }, { merge: true });
}

function audit(b, db, actor, path) {
  const a = doc(collection(db, 'audit'));
  b.set(a, {
    actor: { email: actor, name: name(actor), role: 'test' },
    action: 'x', path, campus: 'goa', at: serverTimestamp(),
  });
  return a.id;
}

const apply = (db, e, extra = {}, dept = 'ELEC') => {
  const b = writeBatch(db);
  b.set(doc(db, 'contributorRequests', reqId(e, dept)), {
    name: name(e), email: e, campus: 'goa', dept, status: 'pending', createdAt: serverTimestamp(), ...extra,
  });
  bumps(b, db, [`contributorRequests/${dept}`]);
  return b.commit();
};

function decide(db, actor, e, status, { grant = true, dept = 'ELEC', reason, grantExtra = {} } = {}) {
  const b = writeBatch(db);
  const auditId = audit(b, db, actor, `contributorRequests/${reqId(e, dept)}`);
  b.update(doc(db, 'contributorRequests', reqId(e, dept)), {
    status, decidedBy: actor, decidedAt: serverTimestamp(), auditId, ...(reason ? { reason } : {}),
  });
  const paths = [`contributorRequests/${dept}`];
  if (status === 'approved' && grant) {
    const ga = audit(b, db, actor, `grants/${gid(e)}`);
    b.set(doc(db, 'grants', gid(e)), {
      role: 'contributor', campus: 'goa', scope: 'goa', email: e, name: name(e), dept,
      active: true, expiresAt: SENTINEL, grantedBy: { email: actor, name: name(actor) },
      grantedAt: serverTimestamp(), auditId: ga, ...grantExtra,
    });
    paths.push('grants');
  }
  bumps(b, db, paths);
  return b.commit();
}

const seedContributor = (e = C) => seed(async (db) => {
  await setDoc(doc(db, 'people', e), { name: name(e), campus: 'goa', firstSignIn: 1 });
  await setDoc(doc(db, 'grants', gid(e)), {
    role: 'contributor', campus: 'goa', scope: 'goa', email: e, name: name(e), dept: 'ELEC',
    active: true, expiresAt: SENTINEL,
  });
});

const link = (extra = {}) => ({
  title: 'Notes', url: URL, host: 'drive.google.com', kind: 'folder',
  campus: 'goa', department: 'ELEC', scope: 'department', courseIds: [], pinnedToDepartment: false,
  removed: false, actingFor: '', ...extra,
});
const copyOf = (r) => Object.fromEntries(Object.entries({
  title: r.title, url: r.url, department: r.department, scope: r.scope,
  courseIds: r.courseIds, pinnedToDepartment: r.pinnedToDepartment,
  approved: r.approved, publishedAt: r.publishedAt,
}).filter(([, v]) => v !== undefined));

async function submit(db, actor, rid, { bid = 'b1', extra = {}, pending = true, approved = false } = {}) {
  const b = writeBatch(db);
  const auditId = audit(b, db, actor, `resources/${rid}`);
  const r = link({ approved, publishedAt: serverTimestamp(), batchId: bid, ...extra });
  b.set(doc(db, 'resources', rid), { ...r, addedBy: { email: actor, name: name(actor) }, addedAt: serverTimestamp(), auditId });
  const v = (await getDoc(doc(db, 'resourceVersions', 'goa'))).data()?.v ?? 0;
  b.set(doc(db, 'resourceVersions', 'goa'), { v: v + 1, k: rid, links: { [rid]: copyOf(r) } }, { merge: true });
  const paths = ['resources'];
  if (pending) {
    b.set(doc(db, 'pending', 'goa|ELEC'), {
      batches: { [bid]: { email: actor, username: 'cee', at: serverTimestamp(), links: { [rid]: { title: r.title, url: r.url } } } },
      b: bid, k: rid,
    }, { merge: true });
    paths.push('pending/ELEC');
  }
  bumps(b, db, paths);
  return b.commit();
}

/// A pending link as the submit left it, written without rules.
async function seedPending(rid, { ageDays = 1, email = C, bid = 'b1' } = {}) {
  await seed(async (db) => {
    const at = Timestamp.fromMillis(Date.now() - ageDays * 864e5);
    await setDoc(doc(db, 'resources', rid), {
      ...link({ approved: false, publishedAt: at, batchId: bid }),
      addedBy: { email, name: name(email) }, addedAt: at, auditId: 'x',
    });
    await setDoc(doc(db, 'resourceVersions', 'goa'), { v: 5, links: { [rid]: copyOf(link({ approved: false, publishedAt: at })) } });
    await setDoc(doc(db, 'pending', 'goa|ELEC'), {
      batches: { [bid]: { email, username: 'cee', at, links: { [rid]: { title: 'Notes', url: URL } } } },
    });
  });
}

/// The approve batch: link, mirror, pending, points, leaderboard, audit,
/// markers. The biggest batch the app writes (one link each, K1).
async function approve(db, actor, rid, { username = 'cee', email = C, bid = 'b1', points = 4, last = true } = {}) {
  const b = writeBatch(db);
  const auditId = audit(b, db, actor, `resources/${rid}`);
  b.update(doc(db, 'resources', rid), { approved: true, auditId });
  // An admin from another campus cannot read the resource: bump the mirror
  // by field path, no read of the link needed.
  const v = (await getDoc(doc(db, 'resourceVersions', 'goa'))).data().v;
  b.update(doc(db, 'resourceVersions', 'goa'), { v: v + 1, k: rid, [`links.${rid}.approved`]: true });
  b.update(doc(db, 'pending', 'goa|ELEC'), { [last ? `batches.${bid}` : `batches.${bid}.links.${rid}`]: deleteField(), b: bid, k: rid });
  const c = (await getDoc(doc(db, 'contributors', email))).data();
  const n = (c?.points ?? 0) + points;
  if (c) b.update(doc(db, 'contributors', email), { points: n, lastLink: rid });
  else b.set(doc(db, 'contributors', email), { campus: 'goa', points: n, lastLink: rid });
  const paths = ['resources', 'pending/ELEC'];
  if (username) {
    b.set(doc(db, 'leaderboard', 'goa'), { p: { [username]: n }, k: username }, { merge: true });
    paths.push('leaderboard');
  }
  bumps(b, db, paths);
  return b.commit();
}

function claim(db, e, u, { campus = 'goa' } = {}) {
  const b = writeBatch(db);
  b.set(doc(db, 'usernames', `${campus}|${u}`), { email: e, claimedAt: serverTimestamp() });
  b.set(doc(db, 'contributors', e), { username: u, campus, points: 0 });
  return b.commit();
}

const seedUsername = () => seed(async (db) => {
  await setDoc(doc(db, 'usernames', 'goa|cee'), { email: C });
  await setDoc(doc(db, 'contributors', C), { username: 'cee', campus: 'goa', points: 8 });
  await setDoc(doc(db, 'leaderboard', 'goa'), { p: { cee: 8 }, tags: {} });
});

describe('requests', () => {
  test('a student applies; twice while pending and for someone else are denied', async () => {
    await assertSucceeds(apply(as(STUDENT), STUDENT));
    await assertFails(apply(as(STUDENT), STUDENT));
    await assertFails(apply(as(OTHER), C));
  });

  test('apply needs the marker bump, the campus, a pending status', async () => {
    const db = as(STUDENT);
    const b = writeBatch(db);
    b.set(doc(db, 'contributorRequests', reqId(STUDENT)), {
      name: name(STUDENT), email: STUDENT, campus: 'goa', dept: 'ELEC', status: 'pending', createdAt: serverTimestamp(),
    });
    await assertFails(b.commit());
    await assertFails(apply(as(STUDENT), STUDENT, { status: 'approved' }));
    await assertFails(apply(as(STUDENT), STUDENT, { campus: 'pilani' }));
  });

  test('withdraw, then apply again', async () => {
    await apply(as(STUDENT), STUDENT);
    const db = as(STUDENT);
    const b = writeBatch(db);
    b.update(doc(db, 'contributorRequests', reqId(STUDENT)), { status: 'withdrawn' });
    bumps(b, db, ['contributorRequests/ELEC']);
    await assertSucceeds(b.commit());
    await assertSucceeds(apply(as(STUDENT), STUDENT));
  });

  test('the student reads their own; another student cannot; the president can', async () => {
    await apply(as(STUDENT), STUDENT);
    await assertSucceeds(getDoc(doc(as(STUDENT), 'contributorRequests', reqId(STUDENT))));
    await assertFails(getDoc(doc(as(OTHER), 'contributorRequests', reqId(STUDENT))));
    await assertSucceeds(getDoc(doc(as(PRES), 'contributorRequests', reqId(STUDENT))));
  });

  for (const [who, actor] of [['admin', ADMIN], ['president', PRES], ['owner', OWNER]]) {
    test(`${who} approves: request, grant and audit in one batch`, async () => {
      await apply(as(STUDENT), STUDENT);
      await assertSucceeds(decide(as(actor), actor, STUDENT, 'approved'));
    });
  }

  test('approve without the grant, or by a student, is denied', async () => {
    await apply(as(STUDENT), STUDENT);
    await assertFails(decide(as(PRES), PRES, STUDENT, 'approved', { grant: false }));
    await assertFails(decide(as(OTHER), OTHER, STUDENT, 'approved'));
    await assertFails(decide(as(STUDENT), STUDENT, STUDENT, 'approved'));
  });

  test('a president of another department cannot decide', async () => {
    await apply(as(STUDENT), STUDENT, {}, 'CS');
    await assertFails(decide(as(PRES), PRES, STUDENT, 'approved', { dept: 'CS' }));
  });

  test('decline by president; decided twice denied; re-apply after decline', async () => {
    await apply(as(STUDENT), STUDENT);
    await assertSucceeds(decide(as(PRES), PRES, STUDENT, 'declined', { reason: 'no' }));
    await assertFails(decide(as(PRES), PRES, STUDENT, 'declined'));
    await assertSucceeds(apply(as(STUDENT), STUDENT));
  });

  test('the grant has the no-expiry sentinel and campus scope; president revokes', async () => {
    await apply(as(STUDENT), STUDENT);
    await assertFails(decide(as(PRES), PRES, STUDENT, 'approved', { grantExtra: { expiresAt: days(10) } }));
    await assertFails(decide(as(PRES), PRES, STUDENT, 'approved', { grantExtra: { scope: 'ELEC' } }));
    await assertSucceeds(decide(as(PRES), PRES, STUDENT, 'approved'));
    const db = as(PRES);
    const b = writeBatch(db);
    const auditId = audit(b, db, PRES, `grants/${gid(STUDENT)}`);
    b.update(doc(db, 'grants', gid(STUDENT)), {
      active: false, auditId, grantedBy: { email: PRES, name: name(PRES) }, grantedAt: serverTimestamp(), name: name(STUDENT),
    });
    bumps(b, db, ['grants']);
    await assertSucceeds(b.commit());
  });

  test('revoke by the contributor themselves is denied', async () => {
    await seedContributor(STUDENT);
    const db = as(STUDENT);
    const b = writeBatch(db);
    const auditId = audit(b, db, STUDENT, `grants/${gid(STUDENT)}`);
    b.update(doc(db, 'grants', gid(STUDENT)), {
      active: false, auditId, grantedBy: { email: STUDENT, name: name(STUDENT) }, grantedAt: serverTimestamp(), name: name(STUDENT),
    });
    bumps(b, db, ['grants']);
    await assertFails(b.commit());
  });
});

describe('links', () => {
  test('a contributor creates an unapproved link with its pending entry', async () => {
    await seedContributor();
    await assertSucceeds(submit(as(C), C, 'r1'));
  });

  test('approved:true, no pending entry, a non-contributor, another campus: denied', async () => {
    await seedContributor();
    await assertFails(submit(as(C), C, 'r1', { approved: true }));
    await assertFails(submit(as(C), C, 'r1', { pending: false }));
    await assertFails(submit(as(STUDENT), STUDENT, 'r1'));
    await assertFails(submit(as(C), C, 'r1', { extra: { campus: 'pilani' } }));
  });

  test("adding into another contributor's batch is denied", async () => {
    await seedContributor();
    await seedContributor(C2);
    await assertSucceeds(submit(as(C), C, 'r1', { bid: 'b1' }));
    await assertFails(submit(as(C2), C2, 'r2', { bid: 'b1' }));
    await assertSucceeds(submit(as(C2), C2, 'r2', { bid: 'b2' }));
  });

  test('a revoked grant cannot create', async () => {
    await seedContributor();
    await seed((db) => setDoc(doc(db, 'grants', gid(C)), { active: false }, { merge: true }));
    await assertFails(submit(as(C), C, 'r1'));
  });

  test('a president still creates approved links; an unapproved one by them is denied', async () => {
    const db = as(PRES);
    const b = writeBatch(db);
    const auditId = audit(b, db, PRES, 'resources/p1');
    b.set(doc(db, 'resources', 'p1'), { ...link(), addedBy: { email: PRES, name: name(PRES) }, addedAt: serverTimestamp(), auditId });
    b.set(doc(db, 'resourceVersions', 'goa'), { v: 1, k: 'p1', links: { p1: copyOf(link()) } });
    bumps(b, db, ['resources']);
    await assertSucceeds(b.commit());
    await assertFails(submit(as(PRES), PRES, 'p2'));
  });

  const edit = async (db, actor, change) => {
    const b = writeBatch(db);
    const auditId = audit(b, db, actor, 'resources/r1');
    b.update(doc(db, 'resources', 'r1'), { ...change, auditId });
    const v = (await getDoc(doc(db, 'resourceVersions', 'goa'))).data().v;
    b.set(doc(db, 'resourceVersions', 'goa'), { v: v + 1 }, { merge: true });
    bumps(b, db, ['resources']);
    return b.commit();
  };

  test('edit own: title ok; approval, window, removal and others edits denied', async () => {
    await seedContributor();
    await seedContributor(C2);
    await seedPending('r1');
    await assertSucceeds(edit(as(C), C, { title: 'New title' }));
    await assertFails(edit(as(C), C, { approved: true }));
    await assertFails(edit(as(C), C, { removed: true }));
    await assertFails(edit(as(C), C, { publishedAt: serverTimestamp() }));
    await assertFails(edit(as(C2), C2, { title: 'Hijack' }));
  });

  // The edit also refreshes the link's title/url in the approvers' queue.
  const editQueued = async (db, actor, title, { qTitle = title, extra = {} } = {}) => {
    const b = writeBatch(db);
    const auditId = audit(b, db, actor, 'resources/r1');
    b.update(doc(db, 'resources', 'r1'), { title, auditId });
    const v = (await getDoc(doc(db, 'resourceVersions', 'goa'))).data().v;
    b.set(doc(db, 'resourceVersions', 'goa'), { v: v + 1 }, { merge: true });
    b.set(doc(db, 'pending', 'goa|ELEC'), {
      batches: { b1: { links: { r1: { title: qTitle, url: URL } }, ...extra } }, b: 'b1', k: 'r1',
    }, { merge: true });
    bumps(b, db, ['resources', 'pending/ELEC']);
    return b.commit();
  };

  test('edit own pending link: queue entry follows; mismatch, batch fields, others denied', async () => {
    await seedContributor();
    await seedContributor(C2);
    await seedPending('r1');
    await assertFails(editQueued(as(C), C, 'Newer', { qTitle: 'Other' }));
    await assertFails(editQueued(as(C), C, 'Newer', { extra: { username: 'x' } }));
    await assertFails(editQueued(as(C2), C2, 'Hijack'));
    await assertSucceeds(editQueued(as(C), C, 'Newer'));
  });

  test('an edited approved link stays approved and earns nothing', async () => {
    await seedContributor();
    await seedPending('r1');
    await approve(as(PRES), PRES, 'r1', { username: null });
    const db = as(C);
    const b = writeBatch(db);
    const auditId = audit(b, db, C, 'resources/r1');
    b.update(doc(db, 'resources', 'r1'), { title: 'Better', auditId });
    const v = (await getDoc(doc(db, 'resourceVersions', 'goa'))).data().v;
    const r = (await getDoc(doc(db, 'resources', 'r1'))).data();
    b.set(doc(db, 'resourceVersions', 'goa'), { v: v + 1, k: 'r1', links: { r1: copyOf({ ...r, title: 'Better' }) } }, { merge: true });
    bumps(b, db, ['resources']);
    await assertSucceeds(b.commit());
    if ((await getDoc(doc(db, 'contributors', C))).data().points !== 4) throw new Error('points moved');
  });

  test('a contributor cannot delete', async () => {
    await seedContributor();
    await seedPending('r1');
    const db = as(C);
    await assertFails(writeBatch(db).delete(doc(db, 'resources', 'r1')).commit());
  });
});

describe('approval and points', () => {
  for (const [who, actor] of [['admin', ADMIN], ['president', PRES], ['owner', OWNER]]) {
    test(`${who} approves with everything in one batch: +4, board mirror, pending dropped`, async () => {
      await seedContributor();
      await seedPending('r1');
      await seedUsername();
      await assertSucceeds(approve(as(actor), actor, 'r1'));
      if ((await getDoc(doc(as(actor), 'contributors', C))).data().points !== 12) throw new Error('points');
    });
  }

  test('first approval creates the contributors doc', async () => {
    await seedContributor();
    await seedPending('r1');
    await assertSucceeds(approve(as(ADMIN), ADMIN, 'r1', { username: null }));
  });

  test('approve after 15 days is denied; just inside works', async () => {
    await seedContributor();
    await seedPending('r1', { ageDays: 16 });
    await assertFails(approve(as(PRES), PRES, 'r1', { username: null }));
    await seedPending('r2', { ageDays: 14.9, bid: 'b2' });
    await assertSucceeds(approve(as(PRES), PRES, 'r2', { username: null, bid: 'b2' }));
  });

  test('one link of a two-link batch: the batch stays, then the last drops it', async () => {
    await seedContributor();
    await seedPending('r1');
    await seedPending('r2');
    await seed(async (db) => {
      const v = (await getDoc(doc(db, 'resourceVersions', 'goa'))).data();
      const r1 = (await getDoc(doc(db, 'resources', 'r1'))).data();
      await setDoc(doc(db, 'resourceVersions', 'goa'), {
        v: 5, links: { ...v.links, r1: copyOf(r1) },
      });
      await setDoc(doc(db, 'pending', 'goa|ELEC'), {
        batches: { b1: { email: C, username: 'cee', at: new Date(), links: {
          r1: { title: 'Notes', url: URL }, r2: { title: 'Notes', url: URL } } } },
      });
    });
    await assertSucceeds(approve(as(PRES), PRES, 'r1', { username: null, last: false }));
    await assertSucceeds(approve(as(PRES), PRES, 'r2', { username: null }));
    if ((await getDoc(doc(as(PRES), 'contributors', C))).data().points !== 8) throw new Error('points');
  });

  test('a second approval of the same link is denied (+4 only on the transition)', async () => {
    await seedContributor();
    await seedPending('r1');
    await approve(as(PRES), PRES, 'r1', { username: null });
    await seed((db) => setDoc(doc(db, 'pending', 'goa|ELEC'), {
      batches: { b1: { email: C, username: 'cee', at: new Date(), links: { r1: { title: 'Notes', url: URL } } } },
    }));
    await assertFails(approve(as(PRES), PRES, 'r1', { username: null }));
  });

  test('+8, +3, +0 are denied', async () => {
    await seedContributor();
    await seedPending('r1');
    for (const points of [8, 3, 0, -4]) {
      await assertFails(approve(as(PRES), PRES, 'r1', { username: null, points }));
    }
  });

  test('a contributor cannot approve their own link or give themselves points', async () => {
    await seedContributor();
    await seedPending('r1');
    await assertFails(approve(as(C), C, 'r1', { username: null }));
    await assertFails(setDoc(doc(as(C), 'contributors', C), { campus: 'goa', points: 4, lastLink: 'r1' }));
  });

  test('a president of another department cannot approve', async () => {
    await seedContributor();
    await seedPending('r1');
    await seed((db) => setDoc(doc(db, 'resources', 'r1'), { department: 'CS' }, { merge: true }));
    await assertFails(approve(as(PRES), PRES, 'r1', { username: null }));
  });

  test('reject: the contributor cannot, an admin can; no points', async () => {
    await seedContributor();
    await seedPending('r1');
    for (const [actor, ok] of [[C, false], [ADMIN, true]]) {
      const db = as(actor);
      const b = writeBatch(db);
      const auditId = audit(b, db, actor, 'resources/r1');
      b.update(doc(db, 'resources', 'r1'), { removed: true, rejectedReason: 'dup', auditId });
      const v = (await getDoc(doc(db, 'resourceVersions', 'goa'))).data().v;
      b.set(doc(db, 'resourceVersions', 'goa'), { v: v + 1, k: 'r1', links: { r1: deleteField() } }, { merge: true });
      b.update(doc(db, 'pending', 'goa|ELEC'), { 'batches.b1': deleteField(), b: 'b1', k: 'r1' });
      bumps(b, db, ['resources', 'pending/ELEC']);
      await (ok ? assertSucceeds : assertFails)(b.commit());
    }
  });

  test('staff create writes +4 for themselves; a bare repeat is denied', async () => {
    const db = as(PRES);
    const b = writeBatch(db);
    const auditId = audit(b, db, PRES, 'resources/p1');
    b.set(doc(db, 'resources', 'p1'), { ...link(), addedBy: { email: PRES, name: name(PRES) }, addedAt: serverTimestamp(), auditId });
    b.set(doc(db, 'resourceVersions', 'goa'), { v: 1, k: 'p1', links: { p1: copyOf(link()) } });
    b.set(doc(db, 'contributors', PRES), { campus: 'goa', points: 4, lastLink: 'p1' });
    bumps(b, db, ['resources']);
    await assertSucceeds(b.commit());
    await assertFails(setDoc(doc(db, 'contributors', PRES), { campus: 'goa', points: 8, lastLink: 'p1' }));
  });
});

describe('usernames and leaderboard', () => {
  test('claim a username', async () => {
    await assertSucceeds(claim(as(STUDENT), STUDENT, 'cee_9'));
  });

  test('taken, bad charset, too short, too long, uppercase, other campus: denied', async () => {
    await claim(as(C), C, 'taken1');
    await assertFails(claim(as(STUDENT), STUDENT, 'taken1'));
    for (const bad of ['ab', 'a'.repeat(21), 'Bad_name', 'has space', 'dot.dot']) {
      await assertFails(claim(as(STUDENT), STUDENT, bad));
    }
    await assertFails(claim(as(STUDENT), STUDENT, 'fine_name', { campus: 'pilani' }));
  });

  test('claiming for someone else, or changing a claimed username, is denied', async () => {
    await assertFails(claim(as(STUDENT), C, 'someone'));
    await claim(as(STUDENT), STUDENT, 'first');
    await assertFails(setDoc(doc(as(STUDENT), 'contributors', STUDENT), { username: 'second', campus: 'goa', points: 0 }));
  });

  test('a president clears an offensive username (audited); a student cannot', async () => {
    await claim(as(STUDENT), STUDENT, 'rude');
    const clear = (actor) => {
      const db = as(actor);
      const b = writeBatch(db);
      const auditId = audit(b, db, actor, `contributors/${STUDENT}`);
      b.update(doc(db, 'contributors', STUDENT), { username: deleteField(), auditId });
      b.delete(doc(db, 'usernames', 'goa|rude'));
      return b.commit();
    };
    await assertFails(clear(OTHER));
    await assertSucceeds(clear(PRES));
  });

  test('leaderboard: campus members read, other campuses do not; a hand edit is denied', async () => {
    await seed((db) => setDoc(doc(db, 'leaderboard', 'goa'), { p: { cee: 4 }, tags: {} }));
    await assertSucceeds(getDoc(doc(as(STUDENT), 'leaderboard', 'goa')));
    await assertFails(getDoc(doc(as(OTHER), 'leaderboard', 'goa')));
    const db = as(PRES);
    const b = writeBatch(db);
    b.set(doc(db, 'leaderboard', 'goa'), { p: { cee: 999 }, k: 'cee' }, { merge: true });
    bumps(b, db, ['leaderboard']);
    await assertFails(b.commit());
  });
});
