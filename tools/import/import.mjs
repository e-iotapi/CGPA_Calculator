#!/usr/bin/env node
// Course reviews import and the derived-copies rebuild, owner-run like the timetable tool.
//
//   node tools/import/import.mjs reviews [--project p --key k] [--allow-prod] [--answers a.json] [--commit]
//   node tools/import/import.mjs rebuild  --project p --key k  [--allow-prod] [--commit]
//
// Dry run by default: prints counts and what needs an answer, writes nothing, and never
// prints review text. `reviews` reads tools/course_reviews_out/ (or --dir): reviews.json,
// courses.json (handout links) and derived_ratings.json, then adds the new professors,
// the reviews (Goa) and one "Handout" link per course; with --commit it then rebuilds.
// `rebuild` alone recomputes every copy the app reads (counters, reviewIndex, review
// copies, resource links, repIndex) from the source docs: the production backfill.
//   --answers {"courses": {"HSF226": "HSS F226" | "skip"}, "professors": {"Name": "<id>" | "new"},
//              "aliases": {"review spelling": "Professor Name" | null}}  (tools/course_reviews_out/answers.json)
// The key is only ever a path handed to firebase-admin; this script never opens it.
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

import { apply, connect } from '../timetable/extract.mjs';
import { catalogIndex, courseIdOf, planImport, planRebuild } from './plan.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const json = (p) => JSON.parse(readFileSync(p, 'utf8'));

export function parseArgs(argv) {
  const [cmd, ...rest] = argv;
  if (!['reviews', 'rebuild'].includes(cmd)) throw new Error('Usage: import.mjs reviews|rebuild [--project p --key k] [--commit]');
  const out = { cmd, campus: 'goa', dir: path.join(root, 'tools', 'course_reviews_out') };
  for (let i = 0; i < rest.length; i++) {
    const a = rest[i];
    if (a === '--commit') out.commit = true;
    else if (a === '--allow-prod') out.allowProd = true;
    else if (['--project', '--key', '--answers', '--dir'].includes(a)) out[a.slice(2)] = rest[++i];
    else throw new Error(`Unknown option ${a}`);
  }
  if ((out.commit || cmd === 'rebuild') && !out.project) throw new Error(`${cmd}${out.commit ? ' --commit' : ''} needs --project`);
  return out;
}

/** Every source doc the rebuild recomputes from, read only. */
export async function readSources(db) {
  const docs = async (q) => (await q.get()).docs;
  const under = (re) => (d) => re.test(d.ref.path);
  return {
    entries: (await docs(db.collectionGroup('entries'))).filter(under(/^reviews\/[^/]+\/entries\/[^/]+$/))
      .map((d) => ({ courseId: d.ref.parent.parent.id, id: d.id, d: d.data() })),
    stats: (await docs(db.collectionGroup('stats'))).filter(under(/^courses\/[^/]+\/stats\/[^/]+$/)).map((d) => d.ref.path),
    mirrors: (await docs(db.collectionGroup('campus'))).filter(under(/^reviews\/[^/]+\/campus\/[^/]+$/))
      .map((d) => ({ path: d.ref.path, base: d.data().base ?? null })),
    resources: (await docs(db.collection('resources'))).map((d) => ({ id: d.id, d: d.data() })),
    directory: (await docs(db.collection('directory'))).map((d) => ({ id: d.id, d: d.data() })),
  };
}

/** What the import compares against: professors, the catalogue, and what an earlier run added. */
export async function readLive(db, campus, paths) {
  const profs = (await db.collection('professors').where('campus', '==', campus).get()).docs.map((d) => ({ id: d.id, ...d.data() }));
  const resources = (await db.collection('resources').where('campus', '==', campus).get()).docs.map((d) => ({ id: d.id, ...d.data() }));
  const existing = new Set();
  const based = new Set();
  for (let i = 0; i < paths.length; i += 300) {
    for (const d of await db.getAll(...paths.slice(i, i + 300).map((p) => db.doc(p)))) {
      if (d.exists) existing.add(d.ref.path);
      if (d.data()?.base) based.add(d.ref.path);
    }
  }
  const marker = (await db.doc('catalog/marker').get()).data();
  const bundle = marker ? (await db.doc(`catalog/v${marker.version}`).get()).data() : null;
  return { profs, resources, existing, based, catalog: bundle ? JSON.parse(bundle.json) : null, newId: (k) => db.collection(k === 'professor' ? 'professors' : 'audit').doc().id };
}

