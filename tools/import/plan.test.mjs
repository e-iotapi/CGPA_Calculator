// node --test tools/import/plan.test.mjs (synthetic rows only; never the real export).
import assert from 'node:assert/strict';
import { test } from 'node:test';

import { catalogIndex, classAverages, cleanFacultyName, courseIdOf, facultyIdOf, planFaculty, planImport, planRebuild, termOf, textOf } from './plan.mjs';

const idx = catalogIndex({ master: [['HSS F314', 'Maritime Studies', 3], ['CS F211', 'Data Structures', 4]], chartOld: [], chartNew: [] });
const row = (o) => ({ review_id: 'r1', course_code: 'CSF211', course_name: '', prof: 'Dr. Alder Quill', taken_in: '2024-25 Sem 1', created_at: '2025-01-01T00:00:00Z', your_grade: 'a-', ...o });
let n = 0;
const newId = (k) => `${k}-${++n}`;
const live = (o = {}) => ({ profs: [], resources: [], existing: new Set(), based: new Set(), ...o });

test('course codes, terms and text', () => {
  assert.equal(courseIdOf('CSF211', '', idx), 'CS F211');
  assert.equal(courseIdOf('HSSF314', '', idx), 'HSS F314');
  assert.equal(courseIdOf('HSS338', '', idx), 'HSS F338');
  assert.equal(courseIdOf('', 'data structures', idx), 'CS F211');
  assert.equal(courseIdOf('F419', 'MCCET', idx), null);
  assert.equal(courseIdOf('F419', '', idx, { F419: 'BITS F419' }), 'BITS F419');
  assert.equal(termOf('2023-24 Sem 2'), '2023-24-2');
  assert.equal(termOf('', '2026-06-10T19:35:28Z'), '2025-26-2');
  assert.equal(termOf('', '2025-09-01T00:00:00Z'), '2025-26-1');
  assert.equal(textOf({ advice: ' Go ', pr_no: '12', course_total: '200' }), 'Advice: Go\n\nPR No: 12\n\nCourse total: 200');
  assert.equal(textOf({}), null);
});

test('class averages: grade points, and marks over the most common total', () => {
  const picked = [
    { cid: 'C', term: 't', row: { av_grade: 'B', av_marks: '60', course_total: '100' } },
    { cid: 'C', term: 't', row: { av_grade: 'B-/B', av_marks: '70ish', course_total: '100' } },
    { cid: 'C', term: 't', row: { av_grade: 'Idk', av_marks: '150', course_total: '200' } },
    { cid: 'C', term: 't', row: { av_grade: '', av_marks: '120', course_total: '100' } }, // above its total: dropped
  ];
  assert.deepEqual(classAverages(picked), { C: { t: { g: 7.75, gn: 2, m: 65, t: 100, mn: 2 } } });
});

test('import: reviews, professors, handouts; a second run adds nothing', () => {
  const rows = [
    row({}),
    row({ review_id: 'r2', prof: 'A. Quill', your_grade: '71 ish', advice: 'x' }),
    row({ review_id: 'r3', course_code: '', course_name: '' }),
    row({ review_id: 'r4', prof: '' }),
  ];
  const ratings = { r1: { stars: 4, recommend: true }, r2: { stars: 2, recommend: false }, r3: { stars: 3, recommend: true }, r4: { stars: 3, recommend: true } };
  const courses = [{ course_code: 'CS F211', course_handout: 'https://drive.google.com/file/d/x' }];
  const aliases = { 'A. Quill': 'Dr. Alder Quill' };
  const p = planImport({ rows, ratings, courses, idx, live: live(), answers: { aliases }, newId });
  assert.equal(p.reviews, 3);
  assert.deepEqual(p.skipped.map((s) => s.why), ['no course']);
  assert.equal(p.res.newProfs.length, 1);
  const ops = p.batches.flatMap((b) => b.ops);
  const reviews = ops.filter((o) => /^reviews\/CS F211\/entries\/imp_/.test(o.path));
  assert.equal(reviews.length, 3);
  assert.equal(reviews[0].set.professorId, reviews[1].set.professorId);
  assert.equal(reviews[2].set.professorId, null, 'no professor is null, never an empty id');
  assert.equal(reviews[0].set.grade, 'A-');
  assert.equal(reviews[1].set.grade, undefined);
  assert.equal(reviews[0].set.text, undefined);
  assert.ok(!JSON.stringify(ops).includes('r1'), 'the source id is not kept');
  const link = ops.find((o) => o.path.startsWith('resources/'));
  assert.equal(link.set.kind, 'folder');
  assert.deepEqual(link.set.courseIds, ['CS F211']);

  const again = planImport({
    rows, ratings, courses, idx, answers: { aliases }, newId,
    live: live({
      profs: [{ id: p.res.newProfs[0].id, name: 'Alder Quill' }],
      existing: new Set(ops.map((o) => o.path)),
      resources: [{ url: link.set.url, courseIds: ['CS F211'] }],
    }),
  });
  assert.equal(again.reviews, 0);
  assert.equal(again.kept, 3);
  assert.equal(again.handouts, 0);
  assert.equal(again.res.newProfs.length, 0);
});

