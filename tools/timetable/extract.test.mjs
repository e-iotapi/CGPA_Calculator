// Matching, chunking, argument checks and the report, on invented data.
import assert from 'node:assert/strict';
import { test } from 'node:test';

import { makePlan, normName, packChunks, parseArgs, summarize, toSchema, unknownCourseIds } from './extract.mjs';

const course = (...names) => ({ title: 'T', sections: [{ type: 'L', no: 1, instructors: names.map((name) => ({ name, ic: true })), slots: [] }] });

test('normName ignores case, titles, dots and word order', () => {
  assert.equal(normName('Dr. Alder  QUILL'), normName('quill alder'));
  assert.equal(normName('Prof. B. Moss'), normName('Moss B'));
  assert.notEqual(normName('Birch Moss'), normName('Birch Mossy'));
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

test('parseArgs: --report and --answers are taken, --report refuses --commit', () => {
  const a = parseArgs(['t.pdf', '--campus', 'goa', '--sem', '2026-1', '--report', 'r.md', '--answers', 'a.json']);
  assert.deepEqual([a.report, a.answers], ['r.md', 'a.json']);
  assert.throws(() => parseArgs(['t.pdf', '--campus', 'goa', '--sem', '2026-1', '--project', 'x', '--commit', '--report', 'r.md']), /dry run/);
});

test('summarize: counts, page and line of unparsed rows, and the headline numbers', () => {
  const out = {
    campus: 'goa', sem: '2026-1', courses: { 'ZZZ F1': course('Zed Quux') }, events: [{}, {}], conflicts: [], hours: { periods: {}, compre: {} },
    unparsed: [{ page: 7, line: 12, why: 'bad row' }],
  };
  const text = summarize(out, makePlan({ campus: 'goa', sem: '2026-1', input: 't' }, out, null, {}, { version: 1, schema: 1, master: [], chartOld: [], chartNew: [], retired: [] }));
  assert.match(text, /courses: 1\n/);
  assert.match(text, /events: 2/);
  assert.match(text, /page 7 line 12: bad row/);
  assert.match(text, /new courses \(not in the catalogue\): 1\n  ZZZ F1 /);
  assert.match(text, /new professors: 1\n  Zed Quux \(GEN\)/);
  assert.match(text, /unsure matches, need your answer: 0/);
});

test('toSchema: day numbers, minutes, L/T/P only, profIds parallel, sem events only', () => {
  const out = {
    campus: 'goa', sem: '2026-1',
    hours: { periods: { 1: ['08:00', '09:00'] }, compre: { FN: ['10:00', '13:00'] } },
    events: [
      { date: '2026-08-03', title: 'Begins', kind: 'term', part: 'sem1' },
      { date: '2027-01-05', end: '2027-01-06', title: 'Later', kind: 'term', part: 'sem2' },
    ],
    courses: { 'ZZZ F1': {
      title: 'T',
      compre: { date: '2026-12-10', session: 'FN', start: '10:00', end: '13:00' },
      midsem: { date: '2026-10-12', note: 'Forenoon' },
      sections: [
        { type: 'L', no: 1, room: 'F101', instructors: [{ name: 'A', prof: 'p1' }, { name: 'B' }], slots: [{ day: 'TH', start: '09:00', end: '10:30' }] },
        { type: 'I', no: 1, instructors: [], slots: [] },
      ],
    } },
  };
  const t = toSchema(out, { marker: 3, publishedAt: 5 });
  assert.deepEqual(t.hours, { 1: [480, 540] });
  assert.deepEqual(t.examSlots, { FN: [600, 780] });
  assert.deepEqual(t.events, [{ from: '2026-08-03', title: 'Begins', kind: 'term' }]);
  const c = t.courses['ZZZ F1'];
  assert.deepEqual(c.sec, [{ ty: 'L', no: 1, prof: ['A', 'B'], slots: [{ d: 4, s: 540, e: 630 }], profIds: ['p1', ''], room: 'F101' }]);
  assert.deepEqual(c.compre, { d: '2026-12-10', slot: 'FN', s: 600, e: 780 });
  assert.equal(c.mid, undefined);
  assert.equal(t.marker, 3);
});
