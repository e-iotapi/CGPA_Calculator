// What a run would write, as plain data (no I/O). extract.mjs reads the live state,
// calls these, then either prints the report (report.mjs) or applies the batches.
//
// An op is {coll, path, action: create|update|unchanged|delete, set | merge, before, note}.
// Values in `set`/`merge` may be {$inc: n} (counter) or {$ts: 1} (server time); the
// writer turns them into FieldValue. Only ever adds: nothing here renames or deletes
// a professor, course or offering (the only delete is a chunk doc a shorter timetable no longer fills).

export const ACTOR = { email: 'timetable-script@pointer.local', name: 'Timetable extractor' };
export const CAMPUSES = ['goa', 'pilani', 'hyderabad', 'dubai'];
export const MAX_MARKER_KEYS = 4; // heads rule: at most 4 `v` keys move per head write
const MAX_WRITES = 450; // a Firestore batch holds 500
const OFFERING_CHUNK = 100;

// ---- ports of the app's helpers ----------------------------------------------

const TITLES = new Set(['dr', 'prof', 'professor', 'mr', 'mrs', 'ms', 'shri', 'smt']);

/** "Dr. R. Menon" -> "menon r": lowercase, no titles or dots, words sorted so order does not matter. */
export function normName(name) {
  return name.toLowerCase().replace(/[.,]/g, ' ').split(/\s+/).filter((w) => w && !TITLES.has(w)).sort().join(' ');
}

/** lib/core/professors/professor.dart nameTokens: every word and its prefixes (to 12), titles dropped. */
export function nameTokens(name) {
  const out = new Set();
  for (const w of name.toLowerCase().split(/[^a-z0-9]+/)) {
    if (!w || ['dr', 'prof', 'mr', 'ms', 'mrs'].includes(w)) continue;
    for (let i = 1; i <= Math.min(w.length, 12); i++) out.add(w.slice(0, i));
  }
  return out;
}

/** professor.dart likelySame: same surname (last word) and a compatible first initial. */
export function likelySame(a, b) {
  const words = (s) => s.toLowerCase().split(/[^a-z]+/).filter((w) => w && !['dr', 'prof', 'mr', 'ms', 'mrs'].includes(w));
  const x = words(a);
  const y = words(b);
  if (!x.length || !y.length || x.at(-1) !== y.at(-1)) return false;
  if (x.length === 1 || y.length === 1) return true;
  return x[0][0] === y[0][0];
}

const DEPTS = new Set(['BIO', 'BIOT', 'CE', 'CHE', 'CHEM', 'CS', 'ECON', 'ELEC', 'ENVS', 'MAC', 'MATH', 'ME', 'MF', 'PHA', 'PHY', 'SNS']);

/** roles.dart / firestore.rules deptOf: the department a course id belongs to, else GEN. */
export function deptOf(courseId) {
  const p = courseId.trim().split(' ')[0].toUpperCase();
  if (['EEE', 'ECE', 'INSTR', 'ECOM'].includes(p)) return 'ELEC';
  if (p === 'FIN') return 'ECON';
  return DEPTS.has(p) ? p : 'GEN';
}

/** "2026-1" -> "2026-27-1": the term id offerings use. */
export function termOf(sem) {
  const y = Number(sem.slice(0, 4));
  return `${y}-${String((y + 1) % 100).padStart(2, '0')}-${sem.slice(5)}`;
}

const SMALL = new Set(['and', 'of', 'for', 'in', 'the', 'to', 'on', 'a', 'an', 'with', 'at', 'by', 'or']);
const KEEP = new Set(['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X', 'VLSI', 'CAD', 'CAM', 'CMOS', 'IOT', 'AI', 'ML', 'DNA', 'RNA', 'MEMS', 'RF', 'DSP', 'FPGA', 'GIS', 'IT', 'CFD', 'FEM', 'PLC', 'SQL', 'HVAC', 'GPS', 'MBA', 'PHD', 'BITS']);

