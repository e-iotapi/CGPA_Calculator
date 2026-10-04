// What an import or a rebuild would write, as plain data (no I/O); import.mjs reads the
// live state, calls these, then prints the summary or applies the batches. Ops use the
// timetable tool's shape ({path, set | merge}, values may be {$ts: 1} or {$inc: n}).
import { createHash } from 'node:crypto';

import { buildBatches, CAMPUSES, deptOf, likelySame, nameTokens, normName, resolveProfessors } from '../timetable/plan.mjs';

export const ACTOR = { email: 'import-script@pointer.local', name: 'Pointer' };
const MAX_WRITES = 450; // a Firestore batch holds 500
const MAX_DOC = 900_000; // a doc holds 1 MiB
const GRADES = new Set(['A', 'A-', 'B', 'B-', 'C', 'C-', 'D', 'E', 'NC', 'RC', 'W', 'ND']);
// The review text: these fields, labelled, in this order (owner, 2026-10-05).
const TEXT = [['advice', 'Advice'], ['comments', 'Comments'], ['pr_no', 'PR No'], ['gr_comm', 'Grading'],
  ['open_book', 'Open book'], ['attendance', 'Attendance'], ['slides', 'Slides'], ['evals', 'Evaluations'],
  ['info', 'About the course'], ['course_total', 'Course total']];

const str = (v) => String(v ?? '').trim();
const hash = (x) => createHash('sha256').update(x).digest('hex').slice(0, 20);
const auditOp = (id, summary, path, campus, after) => ({
  path: `audit/${id}`,
  set: { actor: { ...ACTOR, role: 'owner' }, action: summary, summary, path, campus, before: null, after: after ?? null, at: { $ts: 1 } },
});

/** Ops in batches of at most MAX_WRITES, in order. */
export function pack(label, ops) {
  const out = [];
  for (let i = 0; i < ops.length; i += MAX_WRITES) out.push({ label, ops: ops.slice(i, i + MAX_WRITES) });
  return out;
}

// ---- courses -------------------------------------------------------------------

/** Lookups over the catalogue: id without spaces, title, and the known prefixes. */
export function catalogIndex(catalog) {
  const byKey = new Map();
  const byTitle = new Map();
  const prefixes = new Set();
  for (const k of ['master', 'chartOld', 'chartNew']) {
    for (const [id, title] of catalog[k] ?? []) {
      byKey.set(id.replace(/\s/g, ''), id);
      byTitle.set(str(title).toLowerCase(), id);
      prefixes.add(id.split(' ')[0]);
    }
  }
  return { byKey, byTitle, prefixes };
}

/**
 * The course a row is about: its code as the catalogue spells it ("CSF211" -> "CS F211"),
 * else a known prefix with the number ("HSSF314" -> "HSS F314", "HSS338" -> "HSS F338"),
 * else the catalogue title, else null. `answers` ({"HSF226": "HSS F226" | "skip"}) wins.
 */
export function courseIdOf(code, name, idx, answers = {}) {
  const k = str(code).toUpperCase().replace(/[\s-]/g, '');
  // Answers are keyed by the code so written, or by the name when there is no code.
  const a = answers[k || str(name).toUpperCase().replace(/[\s-]/g, '')];
  if (a) return a === 'skip' ? null : a;
  if (idx.byKey.has(k)) return idx.byKey.get(k);
  const m = k.match(/^([A-Z]{2,4}?)([FGU]?)(\d{3}[A-Z]?)$/);
  if (m && idx.prefixes.has(m[1])) return `${m[1]} ${m[2] || 'F'}${m[3]}`;
  return idx.byTitle.get(str(name).toLowerCase()) ?? null;
}

// ---- rows ----------------------------------------------------------------------

/** "2024-25 Sem 1" -> "2024-25-1"; with none, the term of the date it was written. */
export function termOf(takenIn, createdAt) {
  const m = str(takenIn).match(/^(\d{4})-(\d{2})\s*Sem\s*([12])$/i);
  if (m) return `${m[1]}-${m[2]}-${m[3]}`;
  const d = new Date(createdAt);
  if (Number.isNaN(d.getTime())) return null;
  const y = d.getUTCFullYear();
  const yy = (n) => String(n % 100).padStart(2, '0');
  return d.getUTCMonth() >= 7 ? `${y}-${yy(y + 1)}-1` : `${y - 1}-${yy(y)}-2`;
}

