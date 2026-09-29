// Checks the seed against the real rules and its own arithmetic
// (PERF_TEST_PLAN.md T4b). Run seed.mjs against a running emulator first:
//   node tools/test_env/seed.mjs && npm --prefix tools/test_env test
import { readFileSync } from 'node:fs';
import { after, before, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { collection, doc, getDoc, getDocs } from 'firebase/firestore';
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
