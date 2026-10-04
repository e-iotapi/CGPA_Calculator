#!/usr/bin/env node
// Writes test_env/accounts.json's Auth users and every shared Firestore
// collection they need, plus each account's users/{uid} doc from the
// snapshots build_snapshots_test.dart writes (PERF_TEST_PLAN.md T4b).
//
// Run against the emulator (default): node tools/test_env/seed.mjs
// Run against staging:    node tools/test_env/seed.mjs --project staging
import { createHash } from 'node:crypto';
import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, Timestamp, getFirestore } from 'firebase-admin/firestore';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
/** The account's name, else its key as words: "student_hyd" -> "Student Hyd". */
const personName = (a) =>
  a.name ?? a.key.split('_').map((w) => w[0].toUpperCase() + w.slice(1)).join(' ');
const PROD_PROJECT_ID = 'cgpa-calculator-fb90c';

function parseArgs(argv) {
  const out = { project: 'demo-pointer' };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--project') out.project = argv[++i];
    // Only reset the test accounts' passwords, no wipe: CI runs this on
    // every deploy, so the build's baked-in password always signs in.
    if (argv[i] === '--passwords-only') out.passwordsOnly = true;
  }
  // An alias from .firebaserc ("staging") resolves to its project id.
  const aliases = loadJson(path.join(root, '.firebaserc')).projects ?? {};
  out.project = aliases[out.project] ?? out.project;
  return out;
}

export function hashedId(uid, key) {
  return createHash('sha256').update(uid + key, 'utf8').digest('hex');
}

const loadJson = (p) => JSON.parse(readFileSync(p, 'utf8'));

/// Every seeded doc carries `seed: true`, so a staging wipe can find it
/// without touching anything a real user wrote (T4b).
const s = (data) => ({ ...data, seed: true });

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.project === PROD_PROJECT_ID) {
    throw new Error(`Refusing to seed the production project (${PROD_PROJECT_ID}).`);
  }
  const usingEmulator = args.project === 'demo-pointer';
  if (!usingEmulator) {
    // Never fall back to the emulator for a real project: say what is missing.
    if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
      throw new Error(`Seeding ${args.project} needs GOOGLE_APPLICATION_CREDENTIALS (a service-account key file).`);
    }
    if (!process.env.STAGING_PASSWORD) {
      throw new Error('Seeding staging needs STAGING_PASSWORD; the accounts.json password is public.');
    }
  }
  if (usingEmulator) {
    process.env.FIRESTORE_EMULATOR_HOST ??= 'localhost:8085';
    process.env.FIREBASE_AUTH_EMULATOR_HOST ??= 'localhost:9099';
  }

  initializeApp({ projectId: args.project });
  const db = getFirestore();
  const auth = getAuth();

  const accountsConfig = loadJson(path.join(root, 'test_env', 'accounts.json'));
  const { accounts } = accountsConfig;
  const password = usingEmulator ? accountsConfig.password : process.env.STAGING_PASSWORD;
  const byKey = Object.fromEntries(accounts.map((a) => [a.key, a]));

  if (args.passwordsOnly) {
    await ensureAuthUsers(auth, accounts, password, { staging: !usingEmulator });
    console.log(`Passwords reset for ${accounts.length} test accounts.`);
    process.exit(0);
  }

  if (usingEmulator) {
    await wipeEmulator(args.project);
  } else {
    await wipeStaging(db, accounts);
  }

  console.log(`Seeding ${args.project} (${usingEmulator ? 'emulator' : 'staging'})...`);
  await ensureAuthUsers(auth, accounts, password, { staging: !usingEmulator });
  await seedUserDocs(db, accounts);
  await seedOwners(db, byKey);
  await seedConfig(db, byKey);
  const catalogVersion = await seedCatalog(db, byKey);
  await seedGrantsAndStaff(db, byKey);
  await seedContacts(db, byKey);
  await seedRepIndex(db);
  await seedVolunteers(db, byKey);
  await seedPeople(db, accounts);
  const professorIds = await seedProfessors(db, byKey);
  await seedOfferings(db, byKey, professorIds);
  await seedReviews(db, byKey, professorIds);
  await seedResources(db, byKey);
  await seedContributors(db, byKey);
  await seedPending(db, byKey);
  await seedGateAndClaims(db, byKey);
  await seedActivity(db);
  await bumpMarkers(db);
  await seedTimetable(db);

  console.log(`Done. Catalogue published at version ${catalogVersion}.`);
  process.exit(0);
}

// The seed rewrites data behind the heads' markers, so a phone would keep its
// saved copy as current. One step on every marker makes each re-read once.
// The marker keys the stores read (lib/core/heads/paths.dart) that an empty
// head does not hold yet; timetable moves in seedTimetable.
const NEW_MARKERS = [
  'reviewGate', 'leaderboard', 'grants', 'courseClaims', 'pending/ELEC',
  'professors/ELEC', 'contributorRequests/ELEC',
];

async function bumpMarkers(db) {
  const batch = db.batch();
  for (const campus of ['goa', 'pilani', 'hyderabad', 'dubai']) {
    const head = (await db.doc(`heads/${campus}`).get()).data() ?? {};
    const step = (m, extra = []) =>
      Object.fromEntries([...Object.keys(m ?? {}), ...extra].map((k) => [k, FieldValue.increment(1)]));
    batch.set(db.doc(`heads/${campus}`), { v: step(head.v, NEW_MARKERS), offerings: step(head.offerings) }, { merge: true });
  }
  await batch.commit();
}

// ---- wipe -------------------------------------------------------------

async function wipeEmulator(projectId) {
  const url =
    `http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/` +
    `${projectId}/databases/(default)/documents`;
  const res = await fetch(url, { method: 'DELETE' });
  if (!res.ok) throw new Error(`Firestore emulator wipe failed: ${res.status}`);
}

