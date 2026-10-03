#!/usr/bin/env node
// Timetable extractor (B8a), owner-run like the seed script.
//
//   node tools/timetable/extract.mjs <timetable.pdf|.txt> --campus goa --sem 2026-1
//        [--professors professors.json] [--out result.json]
//        [--project staging --key /path/to/key.json [--commit]]
//
// Dry run by default: parses, prints counts, rows it could not read (page and
// line), professors that match nothing and course ids the catalogue does not
// know. --commit writes timetable/<campus>|<sem> (meta), the chunk docs
// timetable/<campus>|<sem>|<n>, one audit doc and the heads/<campus> bump, in
// one batch, replacing whatever that campus and sem had before.
// Names come from Firestore (--project) or a JSON list (--professors); with
// neither, matching is skipped and the report says so. The key is only ever a
// path handed to firebase-admin; this script never opens it.
import { execFileSync } from 'node:child_process';
import { readFileSync, writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

import { parseTimetable } from './parse.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const PROD_PROJECT_ID = 'cgpa-calculator-fb90c';
const CAMPUSES = ['goa', 'pilani', 'hyderabad', 'dubai'];
export const CHUNK_BYTES = 900_000;

export function parseArgs(argv) {
  const out = { campus: null, sem: null };
  const rest = [];
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--commit') out.commit = true;
    else if (a === '--allow-prod') out.allowProd = true;
    else if (['--campus', '--sem', '--project', '--key', '--professors', '--out'].includes(a)) out[a.slice(2)] = argv[++i];
    else if (a.startsWith('--')) throw new Error(`Unknown option ${a}`);
    else rest.push(a);
  }
  [out.input] = rest;
  if (!out.input) throw new Error('Usage: extract.mjs <timetable.pdf|.txt> --campus goa --sem 2026-1 [--commit]');
  if (!CAMPUSES.includes(out.campus)) throw new Error(`--campus must be one of ${CAMPUSES.join(', ')}`);
  if (!/^\d{4}-[12]$/.test(out.sem ?? '')) throw new Error('--sem must look like 2026-1');
  if (out.commit && !out.project) throw new Error('--commit needs --project (an alias from .firebaserc, or a project id)');
  return out;
}

// ---- professors ------------------------------------------------------------

const TITLES = new Set(['dr', 'prof', 'professor', 'mr', 'mrs', 'ms', 'shri', 'smt']);

/** "Dr. R. Menon" -> "menon r": lowercase, no titles or dots, words sorted so order does not matter. */
export function normName(name) {
  return name.toLowerCase().replace(/[.,]/g, ' ').split(/\s+/).filter((w) => w && !TITLES.has(w)).sort().join(' ');
}

/** Index of normalised name -> professor id from `professors` docs ({id, name, aliases?, campus, mergedInto?}). */
export function profIndex(docs, campus) {
  const idx = new Map();
  for (const d of docs) {
    // A merged-away doc's names live on as aliases of the survivor.
    if (d.campus !== campus || d.mergedInto) continue;
    for (const n of [d.name, ...(d.aliases ?? [])]) idx.set(normName(n), d.id);
  }
  return idx;
}

/** Sets `prof` on each matched instructor; returns the sorted unique names that matched nothing. */
export function matchProfessors(courses, idx) {
  const unmatched = new Set();
  for (const c of Object.values(courses)) {
    for (const s of c.sections) {
      for (const i of s.instructors) {
        const id = idx.get(normName(i.name));
        if (id) i.prof = id;
        else unmatched.add(i.name);
      }
    }
  }
  return [...unmatched].sort((a, b) => a.localeCompare(b));
}

/** Course ids the bundled catalogue has never heard of. */
export function unknownCourseIds(courses, catalog) {
  const known = new Set([...catalog.master, ...catalog.chartOld, ...catalog.chartNew].map((r) => r[0]));
  return Object.keys(courses).filter((id) => !known.has(id));
}

// ---- chunks ---------------------------------------------------------------

/** Courses grouped by id prefix ("BIO"), packed in order into chunks under maxBytes of JSON each. */
export function packChunks(courses, maxBytes = CHUNK_BYTES) {
  const groups = new Map();
  for (const [id, c] of Object.entries(courses)) {
    const p = id.split(' ')[0];
    if (!groups.has(p)) groups.set(p, {});
    groups.get(p)[id] = c;
  }
  const size = (o) => Buffer.byteLength(JSON.stringify(o));
  const chunks = [];
  let cur = {};
  const flush = () => {
    if (Object.keys(cur).length) chunks.push(cur);
    cur = {};
  };
  for (const g of [...groups.keys()].sort().map((k) => groups.get(k))) {
    if (size({ ...cur, ...g }) <= maxBytes) { Object.assign(cur, g); continue; }
    flush();
    if (size(g) <= maxBytes) { cur = { ...g }; continue; }
    // One prefix alone is too big: split it course by course.
    for (const [id, c] of Object.entries(g)) {
      if (size({ ...cur, [id]: c }) > maxBytes) flush();
      cur[id] = c;
    }
  }
  flush();
  return chunks;
}

// ---- report ---------------------------------------------------------------

const list = (xs, n = 40) => (xs.length > n ? [...xs.slice(0, n), `... and ${xs.length - n} more (see --out)`] : xs);

