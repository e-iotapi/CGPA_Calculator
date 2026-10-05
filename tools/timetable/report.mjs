// The dry-run report: exactly what a --commit would write, as Markdown. Pure: takes the plan
// extract.mjs built and returns text; nothing here touches Firestore.
import { canon } from './plan.mjs';

const COLLS = ['timetable', 'heads', 'catalog', 'professors', 'offerings', 'audit'];
const short = (v, n = 160) => {
  const t = typeof v === 'string' ? v : JSON.stringify(v);
  return t.length > n ? `${t.slice(0, n)}... (${t.length} chars)` : t;
};
const code = (v, n) => `\`${short(v, n).replace(/`/g, "'")}\``;
const cell = (v) => String(v).replace(/\|/g, '\\|').replace(/\n/g, ' ');
const kb = (o) => `${(Buffer.byteLength(JSON.stringify(o)) / 1024).toFixed(0)} KB`;

/** Plain value for a field written by the script: server time and counters read as words. */
const val = (v) => (v && v.$ts ? '(server time)' : v && v.$inc ? `+${v.$inc}` : v);

function counts(plan) {
  const c = Object.fromEntries(COLLS.map((k) => [k, { create: 0, update: 0, unchanged: 0 }]));
  const seen = new Set();
  for (const b of plan.batches) {
    for (const o of b.ops) {
      if (o.action === 'delete') { c[o.coll].update++; continue; }
      if (seen.has(o.path)) continue; // a head moves in several batches but is one doc
      seen.add(o.path);
      c[o.coll][o.action]++;
    }
  }
  const u = (coll, n) => { c[coll].unchanged += n; };
  u('professors', plan.res.entries.filter((e) => e.status === 'linked').length);
  u('offerings', plan.offerings.ops.filter((o) => o.action === 'unchanged').length);
  u('timetable', plan.timetable.ops.filter((o) => o.action === 'unchanged').length);
  if (!plan.catalog.next) u('catalog', 1);
  return c;
}

function timetableSection(plan, L) {
  const tt = plan.timetable;
  const doc = plan.doc;
  if (!tt.changed) {
    L.push('Nothing to write: the published timetable already matches this PDF.', '');
    return;
  }
  const meta = tt.ops.find((o) => o.path === `timetable/${doc.campus}|${doc.sem}`);
  L.push(`**${meta.path}** (${meta.action})`, '');
  const before = meta.before;
  for (const [k, v] of Object.entries(meta.set)) {
    const b = before?.[k];
    const same = before && canon(b) === canon(v);
    if (['hours', 'examSlots'].includes(k)) L.push(`- ${k}: ${same ? 'unchanged' : 'set'} ${code(val(v), 300)}`);
    else if (k === 'events') L.push(`- events: ${v.length} ${same ? '(unchanged)' : before ? `(was ${b?.length ?? 0})` : ''}`);
    else if (same) L.push(`- ${k}: ${code(val(v))} (unchanged)`);
    else L.push(`- ${k}: ${before && b !== undefined ? `${code(val(b))} → ` : ''}${code(val(v))}`);
  }
  L.push('');
  const cur = tt.ops.find((o) => o.path === `timetable/${doc.campus}|current`);
  L.push(`**${cur.path}** (${cur.action}): ${cur.before ? `${code(cur.before)} → ` : ''}${code(cur.set)}`, '');
  for (const o of tt.ops.filter((x) => /\|\d+$/.test(x.path))) {
    if (o.action === 'delete') { L.push(`- ${o.path}: delete (the new run needs fewer chunks)`); continue; }
    const ids = Object.keys(o.set.courses);
    let line = `- ${o.path} (${o.action}): ${ids.length} courses, ${kb(o.set)}`;
    if (o.action === 'update') {
      const was = o.before.courses;
      const add = ids.filter((i) => !(i in was));
      const gone = Object.keys(was).filter((i) => !(i in o.set.courses));
      const chg = ids.filter((i) => i in was && canon(was[i]) !== canon(o.set.courses[i]));
      line += `; added ${add.length}, removed ${gone.length}, changed ${chg.length}`;
      if (add.length + gone.length + chg.length <= 30) line += ` (${[...add.map((i) => `+${i}`), ...gone.map((i) => `-${i}`), ...chg.map((i) => `~${i}`)].join(', ')})`;
    } else if (o.action === 'unchanged') line = `- ${o.path}: unchanged`;
    L.push(line);
  }
  L.push('');
}

