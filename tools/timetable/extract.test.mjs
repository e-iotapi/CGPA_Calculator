// Matching, chunking, argument checks and the report, on invented data.
import assert from 'node:assert/strict';
import { test } from 'node:test';

import { matchProfessors, normName, packChunks, parseArgs, profIndex, summarize, unknownCourseIds } from './extract.mjs';

const course = (...names) => ({ title: 'T', sections: [{ type: 'L', no: 1, instructors: names.map((name) => ({ name, ic: false })), slots: [] }] });

test('normName ignores case, titles, dots and word order', () => {
  assert.equal(normName('Dr. Alder  QUILL'), normName('quill alder'));
  assert.equal(normName('Prof. B. Moss'), normName('Moss B'));
  assert.notEqual(normName('Birch Moss'), normName('Birch Mossy'));
});

test('matchProfessors: by name or alias, per campus, survivors of merges, unmatched listed once', () => {
  const idx = profIndex([
    { id: 'p1', name: 'Dr. Alder Quill', campus: 'goa' },
    { id: 'p2', name: 'Birch Moss', aliases: ['Moss B'], campus: 'goa' },
    { id: 'p3', name: 'Prof. Birch Moss', campus: 'goa', mergedInto: 'p2' },
    { id: 'p4', name: 'Cedar Vale', campus: 'pilani' },
  ], 'goa');
  const courses = { 'ZZZ F1': course('ALDER QUILL', 'Cedar Vale'), 'ZZZ F2': course('moss birch', 'Cedar Vale', 'Dune Ash') };
  const unmatched = matchProfessors(courses, idx);
  assert.deepEqual(unmatched, ['Cedar Vale', 'Dune Ash']);
  assert.equal(courses['ZZZ F1'].sections[0].instructors[0].prof, 'p1');
  assert.equal(courses['ZZZ F2'].sections[0].instructors[0].prof, 'p2');
  assert.equal(courses['ZZZ F1'].sections[0].instructors[1].prof, undefined);
});

test('unknownCourseIds checks the bundled catalogue lists', () => {
  const catalog = { master: [['AAA F101', 'x', 3]], chartOld: [['BBB F101', 'y', 3]], chartNew: [['CCC F101', 'z', 3]] };
  assert.deepEqual(unknownCourseIds({ 'AAA F101': {}, 'CCC F101': {}, 'DDD F101': {} }, catalog), ['DDD F101']);
});

test('packChunks: keeps a prefix together, stays under the limit, loses nothing', () => {
  const courses = {};
  for (const p of ['AAA', 'BBB', 'CCC']) for (let i = 0; i < 10; i++) courses[`${p} F${100 + i}`] = { title: 'x'.repeat(100), sections: [] };
  const one = packChunks(courses, 1_000_000);
  assert.equal(one.length, 1);
  const many = packChunks(courses, 1500);
  assert.ok(many.length > 1);
  for (const ch of many) assert.ok(Buffer.byteLength(JSON.stringify(ch)) <= 1500);
  assert.equal(many.reduce((n, ch) => n + Object.keys(ch).length, 0), 30);
  // A prefix that fits one chunk is not split across two.
  for (const p of ['AAA', 'BBB', 'CCC']) assert.equal(many.filter((ch) => Object.keys(ch).some((k) => k.startsWith(p))).length, 1);
  // One prefix bigger than the limit is split by course.
  const big = packChunks(Object.fromEntries(Object.entries(courses).filter(([k]) => k.startsWith('AAA'))), 600);
  assert.ok(big.length > 1);
});

test('parseArgs: required options, commit needs a project, unknown flags refused', () => {
  const ok = parseArgs(['t.pdf', '--campus', 'goa', '--sem', '2026-1']);
  assert.deepEqual([ok.input, ok.campus, ok.sem, ok.commit], ['t.pdf', 'goa', '2026-1', undefined]);
  assert.throws(() => parseArgs(['t.pdf', '--campus', 'mars', '--sem', '2026-1']), /campus/);
  assert.throws(() => parseArgs(['t.pdf', '--campus', 'goa', '--sem', '26']), /sem/);
  assert.throws(() => parseArgs(['t.pdf', '--campus', 'goa', '--sem', '2026-1', '--commit']), /--project/);
  assert.throws(() => parseArgs(['t.pdf', '--campus', 'goa', '--sem', '2026-1', '--nope']), /Unknown/);
  assert.throws(() => parseArgs(['--campus', 'goa', '--sem', '2026-1']), /Usage/);
  assert.equal(parseArgs(['t.pdf', '--campus', 'goa', '--sem', '2026-1', '--project', 'staging', '--key', 'k.json', '--commit']).key, 'k.json');
});

test('summarize: counts, page and line of unparsed rows, and the not-checked note', () => {
  const result = {
    campus: 'goa', sem: '2026-1', courses: { 'ZZZ F1': course('A B') }, events: [{}, {}], conflicts: [],
    unparsed: [{ page: 7, line: 12, why: 'no STAT/SEC' }],
  };
  const text = summarize(result, { chunks: 1, unmatched: null, unknown: ['ZZZ F1'] });
  assert.match(text, /courses: 1\n/);
  assert.match(text, /events: 2/);
  assert.match(text, /page 7 line 12: no STAT\/SEC/);
  assert.match(text, /not checked/);
  assert.match(text, /unknown course ids: 1\n  ZZZ F1/);
});