export const gradeOf = (g) => (GRADES.has(str(g).toUpperCase()) ? str(g).toUpperCase() : null);

/** The labelled text, empty sections left out; null when there is none. */
export function textOf(row) {
  const t = TEXT.filter(([k]) => str(row[k])).map(([k, label]) => `${label}: ${str(row[k])}`).join('\n\n');
  return t || null;
}

/** The first name in "A / B", "A, B", "A & B" or "A and B". */
export const profOf = (p) => str(p).split(/\s*(?:,|\/|&|\band\b)\s*/i).find(Boolean) ?? '';

// ---- class averages ------------------------------------------------------------

const POINTS = { A: 10, 'A-': 9, B: 8, 'B-': 7, C: 6, 'C-': 5, D: 4, E: 2 };
const LETTER = '(A-|A|B-|B|C-|C|D|E)(?![A-Z])';

/** A reported class average grade as points: "B" 8, "B-/B" or "B or B-" halfway; a guess "B (not sure)" counts, "Idk" does not. */
export function gradePointsOf(v) {
  const t = str(v).toUpperCase();
  const two = t.match(new RegExp(`^${LETTER}\\s*(?:/|OR)\\s*${LETTER}`));
  if (two) return (POINTS[two[1]] + POINTS[two[2]]) / 2;
  const one = t.match(new RegExp(`^${LETTER}(?:\\s|\\(|,|$)`));
  return one ? POINTS[one[1]] : null;
}

/** A reported number: "64", "60ish", "around 50", "70-75" (the middle), "68/100" (and its total). */
export function marksOf(v) {
  const m = str(v).match(/^(?:around\s+|~\s*)?(\d+(?:\.\d+)?)(?:\s*-\s*(\d+(?:\.\d+)?))?(?:\s*\/\s*(\d+(?:\.\d+)?))?/i);
  if (!m) return null;
  const a = Number(m[1]);
  return { marks: m[2] ? (a + Number(m[2])) / 2 : a, outOf: m[3] ? Number(m[3]) : null };
}

const round = (x) => Math.round(x * 100) / 100;

/**
 * The class averages of each course and term, set once at import (owner, 2026-10-05): the
 * mean reported grade (points) and the mean reported marks over the rows giving the term's
 * most common course total. {courseId: {term: {g, gn, m, t, mn}}}.
 */
export function classAverages(picked) {
  const by = new Map();
  for (const { row, cid, term } of picked) {
    const k = `${cid}\u0000${term}`;
    const e = by.get(k) ?? { cid, term, g: [], m: [] };
    const g = gradePointsOf(row.av_grade);
    if (g != null) e.g.push(g);
    const mk = marksOf(row.av_marks);
    const outOf = mk?.outOf ?? marksOf(row.course_total)?.marks;
    // A total under 30 is a typo for one (a "12/13" class average), not a course.
    if (mk && outOf >= 30 && mk.marks <= outOf) e.m.push({ marks: mk.marks, outOf });
    by.set(k, e);
  }
  const out = {};
  for (const e of by.values()) {
    const v = {};
    if (e.g.length) Object.assign(v, { g: round(e.g.reduce((a, b) => a + b) / e.g.length), gn: e.g.length });
    if (e.m.length) {
      const n = new Map();
      for (const x of e.m) n.set(x.outOf, (n.get(x.outOf) ?? 0) + 1);
      const t = [...n].sort((a, b) => b[1] - a[1] || b[0] - a[0])[0][0];
      const ms = e.m.filter((x) => x.outOf === t).map((x) => x.marks);
      Object.assign(v, { m: round(ms.reduce((a, b) => a + b) / ms.length), t, mn: ms.length });
    }
    if (Object.keys(v).length) (out[e.cid] ??= {})[e.term] = v;
  }
  return out;
}

/** The review's doc id: stable across runs, and the source id is not kept. */
export const reviewIdOf = (sourceId) => `imp_${hash(`review|${sourceId}`)}`;

// ---- the import ----------------------------------------------------------------

/**
 * Everything one import run adds: new professors, reviews and handout links. Never
 * overwrites: a review or handout already there (by id, or a live link with the same
 * address on the course) is left alone, votes and all.
 *  live: {profs, existing: Set<path>, resources: [{id, url, courseIds, removed}]}
 */