/** The report text for a plan (see makePlan in extract.mjs). */
export function renderReport(plan) {
  const { args, live, res } = plan;
  const L = [];
  const head = plan.liveHead;
  L.push(`# Timetable dry run: ${args.campus} ${args.sem}`, '');
  L.push(live
    ? `Compared against **live data** in project \`${args.project}\` (read only).`
    : '**No project given.** Compared against `assets/catalog.json` and an empty set of professors, offerings and timetable docs, so everything the PDF could add reads as new. Re-run with `--project <alias> --key <path>` for an exact diff.',
  `Nothing was written. Source: ${args.input}. Term for offerings: ${plan.term}.`, '');

  const c = counts(plan);
  L.push('## Summary', '', '| Collection | Create | Update | Unchanged |', '|---|---:|---:|---:|');
  for (const k of COLLS) L.push(`| ${k} | ${c[k].create} | ${c[k].update} | ${c[k].unchanged} |`);
  L.push('', `Writes go in ${plan.batches.length} batch${plan.batches.length === 1 ? '' : 'es'}, in this order: ${plan.batches.map((b) => b.label).join(', ') || 'none'}.`, '');
  const unsure = res.entries.filter((e) => e.status === 'unsure');
  L.push(`Headline: ${plan.catalog.adds.length} new courses, ${res.newProfs.length} new professors, ${unsure.length} unsure matches, ${plan.offerings.ops.filter((o) => o.action !== 'unchanged').length} offerings to fill.`, '');

  // 3: needs an answer comes first, it blocks a good commit.
  L.push('## Needs your answer', '');
  if (!unsure.length) L.push('No professor names to confirm.', '');
  else {
    L.push('Close to an existing professor but not the same spelling. Nothing is linked or created for these until you answer in a JSON file passed as `--answers <file>`: `{"PDF name": "<professor id>"}` to link (the PDF spelling is saved as an alias) or `{"PDF name": "new"}` to add a new professor.', '',
      '| PDF name | Candidate (id, dept) | Appears in |', '|---|---|---|');
    for (const e of unsure) {
      L.push(`| ${cell(e.pdfNames.join(' / '))} | ${cell(e.candidates.map((x) => `${x.name} (${x.id}, ${x.dept})`).join('; '))} | ${cell(e.courses.join(', '))} |`);
    }
    L.push('', 'Example answers file:', '```json', JSON.stringify(Object.fromEntries(unsure.map((e) => [e.pdfNames[0], e.candidates[0].id])), null, 2), '```', '');
  }

  const need = plan.catalog.needCredits ?? [];
  if (need.length) {
    L.push('### Credits', '', `${need.length} new courses whose credits the PDF does not state (a U course's number is its credit hours, which is its weight). They are not added until you give them in a JSON file passed as \`--credits <file>\`; the same file can correct any other course's credits.`, '',
      '| Course | Title |', '|---|---|');
    for (const a of need) L.push(`| ${a.id} | ${cell(a.title)} |`);
    L.push('', 'Credits file to fill in:', '```json', JSON.stringify(Object.fromEntries(need.map((a) => [a.id, 0])), null, 2), '```', '');
  }

  L.push('## Timetable', '');
  timetableSection(plan, L);

  L.push('## Heads (change markers)', '');
  const heads = new Map();
  for (const b of plan.batches) {
    for (const o of b.ops.filter((x) => x.coll === 'heads')) {
      const h = heads.get(o.path) ?? heads.set(o.path, []).get(o.path);
      for (const [k, v] of Object.entries(o.merge)) {
        if (k === 'v' || k === 'offerings') for (const key of Object.keys(v)) h.push({ map: k, key, inc: true });
        else h.push({ map: null, key: k, value: v });
      }
    }
  }
  if (!heads.size) L.push('None.', '');
  for (const [p, items] of heads) {
    const camp = p.split('/')[1];
    const old = camp === args.campus ? head : null;
    L.push(`**${p}** (update)`);
    const seen = new Set();
    const offs = items.filter((it) => it.map === 'offerings');
    if (offs.length) L.push(`- offerings: ${offs.length} course keys (\`<course>|${plan.term}\`) ${old ? 'bumped by 1 each' : '+1 each'}; the courses are listed under Offerings to fill`);
    for (const it of items.filter((x) => x.map !== 'offerings')) {
      const id = `${it.map}.${it.key}`;
      if (seen.has(id)) continue;
      seen.add(id);
      if (it.inc) {
        const was = old?.[it.map]?.[it.key] ?? 0;
        L.push(`- ${it.map}.${it.key}: ${old ? `${was} → ${Number(was) + 1}` : '+1'}`);
      } else L.push(`- ${it.key}: ${it.key === 'catalog' && live ? `${plan.catalog.marker?.version ?? '?'} → ` : ''}${code(it.value)}`);
    }
    L.push('');
  }

  L.push('## Catalogue', '');
  const cat = plan.catalog;
  if (!cat.next) L.push('Every course in the PDF is already in the catalogue: no new version.', '');
  else {
    L.push(`**catalog/v${cat.next.version}** (create): the current catalogue (v${cat.base}) plus ${cat.adds.length} course${cat.adds.length === 1 ? '' : 's'}, src \`timetable\`. Fields: version, schema ${cat.next.schema}, json (${kb(cat.next)}).`, '',
      '| Course | Title | Credits |', '|---|---|---:|');
    for (const a of cat.adds) L.push(`| ${a.id} | ${cell(a.title)} | ${a.credits} |`);
    L.push('', `**catalog/marker** (${cat.hadMarker ? 'update' : 'create'}): ${cat.marker ? `version ${cat.marker.version} → ${cat.next.version}` : `version ${cat.next.version}`}, schema ${cat.next.schema}, auditId (new).`, '',
      'Every campus head then gets `catalog` and `catalogSchema` set to the same version (see Heads).', '');
  }

  L.push('## Professors', '');
  if (!res.newProfs.length) L.push('No new professors.', '');
  else {
    L.push(`New (create), each with name, campus ${args.campus}, department, aliases [], nameTokens, mergedIds [], active true, src \`timetable\`:`, '', '| Name | Dept | Teaches |', '|---|---|---|');
    for (const p of res.newProfs) L.push(`| ${cell(p.name)} | ${p.dept} | ${cell(p.courses.slice(0, 5).join(', ') + (p.courses.length > 5 ? ` +${p.courses.length - 5}` : ''))} |`);
    L.push('');
  }
  if (res.aliasOps.length) {
    L.push('Aliases saved from your answers (update):', '');
    for (const a of res.aliasOps) L.push(`- professors/${a.prof.id} (${a.prof.name}): aliases ${code(a.prof.aliases ?? [])} → ${code(a.aliases)}`);
    L.push('');
  }
  L.push(`Exact matches, no write: ${res.entries.filter((e) => e.status === 'linked').length}.`, '');

  L.push('## Offerings to fill', '');
  const fill = plan.offerings.ops.filter((o) => o.action !== 'unchanged');
  if (!fill.length) L.push('None.', '');
  else {
    L.push('Only `professors` is written, and only because the field is missing or empty. A new offering doc also carries the empty defaults (weighted true, totalMarks 100, components []).', '', '| Doc | Action | Professors |', '|---|---|---|');
    for (const o of fill) {
      const ids = (o.set ?? o.merge).professors;
      L.push(`| ${o.path} | ${o.action} | ${cell(ids.map((i) => plan.nameOf(i)).join(', '))} |`);
    }
    L.push('');
  }

  L.push('## Audit entries', '');
  const audits = plan.batches.flatMap((b) => b.ops.filter((o) => o.coll === 'audit'));
  const bySummary = new Map();
  for (const a of audits) {
    const k = a.set.summary.replace(/ .*$/, '');
    bySummary.set(k, (bySummary.get(k) ?? 0) + 1);
  }
  L.push(audits.length ? `${audits.length} audit docs (create), one for each professor, alias, offering, catalogue and timetable write: ${[...bySummary].map(([k, n]) => `${k} x${n}`).join(', ')}.` : 'None.', '');
  for (const a of audits.slice(0, 12)) L.push(`- ${a.path}: ${a.set.summary}`);
  if (audits.length > 12) L.push(`- ... and ${audits.length - 12} more of the same kinds`);
  L.push('');

  L.push('## Skipped or kept', '');
  const kept = [];
  for (const k of plan.offerings.kept) kept.push(`Offering of ${k.courseId} left alone: staff already set ${k.existing.length} professor${k.existing.length === 1 ? '' : 's'} (${k.existing.map((i) => plan.nameOf(i)).join(', ')}); the PDF has ${k.ours.map((i) => plan.nameOf(i)).join(', ')}.`);
  if (plan.offerings.deferred.length) kept.push(`Offerings not filled yet because an instructor is still unsure: ${plan.offerings.deferred.join(', ')}.`);
  for (const x of plan.parsed.conflicts) kept.push(`Date conflict in ${x.id} (${x.field}, page ${x.page} line ${x.line}): the first value is kept.`);
  for (const u of plan.parsed.unparsed) kept.push(`Row not read (page ${u.page} line ${u.line}): ${u.why}.`);
  for (const e of res.entries.filter((x) => x.status === 'removed')) kept.push(`Instructor ${e.name} matches a removed professor: not linked, not recreated.`);
  for (const w of res.warnings) kept.push(w);
  if (!kept.length) L.push('Nothing.', '');
  else L.push(...kept.map((k) => `- ${k}`), '');
  L.push('Never changed by this run: any existing professor name, course title, credits, or staff-set offering.', '');
  return L.join('\n');
}