const SEEDED_COLLECTIONS = [
  'owners', 'grants', 'staff', 'audit', 'staffContacts', 'directory',
  'volunteers', 'people', 'professors', 'resources', 'resourceVersions',
  'users', 'reviewIndex', 'repIndex',
  'contributors', 'usernames', 'contributorRequests', 'courseClaims', 'reviewGate',
];
const SEEDED_COLLECTION_GROUPS = [
  'offerings', 'entries', 'votes', 'reports', 'stats', 'campus',
];

/// Staging never gets a full wipe: only documents this script itself wrote
/// (`seed: true`), or a handful of known singleton ids (§0.5, T4b).
async function wipeStaging(db, accounts) {
  for (const name of SEEDED_COLLECTIONS) {
    await deleteWhereSeeded(db.collection(name));
  }
  for (const name of SEEDED_COLLECTION_GROUPS) {
    await deleteWhereSeeded(db.collectionGroup(name), { group: true });
  }
  const people = db.batch();
  for (const a of accounts) people.delete(db.doc(`people/${a.email}`));
  await people.commit();
  for (const id of ['grantTerms', 'public']) {
    await db.doc(`config/${id}`).delete().catch(() => {});
  }
  // Docs whose rules allow only their own keys carry no `seed` flag; they
  // are wiped by their known ids.
  // The timetable is wiped only when it is this seed's own: the owner may
  // have published the real one to staging (B8a), under the same sem id.
  const tt = (await isSeededTimetable(db))
    ? ['timetable/goa|current', 'timetable/goa|2026-1', 'timetable/goa|2026-1|0']
    : [];
  for (const p of ['pending/goa|ELEC', 'leaderboard/goa', 'activity/goa', ...tt]) {
    await db.doc(p).delete().catch(() => {});
  }
  await db.doc('catalog/marker').delete().catch(() => {});
  const versions = await db.collection('catalog').listDocuments();
  for (const ref of versions) {
    if (ref.id !== 'marker') await ref.delete().catch(() => {});
  }
}

// A collection-group filter needs its own index, which production would
// inherit; groups are read whole and filtered here instead.
// ponytail: fine while staging is only seed data, add the indexes if it grows.
async function deleteWhereSeeded(query, { group = false } = {}) {
  const snap = await (group ? query : query.where('seed', '==', true)).get();
  const seeded = snap.docs.filter((d) => d.get('seed') === true || d.get('touchedBy') === 'seed');
  if (!seeded.length) return;
  const batches = chunk(seeded, 400);
  for (const docs of batches) {
    const b = query.firestore.batch();
    for (const d of docs) b.delete(d.ref);
    await b.commit();
  }
}

function chunk(arr, size) {
  const out = [];
  for (let i = 0; i < arr.length; i += size) out.push(arr.slice(i, i + size));
  return out;
}

// ---- auth ---------------------------------------------------------------

// The staging web API key (public: it ships in every staging build).
function stagingApiKey() {
  const src = readFileSync(path.join(root, 'lib', 'firebase_options_staging.dart'), 'utf8');
  return /apiKey: '([^']+)'/.exec(src)[1];
}