/** The catalogue's lookups, plus the review site's own course names (courses.json) where the catalogue lacks them. */
function index(catalog, courses) {
  const idx = catalogIndex(catalog);
  for (const c of courses) {
    const id = courseIdOf(c.course_code, '', idx);
    const name = String(c.course_name ?? '').trim().toLowerCase();
    if (id && name && !idx.byTitle.has(name)) idx.byTitle.set(name, id);
  }
  return idx;
}

const list = (xs, n = 40) => (xs.length > n ? [...xs.slice(0, n), `  ... and ${xs.length - n} more`] : xs);

export function summarize(p) {
  const why = p.skipped.reduce((m, s) => m.set(s.why, (m.get(s.why) ?? 0) + 1), new Map());
  const unsure = p.res.entries.filter((e) => e.status === 'unsure');
  return [
    `reviews to add: ${p.reviews} (${p.kept} already there)`,
    `rows skipped: ${p.skipped.length}${[...why].map(([w, n]) => `, ${n} ${w}`).join('')}`,
    ...list([...p.unknownCodes].map(([k, n]) => `  "${k}" (${n} rows): answer it in --answers courses`)),
    `courses not in the catalogue (imported, shown once the catalogue has them): ${p.notInCatalog.length}`,
    ...list(p.notInCatalog.map((c) => `  ${c}`)),
    `new professors: ${p.res.newProfs.length}`,
    ...list(p.res.newProfs.map((x) => `  ${x.name} (${x.dept})`)),
    `professors linked by exact match: ${p.res.entries.filter((e) => e.status === 'linked').length}`,
    `unsure matches, need your answer (left unlinked until then): ${unsure.length}`,
    ...list(unsure.map((e) => `  ${e.pdfNames[0]} ~ ${e.candidates.map((c) => `${c.name} (${c.id})`).join(' / ')}`)),
    `courses getting class averages: ${p.classCourses}`,
    `handout links to add: ${p.handouts}${p.handoutSkipped.length ? `, ${p.handoutSkipped.length} skipped` : ''}`,
    ...list(p.handoutSkipped.map((h) => `  ${h.code}: ${h.why}`)),
    ...p.res.warnings.map((w) => `warning: ${w}`),
  ].join('\n');
}

const rebuildSummary = ({ counts: c, batches }) => [
  `rebuild: ${c.reviews} visible reviews -> ${c.stats} counters (${c.zeroed} zeroed), ${c.mirrors} review copies`,
  `  resource links ${JSON.stringify(c.links)}, listed reps ${JSON.stringify(c.reps)}; ${batches.length} batches`,
].join('\n');

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const fs = args.project ? connect(args) : null;
  const db = fs?.getFirestore();
  const log = (s) => console.log(s);

  if (args.cmd === 'rebuild') {
    const plan = planRebuild(await readSources(db));
    log(rebuildSummary(plan));
    if (!args.commit) return log('\nDry run: nothing written. Add --commit to write.');
    await apply(fs, plan.batches, log);
    return log('\nRebuilt.');
  }

  const rows = json(path.join(args.dir, 'reviews.json'));
  const courses = json(path.join(args.dir, 'courses.json'));
  const ratings = json(path.join(args.dir, 'derived_ratings.json'));
  const answers = args.answers ? json(args.answers) : {};
  const asset = json(path.join(root, 'assets', 'catalog.json'));
  let n = 0;
  const offline = { profs: [], resources: [], existing: new Set(), catalog: null, newId: (k) => `new-${k}-${++n}` };
  // The paths a run could add, so an earlier run's are found: reviews and handouts by id.
  const first = planImport({ rows, ratings, courses, idx: index(asset, courses), live: offline, answers, newId: offline.newId, campus: args.campus });
  // (and the course copies, to see which already have class averages).
  const paths = first.batches.flatMap((b) => b.ops.map((o) => o.path)).filter((p) => /^(reviews|resources)\//.test(p));
  const live = db ? await readLive(db, args.campus, paths) : offline;
  const plan = db ? planImport({ rows, ratings, courses, idx: index(live.catalog ?? asset, courses), live, answers, newId: live.newId, campus: args.campus }) : first;
  log(db ? `compared with ${args.project}` : 'compared with nothing (give --project for an exact diff)');
  log(summarize(plan));
  if (!args.commit) return log('\nDry run: nothing written. Add --commit to write.');
  await apply(fs, plan.batches, log);
  const rebuilt = planRebuild(await readSources(db));
  log(rebuildSummary(rebuilt));
  await apply(fs, rebuilt.batches, log);
  log('\nDone.');
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().then(() => process.exit(0), (e) => {
    console.error(e.message);
    process.exit(1);
  });
}
