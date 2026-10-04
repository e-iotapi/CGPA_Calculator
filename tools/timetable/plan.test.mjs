// The plan on invented data: matching, the three kinds of write, batch limits, the report, and
// that applying a plan to a stand-in database and planning again finds nothing to do.
import assert from 'node:assert/strict';
import { test } from 'node:test';

import { makePlan, readAnswers } from './extract.mjs';
import { buildBatches, deptOf, likelySame, nameTokens, pdfCredits, planCatalog, planOfferings, resolveProfessors, termOf, titleCase } from './plan.mjs';
import { renderReport } from './report.mjs';

const ARGS = { campus: 'goa', sem: '2026-1', input: 't.pdf' };
const asset = { version: 4, schema: 1, master: [['AAA F101', 'Alpha', 3]], chartOld: [], chartNew: [], retired: [] };
const sec = (...names) => ({ type: 'L', no: 1, instructors: names.map((name) => ({ name, ic: true })), slots: [{ day: 'M', start: '09:00', end: '09:50' }] });
const mk = () => ({
  sem: '2026-1', campus: 'goa', unparsed: [], conflicts: [{ id: 'AAA F101', field: 'compre', page: 2, line: 3 }], events: [],
  hours: { periods: { 1: ['09:00', '09:50'] }, compre: { FN: ['10:00', '13:00'] } },
  courses: {
    'AAA F101': { title: 'ALPHA', sections: [sec('Dr. Alder Quill')] },
    'BBB F202': { title: 'BETA OF THINGS', credits: 4, sections: [sec('R. Aduri', 'Cedar Vale')] },
    'ECE F303': { title: 'GAMMA', credits: 3, sections: [sec('TBA')] },
  },
});
const prof = (id, name, extra = {}) => ({ id, name, campus: 'goa', department: 'BIO', aliases: [], nameTokens: [], ...extra });

test('helpers: names, dept, term, title case', () => {
  assert.ok(likelySame('R. Aduri', 'Raviprasad Aduri'));
  assert.ok(!likelySame('S. Aduri', 'Raviprasad Aduri'));
  assert.ok(nameTokens('Dr. Alder').has('ald') && !nameTokens('Dr. Alder').has('dr'));
  assert.deepEqual(['ECE F1', 'FIN F2', 'ZZZ F3', 'CS F4'].map(deptOf), ['ELEC', 'ECON', 'GEN', 'CS']);
  assert.equal(termOf('2026-1'), '2026-27-1');
  assert.equal(titleCase('INTRO TO VLSI DESIGN AND II'), 'Intro to VLSI Design and II');
  assert.equal(titleCase('Already Fine'), 'Already Fine');
});