/** ALL-CAPS PDF text in the catalogue's style; text that already has lower case is left alone. */
export function titleCase(s) {
  if (/[a-z]/.test(s)) return s;
  return s.split(' ').map((w, i) => {
    if (KEEP.has(w) || /[\d&/]/.test(w)) return w;
    const lw = w.toLowerCase();
    return i > 0 && SMALL.has(lw) ? lw : lw.replace(/(^|[-(])([a-z])/g, (_, p, c) => p + c.toUpperCase());
  }).join(' ');
}

/** Stable JSON: keys sorted, so two maps with the same content compare equal. */
export const canon = (v) => JSON.stringify(v, (k, x) => (x && typeof x === 'object' && !Array.isArray(x)
  ? Object.fromEntries(Object.entries(x).sort(([a], [b]) => (a < b ? -1 : 1))) : x));

/** An audit entry in the shape the app and seed script write (actor, action, before, after, at). */
export const auditOp = (id, summary, path, campus, after) => ({
  coll: 'audit', path: `audit/${id}`, action: 'create', id, forPath: path,
  set: { actor: { ...ACTOR, role: 'owner' }, action: summary, summary, path, campus, before: null, after: after ?? null, at: { $ts: 1 } },
});

// ---- professors --------------------------------------------------------------

/**
 * Who each instructor in the PDF is. Per campus:
 *  - exact match on name or alias (case, titles, dots, word order ignored) -> linked;
 *  - an answer in `answers` ({"PDF name": "<profId>" | "new"}) -> alias of that professor, or new;
 *  - a close match (likelySame) with no answer -> unsure: not linked, not created, listed;
 *  - nothing close -> new professor (dept from the first course they teach).
 *  Instructors-in-charge only: assistants are never professors.
 * Sets `prof` on every instructor it settles. Returns {entries, newProfs, aliasOps, warnings}.
 */
export function resolveProfessors(courses, profs, answers, newId) {
  const live = profs.filter((p) => !p.mergedInto);
  const byId = new Map(profs.map((p) => [p.id, p]));
  const idx = new Map();
  for (const p of live) for (const n of [p.name, ...(p.aliases ?? [])]) if (!idx.has(normName(n))) idx.set(normName(n), p.id);
  const ans = new Map(Object.entries(answers ?? {}).map(([k, v]) => [normName(k), v]));

  const ent = new Map();
  for (const [cid, c] of Object.entries(courses)) {
    for (const s of c.sections) {
      if (!'LTP'.includes(s.type)) continue;
      for (const i of s.instructors) {
        // Only the instructor-in-charge becomes a professor (owner, 2026-10-04);
        // assistants stay on the timetable's sections only.
        if (!i.ic) continue;
        if (/^(tba|tbd|to be announced|-)$/i.test(i.name)) continue;
        const k = normName(i.name);
        const e = ent.get(k) ?? { norm: k, names: new Set(), courses: [], dept: deptOf(cid) };
        e.names.add(i.name);
        if (!e.courses.includes(cid)) e.courses.push(cid);
        ent.set(k, e);
      }
    }
  }

  const warnings = [];
  const entries = [];
  const newProfs = [];
  const aliasBy = new Map(); // profId -> names to add
  for (const e of ent.values()) {
    const names = [...e.names];
    e.name = names.find((n) => /[a-z]/.test(n)) ?? titleCase(names[0]);
    e.pdfNames = names;
    const a = ans.get(e.norm);
    let id = idx.get(e.norm);
    if (id) {
      e.status = byId.get(id).removed ? 'removed' : 'linked';
    } else if (a === 'new') {
      e.status = 'new';
    } else if (a && byId.get(a) && !byId.get(a).mergedInto) {
      id = a;
      e.status = 'alias';
      (aliasBy.get(a) ?? aliasBy.set(a, []).get(a)).push(e.name);
    } else {
      if (a) warnings.push(`answer for "${e.name}" names ${a}, which is not a live professor on this campus: asked again`);
      const near = live.filter((p) => !p.removed && [p.name, ...(p.aliases ?? [])].some((n) => likelySame(e.name, n)));
      if (near.length) {
        e.status = 'unsure';
        e.candidates = near.map((p) => ({ id: p.id, name: p.name, dept: p.department }));
      } else {
        e.status = 'new';
      }
    }
    if (e.status === 'new') {
      id = newId('professor');
      newProfs.push({ id, name: e.name, dept: e.dept, courses: e.courses });
    }
    e.id = id;
    entries.push(e);
  }

  // The settled ones go onto the instructors (unsure and removed stay unlinked).
  const settled = new Map(entries.filter((e) => ['linked', 'alias', 'new'].includes(e.status)).map((e) => [e.norm, e.id]));
  for (const c of Object.values(courses)) {
    for (const s of c.sections) {
      for (const i of s.instructors) {
        const id = settled.get(normName(i.name));
        if (id) i.prof = id;
        else delete i.prof;
      }
    }
  }

  const aliasOps = [];
  for (const [id, add] of aliasBy) {
    const p = byId.get(id);
    const aliases = [...new Set([...(p.aliases ?? []), ...add])];
    if (aliases.length > 20) {
      warnings.push(`${p.name} would have ${aliases.length} aliases (limit 20): not added`);
      continue;
    }
    aliasOps.push({ prof: p, add, aliases, tokens: [...new Set([...(p.nameTokens ?? []), ...add.flatMap((n) => [...nameTokens(n)])])] });
  }
  return { entries, newProfs, aliasOps, warnings };
}

// ---- catalogue ---------------------------------------------------------------

/** The catalogue plus the courses the PDF has that it lacks (master rows [id, title, credits, 'timetable']). */
export function planCatalog(courses, catalog, markerVersion) {
  const known = new Set([...catalog.master, ...catalog.chartOld, ...catalog.chartNew].map((r) => r[0]));
  const adds = Object.entries(courses).filter(([id]) => !known.has(id)).map(([id, c]) => ({
    id, title: titleCase(c.title), credits: c.credits ?? 0, creditsKnown: c.credits != null,
  }));
  if (!adds.length) return { adds, next: null };
  const version = Math.max(markerVersion ?? 0, catalog.version) + 1;
  return { adds, next: { ...catalog, version, master: [...catalog.master, ...adds.map((a) => [a.id, a.title, a.credits, 'timetable'])] } };
}

// ---- offerings ---------------------------------------------------------------

/**
 * `professors` for each course's offering this term, filled only when the field is missing or
 * empty. `existing` is Map(courseId -> offering doc data | null). A course with an instructor
 * still unsure waits until every instructor is settled.
 */
export function planOfferings(courses, existing, profById, term, campus, newId) {
  const ops = [];
  const kept = [];
  const deferred = [];
  for (const [cid, c] of Object.entries(courses)) {
    const ids = [];
    let waiting = false;
    for (const s of c.sections) {
      if (!'LTP'.includes(s.type)) continue;
      for (const i of s.instructors) {
        if (!i.ic) continue; // see resolveProfessors
        if (i.prof) { if (!ids.includes(i.prof) && !profById.get(i.prof)?.removed) ids.push(i.prof); } else if (!/^(tba|tbd|to be announced|-)$/i.test(i.name)) waiting = true;
      }
    }
    if (waiting) { deferred.push(cid); continue; }
    if (!ids.length) continue;
    const have = existing.get(cid);
    const path = `courses/${cid}/offerings/${campus}_${term}`;
    if (have && (have.professors ?? []).length) {
      const same = canon([...have.professors].sort()) === canon([...ids].sort());
      if (!same) kept.push({ courseId: cid, existing: have.professors, ours: ids });
      ops.push({ coll: 'offerings', path, action: 'unchanged', before: { professors: have.professors }, note: same ? 'already filled' : 'staff already set professors' });
      continue;
    }
    const auditId = newId('audit');
    if (have) {
      ops.push({ coll: 'offerings', path, action: 'update', merge: { professors: ids, src: 'timetable', auditId }, before: { professors: have.professors ?? [] }, auditId, courseId: cid });
    } else {
      ops.push({
        coll: 'offerings', path, action: 'create', auditId, courseId: cid,
        set: {
          courseId: cid, campus, term, weighted: true, totalMarks: 100, components: [], professors: ids,
          updatedAt: { $ts: 1 }, updatedBy: ACTOR, auditId, src: 'timetable',
        },
      });
    }
  }
  return { ops, kept, deferred };
}

// ---- timetable ---------------------------------------------------------------

/** Meta, chunks and pointer docs compared with what is live; nothing changes if the content is the same. */
export function planTimetable(doc, chunks, live, headTimetable, newId) {
  const base = `${doc.campus}|${doc.sem}`;
  const metaNew = { v: 1, sem: doc.sem, campus: doc.campus, hours: doc.hours, examSlots: doc.examSlots, events: doc.events, chunks: chunks.length };
  const same = (a, b) => canon(a) === canon(b);
  const oldMeta = live?.meta ?? null;
  const metaSame = oldMeta && same({ v: oldMeta.v, sem: oldMeta.sem, campus: oldMeta.campus, hours: oldMeta.hours, examSlots: oldMeta.examSlots, events: oldMeta.events, chunks: oldMeta.chunks }, metaNew);
  const ops = [];
  let changed = !metaSame;
  const chunkOps = chunks.map((courses, n) => {
    const old = live?.chunks?.get(n);
    const eq = old && same(old.courses, courses);
    if (!eq) changed = true;
    return { coll: 'timetable', path: `timetable/${base}|${n}`, action: eq ? 'unchanged' : old ? 'update' : 'create', set: { n, courses }, before: old ? { n: old.n, courses: old.courses } : null };
  });
  const stale = [...(live?.chunks?.keys() ?? [])].filter((n) => n >= chunks.length);
  if (stale.length) changed = true;
  if (!changed) {
    return { changed, ops: [{ coll: 'timetable', path: `timetable/${base}`, action: 'unchanged', before: oldMeta }, ...chunkOps] };
  }
  const marker = headTimetable + 1;
  const auditId = newId('audit');
  const nSections = Object.values(doc.courses).reduce((n, c) => n + c.sec.length, 0);
  ops.push(...chunkOps);
  for (const n of stale) ops.push({ coll: 'timetable', path: `timetable/${base}|${n}`, action: 'delete', before: { n } });
  ops.push({
    coll: 'timetable', path: `timetable/${base}`, action: oldMeta ? 'update' : 'create', before: oldMeta,
    set: { ...metaNew, publishedAt: { $ts: 1 }, marker, auditId },
  });
  const cur = live?.current ?? null;
  ops.push({ coll: 'timetable', path: `timetable/${doc.campus}|current`, action: cur ? (cur.sem === doc.sem && cur.marker === marker ? 'unchanged' : 'update') : 'create', before: cur, set: { sem: doc.sem, marker } });
  ops.push(auditOp(auditId, 'publish timetable', `timetable/${base}`, doc.campus, { sem: doc.sem, courses: Object.keys(doc.courses).length, sections: nSections, chunks: chunks.length }));
  return { changed, marker, ops };
}

// ---- batches -----------------------------------------------------------------

/** Units (one department's professors) packed into batches of <= 4 marker keys and <= MAX_WRITES writes. */
function packUnits(units) {
  const batches = [];
  let cur = null;
  for (const u of units) {
    if (!cur || (!cur.keys.has(u.key) && cur.keys.size >= MAX_MARKER_KEYS) || cur.writes + u.ops.length > MAX_WRITES) {
      cur = { keys: new Set(), ops: [], writes: 0 };
      batches.push(cur);
    }
    cur.keys.add(u.key);
    cur.ops.push(...u.ops);
    cur.writes += u.ops.length;
  }
  return batches;
}

/** Everything to write, in the order it should land, each batch atomic: professors, offerings, catalogue, timetable. */
export function buildBatches({ campus, term, res, offerings, catalog, catalogAdds, timetable, newId, profById }) {
  const batches = [];

  // Professors: new docs and confirmed aliases, grouped by department.
  const byDept = new Map();
  const add = (dept, ops) => {
    const list = byDept.get(dept) ?? byDept.set(dept, []).get(dept);
    list.push(...ops);
  };
  for (const p of res.newProfs) {
    const auditId = newId('audit');
    add(p.dept, [
      {
        coll: 'professors', path: `professors/${p.id}`, action: 'create', id: p.id, auditId,
        set: {
          name: p.name, campus, department: p.dept, aliases: [], nameTokens: [...nameTokens(p.name)], mergedIds: [], active: true,
          src: 'timetable', updatedBy: ACTOR, updatedAt: { $ts: 1 }, auditId,
        },
        note: `teaches ${p.courses.slice(0, 4).join(', ')}${p.courses.length > 4 ? ` and ${p.courses.length - 4} more` : ''}`,
      },
      auditOp(auditId, `Added professor ${p.name} to ${p.dept}`, `professors/${p.id}`, campus, { name: p.name, department: p.dept, src: 'timetable' }),
    ]);
  }
  for (const a of res.aliasOps) {
    const auditId = newId('audit');
    const dept = a.prof.department;
    add(dept, [
      {
        coll: 'professors', path: `professors/${a.prof.id}`, action: 'update', id: a.prof.id, auditId,
        merge: { aliases: a.aliases, nameTokens: a.tokens, updatedBy: ACTOR, updatedAt: { $ts: 1 }, auditId },
        before: { name: a.prof.name, aliases: a.prof.aliases ?? [] }, dept,
      },
      auditOp(auditId, `Added alias ${a.add.join(', ')} to professor ${a.prof.name}`, `professors/${a.prof.id}`, campus, { aliases: a.aliases }),
    ]);
  }
  const units = [];
  for (const [dept, ops] of byDept) {
    // Keep a professor with its audit entry when a department is split across batches.
    for (let i = 0; i < ops.length; i += 160) units.push({ key: `professors/${dept}`, ops: ops.slice(i, i + 160) });
  }
  for (const b of packUnits(units)) {
    batches.push({ label: 'professors', ops: [...b.ops, { coll: 'heads', path: `heads/${campus}`, action: 'update', merge: { v: Object.fromEntries([...b.keys].map((k) => [k, { $inc: 1 }])) } }] });
  }

  // Offerings: five hundred writes would be a lot; a hundred courses a batch (offering + audit each).
  const fill = offerings.ops.filter((o) => o.action === 'create' || o.action === 'update');
  for (let i = 0; i < fill.length; i += OFFERING_CHUNK) {
    const part = fill.slice(i, i + OFFERING_CHUNK);
    batches.push({
      label: 'offerings',
      ops: [
        ...part,
        ...part.map((o) => auditOp(o.auditId, `Filled the professors of ${o.courseId} for ${term} from the timetable`, o.path, campus, { professors: (o.set ?? o.merge).professors })),
        { coll: 'heads', path: `heads/${campus}`, action: 'update', merge: { offerings: Object.fromEntries(part.map((o) => [`${o.courseId}|${term}`, { $inc: 1 }])) } },
      ],
    });
  }

  // Catalogue: v<n+1>, the marker, and every campus head, exactly as seedCatalog does.
  if (catalog.next) {
    const n = catalog.next;
    const auditId = newId('audit');
    batches.push({
      label: 'catalogue',
      ops: [
        { coll: 'catalog', path: `catalog/v${n.version}`, action: 'create', set: { version: n.version, schema: n.schema, json: JSON.stringify(n) }, added: catalogAdds },
        { coll: 'catalog', path: 'catalog/marker', action: catalog.hadMarker ? 'update' : 'create', before: catalog.marker ?? null, set: { version: n.version, schema: n.schema, auditId } },
        auditOp(auditId, 'publish catalogue', 'catalog/marker', 'all', { version: n.version, credits: [], retired: n.retired, added: catalogAdds.map((a) => a.id) }),
        ...CAMPUSES.map((c) => ({ coll: 'heads', path: `heads/${c}`, action: 'update', merge: { catalog: n.version, catalogSchema: n.schema } })),
      ],
    });
  }

  // Timetable last: it names the professors above by id.
  if (timetable.changed) {
    batches.push({
      label: 'timetable',
      ops: [...timetable.ops.filter((o) => o.action !== 'unchanged'), { coll: 'heads', path: `heads/${campus}`, action: 'update', merge: { v: { timetable: { $inc: 1 } } } }],
    });
  }
  return batches;
}
