#!/usr/bin/env node
// Timetable extractor (B8a), owner-run like the seed script.
//
//   node tools/timetable/extract.mjs <timetable.pdf|.txt> --campus goa --sem 2026-1
//        [--project staging --key /path/to/key.json]
//        [--report plan.md] [--answers answers.json] [--professors professors.json] [--out result.json]
//        [--commit]
//
// Dry run by default: parses, prints what a commit would add, writes nothing.
//   --report <file.md>   the same as a Markdown report (every doc, field, before and after).
//   --project/--key      read the live data (read only) for an exact diff; without them the
//                        run compares against assets/catalog.json and an empty set of docs.
//   --answers <file>     {"R. Aduri": "<professor id>" | "new"}: your answer for each name the
//                        report lists under "Needs your answer". A link is saved as an alias.
// --commit (needs --project) only ever adds, in this order, each batch atomic:
//   professors   new ones (src "timetable") and confirmed aliases;
//   offerings    `professors` of courses/<id>/offerings/<campus>_<term>, only where the field
//                is missing or empty (never over a staff or CR edit);
//   catalogue    catalog/v<n+1> = the current catalogue + the courses it lacks, then the marker
//                and every campus head, as the seed script does;
//   timetable    meta, chunks and the current pointer of that campus and sem.
// Names with an exact match (case, titles, dots, word order ignored) link by themselves; a close
// match is never applied without an answer. Re-running does nothing more. The key is only ever a
// path handed to firebase-admin; this script never opens it.
import { execFileSync } from 'node:child_process';
import { readFileSync, writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

import { parseTimetable } from './parse.mjs';
import { buildBatches, planCatalog, planOfferings, planTimetable, resolveProfessors, termOf, titleCase } from './plan.mjs';
import { renderReport } from './report.mjs';

export { normName } from './plan.mjs';

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
    else if (['--campus', '--sem', '--project', '--key', '--professors', '--out', '--report', '--answers', '--credits'].includes(a)) out[a.slice(2)] = argv[++i];
    else if (a.startsWith('--')) throw new Error(`Unknown option ${a}`);
    else rest.push(a);
  }
  [out.input] = rest;
  if (!out.input) throw new Error('Usage: extract.mjs <timetable.pdf|.txt> --campus goa --sem 2026-1 [--commit]');
  if (!CAMPUSES.includes(out.campus)) throw new Error(`--campus must be one of ${CAMPUSES.join(', ')}`);
  if (!/^\d{4}-[12]$/.test(out.sem ?? '')) throw new Error('--sem must look like 2026-1');
  if (out.commit && out.report) throw new Error('--report is for the dry run: drop --commit, or drop --report.');
  if (out.commit && !out.project) throw new Error('--commit needs --project (an alias from .firebaserc, or a project id)');
  return out;
}

// ---- catalogue check ---------------------------------------------------------

/** Course ids the bundled catalogue has never heard of. */
export function unknownCourseIds(courses, catalog) {
  const known = new Set([...catalog.master, ...catalog.chartOld, ...catalog.chartNew].map((r) => r[0]));
  return Object.keys(courses).filter((id) => !known.has(id));
}

// ---- schema (BUILDOUT_CONTRACTS B8b) ----------------------------------------

const DAYNO = { M: 1, T: 2, W: 3, TH: 4, F: 5, S: 6 };
const mins = (hhmm) => Number(hhmm.slice(0, 2)) * 60 + Number(hhmm.slice(3, 5));
const span = (a, b) => [mins(a), mins(b)];