export function summarize(result, extra) {
  const courses = Object.values(result.courses);
  const lines = [
    `campus ${result.campus}, sem ${result.sem}`,
    `courses: ${courses.length}`,
    `sections: ${courses.reduce((n, c) => n + c.sections.length, 0)}`,
    `events: ${result.events.length}`,
    `chunks: ${extra.chunks}`,
    `unparsed rows: ${result.unparsed.length}`,
    ...list(result.unparsed.map((u) => `  page ${u.page} line ${u.line}: ${u.why}`)),
    `compre/midsem disagreements between sections of one course: ${result.conflicts.length}`,
    ...list(result.conflicts.map((c) => `  ${c.id} ${c.field} (page ${c.page} line ${c.line})`)),
    extra.unmatched
      ? `unmatched professors: ${extra.unmatched.length}`
      : 'unmatched professors: not checked (give --professors or --project)',
    ...list(extra.unmatched ?? []).map((n) => `  ${n}`),
    `unknown course ids: ${extra.unknown.length}`,
    ...list(extra.unknown).map((id) => `  ${id}`),
  ];
  return lines.join('\n');
}

// ---- Firestore ------------------------------------------------------------

function firebase(mod) {
  const req = createRequire(import.meta.url);
  try {
    return req(mod);
  } catch {
    // firebase-admin is installed under tools/test_env.
    return createRequire(path.join(root, 'tools', 'test_env', 'package.json'))(mod);
  }
}

function connect(args) {
  const aliases = JSON.parse(readFileSync(path.join(root, '.firebaserc'), 'utf8')).projects ?? {};
  const project = aliases[args.project] ?? args.project;
  if (project === PROD_PROJECT_ID && !args.allowProd) {
    throw new Error(`${project} is production: pass --allow-prod once you mean it.`);
  }
  if (project === 'demo-pointer') {
    process.env.FIRESTORE_EMULATOR_HOST ??= 'localhost:8085';
  } else {
    if (args.key) process.env.GOOGLE_APPLICATION_CREDENTIALS = args.key;
    if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
      throw new Error(`${project} needs --key <service-account key path> (or GOOGLE_APPLICATION_CREDENTIALS).`);
    }
  }
  firebase('firebase-admin/app').initializeApp({ projectId: project });
  return firebase('firebase-admin/firestore');
}

async function readProfessors(fs, campus) {
  const snap = await fs.getFirestore().collection('professors').where('campus', '==', campus).get();
  return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
}

const ACTOR = { email: 'timetable-script@pointer.local', name: 'Timetable extractor', role: 'owner' };

async function commit(fs, out, chunks) {
  const db = fs.getFirestore();
  const { FieldValue, FieldPath } = fs;
  const base = `${out.campus}|${out.sem}`;
  const batch = db.batch();
  // Replace, not merge: chunk docs a shorter run no longer fills are removed.
  const old = await db.collection('timetable')
    .where(FieldPath.documentId(), '>=', `${base}|`).where(FieldPath.documentId(), '<', `${base}|`).get();
  old.docs.filter((d) => Number(d.id.split('|')[2]) >= chunks.length).forEach((d) => batch.delete(d.ref));
  chunks.forEach((courses, n) => batch.set(db.doc(`timetable/${base}|${n}`), { sem: out.sem, campus: out.campus, n, courses }));
  const audit = db.collection('audit').doc();
  const nSections = Object.values(out.courses).reduce((n, c) => n + c.sections.length, 0);
  batch.set(audit, {
    actor: ACTOR,
    action: 'publish timetable',
    summary: 'publish timetable',
    path: `timetable/${base}`,
    campus: out.campus,
    before: null,
    after: { sem: out.sem, courses: Object.keys(out.courses).length, sections: nSections, chunks: chunks.length },
    at: FieldValue.serverTimestamp(),
  });
  batch.set(db.doc(`timetable/${base}`), {
    sem: out.sem, campus: out.campus, hours: out.hours, chunks: chunks.length, events: out.events,
    publishedAt: FieldValue.serverTimestamp(), auditId: audit.id,
  });
  batch.set(db.doc(`heads/${out.campus}`), { v: { timetable: FieldValue.increment(1) } }, { merge: true });
  await batch.commit();
}

// ---- main -----------------------------------------------------------------

export function loadText(file) {
  return /\.txt$/i.test(file)
    ? readFileSync(file, 'utf8')
    : execFileSync('pdftotext', ['-layout', file, '-'], { encoding: 'utf8', maxBuffer: 1 << 28 });
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const parsed = parseTimetable(loadText(args.input), args.sem);
  const out = { sem: args.sem, campus: args.campus, ...parsed };

  const fs = args.project ? connect(args) : null;
  let docs = null;
  if (args.professors) docs = JSON.parse(readFileSync(args.professors, 'utf8'));
  else if (fs) docs = await readProfessors(fs, args.campus);
  const unmatched = docs ? matchProfessors(out.courses, profIndex(docs, args.campus)) : null;
  out.unmatchedProfessors = unmatched;
  out.unknownCourseIds = unknownCourseIds(out.courses, JSON.parse(readFileSync(path.join(root, 'assets', 'catalog.json'), 'utf8')));

  const chunks = packChunks(out.courses);
  if (args.out) writeFileSync(args.out, JSON.stringify(out, null, 1));
  console.log(summarize(out, { chunks: chunks.length, unmatched, unknown: out.unknownCourseIds }));
  if (!args.commit) {
    console.log('\nDry run: nothing written. Add --commit to publish.');
    return;
  }
  await commit(fs, out, chunks);
  console.log(`\nPublished timetable/${args.campus}|${args.sem} (${chunks.length} chunks).`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().then(() => process.exit(0), (e) => {
    console.error(e.message);
    process.exit(1);
  });
}