test('rebuild: counters, copies, links and reps from the source docs', () => {
  const ts = { toMillis: () => 5 };
  const e = (id, d) => ({ courseId: 'CS F211', id, d: { campus: 'goa', term: 't', stars: 4, recommend: true, helpful: 1, createdAt: ts, updatedAt: ts, ...d } });
  const plan = planRebuild({
    entries: [e('a', { professorId: 'p1' }), e('b', { stars: 2, recommend: false, professorId: '' }), e('h', { hidden: true })],
    stats: ['courses/CS F211/stats/goa', 'courses/OLD/stats/goa'],
    mirrors: [{ path: 'reviews/CS F211/campus/goa', base: { t: { g: 8, gn: 1 } } }, { path: 'reviews/OLD/campus/goa', base: null }],
    resources: [
      { id: 'l1', d: { campus: 'goa', title: 'T', url: 'u', host: 'h', kind: 'link', department: 'CS', addedAt: ts, removed: false } },
      { id: 'l2', d: { campus: 'goa', removed: true } },
      { id: 'l3', d: { campus: 'goa', title: 'C', approved: false, publishedAt: ts, addedAt: 1 } },
    ],
    directory: [{ id: 'x@y', d: { campus: 'pilani', name: 'X' } }],
  }, 99);
  const ops = Object.fromEntries(plan.batches.flatMap((b) => b.ops).map((o) => [o.path, o.set ?? o.merge]));
  assert.deepEqual(ops['courses/CS F211/stats/goa'], { count: 2, starSum: 6, recommendCount: 1, courseId: 'CS F211', campus: 'goa', scope: 'course', professorId: null });
  assert.equal(ops['courses/CS F211/stats/goa_p1'].count, 1);
  assert.equal(ops['courses/OLD/stats/goa'], undefined);
  assert.equal(plan.batches.flatMap((b) => b.ops).find((o) => o.path === 'courses/OLD/stats/goa').action, 'delete');
  assert.equal(ops['courses/CS F211/stats/goa_'], undefined, "'' is no professor");
  assert.deepEqual(Object.keys(ops['reviews/CS F211/campus/goa'].r), ['a', 'b']);
  assert.deepEqual(ops['reviews/CS F211/campus/goa'].base, { t: { g: 8, gn: 1 } });
  assert.deepEqual(ops['reviews/OLD/campus/goa'], { k: 'rebuild', r: {} });
  assert.deepEqual(ops['reviewIndex/goa'].c['CS F211'], { count: 2, starSum: 6, recommendCount: 1 });
  assert.deepEqual(Object.keys(ops['resourceVersions/goa'].links), ['l1', 'l3']);
  assert.equal(ops['resourceVersions/goa'].links.l1.addedAt, 5);
  assert.equal(ops['resourceVersions/goa'].links.l3.approved, false);
  assert.equal(ops['resourceVersions/goa'].v, 99);
  assert.deepEqual(Object.keys(ops['repIndex/pilani'].p), ['x@y']);
  assert.deepEqual(ops['repIndex/goa'].p, {});
  assert.deepEqual(Object.keys(ops['heads/goa'].v).sort(), ['reps', 'resources', 'reviews', 'reviews/CS F211', 'reviews/OLD']);
  assert.equal(plan.batches.at(-1).ops.at(-1).path, 'heads/dubai', 'markers move last');
});

test('faculty: one professor each under their own department, titles off, existing names kept', () => {
  assert.equal(cleanFacultyName('Dr. Mainak Banerjee, PhD, FRSC'), 'Mainak Banerjee');
  assert.equal(cleanFacultyName('Prof. K.A.Geetha'), 'K.A.Geetha');
  assert.equal(facultyIdOf('https://x/goa/a-baskar/'), 'fac_a-baskar');
  const f = (name, department, slug, campus = 'K K Birla Goa') => ({ name, department, url: `https://x/goa/${slug}`, campus });
  const faculty = [
    f('Dr. Leshma Manogna', 'Economics & Finance', 'leshma'),
    f('Ann Other', 'Humanities and Social Sciences', 'ann'),
    f('Al Ready', 'Physics', 'al'),
    f('Bo Near', 'Physics', 'bo'),
    f('Du Bai', 'Physics', 'du', 'Dubai'),
  ];
  const live = { profs: [{ id: 'p1', name: 'AL READY' }, { id: 'p2', name: 'B. Near' }], existing: new Set() };
  const p = planFaculty({ faculty, live, newId });
  assert.deepEqual(p.created.map((c) => [c.id, c.name, c.department]), [['fac_leshma', 'Leshma Manogna', 'ECON'], ['fac_ann', 'Ann Other', 'GEN']]);
  assert.deepEqual(p.linked, [{ name: 'Al Ready', id: 'p1' }]);
  assert.equal(p.unsure[0].name, 'Bo Near');
  assert.deepEqual(p.skipped, ['Du Bai']);
  const heads = p.batches.flatMap((b) => b.ops).filter((o) => o.path === 'heads/goa');
  assert.deepEqual(Object.keys(heads[0].merge.v).sort(), ['professors/ECON', 'professors/GEN']);
  assert.equal(planFaculty({ faculty, live, newId, answers: { 'Bo Near': 'new' } }).created.length, 3);
});