/** The parser's output in the published shape: day numbers, minutes, section type L/T/P only. */
export function toSchema(out, { marker, publishedAt }) {
  const part = out.sem.endsWith('-2') ? 'sem2' : 'sem1';
  const courses = {};
  for (const [id, c] of Object.entries(out.courses)) {
    const sec = c.sections.filter((x) => 'LTP'.includes(x.type)).map((x) => {
      // Only the instructor-in-charge is published; assistants are never listed.
      const ic = x.instructors.filter((i) => i.ic);
      const o = {
        ty: x.type, no: x.no,
        // The PDF prints the IC in capitals: show it as a name.
        prof: ic.map((i) => (/[a-z]/.test(i.name) ? i.name : titleCase(i.name))),
        slots: x.slots.map((sl) => ({ d: DAYNO[sl.day], s: mins(sl.start), e: mins(sl.end) })),
      };
      if (ic.some((i) => i.prof)) o.profIds = ic.map((i) => i.prof ?? '');
      if (x.room) o.room = x.room;
      return o;
    });
    const r = { t: c.title, sec };
    if (c.compre) r.compre = { d: c.compre.date, slot: c.compre.session, s: mins(c.compre.start), e: mins(c.compre.end) };
    if (c.midsem?.start) r.mid = { d: c.midsem.date, s: mins(c.midsem.start), e: mins(c.midsem.end) };
    courses[id] = r;
  }
  return {
    v: 1, campus: out.campus, sem: out.sem, publishedAt, marker,
    hours: Object.fromEntries(Object.entries(out.hours.periods).map(([k, v]) => [k, span(...v)])),
    examSlots: Object.fromEntries(Object.entries(out.hours.compre).map(([k, v]) => [k, span(...v)])),
    events: out.events.filter((e) => e.part === part).map((e) => {
      const o = { from: e.date, title: e.title, kind: e.kind };
      if (e.end && e.end !== e.date) o.to = e.end;
      return o;
    }),
    courses,
  };
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

// ---- console summary ---------------------------------------------------------

const list = (xs, n = 40) => (xs.length > n ? [...xs.slice(0, n), `... and ${xs.length - n} more (see --report)`] : xs);

export function summarize(result, plan) {
  const courses = Object.values(result.courses);
  const res = plan.res;
  const unsure = res.entries.filter((e) => e.status === 'unsure');
  const fill = plan.offerings.ops.filter((o) => o.action !== 'unchanged');
  return [
    `campus ${result.campus}, sem ${result.sem} (offering term ${plan.term})`,
    plan.live ? `compared with live data in ${plan.args.project}` : 'compared with assets/catalog.json and no existing professors or offerings (give --project for an exact diff)',
    `courses: ${courses.length}`,
    `sections: ${courses.reduce((n, c) => n + c.sections.length, 0)}`,
    `events: ${result.events.length}`,
    `chunks: ${plan.chunks.length}${plan.timetable.changed ? '' : ' (timetable already published as is)'}`,
    `unparsed rows: ${result.unparsed.length}`,
    ...list(result.unparsed.map((u) => `  page ${u.page} line ${u.line}: ${u.why}`)),
    `compre/midsem disagreements between sections of one course (first kept): ${result.conflicts.length}`,
    ...list(result.conflicts.map((c) => `  ${c.id} ${c.field} (page ${c.page} line ${c.line})`)),
    `new courses (not in the catalogue): ${plan.catalog.adds.length}`,
    ...list(plan.catalog.adds.map((a) => `  ${a.id} ${a.title} (${a.credits} ${/ U\d/.test(a.id) ? 'credit hours' : 'credits'})`)),
    `new courses waiting for their credits (give --credits): ${plan.catalog.needCredits.length}`,
    ...list(plan.catalog.needCredits.map((a) => `  ${a.id} ${a.title}`)),
    `new professors: ${res.newProfs.length}`,
    ...list(res.newProfs.map((p) => `  ${p.name} (${p.dept})`)),
    `professors linked by exact match: ${res.entries.filter((e) => e.status === 'linked').length}`,
    `unsure matches, need your answer: ${unsure.length}`,
    ...list(unsure.map((e) => `  ${e.pdfNames[0]} ~ ${e.candidates.map((c) => `${c.name} (${c.id})`).join(' / ')}`)),
    `offerings it would fill: ${fill.length} (${plan.offerings.kept.length} left alone: staff already set them)`,
    ...res.warnings.map((w) => `warning: ${w}`),
  ].join('\n');
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

export function connect(args) {
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

/** Everything the plan compares against, read only: professors, catalogue, head, timetable docs, offerings. */
export async function readLive(fs, args, courseIds, term) {
  const db = fs.getFirestore();
  const { campus, sem } = args;
  const data = async (p) => {
    const d = await db.doc(p).get();
    return d.exists ? d.data() : null;
  };
  const profs = (await db.collection('professors').where('campus', '==', campus).get()).docs.map((d) => ({ id: d.id, ...d.data() }));
  const marker = await data('catalog/marker');
  const bundle = marker ? await data(`catalog/v${marker.version}`) : null;
  const base = `${campus}|${sem}`;
  const meta = await data(`timetable/${base}`);
  const chunks = new Map();
  const snap = await db.collection('timetable')
    .where(fs.FieldPath.documentId(), '>=', `${base}|`).where(fs.FieldPath.documentId(), '<', `${base}|`).get();
  for (const d of snap.docs) chunks.set(Number(d.id.split('|')[2]), d.data());
  const refs = courseIds.map((id) => db.doc(`courses/${id}/offerings/${campus}_${term}`));
  const offerings = new Map();
  for (let i = 0; i < refs.length; i += 300) {
    const got = await db.getAll(...refs.slice(i, i + 300));
    got.forEach((d, k) => { if (d.exists) offerings.set(courseIds[i + k], d.data()); });
  }
  return {
    profs, marker, catalog: bundle ? JSON.parse(bundle.json) : null,
    head: await data(`heads/${campus}`),
    tt: { meta, chunks, current: await data(`timetable/${campus}|current`) },
    offerings,
    newId: (kind) => db.collection(kind === 'professor' ? 'professors' : 'audit').doc().id,
  };
}

const isFv = (v) => v && typeof v === 'object' && ('$ts' in v || '$inc' in v);

/** Plan values ({$ts}, {$inc}) become the SDK's server values. */
function fv(fs, v) {
  if (isFv(v)) return '$ts' in v ? fs.FieldValue.serverTimestamp() : fs.FieldValue.increment(v.$inc);
  if (Array.isArray(v)) return v.map((x) => fv(fs, x));
  // Plain maps only: a Timestamp read back from Firestore is written as is.
  if (v && Object.getPrototypeOf(v) === Object.prototype) return Object.fromEntries(Object.entries(v).map(([k, x]) => [k, fv(fs, x)]));
  return v;
}

export async function apply(fs, batches, log = () => {}) {
  const db = fs.getFirestore();
  for (const b of batches) {
    const w = db.batch();
    for (const o of b.ops) {
      const ref = db.doc(o.path);
      if (o.action === 'delete') w.delete(ref);
      else if (o.merge) w.set(ref, fv(fs, o.merge), { merge: true });
      else w.set(ref, fv(fs, o.set));
    }
    await w.commit();
    log(`  ${b.label}: ${b.ops.length} writes`);
  }
}

// ---- the plan -------------------------------------------------------------

/**
 * Everything one run would do. `live` is null for a run with no project: the catalogue is the
 * bundled asset and there are no professors, offerings or timetable docs yet.
 */
export function makePlan(args, out, live, answers, asset, extraProfs = []) {
  let n = 0;
  const newId = live?.newId ?? ((kind) => `new-${kind}-${++n}`);
  const profs = live?.profs ?? extraProfs;
  const term = termOf(args.sem);
  const res = resolveProfessors(out.courses, profs, answers, newId);
  const profById = new Map(profs.map((p) => [p.id, p]));
  const names = new Map([...profs.map((p) => [p.id, p.name]), ...res.newProfs.map((p) => [p.id, p.name])]);

  const baseCat = live?.catalog ?? asset;
  const catalog = { ...planCatalog(out.courses, baseCat, live?.marker?.version ?? 0, args.creditsGiven ?? {}), base: baseCat.version, marker: live?.marker ?? null, hadMarker: !!live?.marker };
  const offerings = planOfferings(out.courses, live?.offerings ?? new Map(), profById, term, args.campus, newId);

  const doc = toSchema(out, { marker: Number(live?.head?.v?.timetable ?? 0) + 1, publishedAt: 0 });
  const chunks = packChunks(doc.courses);
  const timetable = planTimetable(doc, chunks, live?.tt ?? null, Number(live?.head?.v?.timetable ?? 0), newId);
  const batches = buildBatches({ campus: args.campus, term, res, offerings, catalog, catalogAdds: catalog.adds, timetable, newId, profById });
  return {
    args, live: !!live, liveHead: live?.head ?? null, term, res, offerings, catalog, timetable, doc, chunks, batches,
    parsed: { unparsed: out.unparsed, conflicts: out.conflicts },
    nameOf: (id) => names.get(id) ?? id,
  };
}

// ---- main -----------------------------------------------------------------

export function loadText(file) {
  return /\.txt$/i.test(file)
    ? readFileSync(file, 'utf8')
    : execFileSync('pdftotext', ['-layout', file, '-'], { encoding: 'utf8', maxBuffer: 1 << 28 });
}

/** `--credits <file>`: {"CS U111": 4}, credits for courses the PDF can't give (or a correction). */
export function readCredits(file) {
  if (!file) return {};
  const a = JSON.parse(readFileSync(file, 'utf8'));
  if (!a || typeof a !== 'object' || Array.isArray(a) || Object.values(a).some((v) => !Number.isInteger(v) || v < 0 || v > 40)) {
    throw new Error('--credits must be a JSON object of {"COURSE ID": <whole number 0-40>}');
  }
  return a;
}

export function readAnswers(file) {
  if (!file) return {};
  const a = JSON.parse(readFileSync(file, 'utf8'));
  if (!a || typeof a !== 'object' || Array.isArray(a) || Object.values(a).some((v) => typeof v !== 'string')) {
    throw new Error('--answers must be a JSON object of {"PDF name": "<professor id>" | "new"}');
  }
  return a;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const parsed = parseTimetable(loadText(args.input), args.sem);
  const out = { sem: args.sem, campus: args.campus, ...parsed };
  const answers = readAnswers(args.answers);
  args.creditsGiven = readCredits(args.credits);
  const asset = JSON.parse(readFileSync(path.join(root, 'assets', 'catalog.json'), 'utf8'));
  const term = termOf(args.sem);

  const fs = args.project ? connect(args) : null;
  const live = fs ? await readLive(fs, args, Object.keys(out.courses), term) : null;
  const extra = !live && args.professors ? JSON.parse(readFileSync(args.professors, 'utf8')).filter((p) => p.campus === args.campus) : [];
  const plan = makePlan(args, out, live, answers, asset, extra);
  if (args.out) writeFileSync(args.out, JSON.stringify({ ...out, published: plan.doc }, null, 1));
  console.log(summarize(out, plan));
  if (args.report) {
    writeFileSync(args.report, renderReport(plan));
    console.log(`\nReport written to ${args.report}`);
  }
  if (!args.commit) {
    console.log('\nDry run: nothing written. Add --commit to publish.');
    return;
  }
  if (!plan.batches.length) {
    console.log('\nNothing to write: everything is already there.');
    return;
  }
  await apply(fs, plan.batches, console.log);
  console.log(`\nDone: ${plan.batches.length} batch${plan.batches.length === 1 ? '' : 'es'} written for ${args.campus} ${args.sem}.`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().then(() => process.exit(0), (e) => {
    console.error(e.message);
    process.exit(1);
  });
}