// True when [password] already signs [email] in on staging.
async function passwordWorks(email, password) {
  const res = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${stagingApiKey()}`,
    { method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password, returnSecureToken: false }) },
  );
  return res.ok;
}

async function ensureAuthUsers(auth, accounts, password, { staging = false } = {}) {
  for (const a of accounts) {
    try {
      a.uid = (await auth.getUserByEmail(a.email)).uid;
      // The build bakes in this run's password, and an account left on an
      // older one refuses every ?as= sign-in. But setting a password revokes
      // the account's sessions (a load mid-sign-in got user-token-expired,
      // TM-11), so on staging it is set only when it differs.
      if (!staging || !(await passwordWorks(a.email, password).catch(() => false))) {
        await auth.updateUser(a.uid, { password });
      }
    } catch {
      a.uid = (
        await auth.createUser({
          email: a.email,
          password,
          displayName: personName(a),
          emailVerified: true,
        })
      ).uid;
    }
  }
}

// ---- users/{uid}: the Sync snapshot from build_snapshots_test.dart ------

// A snapshot file is baked for one specific batch (e.g. student_full is
// batch 24); an account that reuses it (president, cr) has its own real
// batch in its BITS address. Left unpatched, the synced settingsBox.batch
// overwrites what the address says, and Settings/the current-semester math
// go by the wrong year (BUG-15). Patch the one field to match the address.
export function patchedBatch(email, json) {
  const m = /^[fhp](\d{4})\d*@/i.exec(email);
  if (!m) return json;
  const batch = Number(m[1]) % 100;
  const data = JSON.parse(json);
  const settings = data.settingsBox;
  if (!Array.isArray(settings)) return json;
  const entry = settings.find(([k]) => k === 'batch');
  if (entry) entry[1] = batch;
  else settings.push(['batch', batch]);
  // Same for campus (BUG-10): student_hyd reuses a Goa-baked snapshot.
  const campus = /@([a-z]+)\.bits-pilani\.ac\.in$/i.exec(email)?.[1].toLowerCase();
  if (campus) {
    const c = settings.find(([k]) => k === 'campus');
    if (c) c[1] = campus;
    else settings.push(['campus', campus]);
  }
  return JSON.stringify(data);
}

async function seedUserDocs(db, accounts) {
  for (const a of accounts) {
    // first_login (and no dataset at all): no users/{uid} doc, so the app
    // takes the genuine new-user path (Sync.pull sees nothing and pushes).
    if (!a.dataset || a.dataset === 'first_login') continue;
    const file = path.join(root, 'tools', 'test_env', 'out', `${a.dataset}.json`);
    // Fail, don't skip: without its snapshot the account opens on setup and
    // the app pushes that empty state over the seed (QA-09).
    if (!existsSync(file)) {
      throw new Error(
        `users/${a.uid} (${a.key}): ${file} is missing. ` +
        'Run POINTER_SEED=1 flutter test tools/test_env/build_snapshots_test.dart first.',
      );
    }
    await db.doc(`users/${a.uid}`).set(
      s({
        rev: 1,
        data: patchedBatch(a.email, readFileSync(file, 'utf8')),
        updatedAt: FieldValue.serverTimestamp(),
      }),
    );
  }
}

// ---- audit + actor helpers ------------------------------------------------

const OWNER_ACTOR = { email: 'seed@pointer.test', name: 'Seed script', role: 'owner' };

function audit(batch, { actor = OWNER_ACTOR, action, path: p, campus, course, before, after, uploadId }) {
  const ref = getFirestore().collection('audit').doc();
  const data = {
    actor: { email: actor.email, name: actor.name, role: actor.role },
    action,
    summary: action,
    path: p,
    campus,
    before: before ?? null,
    after: after ?? null,
    at: FieldValue.serverTimestamp(),
  };
  if (course != null) data.course = course;
  if (uploadId != null) data.uploadId = uploadId;
  batch.set(ref, s(data));
  return ref.id;
}

// ---- owners ---------------------------------------------------------------

async function seedOwners(db, byKey) {
  const owner = byKey.owner;
  const batch = db.batch();
  const auditId = audit(batch, {
    action: 'add owner',
    path: `owners/${owner.email}`,
    campus: 'all',
  });
  batch.set(
    db.doc(`owners/${owner.email}`),
    s({
      email: owner.email,
      name: owner.name,
      active: true,
      addedBy: { email: OWNER_ACTOR.email, name: OWNER_ACTOR.name },
      addedAt: FieldValue.serverTimestamp(),
      auditId,
    }),
  );
  await batch.commit();
}

// ---- config ---------------------------------------------------------------

async function seedConfig(db, byKey) {
  const batch = db.batch();
  const termsAuditId = audit(batch, {
    action: 'save grant terms',
    path: 'config/grantTerms',
    campus: 'all',
  });
  batch.set(
    db.doc('config/grantTerms'),
    s({ crDays: 183, presidentDays: 365, adminDays: 730, auditId: termsAuditId }),
  );
  const publicAuditId = audit(batch, {
    action: 'save public contact',
    path: 'config/public',
    campus: 'all',
  });
  batch.set(
    db.doc('config/public'),
    s({
      contactName: 'Pointer Support',
      contactMethod: 'whatsapp',
      contactTarget: '910000000000',
      contactEnabled: true,
      updatedBy: { email: OWNER_ACTOR.email, name: OWNER_ACTOR.name },
      updatedAt: FieldValue.serverTimestamp(),
      auditId: publicAuditId,
    }),
  );
  await batch.commit();
}

// ---- catalog ----------------------------------------------------------

async function seedCatalog(db, byKey) {
  const asset = loadJson(path.join(root, 'assets', 'catalog.json'));
  const next = { ...asset, version: asset.version + 1 };
  const batch = db.batch();
  batch.set(db.doc(`catalog/v${next.version}`), s({
    version: next.version,
    schema: next.schema,
    json: JSON.stringify(next),
  }));
  const auditId = audit(batch, {
    action: 'publish catalogue',
    path: 'catalog/marker',
    campus: 'all',
    after: { version: next.version, credits: [], retired: next.retired },
  });
  batch.set(db.doc('catalog/marker'), s({
    version: next.version,
    schema: next.schema,
    auditId,
  }));
  // The campus heads carry the published version too, and the app reads it
  // from there: left at a version the wipe removed, every app asked for a
  // missing bundle (TM-13). Merged, and no seed flag: the heads' own rules
  // check their keys.
  for (const campus of ['goa', 'pilani', 'hyderabad', 'dubai']) {
    batch.set(db.doc(`heads/${campus}`), {
      catalog: next.version,
      catalogSchema: next.schema,
    }, { merge: true });
  }
  await batch.commit();
  return next.version;
}

// ---- grants + staff ---------------------------------------------------

const grantId = (g) => `${g.role}|${g.campus}|${g.scope}|${g.email}`;
// One clock per run: a directory entry's `until` must equal its grant's
// expiresAt exactly, or the rules refuse the person's next profile save.
const seededAt = Date.now();
const inDays = (n) => Timestamp.fromMillis(seededAt + n * 864e5);

async function seedGrantsAndStaff(db, byKey) {
  for (const a of accounts_with_roles(byKey)) {
    for (const r of a.roles) {
      await seedOneGrant(db, a, r);
    }
  }
}

function accounts_with_roles(byKey) {
  return Object.values(byKey).filter((a) => Array.isArray(a.roles) && a.roles.length);
}

async function seedOneGrant(db, account, r) {
  const g = {
    role: r.role,
    campus: r.campus,
    scope: r.scope,
    ...(r.programme ? { programme: r.programme } : {}),
    email: account.email,
  };
  const id = grantId(g);
  const expiresAt = inDays(r.expiresInDays ?? 180);
  const active = (r.expiresInDays ?? 180) > 0;
  const batch = db.batch();
  const auditId = audit(batch, {
    action: `appoint ${r.role}`,
    path: `grants/${id}`,
    campus: r.campus,
    course: r.role === 'course' ? r.scope : undefined,
    after: { active, expiresAt: expiresAt.toDate().toISOString() },
  });
  batch.set(db.doc(`grants/${id}`), s({
    ...g,
    name: personName(account),
    active,
    expiresAt,
    grantedBy: { email: OWNER_ACTOR.email, name: OWNER_ACTOR.name },
    grantedAt: FieldValue.serverTimestamp(),
    auditId,
  }));
  batch.set(db.doc(`staff/${account.email}`), s({
    email: account.email,
    name: personName(account),
    campus: r.campus,
    owner: false,
    admin: r.role === 'admin' ? active : false,
    presidentOf: r.role === 'dept' ? [r.scope] : [],
    courses: r.role === 'course' ? [r.scope] : [],
    expiresAt,
    lastGrant: id,
  }), { merge: true });
  await batch.commit();
}

// The per-campus copy of the directory the app reads (repIndex).
async function seedRepIndex(db) {
  const byCampus = {};
  for (const d of (await db.collection('directory').get()).docs) {
    (byCampus[d.data().campus] ??= {})[d.id] = d.data();
  }
  const b = db.batch();
  for (const [campus, p] of Object.entries(byCampus)) b.set(db.doc(`repIndex/${campus}`), { k: 'seed', p });
  await b.commit();
}

// ---- staffContacts + directory -----------------------------------------

async function seedContacts(db, byKey) {
  for (const key of ['president', 'cr']) {
    const a = byKey[key];
    if (!a?.roles?.length) continue;
    const profile = a.profile ?? {};
    const batch = db.batch();
    batch.set(db.doc(`staffContacts/${a.email}`), s({
      name: personName(a),
      phone: profile.phone ?? '',
      email: a.email,
      updatedAt: FieldValue.serverTimestamp(),
    }));
    batch.set(db.doc(`directory/${a.email}`), s({
      name: personName(a),
      campus: a.roles[0].campus,
      roles: a.roles.map((r) => ({
        role: r.role === 'dept' ? 'dept' : 'course',
        scope: r.scope,
        ...(r.programme ? { programme: r.programme } : {}),
        until: inDays(r.expiresInDays ?? 180),
      })),
      ...(profile.showEmail ? { email: a.email } : {}),
      ...(profile.whatsapp ? { whatsapp: profile.whatsapp } : {}),
      ...(profile.phone ? { phone: profile.phone } : {}),
      updatedAt: FieldValue.serverTimestamp(),
    }));
    await batch.commit();
  }
}

// ---- volunteers ---------------------------------------------------------

async function seedVolunteers(db, byKey) {
  const student = byKey.student_full;
  const term = '2026-27-1';
  const offers = [
    // Open, on EEE F311 — one of student_full's own current (3-1) courses
    // with no CR, so their own Representatives page shows it as taken.
    // EEE F313, their other current course, is left with no volunteer
    // record at all, for T6's own live volunteer-then-withdraw spec.
    { campus: 'goa', courseId: 'EEE F311', dept: 'ELEC', open: true, email: student.email, name: student.name },
    // Open in ELEC, by someone else, so the president can dismiss it.
    { campus: 'goa', courseId: 'EEE F332', dept: 'ELEC', open: true, email: 'f20259001@goa.bits-pilani.ac.in', name: 'Seed Volunteer' },
    // Already closed.
    { campus: 'goa', courseId: 'EEE F341', dept: 'ELEC', open: false, email: 'f20259002@goa.bits-pilani.ac.in', name: 'Seed Volunteer 2' },
  ];
  const batch = db.batch();
  for (const o of offers) {
    const id = `${o.campus}|${o.courseId}|${o.email}`;
    const data = s({
      name: o.name,
      email: o.email,
      campus: o.campus,
      courseId: o.courseId,
      dept: o.dept,
      term,
      open: o.open,
      createdAt: FieldValue.serverTimestamp(),
    });
    if (!o.open) {
      data.closedBy = { email: o.email, name: o.name };
    }
    batch.set(db.doc(`volunteers/${id}`), data);
  }
  await batch.commit();
}

// ---- people ---------------------------------------------------------------

async function seedPeople(db, accounts) {
  const batch = db.batch();
  for (const a of accounts) {
    const campus = a.email.split('@')[1]?.split('.')[0] ?? 'goa';
    // No `seed` flag: the rules fix people's keys, so it blocked the
    // account's own profile writes. The wipe finds these by address.
    batch.set(db.doc(`people/${a.email}`), {
      name: personName(a),
      campus,
      firstSignIn: Date.now(),
    });
  }
  await batch.commit();
}

// ---- professors -----------------------------------------------------------

function nameTokens(name) {
  const titles = new Set(['dr', 'prof', 'mr', 'ms', 'mrs']);
  const words = name
    .toLowerCase()
    .split(/[^a-z0-9]+/)
    .filter((w) => w && !titles.has(w));
  const tokens = new Set();
  for (const w of words) {
    for (let i = 1; i <= Math.min(w.length, 12); i++) tokens.add(w.slice(0, i));
  }
  return [...tokens];
}

async function seedProfessors(db, byKey) {
  const rows = [
    { name: 'Dr. R. Menon', campus: 'goa', department: 'ELEC' },
    { name: 'Dr. S. Kulkarni', campus: 'goa', department: 'ELEC' },
    { name: 'Prof. A. Iyer', campus: 'hyderabad', department: 'CS' },
    // Merge pair: "Prof. K. Rao" gets absorbed into "Dr. K. Rao" below.
    { name: 'Dr. K. Rao', campus: 'goa', department: 'ELEC' },
    { name: 'Prof. K. Rao', campus: 'goa', department: 'ELEC' },
    // Soft-removed below: kept so reviews stay named, hidden from pickers.
    { name: 'Dr. T. Nair', campus: 'goa', department: 'ELEC' },
  ];
  const ids = [];
  const batch = db.batch();
  for (const r of rows) {
    const ref = db.collection('professors').doc();
    const auditId = audit(batch, {
      action: 'add professor',
      path: `professors/${ref.id}`,
      campus: r.campus,
    });
    batch.set(ref, s({
      name: r.name,
      campus: r.campus,
      department: r.department,
      aliases: [],
      nameTokens: nameTokens(r.name),
      mergedIds: [],
      active: true,
      updatedBy: { email: OWNER_ACTOR.email, name: OWNER_ACTOR.name },
      updatedAt: FieldValue.serverTimestamp(),
      auditId,
    }));
    ids.push(ref.id);
  }
  await batch.commit();

  const [menon, kulkarni, iyer, keepRao, absorbedRao, removedNair] = ids;
  await db.doc(`professors/${removedNair}`).update({
    removed: true,
    removedBy: { email: OWNER_ACTOR.email, name: OWNER_ACTOR.name },
    removedAt: FieldValue.serverTimestamp(),
  });
  const mergeBatch = db.batch();
  const mergeAuditId = audit(mergeBatch, {
    action: 'merge professor',
    path: `professors/${keepRao}`,
    campus: 'goa',
  });
  mergeBatch.update(db.doc(`professors/${absorbedRao}`), {
    mergedInto: keepRao,
    active: false,
    updatedBy: { email: OWNER_ACTOR.email, name: OWNER_ACTOR.name },
    updatedAt: FieldValue.serverTimestamp(),
    auditId: mergeAuditId,
  });
  const keptName = 'Dr. K. Rao';
  const absorbedName = 'Prof. K. Rao';
  mergeBatch.update(db.doc(`professors/${keepRao}`), {
    mergedIds: [absorbedRao],
    aliases: [absorbedName],
    nameTokens: [...new Set([...nameTokens(keptName), ...nameTokens(absorbedName)])],
    updatedBy: { email: OWNER_ACTOR.email, name: OWNER_ACTOR.name },
    updatedAt: FieldValue.serverTimestamp(),
    auditId: mergeAuditId,
  });
  await mergeBatch.commit();

  return { menon, kulkarni, iyer, keepRao };
}

// ---- offerings --------------------------------------------------------

async function seedOfferings(db, byKey, professorIds) {
  const term = '2026-27-1'; // student_full's current term (batch 24, 3-1)
  const campus = 'goa';
  const courses = [
    { id: 'EEE F311', title: 'Communication System' },
    { id: 'EEE F313', title: 'Analog and Digital VLSI Design' },
  ];
  for (const c of courses) {
    const components = [
      { id: 'quiz1', name: 'Quiz 1', weight: 10, countBest: 0, parts: [{ name: '', outOf: 20 }] },
      { id: 'quiz2', name: 'Quiz 2', weight: 10, countBest: 0, parts: [{ name: '', outOf: 20 }] },
      { id: 'midsem', name: 'Midsem', weight: 30, countBest: 0, parts: [{ name: '', outOf: 60, date: '2026-10-15' }] },
      { id: 'compre', name: 'Compre', weight: 50, countBest: 0, parts: [{ name: '', outOf: 80, date: '2026-12-05' }] },
    ];
    const batch = db.batch();
    const auditId = audit(batch, {
      action: 'publish offering',
      path: `courses/${c.id}/offerings/${campus}_${term}`,
      campus,
      course: c.id,
      after: { scheme: `${c.id}:${term}` },
    });
    batch.set(db.doc(`courses/${c.id}/offerings/${campus}_${term}`), s({
      courseId: c.id,
      campus,
      term,
      weighted: true,
      totalMarks: 100,
      components,
      professors: [professorIds.menon],
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: { email: OWNER_ACTOR.email, name: OWNER_ACTOR.name },
      auditId,
    }));
    await batch.commit();
  }
}

// ---- reviews + stats ----------------------------------------------------

function statsId(campus, professorId) {
  return professorId == null ? campus : `${campus}_${professorId}`;
}

async function seedReviews(db, byKey, professorIds) {
  const student = byKey.student_full;
  const goaCourses = ['EEE F311', 'EEE F313', 'EEE F211'];
  const term = '2026-27-1';
  // Deterministic "other reviewer" uids: real accounts aren't needed for
  // this, since Firestore rules aren't enforced against admin writes.
  const otherUids = Array.from({ length: 20 }, (_, i) => `reviewer-${i}`);
  let nextOther = 0;

  const totals = new Map(); // statsId -> {count, starSum, recommendCount}
  const bump = (courseId, campus, professorId, stars, recommend) => {
    for (const p of [null, professorId]) {
      if (p === undefined) continue;
      const key = `${courseId}\u0000${statsId(campus, p)}`;
      const t = totals.get(key) ?? { count: 0, starSum: 0, recommendCount: 0, courseId, campus, scope: p == null ? 'course' : 'professor', professorId: p ?? null };
      t.count += 1;
      t.starSum += stars;
      t.recommendCount += recommend ? 1 : 0;
      totals.set(key, t);
    }
  };

  for (const courseId of goaCourses) {
    const batch = db.batch();
    for (let i = 0; i < 5; i++) {
      const stars = i + 1; // covers every star value on every course
      const uid = i === 0 && courseId === goaCourses[0] ? student.uid : otherUids[nextOther++];
      const reviewId = hashedId(uid, courseId);
      const hidden = courseId === goaCourses[0] && i === 0; // one hidden review
      const ref = db.doc(`reviews/${courseId}/entries/${reviewId}`);
      batch.set(ref, s({
        courseId,
        department: 'ELEC',
        stars,
        recommend: stars >= 3,
        text: `Review ${i + 1} for ${courseId}.`,
        grade: ['E', 'C', 'B', 'A-', 'A'][i],
        ...(i >= 2 ? { marks: 500 + i * 100 } : {}),
        campus: 'goa',
        term,
        professorId: professorIds.menon,
        hidden,
        reason: hidden ? 'off-topic' : null,
        helpful: 0,
        reports: courseId === goaCourses[1] && i === 1 ? 1 : 0,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }));
      if (!hidden) bump(courseId, 'goa', professorIds.menon, stars, stars >= 3);
      // One reported (but not hidden) review, so moderation has both cases.
      if (courseId === goaCourses[1] && i === 1) {
        batch.set(ref.collection('reports').doc(hashedId('reporter-0', reviewId)), s({
          createdAt: FieldValue.serverTimestamp(),
        }));
      }
      if (i === 0) {
        batch.set(ref.collection('votes').doc(hashedId('voter-0', reviewId)), s({
          createdAt: FieldValue.serverTimestamp(),
        }));
      }
    }
    await batch.commit();
  }

  // One review on Hyderabad.
  const hydCourseId = 'CS F211';
  const hydUid = otherUids[nextOther++];
  const hydReviewId = hashedId(hydUid, hydCourseId);
  await db.doc(`reviews/${hydCourseId}/entries/${hydReviewId}`).set(s({
    courseId: hydCourseId,
    department: 'CS',
    stars: 4,
    recommend: true,
    text: 'Solid course.',
    grade: 'ND',
    campus: 'hyderabad',
    term,
    professorId: professorIds.iyer,
    hidden: false,
    helpful: 0,
    reports: 0,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  }));
  bump(hydCourseId, 'hyderabad', professorIds.iyer, 4, true);

  const statsBatch = db.batch();
  for (const t of totals.values()) {
    statsBatch.set(
      db.doc(`courses/${t.courseId}/stats/${statsId(t.campus, t.professorId)}`),
      // No `seed` marker: the stats rule allows only its own keys, so a
      // marked doc refuses every student review (BUG-03). touchedBy marks it.
      {
        count: t.count,
        starSum: t.starSum,
        recommendCount: t.recommendCount,
        campus: t.campus,
        courseId: t.courseId,
        scope: t.scope,
        professorId: t.professorId,
        touchedBy: 'seed',
      },
    );
  }
  await statsBatch.commit();
  await seedReviewCopies(db);
}

// The per-campus copies the app reads (reviewIndex, reviews/{c}/campus),
// derived from the entries so they always agree.
async function seedReviewCopies(db) {
  const index = {};
  const mirrors = {};
  for (const d of (await db.collectionGroup('entries').get()).docs) {
    const e = d.data();
    if (!d.ref.path.startsWith('reviews/') || e.hidden) continue;
    const c = (index[e.campus] ??= {});
    const t = (c[e.courseId] ??= { count: 0, starSum: 0, recommendCount: 0 });
    t.count += 1;
    t.starSum += e.stars;
    t.recommendCount += e.recommend ? 1 : 0;
    const m = (mirrors[`${e.courseId}|${e.campus}`] ??= {});
    m[d.id] = {
      stars: e.stars, recommend: e.recommend, text: e.text ?? null, term: e.term,
      ...(e.grade != null ? { grade: e.grade } : {}), ...(e.marks != null ? { marks: e.marks } : {}),
      professorId: e.professorId ?? null, helpful: e.helpful ?? 0,
      createdAt: e.createdAt, updatedAt: e.updatedAt,
    };
  }
  const b = db.batch();
  for (const [campus, c] of Object.entries(index)) {
    b.set(db.doc(`reviewIndex/${campus}`), { k: 'seed', c });
  }
  for (const [key, r] of Object.entries(mirrors)) {
    const [courseId, campus] = key.split('|');
    b.set(db.doc(`reviews/${courseId}/campus/${campus}`), { k: 'seed', r });
  }
  await b.commit();
}

// ---- resources ------------------------------------------------------------

async function seedResources(db, byKey) {
  const owner = byKey.owner;
  const departments = ['ELEC', 'CS'];
  const links = [
    { title: 'Course Drive folder', url: 'https://drive.google.com/drive/folders/1abc', kind: 'folder' },
    { title: 'Lecture recordings', url: 'https://youtube.com/playlist?list=abc', kind: 'video' },
    { title: 'Formula sheet', url: 'https://docs.google.com/document/d/1abc', kind: 'doc' },
    { title: 'Past papers repo', url: 'https://github.com/example/papers', kind: 'link' },
  ];
  let flaggedRef = null;
  const mirror = {};
  for (const dept of departments) {
    const batch = db.batch();
    for (const [i, link] of links.entries()) {
      const ref = db.collection('resources').doc();
      const host = new URL(link.url).host;
      const auditId = audit(batch, {
        action: 'add resource',
        path: `resources/${ref.id}`,
        campus: 'goa',
      });
      batch.set(ref, s({
        title: `${dept} ${link.title}`,
        url: link.url,
        host,
        kind: link.kind,
        campus: 'goa',
        department: dept,
        scope: 'department',
        courseIds: [],
        pinnedToDepartment: true,
        addedBy: { email: owner.email, name: owner.name },
        addedAt: FieldValue.serverTimestamp(),
        removed: false,
        auditId,
        actingFor: '',
      }));
      mirror[ref.id] = {
        title: `${dept} ${link.title}`, url: link.url, host, kind: link.kind,
        department: dept, scope: 'department', courseIds: [], pinnedToDepartment: true,
        addedBy: { email: owner.email, name: owner.name }, addedAt: Date.now(),
      };
      if (dept === departments[0] && i === 0) flaggedRef = ref;
    }
    await batch.commit();
  }
  // Shaped as the app writes it: the rules allow only v, k and links, so a
  // `seed` flag here refused every later link write. Overwritten, never
  // merged, so a reseed drops the old copies; v moves so caches re-read.
  await db.doc('resourceVersions/goa').set({ v: Date.now(), k: 'seed', links: mirror });

  // One flagged/reported link, for the moderation screens.
  const reporter = 'resource-reporter-0';
  const reportId = hashedId(reporter, flaggedRef.id);
  const reportBatch = db.batch();
  reportBatch.set(db.doc(`resourceReports/${flaggedRef.id}/entries/${reportId}`), s({
    reason: 'broken',
    note: 'Link no longer opens.',
    campus: 'goa',
    createdAt: FieldValue.serverTimestamp(),
  }));
  reportBatch.set(db.doc(`resourceFlags/${flaggedRef.id}`), s({
    campus: 'goa',
    department: departments[0],
    courseIds: [],
    open: true,
    count: 1,
    reasons: { broken: 1 },
    lastAt: FieldValue.serverTimestamp(),
  }));
  await reportBatch.commit();
}

// ---- contributors (B7) ----------------------------------------------------

const daysAgo = (n) => Timestamp.fromMillis(seededAt - n * 864e5);
const SEED_CONTRIBUTORS = Array.from({ length: 12 }, (_, i) => ({
  email: `f202591${String(i).padStart(2, '0')}@goa.bits-pilani.ac.in`,
  username: `seeduser${i + 1}`,
  points: 4 * (12 - Math.floor(i / 2)), // ties in pairs: 48, 48, 44, 44, ...
}));

// Grants (live, until revoked), requests, usernames, contributors and the
// mirrored leaderboard; shapes as ContributorStore and LeaderboardStore read.
async function seedContributors(db, byKey) {
  const campus = 'goa';
  const me = byKey.contributor;
  const until = Timestamp.fromDate(new Date(Date.UTC(2100, 0, 1)));
  const b = db.batch();
  const gid = `contributor|${campus}|${campus}|${me.email}`;
  const auditId = audit(b, { action: 'appoint contributor', path: `grants/${gid}`, campus,
                             after: { active: true } });
  b.set(db.doc(`grants/${gid}`), s({
    role: 'contributor', email: me.email, name: personName(me), campus, scope: campus,
    dept: me.contributor.dept, active: true, expiresAt: until,
    grantedBy: { email: OWNER_ACTOR.email, name: OWNER_ACTOR.name },
    grantedAt: FieldValue.serverTimestamp(), auditId,
  }));
  b.set(db.doc(`contributorRequests/${campus}|${me.contributor.dept}|${me.email}`), s({
    name: personName(me), email: me.email, campus, dept: me.contributor.dept,
    status: 'approved', createdAt: daysAgo(30), decidedBy: byKey.president.email,
    decidedAt: daysAgo(29),
  }));
  const ap = byKey.applicant;
  b.set(db.doc(`contributorRequests/${campus}|${ap.applicant.dept}|${ap.email}`), s({
    name: personName(ap), email: ap.email, campus, dept: ap.applicant.dept,
    status: 'pending', createdAt: daysAgo(2),
  }));

  const rows = [
    { email: me.email, username: me.contributor.username, points: me.contributor.points, tag: 'A3' },
    ...SEED_CONTRIBUTORS.map((c, i) => ({ ...c, tag: i < 2 ? 'A7' : undefined })),
  ];
  const p = {}, tags = {};
  for (const r of rows) {
    b.set(db.doc(`contributors/${r.email}`), s({ username: r.username, campus, points: r.points }));
    b.set(db.doc(`usernames/${campus}|${r.username}`), s({ email: r.email, claimedAt: daysAgo(20) }));
    p[r.username] = r.points;
    if (r.tag) tags[r.username] = r.tag;
  }
  // No `seed` flag: the rules allow only p, tags and k, so it would refuse
  // every later leaderboard write.
  b.set(db.doc(`leaderboard/${campus}`), { p, tags, k: me.contributor.username });
  await b.commit();
}

// Two unapproved batches in ELEC: 3 links (ctest, fresh) and 1 link (14 days
// old, a day from hiding). Each link is a live unapproved resource, its
// mirror in resourceVersions and its entry in pending/<campus>|<dept>.
async function seedPending(db, byKey) {
  const campus = 'goa', dept = 'ELEC';
  const me = byKey.contributor;
  const batches = [
    { email: me.email, username: me.contributor.username, ageDays: 1, links: [
      ['Lecture notes drive', 'https://drive.google.com/drive/folders/1pend1', 'folder'],
      ['Tutorial videos', 'https://youtube.com/playlist?list=pend2', 'video'],
      ['Formula cheat sheet', 'https://docs.google.com/document/d/1pend3', 'doc'],
    ] },
    { email: SEED_CONTRIBUTORS[0].email, username: SEED_CONTRIBUTORS[0].username, ageDays: 14, links: [
      ['Old papers archive', 'https://github.com/example/pend4', 'link'],
    ] },
  ];
  const pending = {}, mirror = {};
  const b = db.batch();
  for (const bt of batches) {
    const bid = db.collection('resources').doc().id;
    const at = daysAgo(bt.ageDays);
    pending[bid] = { email: bt.email, username: bt.username, at, links: {} };
    for (const [title, url, kind] of bt.links) {
      const ref = db.collection('resources').doc();
      const host = new URL(url).host;
      const addedBy = { email: bt.email, name: bt.username };
      const auditId = audit(b, { action: 'submit resource', path: `resources/${ref.id}`, campus,
                                 actor: { ...addedBy, role: 'contributor' } });
      b.set(ref, s({
        title, url, host, kind, campus, department: dept, scope: 'department', courseIds: [],
        pinnedToDepartment: true, addedBy, addedAt: at, removed: false, approved: false,
        publishedAt: at, batchId: bid, auditId, actingFor: '',
      }));
      pending[bid].links[ref.id] = { title, url };
      mirror[ref.id] = {
        title, url, host, kind, department: dept, scope: 'department', courseIds: [],
        pinnedToDepartment: true, addedBy, addedAt: at.toMillis(), approved: false,
        publishedAt: at.toMillis(),
      };
    }
  }
  // Overwrites pending/<campus>|<dept> whole; no `seed` (rules allow batches, b, k).
  b.set(db.doc(`pending/${campus}|${dept}`), { batches: pending });
  await b.commit();
  await db.doc(`resourceVersions/${campus}`).set(
    { v: FieldValue.increment(1), links: mirror }, { merge: true });
}

// reviewGate on for Goa, and one GEN-prefix course claimed by ELEC (the
// president claimed it); HSS F266 stays unclaimed as the claim target.
async function seedGateAndClaims(db, byKey) {
  const campus = 'goa';
  const pres = byKey.president;
  const by = { email: pres.email, name: personName(pres) };
  const b = db.batch();
  const gateAudit = audit(b, { action: 'Turned the review gate on', path: `reviewGate/${campus}`, campus });
  b.set(db.doc(`reviewGate/${campus}`), s({
    on: true, by: { email: OWNER_ACTOR.email, name: OWNER_ACTOR.name },
    at: FieldValue.serverTimestamp(), auditId: gateAudit,
  }));
  const course = 'HSS F219';
  const claimAudit = audit(b, { actor: { ...by, role: 'dept' }, action: `Claimed ${course} for ELEC`,
                                path: `courseClaims/${campus}|${course}`, campus, course, after: 'ELEC' });
  b.set(db.doc(`courseClaims/${campus}|${course}`), s({
    campus, courseId: course, dept: 'ELEC', by, at: daysAgo(10), auditId: claimAudit,
  }));
  await b.commit();
}

// When staff last edited (Last updated): fresh and stale (4 semesters back).
async function seedActivity(db) {
  // No `seed` flag: the rules allow only course, dept, c and d.
  await db.doc('activity/goa').set({
    course: { 'EEE F311': daysAgo(3), 'EEE F313': daysAgo(20), 'EEE F211': daysAgo(500) },
    dept: { ELEC: daysAgo(3), CS: daysAgo(600) },
    c: '', d: '',
  });
}

// ---- timetable (B8b) --------------------------------------------------------

// Invented courses only (never the published PDF). Moves the timetable
// marker by one and writes the same number into the docs.
/// True when goa has no timetable yet, or the one it has is this seed's
/// (its chunk holds the invented `AAA F111`).
async function isSeededTimetable(db) {
  if (!(await db.doc('timetable/goa|current').get()).exists) return true;
  const chunk = (await db.doc('timetable/goa|2026-1|0').get()).data();
  return Boolean(chunk?.courses?.['AAA F111']);
}

async function seedTimetable(db) {
  // Never overwrite a real published timetable (see wipeStaging).
  if (!(await isSeededTimetable(db))) {
    console.log('Timetable: a real one is published on goa; left as is.');
    return;
  }
  const campus = 'goa', sem = '2026-1';
  const head = (await db.doc(`heads/${campus}`).get()).data() ?? {};
  const marker = (head.v?.timetable ?? 0) + 1;
  const sec = (ty, no, room, slots, prof = ['A Teacher']) =>
    ({ ty, no, prof, room, slots: slots.map(([d, st, e]) => ({ d, s: st, e })) });
  const courses = {
    'AAA F111': { t: 'Intro Widgets', cr: 4,
      sec: [sec('L', 1, 'F101', [[1, 540, 600], [3, 540, 600], [5, 540, 600]]),
            sec('T', 1, 'F102', [[4, 660, 720]], [])],
      mid: { d: '2026-10-12', s: 570, e: 660 }, compre: { d: '2026-12-10', slot: 'FN', s: 570, e: 750 } },
    'BBB F211': { t: 'Applied Gadgets', cr: 3,
      sec: [sec('L', 1, 'G12', [[2, 840, 900], [4, 840, 900]]), sec('L', 2, 'G13', [[2, 900, 960], [4, 900, 960]])],
      mid: { d: '2026-10-14', s: 570, e: 660 }, compre: { d: '2026-12-12', slot: 'AN', s: 840, e: 1020 } },
    'CCC F311': { t: 'Gadget Design', cr: 3,
      sec: [sec('L', 1, 'H21', [[1, 600, 660], [3, 600, 660]]), sec('P', 1, 'LAB1', [[5, 840, 1020]], [])],
      compre: { d: '2026-12-14', slot: 'FN', s: 570, e: 750 } },
  };
  const events = [
    { from: '2026-08-03', title: 'Instruction begins', kind: 'term' },
    { from: '2026-09-22', title: 'Fees due', kind: 'deadline' },
    { from: '2026-09-24', to: '2026-09-25', title: 'Founders day', kind: 'holiday' },
    { from: '2026-10-12', to: '2026-10-17', title: 'Midsem exams', kind: 'exam' },
    { from: '2026-11-28', title: 'Last day of classes', kind: 'term' },
  ];
  const b = db.batch();
  const auditId = audit(b, { action: 'publish timetable', path: `timetable/${campus}|${sem}`, campus });
  b.set(db.doc(`timetable/${campus}|${sem}|0`), s({ n: 0, courses }));
  b.set(db.doc(`timetable/${campus}|${sem}`), s({
    v: 1, sem, campus, hours: { 1: [480, 540], 2: [540, 600] }, examSlots: { FN: [570, 750], AN: [840, 1020] },
    events, chunks: 1, publishedAt: FieldValue.serverTimestamp(), marker, auditId,
  }));
  // The rules allow only sem and marker here, so no `seed` flag.
  b.set(db.doc(`timetable/${campus}|current`), { sem, marker });
  b.set(db.doc(`heads/${campus}`), { v: { timetable: marker } }, { merge: true });
  await b.commit();
}

await main();