test('exact match links, a close match waits for an answer, nothing close is new', () => {
  const live = {
    profs: [prof('p1', 'Alder Quill'), prof('p2', 'Raviprasad Aduri', { department: 'ME' })],
    marker: null, catalog: null, head: null, tt: null, offerings: new Map(), newId: (k) => `${k}-x`,
  };
  const out = mk();
  const plan = makePlan(ARGS, out, live, {}, asset);
  const by = Object.fromEntries(plan.res.entries.map((e) => [e.norm, e]));
  assert.equal(by['alder quill'].status, 'linked');
  assert.equal(by['aduri r'].status, 'unsure');
  assert.deepEqual(by['aduri r'].candidates, [{ id: 'p2', name: 'Raviprasad Aduri', dept: 'ME' }]);
  assert.equal(by['cedar vale'].status, 'new');
  assert.equal(out.courses['BBB F202'].sections[0].instructors[0].prof, undefined);
  assert.equal(out.courses['BBB F202'].sections[0].instructors[1].prof, 'professor-x');
  // BBB waits for its unsure instructor; AAA fills; TBA is ignored, so ECE has none.
  assert.deepEqual(plan.offerings.deferred, ['BBB F202']);
  assert.deepEqual(plan.offerings.ops.map((o) => o.path), ['courses/AAA F101/offerings/goa_2026-27-1']);
  const text = renderReport(plan);
  assert.match(text, /## Needs your answer[\s\S]*R\. Aduri[\s\S]*p2, ME[\s\S]*BBB F202/);
  assert.match(text, /1 unsure matches/);
});

test('answers: an id links and saves the alias, "new" creates, a bad id asks again', () => {
  const profs = [prof('p2', 'Raviprasad Aduri', { aliases: ['Old Name'] })];
  const mkLive = () => ({ profs, marker: null, catalog: null, head: null, tt: null, offerings: new Map(), newId: (k) => `${k}-x` });
  let plan = makePlan(ARGS, mk(), mkLive(), { 'R. Aduri': 'p2' }, asset);
  assert.equal(plan.res.aliasOps.length, 1);
  assert.deepEqual(plan.res.aliasOps[0].aliases, ['Old Name', 'R. Aduri']);
  const op = plan.batches.flatMap((b) => b.ops).find((o) => o.path === 'professors/p2');
  assert.deepEqual(op.merge.aliases, ['Old Name', 'R. Aduri']);
  assert.ok(op.merge.nameTokens.includes('aduri') && op.merge.nameTokens.includes('r'));
  assert.equal(plan.offerings.deferred.length, 0);

  plan = makePlan(ARGS, mk(), mkLive(), { 'R. Aduri': 'new' }, asset);
  assert.equal(plan.res.newProfs.filter((p) => p.name === 'R. Aduri').length, 1);

  plan = makePlan(ARGS, mk(), mkLive(), { 'R. Aduri': 'nope' }, asset);
  assert.equal(plan.res.entries.find((e) => e.norm === 'aduri r').status, 'unsure');
  assert.match(plan.res.warnings[0], /not a live professor/);
});

test('catalogue: only the missing courses, next version, titles cased, 4th element names the source', () => {
  const plan = makePlan(ARGS, mk(), null, {}, asset);
  assert.deepEqual(plan.catalog.adds.map((a) => a.id), ['BBB F202', 'ECE F303']);
  const n = plan.catalog.next;
  assert.equal(n.version, 5);
  assert.deepEqual(n.master.slice(1), [['BBB F202', 'Beta of Things', 4, 'timetable'], ['ECE F303', 'Gamma', 3, 'timetable']]);
  assert.deepEqual(n.master[0], ['AAA F101', 'Alpha', 3]);
  const cat = plan.batches.find((b) => b.label === 'catalogue');
  assert.deepEqual(cat.ops.map((o) => o.path), ['catalog/v5', 'catalog/marker', cat.ops[2].path, 'heads/goa', 'heads/pilani', 'heads/hyderabad', 'heads/dubai']);
  assert.deepEqual(cat.ops[1].set, { version: 5, schema: 1, auditId: cat.ops[2].id });
});

test('offerings: fill only when empty, never over staff, one marker key per course', () => {
  const live = {
    profs: [prof('p1', 'Alder Quill'), prof('p3', 'Cedar Vale'), prof('p9', 'Staff Pick')],
    marker: null, catalog: null, head: null, tt: null, newId: (k) => `${k}-x`,
    offerings: new Map([['AAA F101', { professors: ['p9'] }], ['BBB F202', { components: [], professors: [] }]]),
  };
  const out = mk();
  out.courses['BBB F202'].sections[0].instructors.shift(); // only Cedar Vale
  const plan = makePlan(ARGS, out, live, {}, asset);
  const [aaa, bbb] = plan.offerings.ops;
  assert.equal(aaa.action, 'unchanged');
  assert.deepEqual(plan.offerings.kept, [{ courseId: 'AAA F101', existing: ['p9'], ours: ['p1'] }]);
  assert.equal(bbb.action, 'update');
  assert.deepEqual(bbb.merge.professors, ['p3']);
  const b = plan.batches.find((x) => x.label === 'offerings');
  assert.deepEqual(b.ops.at(-1).merge, { offerings: { 'BBB F202|2026-27-1': { $inc: 1 } } });
  assert.match(renderReport(plan), /Offering of AAA F101 left alone: staff already set 1 professor \(Staff Pick\)/);
});

test('batches: at most 4 marker keys per head write, professors, then offerings, catalogue, timetable', () => {
  const out = { ...mk(), courses: {} };
  const depts = ['BIO', 'CS', 'CHE', 'CHEM', 'ECON', 'MATH', 'ME', 'PHY', 'MAC'];
  depts.forEach((d, i) => { out.courses[`${d} F${100 + i}`] = { title: 'X', credits: 3, sections: [sec(`Person${i} Zed`)] }; });
  const plan = makePlan(ARGS, out, null, {}, asset);
  const profBatches = plan.batches.filter((b) => b.label === 'professors');
  assert.equal(profBatches.length, 3);
  for (const b of profBatches) assert.ok(Object.keys(b.ops.find((o) => o.path === 'heads/goa').merge.v).length <= 4);
  assert.deepEqual(plan.batches.map((b) => b.label), ['professors', 'professors', 'professors', 'offerings', 'catalogue', 'timetable']);
  for (const b of plan.batches) assert.ok(b.ops.length < 500);
});

/** A stand-in for Firestore: applies plan ops to a Map and reads back the shape makePlan wants. */
function fakeDb() {
  const docs = new Map();
  let n = 0;
  const merge = (a, b) => {
    const r = { ...a };
    for (const [k, v] of Object.entries(b)) {
      if (v && v.$inc) r[k] = (r[k] ?? 0) + v.$inc;
      else if (v && v.$ts) r[k] = 'ts';
      else if (v && typeof v === 'object' && !Array.isArray(v) && r[k] && typeof r[k] === 'object') r[k] = merge(r[k], v);
      else r[k] = v;
    }
    return r;
  };
  const plain = (o) => merge({}, o);
  return {
    apply(batches) {
      for (const b of batches) {
        for (const o of b.ops) {
          if (o.action === 'delete') docs.delete(o.path);
          else docs.set(o.path, o.merge ? merge(docs.get(o.path) ?? {}, o.merge) : plain(o.set));
        }
      }
    },
    live() {
      const g = (p) => docs.get(p) ?? null;
      const chunks = new Map();
      for (const [p, d] of docs) { const m = p.match(/^timetable\/goa\|2026-1\|(\d+)$/); if (m) chunks.set(Number(m[1]), d); }
      const marker = g('catalog/marker');
      const offerings = new Map();
      for (const [p, d] of docs) { const m = p.match(/^courses\/(.+)\/offerings\/goa_2026-27-1$/); if (m) offerings.set(m[1], d); }
      return {
        profs: [...docs].filter(([p]) => p.startsWith('professors/')).map(([p, d]) => ({ id: p.slice(11), ...d })),
        marker, catalog: marker ? JSON.parse(g(`catalog/v${marker.version}`).json) : null, head: g('heads/goa'),
        tt: { meta: g('timetable/goa|2026-1'), chunks, current: g('timetable/goa|current') }, offerings,
        newId: (k) => `${k}-${++n}`,
      };
    },
  };
}

test('applying a plan, then planning again from the result, finds nothing to do', () => {
  const db = fakeDb();
  const first = makePlan(ARGS, mk(), db.live(), {}, asset);
  assert.ok(first.batches.length >= 4);
  db.apply(first.batches);
  const second = makePlan(ARGS, mk(), db.live(), {}, asset);
  assert.deepEqual(second.batches.map((b) => b.label), []);
  assert.equal(second.res.newProfs.length, 0);
  assert.equal(second.catalog.next, null);
  assert.equal(second.offerings.kept.length, 0);
  assert.match(renderReport(second), /Nothing to write: the published timetable already matches/);
  // What the first run left: the catalogue grew by exactly the missing courses, markers moved once.
  const live = db.live();
  assert.equal(live.marker.version, 5);
  assert.equal(live.catalog.master.length, 3);
  assert.equal(live.head.catalog, 5);
  assert.equal(live.head.v.timetable, 1);
});

test('a changed timetable republishes; a staff edit between runs is kept; a new professor id is not reused', () => {
  const db = fakeDb();
  db.apply(makePlan(ARGS, mk(), db.live(), {}, asset).batches);
  const edited = db.live().offerings;
  edited.get('AAA F101').professors = ['staff-pick'];
  const out = mk();
  out.courses['AAA F101'].sections[0].slots[0].start = '10:00';
  const plan = makePlan(ARGS, out, db.live(), {}, asset);
  assert.deepEqual(plan.batches.map((b) => b.label), ['timetable']);
  const meta = plan.batches[0].ops.find((o) => o.path === 'timetable/goa|2026-1');
  assert.equal(meta.set.marker, 2);
  assert.equal(meta.action, 'update');
  assert.match(renderReport(plan), /marker: `1` → `2`/);
  assert.match(renderReport(plan), /~AAA F101/);
});

test('readAnswers: an object of strings only', async () => {
  const { writeFileSync, mkdtempSync } = await import('node:fs');
  const { tmpdir } = await import('node:os');
  const dir = mkdtempSync(`${tmpdir()}/ans-`);
  writeFileSync(`${dir}/ok.json`, '{"A B": "new", "C D": "p1"}');
  writeFileSync(`${dir}/bad.json`, '{"A B": 3}');
  assert.deepEqual(readAnswers(`${dir}/ok.json`), { 'A B': 'new', 'C D': 'p1' });
  assert.deepEqual(readAnswers(undefined), {});
  assert.throws(() => readAnswers(`${dir}/bad.json`), /--answers/);
});

test('only the instructor-in-charge becomes a professor and fills the offering', () => {
  const courses = {
    'AAA F101': { title: 'T', sections: [{ type: 'L', no: 1, slots: [], instructors: [
      { name: 'Ida Incharge', ic: true }, { name: 'Ash Assistant', ic: false }] }] },
  };
  let n = 0;
  const newId = (k) => `${k}-${++n}`;
  const res = resolveProfessors(courses, [], {}, newId);
  assert.deepEqual(res.newProfs.map((p) => p.name), ['Ida Incharge']);
  const { ops } = planOfferings(courses, new Map(), new Map(), '2026-27-1', 'goa', newId);
  assert.deepEqual(ops.find((o) => o.coll === 'offerings').set.professors, [res.newProfs[0].id]);
});

test('a branch department beats GEN for a professor who leads both', () => {
  const ic = (name) => ({ name, ic: true });
  const c = (name) => ({ title: 'T', sections: [{ type: 'L', no: 1, slots: [], instructors: [ic(name)] }] });
  const courses = { 'BITS F234': c('Abe Chat'), 'ME G641': c('Abe Chat'), 'HSS F343': c('Rena Cher') };
  let n = 0;
  const res = resolveProfessors(courses, [], {}, (k) => `${k}-${++n}`);
  const dept = Object.fromEntries(res.newProfs.map((p) => [p.name, p.dept]));
  assert.deepEqual(dept, { 'Abe Chat': 'ME', 'Rena Cher': 'GEN' });
});

test('credits: LPU units digit; a U course never takes its credit hours; --credits fills and corrects', () => {
  assert.equal(pdfCredits('CS F211', { credits: 4, lpu3: true }), 4);
  assert.equal(pdfCredits('BITS F422T', { credits: 16, lpu3: false }), 16);
  assert.equal(pdfCredits('CS U111', { credits: 12, lpu3: false }), null);
  const courses = {
    'CS U111': { title: 'COMPUTATIONAL THINKING', credits: 12, lpu3: false, sections: [] },
    'EEE U111': { title: 'ELECTRICAL SCIENCES', credits: 10, lpu3: false, sections: [] },
  };
  const cat = { version: 1, master: [], chartOld: [], chartNew: [] };
  const none = planCatalog(courses, cat, 1);
  assert.deepEqual(none.adds, []);
  assert.deepEqual(none.needCredits.map((a) => a.id), ['CS U111', 'EEE U111']);
  const some = planCatalog(courses, cat, 1, { 'CS U111': 4 });
  assert.deepEqual(some.adds.map((a) => [a.id, a.credits]), [['CS U111', 4]]);
  assert.deepEqual(some.next.master.at(-1), ['CS U111', 'Computational Thinking', 4, 'timetable']);
});
