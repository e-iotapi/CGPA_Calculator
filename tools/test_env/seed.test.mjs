// Checks the seed against the real rules and its own arithmetic
// (PERF_TEST_PLAN.md T4b). Run seed.mjs against a running emulator first:
//   node tools/test_env/seed.mjs && npm --prefix tools/test_env test
import { readFileSync } from 'node:fs';
import { after, before, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { collection, collectionGroup, doc, getDoc, getDocs } from 'firebase/firestore';
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

import accountsConfig from '../../test_env/accounts.json' with { type: 'json' };

const byKey = Object.fromEntries(accountsConfig.accounts.map((a) => [a.key, a]));

let env;
before(async () => {
  process.env.FIREBASE_AUTH_EMULATOR_HOST ??= 'localhost:9099';
  const authApp = getAuth(initializeApp({ projectId: 'demo-pointer' }, 'seed-test-lookup'));
  // seed.mjs never writes uids back to accounts.json; resolve them fresh.
  for (const a of accountsConfig.accounts) {
    a.uid = (await authApp.getUserByEmail(a.email)).uid;
  }

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

// A context authenticated as an already-seeded account, WITHOUT touching
// Firestore's contents (unlike test/rules/helpers.mjs's useEmulator(),
// which clears and reseeds before every test).
// The real Firebase Auth uid, not the email, must be the context's uid: the
// users/{uid} rule checks request.auth.uid == uid directly (§2, T1).
function as(key) {
  const a = byKey[key];
  return env
    .authenticatedContext(a.uid, { email: a.email, email_verified: true, name: a.name ?? key })
    .firestore();
}

async function canGet(email, path) {
  try {
    await getDoc(doc(as_by_email(email), path));
    return true;
  } catch {
    return false;
  }
}

function as_by_email(email) {
  const key = Object.keys(byKey).find((k) => byKey[k].email === email);
  return as(key);
}

describe('role matrix against the seeded emulator', () => {
  test('a student reads their own users/{uid} doc, not another student\'s', async () => {
    const full = byKey.student_full, dual = byKey.student_dual;
    assert.ok(full.uid, 'run seed.mjs first (accounts.json has no uid)');
    assert.equal(await canGet(full.email, `users/${full.uid}`), true);
    assert.equal(await canGet(full.email, `users/${dual.uid}`), false);
  });

  test('a first-login account (the 2026 student) has no users/{uid} doc', async () => {
    const fresher = byKey.student_new;
    const snap = await getDoc(doc(as('student_new'), `users/${fresher.uid}`));
    assert.equal(snap.exists(), false);
  });

  test('a plain student cannot read another account\'s grant', async () => {
    const student = byKey.student_full, admin = byKey.admin;
    const adminGrantId = `admin|all|all|${admin.email}`;
    assert.equal(await canGet(student.email, `grants/${adminGrantId}`), false);
  });

  test('admin reads any grant; a student reads only their own owners doc', async () => {
    const admin = byKey.admin, president = byKey.president, student = byKey.student_full;
    const presGrantId = `dept|goa|ELEC|${president.email}`;
    assert.equal(await canGet(admin.email, `grants/${presGrantId}`), true);
    assert.equal(await canGet(student.email, `owners/${student.email}`), true);
    assert.equal(await canGet(student.email, `owners/${byKey.owner.email}`), false);
  });
});

describe('review counters equal the seeded entries', () => {
  test('EEE F311 course-level stats match its non-hidden entries', async () => {
    const db = as('owner'); // any signed-in context reads reviews; owner is convenient
    const entries = await getDocs(collection(db, 'reviews/EEE F311/entries'));
    let count = 0, starSum = 0, recommendCount = 0;
    entries.forEach((d) => {
      const r = d.data();
      if (r.hidden) return;
      count++;
      starSum += r.stars;
      if (r.recommend) recommendCount++;
    });
    const stats = (await getDoc(doc(db, 'courses/EEE F311/stats/goa'))).data();
    assert.equal(stats.count, count);
    assert.equal(stats.starSum, starSum);
    assert.equal(stats.recommendCount, recommendCount);
  });
});

describe('the seed leaves room for the app\'s own writes', () => {
  test('stats docs hold only the keys the rules allow, so a student can post a review (BUG-03)', async () => {
    const allowed = ['count', 'starSum', 'recommendCount', 'campus', 'courseId', 'scope', 'professorId', 'touchedBy'];
    const db = as('owner');
    const stats = await getDocs(collectionGroup(db, 'stats'));
    assert.ok(stats.size > 0);
    stats.forEach((d) => {
      const extra = Object.keys(d.data()).filter((k) => !allowed.includes(k));
      assert.deepEqual(extra, [], d.ref.path);
    });
  });
});

describe('build-out seed (B9) matches the shapes the stores read', () => {
  const owner = () => as('owner');
  const data = async (path) => (await getDoc(doc(owner(), path))).data();

  test('contributor holds a live grant, a username and 8 points', async () => {
    const c = byKey.contributor;
    const g = await data(`grants/contributor|goa|goa|${c.email}`);
    assert.equal(g.active, true);
    assert.equal(g.expiresAt.toDate().getUTCFullYear(), 2100);
    const me = await data(`contributors/${c.email}`);
    assert.deepEqual([me.username, me.points], ['ctest', 8]);
    assert.equal((await data('usernames/goa|ctest')).email, c.email);
  });

  test('the leaderboard has >= 12 rows, each mirrored by a contributors doc', async () => {
    const lb = await data('leaderboard/goa');
    const names = Object.keys(lb.p);
    assert.ok(names.length >= 12);
    for (const u of names) {
      const un = await data(`usernames/goa|${u}`);
      assert.equal((await data(`contributors/${un.email}`)).points, lb.p[u], u);
    }
  });

  test('the applicant has a pending request, the elective lead a GEN grant', async () => {
    const a = byKey.applicant, e = byKey.electiveContributor;
    assert.equal((await data(`contributorRequests/goa|ELEC|${a.email}`)).status, 'pending');
    assert.equal((await data(`grants/dept|goa|GEN|${e.email}`)).active, true);
  });

  test('pending/goa|ELEC has a 3-link and a 1-link batch, the older 14 days old, all backed by unapproved links', async () => {
    const { batches } = await data('pending/goa|ELEC');
    const list = Object.entries(batches).sort((x, y) => x[1].at.toMillis() - y[1].at.toMillis());
    assert.deepEqual(list.map(([, b]) => Object.keys(b.links).length), [1, 3]);
    const age = (Date.now() - list[0][1].at.toMillis()) / 864e5;
    assert.ok(age > 13.9 && age < 14.5, `age ${age}`);
    for (const [bid, b] of list) {
      for (const id of Object.keys(b.links)) {
        const r = await data(`resources/${id}`);
        assert.equal(r.approved, false);
        assert.equal(r.batchId, bid);
      }
    }
  });

  test('gate on, one course claim, fresh and stale activity, one removed professor', async () => {
    assert.equal((await data('reviewGate/goa')).on, true);
    // courseClaims rules land with B2 (branch bo-u12), so read it unguarded.
    let claim;
    await env.withSecurityRulesDisabled(async (ctx) => {
      claim = (await getDoc(doc(ctx.firestore(), 'courseClaims/goa|HSS F219'))).data();
    });
    assert.equal(claim.dept, 'ELEC');
    assert.equal(claim.by.email, byKey.president.email);
    const act = await data('activity/goa');
    assert.ok(Date.now() - act.course['EEE F311'].toMillis() < 30 * 864e5);
    assert.ok(Date.now() - act.course['EEE F211'].toMillis() > 400 * 864e5);
    const profs = await getDocs(collection(owner(), 'professors'));
    assert.equal(profs.docs.filter((d) => d.data().removed === true).length, 1);
  });

  test('reviews carry grade, and marks on some', async () => {
    const entries = await getDocs(collection(owner(), 'reviews/EEE F311/entries'));
    const rows = entries.docs.map((d) => d.data());
    assert.ok(rows.every((r) => typeof r.grade === 'string'));
    assert.ok(rows.some((r) => typeof r.marks === 'number'));
  });

  test('the timetable has 3 courses of 2 sections, events, exams and a current pointer', async () => {
    const cur = await data('timetable/goa|current');
    const meta = await data(`timetable/goa|${cur.sem}`);
    assert.equal(meta.marker, cur.marker);
    assert.ok(meta.events.length > 0);
    const chunk = await data(`timetable/goa|${cur.sem}|0`);
    const cs = Object.values(chunk.courses);
    assert.equal(cs.length, 3);
    assert.ok(cs.every((c) => c.sec.length === 2));
    assert.ok(cs.some((c) => c.mid) && cs.every((c) => c.compre || c.mid));
  });

  test('the heads carry the new markers', async () => {
    const v = (await data('heads/goa')).v;
    for (const k of ['reviewGate', 'timetable', 'leaderboard', 'pending/ELEC', 'courseClaims']) {
      assert.ok(v[k] >= 1, k);
    }
  });
});