export function planImport({ rows, ratings, courses, idx, live, answers = {}, campus = 'goa', newId }) {
  const skipped = [];
  const unknownCodes = new Map();
  const picked = [];
  rows.forEach((row, i) => {
    const cid = courseIdOf(row.course_code, row.course_name, idx, answers.courses);
    const r = ratings[row.review_id];
    if (!cid) {
      const key = (str(row.course_code) || str(row.course_name)).toUpperCase().replace(/[\s-]/g, '');
      skipped.push({ row: i, why: !key ? 'no course' : answers.courses?.[key] === 'skip' ? 'skipped by your answer' : 'course not recognised' });
      if (key && answers.courses?.[key] !== 'skip') {
        unknownCodes.set(key, (unknownCodes.get(key) ?? 0) + 1);
      }
      return;
    }
    if (!r) return skipped.push({ row: i, why: 'no derived rating' });
    const term = termOf(row.taken_in, row.created_at);
    if (!term) return skipped.push({ row: i, why: 'no term' });
    // answers.aliases: {"review spelling": "the professor's name" | null (no professor)}.
    const p = profOf(row.prof);
    picked.push({ row, cid, r, term, prof: (answers.aliases && p in answers.aliases ? answers.aliases[p] : p) ?? '' });
  });

  // Professors: the timetable tool's matcher, every name as an instructor-in-charge.
  const byCourse = {};
  for (const p of picked) {
    if (!p.prof) continue;
    const c = (byCourse[p.cid] ??= { sections: [{ type: 'L', instructors: [] }] });
    c.sections[0].instructors.push({ name: p.prof, ic: true });
  }
  const res = resolveProfessors(byCourse, live.profs, answers.professors, newId);
  const settled = new Map(res.entries.filter((e) => ['linked', 'alias', 'new'].includes(e.status)).map((e) => [e.norm, e.id]));
  const profBatches = buildBatches({ campus, term: '', res, offerings: { ops: [] }, catalog: {}, catalogAdds: [], timetable: { changed: false }, newId })
    .map((b) => ({
      ...b,
      ops: b.ops.map((o) => (o.coll === 'professors' && o.set ? { ...o, set: { ...o.set, src: 'import', updatedBy: ACTOR } }
        : o.coll === 'professors' ? { ...o, merge: { ...o.merge, updatedBy: ACTOR } }
          : o.coll === 'audit' ? { ...o, set: { ...o.set, actor: { ...ACTOR, role: 'owner' } } } : o)),
    }));

  const reviewOps = [];
  let kept = 0;
  for (const { row, cid, r, term, prof } of picked) {
    const path = `reviews/${cid}/entries/${reviewIdOf(row.review_id)}`;
    if (live.existing.has(path)) { kept++; continue; }
    const text = textOf(row);
    const grade = gradeOf(row.your_grade);
    reviewOps.push({
      path,
      set: {
        courseId: cid, department: deptOf(cid), campus, term,
        stars: r.stars, recommend: r.recommend,
        ...(text ? { text } : {}), ...(grade ? { grade } : {}),
        professorId: prof ? settled.get(normName(prof)) ?? null : null,
        hidden: false, reason: null, helpful: 0, reports: 0,
        createdAt: { $ts: 1 }, updatedAt: { $ts: 1 },
      },
    });
  }
  // The class averages, once: only where the course's copy has none yet.
  const classes = classAverages(picked);
  const baseOps = Object.entries(classes)
    .filter(([cid]) => !live.based?.has(`reviews/${cid}/campus/${campus}`))
    .map(([cid, base]) => ({ path: `reviews/${cid}/campus/${campus}`, merge: { base } }));
  if (reviewOps.length) {
    const auditId = newId('audit');
    reviewOps.push(auditOp(auditId, `Imported ${reviewOps.length} course reviews`, 'reviews', campus, { count: reviewOps.length }));
  }

  // Handouts: one "Handout" link per course, on the course's own list.
  const norm = (u) => str(u).toLowerCase().replace(/^[a-z]+:\/\//, '').replace(/^www\./, '').split(/[?#]/)[0].replace(/\/+$/, '');
  const onCourse = new Set(live.resources.filter((x) => !x.removed).flatMap((x) => (x.courseIds ?? []).map((c) => `${c}|${norm(x.url)}`)));
  const handoutOps = [];
  const handoutSkipped = [];
  for (const c of courses) {
    const url = str(c.course_handout);
    if (!url) continue;
    const cid = courseIdOf(c.course_code, c.course_name, idx, answers.courses);
    let host = null;
    try { host = new URL(url).host.toLowerCase().replace(/^www\./, ''); } catch { /* not a URL */ }
    if (!cid || !host || !/^https?:/.test(url)) { handoutSkipped.push({ code: str(c.course_code), why: cid ? 'not a link' : 'course not recognised' }); continue; }
    const id = `imp_${hash(`handout|${cid}`)}`;
    if (live.existing.has(`resources/${id}`) || onCourse.has(`${cid}|${norm(url)}`)) continue;
    const auditId = newId('audit');
    handoutOps.push(
      {
        path: `resources/${id}`,
        set: {
          title: 'Handout', url, host, kind: { 'docs.google.com': 'doc', 'drive.google.com': 'folder', 'youtube.com': 'video', 'youtu.be': 'video' }[host] ?? 'link',
          campus, department: deptOf(cid), scope: 'course', courseIds: [cid], pinnedToDepartment: false,
          addedBy: { email: ACTOR.email, name: ACTOR.name }, addedAt: { $ts: 1 }, removed: false, auditId, actingFor: '',
        },
      },
      auditOp(auditId, `Added “Handout” to ${cid}`, `resources/${id}`, campus, { url }),
    );
  }

  return {
    res, skipped, unknownCodes, kept, handoutSkipped,
    notInCatalog: [...new Set(picked.map((p) => p.cid))].filter((c) => !idx.byKey.has(c.replace(/\s/g, ''))).sort(),
    reviews: reviewOps.filter((o) => o.path.startsWith('reviews/')).length,
    handouts: handoutOps.filter((o) => o.path.startsWith('resources/')).length,
    classCourses: baseOps.length,
    batches: [...profBatches, ...pack('reviews', reviewOps), ...pack('class averages', baseOps), ...pack('handouts', handoutOps)],
  };
}

// ---- faculty ---------------------------------------------------------------------

// The campus website's departments as the app's; HSS and General Sciences are GEN.
const FACULTY_DEPTS = {
  'Electrical & Electronics Engineering': 'ELEC', 'Computer Science & Information Systems': 'CS', 'Computer Science': 'CS',
  'Mechanical Engineering': 'ME', 'Chemical Engineering': 'CHE', Mathematics: 'MATH', 'Biological Sciences': 'BIO',
  Physics: 'PHY', Chemistry: 'CHEM', 'Economics & Finance': 'ECON',
};
export const facultyDept = (d) => FACULTY_DEPTS[str(d)] ?? 'GEN';

/** "Dr. Mainak Banerjee, PhD, FRSC" -> "Mainak Banerjee": the website's titles off. */
export const cleanFacultyName = (n) => str(n).replace(/^(?:(?:dr|prof|professor)\.?\s+)+/i, '')
  .replace(/(?:,\s*(?:ph\.?\s*d\.?|frsc|fna|fnasc|fasc))+\s*$/i, '').replace(/\s+/g, ' ').trim();

/** "https://…/goa/a-baskar" -> "fac_a-baskar": the same person gets the same id on every run. */
export const facultyIdOf = (url) => `fac_${str(url).replace(/\/+$/, '').split('/').pop().toLowerCase().replace(/[^a-z0-9-]/g, '')}`;

/**
 * The campus faculty list as professors: one doc each, id from the profile address. A
 * faculty member whose name a live professor already has (or an alias of) is that
 * professor: nothing written. A close but not exact name is listed, not created, until
 * answers ({"Faculty Name": "<professor id>" | "new"}) settles it.
 */
export function planFaculty({ faculty, live, answers = {}, campus = 'goa', newId }) {
  const liveProfs = live.profs.filter((p) => !p.mergedInto);
  const byName = new Map();
  for (const p of liveProfs) for (const n of [p.name, ...(p.aliases ?? [])]) if (!byName.has(normName(n))) byName.set(normName(n), p.id);
  const ops = [];
  const out = { created: [], linked: [], unsure: [], skipped: [] };
  const depts = new Set();
  for (const raw of faculty) {
    const f = { ...raw, name: cleanFacultyName(raw.name) };
    if (!/goa/i.test(f.campus)) { out.skipped.push(f.name); continue; }
    const id = facultyIdOf(f.url);
    const a = answers[f.name];
    const same = byName.get(normName(f.name)) ?? (a && a !== 'new' ? a : null);
    if (same || live.existing.has(`professors/${id}`)) { out.linked.push({ name: f.name, id: same ?? id }); continue; }
    const near = liveProfs.filter((p) => !p.removed && [p.name, ...(p.aliases ?? [])].some((n) => likelySame(f.name, n)));
    if (near.length && a !== 'new') { out.unsure.push({ name: f.name, candidates: near.map((p) => `${p.name} (${p.id})`) }); continue; }
    const department = facultyDept(f.department);
    const auditId = newId('audit');
    ops.push(
      {
        path: `professors/${id}`,
        set: {
          name: f.name, campus, department, aliases: [], nameTokens: [...nameTokens(f.name)], mergedIds: [], active: true,
          designation: str(f.designation), profile: str(f.url), src: 'faculty', updatedBy: ACTOR, updatedAt: { $ts: 1 }, auditId,
        },
      },
      auditOp(auditId, `Added professor ${f.name} to ${department}`, `professors/${id}`, campus, { name: f.name, department, src: 'faculty' }),
    );
    depts.add(department);
    out.created.push({ name: f.name, id, department });
  }
  const heads = { path: `heads/${campus}`, merge: { v: Object.fromEntries([...depts].map((d) => [`professors/${d}`, { $inc: 1 }])) } };
  // At most 4 markers per batch, as the app writes them; a department's docs stay in one batch.
  const byDept = new Map();
  for (let i = 0; i < ops.length; i += 2) {
    const d = ops[i].set.department;
    (byDept.get(d) ?? byDept.set(d, []).get(d)).push(ops[i], ops[i + 1]);
  }
  const batches = [];
  let cur = null;
  for (const [d, list] of byDept) {
    if (!cur || cur.depts.length >= 4 || cur.ops.length + list.length > MAX_WRITES - 1) batches.push(cur = { label: 'faculty', ops: [], depts: [] });
    cur.ops.push(...list);
    cur.depts.push(d);
  }
  for (const b of batches) b.ops.push({ ...heads, merge: { v: Object.fromEntries(b.depts.map((d) => [`professors/${d}`, { $inc: 1 }])) } });
  return { ...out, batches: batches.map(({ label, ops: o }) => ({ label, ops: o })) };
}

// ---- the rebuild ---------------------------------------------------------------

const statsId = (campus, p) => (p == null ? campus : `${campus}_${p}`);
const ms = (t) => (typeof t === 'number' ? t : t?.toMillis?.() ?? Date.now());

/**
 * Every copy the app reads instead of the source docs, recomputed from them:
 * course and professor counters, reviewIndex/<campus>, the review copies
 * reviews/<c>/campus/<campus>, the links map of resourceVersions/<campus> and
 * repIndex/<campus>; then the heads markers move so caches re-read.
 * The import's class averages (`base`) on a copy are kept as they are.
 *  src: {entries: [{courseId, id, d}], stats: [path], mirrors: [{path, base}], resources: [{id, d}], directory: [{id, d}]}
 */
export function planRebuild(src, now = Date.now()) {
  const stats = new Map();
  const index = Object.fromEntries(CAMPUSES.map((c) => [c, {}]));
  const mirrors = new Map();
  for (const { courseId: c, id, d: raw } of src.entries) {
    // An empty professor id is no professor (an early import wrote '').
    const d = { ...raw, professorId: raw.professorId || null };
    if (d.hidden || !CAMPUSES.includes(d.campus)) continue;
    for (const p of d.professorId == null ? [null] : [null, d.professorId]) {
      const path = `courses/${c}/stats/${statsId(d.campus, p)}`;
      const t = stats.get(path) ?? { count: 0, starSum: 0, recommendCount: 0, courseId: c, campus: d.campus, scope: p == null ? 'course' : 'professor', professorId: p };
      t.count += 1;
      t.starSum += d.stars;
      t.recommendCount += d.recommend ? 1 : 0;
      stats.set(path, t);
    }
    const ix = (index[d.campus][c] ??= { count: 0, starSum: 0, recommendCount: 0 });
    ix.count += 1;
    ix.starSum += d.stars;
    ix.recommendCount += d.recommend ? 1 : 0;
    const m = mirrors.get(`reviews/${c}/campus/${d.campus}`) ?? {};
    m[id] = {
      stars: d.stars, recommend: d.recommend, text: d.text ?? null, term: d.term,
      ...(d.grade != null ? { grade: d.grade } : {}), ...(d.marks != null ? { marks: d.marks } : {}),
      professorId: d.professorId ?? null, helpful: d.helpful ?? 0, createdAt: d.createdAt, updatedAt: d.updatedAt,
    };
    mirrors.set(`reviews/${c}/campus/${d.campus}`, m);
  }

  const ops = [];
  for (const [path, t] of stats) ops.push({ path, set: t });
  // A counter no live review backs any more goes.
  for (const path of src.stats) if (!stats.has(path)) ops.push({ path, action: 'delete' });
  const bases = new Map(src.mirrors.filter((x) => x.base).map((x) => [x.path, x.base]));
  for (const { path } of src.mirrors) if (!mirrors.has(path)) mirrors.set(path, {});
  const marks = Object.fromEntries(CAMPUSES.map((c) => [c, { reviews: { $inc: 1 }, resources: { $inc: 1 }, reps: { $inc: 1 } }]));
  for (const [path, r] of mirrors) {
    const size = Buffer.byteLength(JSON.stringify(r));
    if (size > MAX_DOC) throw new Error(`${path} would be ${size} bytes: too big for one doc`);
    ops.push({ path, set: { k: 'rebuild', r, ...(bases.has(path) ? { base: bases.get(path) } : {}) } });
    const [, c, , campus] = path.split('/');
    marks[campus][`reviews/${c}`] = { $inc: 1 };
  }
  for (const c of CAMPUSES) ops.push({ path: `reviewIndex/${c}`, set: { k: 'rebuild', c: index[c] } });

  const links = Object.fromEntries(CAMPUSES.map((c) => [c, {}]));
  for (const { id, d } of src.resources) {
    if (d.removed || !links[d.campus]) continue;
    links[d.campus][id] = {
      title: d.title, url: d.url, host: d.host, kind: d.kind, department: d.department, scope: d.scope ?? 'department',
      courseIds: d.courseIds ?? [], pinnedToDepartment: d.pinnedToDepartment ?? false,
      addedBy: { name: d.addedBy?.name ?? '', email: d.addedBy?.email ?? '' }, addedAt: ms(d.addedAt),
      // The contributor flows' fields, as their writes leave them in the copy.
      ...(d.approved === false ? { approved: false } : {}),
      ...(d.publishedAt != null ? { publishedAt: ms(d.publishedAt) } : {}),
      ...(d.batchId ? { batchId: d.batchId } : {}),
      ...(d.rejectedReason ? { rejectedReason: d.rejectedReason } : {}),
    };
  }
  // v moves to a new value, never back to one a cache may hold.
  for (const c of CAMPUSES) ops.push({ path: `resourceVersions/${c}`, set: { v: now, k: 'rebuild', links: links[c] } });

  const reps = Object.fromEntries(CAMPUSES.map((c) => [c, {}]));
  for (const { id, d } of src.directory) if (reps[d.campus]) reps[d.campus][id] = d;
  for (const c of CAMPUSES) ops.push({ path: `repIndex/${c}`, set: { k: 'rebuild', p: reps[c] } });

  // Markers last, in the final batch, so a cache never re-reads a half-written copy.
  const batches = pack('rebuild', ops);
  const heads = CAMPUSES.map((c) => ({ path: `heads/${c}`, merge: { v: marks[c] } }));
  if (batches.length && batches.at(-1).ops.length + heads.length <= MAX_WRITES) batches.at(-1).ops.push(...heads);
  else batches.push({ label: 'heads', ops: heads });
  return {
    batches,
    counts: {
      stats: stats.size, removed: src.stats.filter((p) => !stats.has(p)).length, mirrors: mirrors.size,
      reviews: Object.values(index).reduce((n, c) => n + Object.values(c).reduce((m, t) => m + t.count, 0), 0),
      links: Object.fromEntries(CAMPUSES.map((c) => [c, Object.keys(links[c]).length])),
      reps: Object.fromEntries(CAMPUSES.map((c) => [c, Object.keys(reps[c]).length])),
    },
  };
}
