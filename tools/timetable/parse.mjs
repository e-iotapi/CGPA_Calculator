// Pure parsing for the timetable PDF's `pdftotext -layout` text (B8a). No I/O.
// Everything here is exercised by parse.test.mjs on hand-written fixtures.

const COLS = ['COURSE NO', 'COURSE TITLE', 'LPU', 'CREDIT', 'STAT', 'SEC', 'INSTRUCTOR', 'SCHEDULE', 'ROOM', 'COMPRE', 'MIDSEM DATE', 'MIDSEM TIME'];
const ID_RE = /^([A-Z]{2,5} [A-Z]?\d{3}[A-Z]?)(?=\s)/; // 5 letters: INSTR
const DAY = '(?:TH|[MTWFS])';
const GROUP = `${DAY}(?:\\s*${DAY})*\\s*\\d+(?:\\s+\\d+)*`;
// "T TH 12 to 1.15 PM": an explicit clock range; the end time wraps to the next line.
const CLOCK = '\\d{1,2}[.:]\\d{2}\\s*[AP]M';
const TIMED = `${DAY}(?:\\s*${DAY})*\\s*\\d{1,2}\\s+to(?:\\s+${CLOCK})?`;
// A whole schedule at the end of a text run: TBA, or day groups each with hours.
const SCHED_TAIL = new RegExp(`(?:^|\\s)(TBA|${CLOCK}|${TIMED}|${GROUP}(?:\\s*${GROUP})*)\\s*$`);
// A room is letters then digits ("C404", "DLT5"), "CC 219" or "WS"; "T9" is a schedule.
const ROOM_TAIL = /(?:^|\s)((?:CC \d{2,3}|[A-Z]{1,3}\d{1,3}|WS|TBA))$/;
const PURE_SCHED = /^(?:TH|[MTWFS])+\d+$/;

export const DEFAULT_HOURS = {
  // Hour 1 = 08:00, one hour each; replaced by the PDF's own grid when it has one.
  periods: Object.fromEntries(Array.from({ length: 12 }, (_, i) => [i + 1, [hhmm(8 + i, 0), hhmm(9 + i, 0)]])),
  compre: { FN: ['10:00', '13:00'], AN: ['14:00', '17:00'] },
};

function hhmm(h, m) {
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
}

const to24 = (h, m, ap) => hhmm((Number(h) % 12) + (/pm/i.test(ap) ? 12 : 0), Number(m));

/** Times the PDF states itself: the period grid and the FN/AN notes. Anything missing keeps the default. */
export function parseHours(text) {
  const hours = structuredClone(DEFAULT_HOURS);
  const lines = text.split('\n');
  const gi = lines.findIndex((l) => /^Day\s+\d/.test(l));
  if (gi >= 0) {
    const spans = [...lines[gi].matchAll(/(\d{1,2})(?::(\d{2}))?\s*-\s*(\d{1,2})(?::(\d{2}))?/g)];
    const aps = (lines.slice(gi + 1, gi + 4).find((l) => /^\s*(?:[ap]m\s*)+$/i.test(l))?.match(/[ap]m/gi) ?? []);
    if (spans.length >= 8 && aps.length === spans.length) {
      spans.forEach((s, i) => {
        hours.periods[i + 1] = [to24(s[1], s[2] ?? 0, aps[i]), to24(s[3], s[4] ?? 0, aps[i])];
      });
    }
  }
  for (const k of ['FN', 'AN']) {
    const m = text.match(new RegExp(`${k}:\\s*(\\d{1,2})(?::(\\d{2}))?\\s*(AM|PM)\\s*to\\s*(\\d{1,2})(?::(\\d{2}))?\\s*(AM|PM)`, 'i'));
    if (m) hours.compre[k] = [to24(m[1], m[2] ?? 0, m[3]), to24(m[4], m[5] ?? 0, m[6])];
  }
  return hours;
}

/** "T TH 4 W 1", "MWF9", "M 4 5" -> [{day, start, end}] ([] for TBA); null when it is not a schedule. */
export function parseSchedule(text, hours = DEFAULT_HOURS) {
  const t = text.trim();
  if (t === 'TBA') return [];
  const tm = t.match(new RegExp(`^((?:${DAY}\\s*)+?)(\\d{1,2})\\s+to\\s+(\\d{1,2})[.:](\\d{2})\\s*([AP]M)$`, 'i'));
  if (tm) {
    // An explicit clock range ("12 to 1.15 PM"): the start is the hour that lands before the end.
    const end = (Number(tm[3]) % 12) + (/pm/i.test(tm[5]) ? 12 : 0);
    const h = Number(tm[2]) % 12;
    const start = /pm/i.test(tm[5]) && h + 12 <= end ? h + 12 : h;
    return tm[1].match(/TH|[MTWFS]/g).map((day) => ({ day, start: hhmm(start, 0), end: hhmm(end, Number(tm[4])) }));
  }
  if (!t || !new RegExp(`^${GROUP}(?:\\s*${GROUP})*$`).test(t)) return null;
  const slots = [];
  let days = [];
  let nums = [];
  const flush = () => {
    if (!days.length) return;
    const hs = [...new Set(nums)].sort((a, b) => a - b);
    for (const day of days) {
      let run = [];
      const emit = () => {
        if (run.length) {
          slots.push({ day, start: hours.periods[run[0]]?.[0], end: hours.periods[run.at(-1)]?.[1] });
        }
        run = [];
      };
      for (const h of hs) {
        if (run.length && h !== run.at(-1) + 1) emit();
        run.push(h);
      }
      emit();
    }
    days = [];
    nums = [];
  };
  for (const tok of t.match(/TH|[MTWFS]|\d+/g)) {
    if (/\d/.test(tok)) {
      // "89" is hours 8 and 9; "10".."12" are single hours.
      nums.push(...tok.match(/1[0-2]|[1-9]/g).map(Number));
    } else {
      if (nums.length) flush();
      days.push(tok);
    }
  }
  flush();
  return slots.some((s) => !s.start || !s.end) ? null : slots;
}

/** "14/12/26 (FN)" -> {date, session, start, end}; 'tba' for TBA/empty; null when unreadable. */
export function parseCompre(text, hours = DEFAULT_HOURS) {
  const t = text.trim();
  if (!t || /^TBA$/i.test(t)) return 'tba';
  const m = t.match(/^(\d{2})\/(\d{2})\/(\d{2})\s*\((FN|AN)\)$/);
  if (!m) return null;
  const [start, end] = hours.compre[m[4]];
  return { date: `20${m[3]}-${m[2]}-${m[1]}`, session: m[4], start, end };
}

/** "10/10/2026, 11:30 AM - 01:00 PM" (wrapped, with a weekday in between); 'tba' or null as above. */
export function parseMidsem(text) {
  const t = text.trim().replace(/\s+/g, ' ');
  if (!t || /^TBA$/i.test(t)) return 'tba';
  const d = t.match(/(\d{2})\/(\d{2})\/(\d{4})/);
  if (!d) return null;
  const out = { date: `${d[3]}-${d[2]}-${d[1]}` };
  const times = [...t.matchAll(/(\d{1,2}):(\d{2})\s*(AM|PM)/gi)];
  if (times.length >= 2) {
    out.start = to24(times[0][1], times[0][2], times[0][3]);
    out.end = to24(times[1][1], times[1][2], times[1][3]);
  } else {
    // "Forenoon" and the like: no clock times, keep the words.
    const note = t.replace(d[0], '').replace(/\b(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun)\b|[,-]/gi, ' ').replace(/\s+/g, ' ').trim();
    if (note) out.note = note;
  }
  return out;
}

const ROW_SKIP = /^(BIRLA INSTITUTE|TIMETABLE FIRST|\s*HOUR\s*$)/;

function offsets(header) {
  return COLS.map((c) => header.indexOf(c));
}

/**
 * Table rows from the full text (pages split on form feed). Returns
 * {rows, unparsed}: each row is {page, line, id, title, type, no, instructors[], schedule, room, compre, midsem};
 * `unparsed` lists {page, line, text, why} for rows that could not be read.
 */
export function parseTable(text, hours = DEFAULT_HOURS) {
  const rows = [];
  const unparsed = [];
  let cur = null;
  const finish = () => {
    if (!cur) return;
    const row = finishRow(cur, hours);
    if (row.why) unparsed.push({ page: cur.page, line: cur.line, text: cur.first, why: row.why });
    else rows.push(row);
    cur = null;
  };
  text.split('\f').forEach((page, pi) => {
    const lines = page.split('\n');
    const hi = lines.findIndex((l) => l.startsWith('COURSE NO'));
    if (hi < 0) return;
    const c = offsets(lines[hi]);
    for (let li = hi + 1; li < lines.length; li++) {
      const l = lines[li];
      if (!l.trim() || ROW_SKIP.test(l)) continue;
      if (l.startsWith('COURSE NO')) { finish(); continue; }
      const m = l.match(ID_RE);
      if (m) {
        finish();
        cur = { page: pi + 1, line: li + 1, id: m[1], first: l, parts: [] };
      }
      if (!cur) continue;
      cur.parts.push(splitLine(l, c, !!m));
    }
  });
  finish();
  return { rows, unparsed };
}

function splitLine(l, c, first) {
  const out = { title: l.slice(first ? c[1] : 0, c[2]).trim() };
  if (first) {
    // STAT then SEC. Either may be missing or odd ("P P"): the type defaults to L, the section to 1.
    const st = l.slice(c[4] - 1, c[6] - 1);
    out.type = (st.match(/[LTPIRltpir]/)?.[0] ?? 'L').toUpperCase();
    out.no = Number(st.match(/\d+/)?.[0] ?? 1);
  }
  // Instructor, schedule and room share one run: peel the room off the end (it
  // sits in the room column), then the schedule (it may start a few columns left
  // of its own, where a long name overflows).
  let reg = l.slice(c[6] - 1, c[9]).replace(/\s+$/, '');
  const rm = reg.match(ROOM_TAIL);
  if (rm && !PURE_SCHED.test(rm[1])) {
    out.room = rm[1];
    reg = reg.slice(0, reg.length - rm[1].length).replace(/\s+$/, '');
  }
  const sFrom = Math.max(c[7] - 14 - (c[6] - 1), 0);
  let s = sFrom;
  while (s < reg.length && s > 0 && reg[s - 1] !== ' ') s++;
  const sm = reg.slice(s).match(SCHED_TAIL);
  if (sm) {
    out.sched = sm[1];
    out.instr = (reg.slice(0, s) + reg.slice(s, s + sm.index)).trim();
  } else if (reg.slice(s).trim()) {
    // Nothing after the instructor column parses as a schedule: it is all names,
    // unless digits are in there (a schedule we could not read).
    out.instr = reg.trim();
    if (/\s(?:TH|[MTWFS])\s*\d/.test(` ${reg.slice(s)}`)) out.badSched = reg.slice(s).trim();
  } else {
    out.instr = reg.trim();
  }
  const tail = l.slice(c[9] - 1);
  out.compre = first ? l.slice(c[9], c[10] - 1) : '';
  out.midsem = first ? l.slice(c[10] - 1) : tail.slice(c[10] - c[9]);
  return out;
}

const join = (xs) => xs.filter(Boolean).join(' ').replace(/\s+/g, ' ').trim();

function finishRow(cur, hours) {
  const f = cur.parts[0];
  // pdftotext sometimes prints a title line twice; drop an exact repeat of the line above.
  const titles = [];
  for (const p of cur.parts) if (p.title && titles.at(-1) !== p.title) titles.push(p.title);
  if (cur.parts.some((p) => p.badSched)) return { why: `schedule not understood: ${cur.parts.find((p) => p.badSched).badSched}` };
  const schedText = join(cur.parts.map((p) => p.sched));
  const schedule = schedText ? parseSchedule(schedText, hours) : [];
  if (schedule == null) return { why: `schedule not understood: ${schedText}` };
  const compre = parseCompre(f.compre, hours);
  if (compre == null) return { why: `compre not understood: ${f.compre.trim()}` };
  const midsem = parseMidsem(join(cur.parts.map((p) => p.midsem)));
  if (midsem == null) return { why: `midsem not understood: ${join(cur.parts.map((p) => p.midsem))}` };
  const names = join(cur.parts.map((p) => p.instr)).split(/\s*[/,]\s*/).map((n) => n.trim()).filter(Boolean);
  return {
    id: cur.id,
    title: join(titles),
    type: f.type,
    no: f.no,
    instructors: names.map((name) => ({ name, ic: /[A-Z]/.test(name) && name === name.toUpperCase() })),
    slots: schedule,
    room: join(cur.parts.map((p) => p.room)) || undefined,
    compre: compre === 'tba' ? undefined : compre,
    midsem: midsem === 'tba' ? undefined : midsem,
    page: cur.page,
    line: cur.line,
  };
}

/** Rows -> {courses:{id:{title, sections[], compre?, midsem?}}, conflicts[]}. Courses keep PDF order. */
export function groupCourses(rows) {
  const courses = {};
  const conflicts = [];
  for (const r of rows) {
    const c = (courses[r.id] ??= { title: '', sections: [] });
    if (r.title.length > c.title.length) c.title = r.title;
    const room = r.room === 'TBA' ? undefined : r.room;
    // A second line for the same section (another day, maybe another room) joins it.
    const same = c.sections.find((x) => x.type === r.type && x.no === r.no);
    if (same) {
      for (const i of r.instructors) if (!same.instructors.some((x) => x.name === i.name)) same.instructors.push(i);
      same.slots.push(...r.slots.map((sl) => (room && room !== same.room ? { ...sl, room } : sl)));
      if (!same.room && room) same.room = room;
    } else {
      const sec = { type: r.type, no: r.no, instructors: r.instructors, slots: r.slots };
      if (room) sec.room = room;
      c.sections.push(sec);
    }
    for (const k of ['compre', 'midsem']) {
      if (!r[k]) continue;
      if (!c[k]) c[k] = r[k];
      // The first value wins; a disagreement is only counted, for the summary.
      else if (JSON.stringify(c[k]) !== JSON.stringify(r[k])) conflicts.push({ id: r.id, field: k, page: r.page, line: r.line });
    }
  }
  return { courses, conflicts };
}

// ---- academic calendar (two text columns on the first pages) -------------

const MON = 'Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|June?|July?|Aug(?:ust)?|Sep(?:t(?:ember)?)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?';
const MONTHS = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
const monthNo = (s) => MONTHS.indexOf(s.slice(0, 3).toLowerCase()) + 1;
const WD = '(?:\\([A-Za-z]{1,2}\\)\\*?)?';
const FIRST_DATE = new RegExp(`^(${MON})\\s*(\\d{1,2})\\s*${WD}\\s*(.*)$`, 'i');
const RANGE = new RegExp(`^(?:--|–|—|-)\\s*(?:(${MON})\\s*)?(\\d{1,2})?\\s*${WD}\\s*(.*)$`, 'i');
const CONT = new RegExp(`^(?:(${MON})\\s*)?(\\d{1,2})\\s*${WD}\\s*(.*)$`, 'i');

export function kindOf(title, holiday) {
  if (holiday) return 'holiday';
  if (/last date|registration|withdrawal|substitution|display|declaring|returning|grading/i.test(title)) return 'deadline';
  if (/exam|comprehensive|mid-?\s?sem/i.test(title)) return 'exam';
  return 'term';
}

/** Dates from the calendar block: {date, end?, title, kind, part}; `sem` is "2026-1" and sets the years. */
export function parseCalendar(text, sem) {
  const y = Number(sem.slice(0, 4));
  const lines = text.split('\f').slice(0, 3).join('\n').split('\n');
  const hi = lines.findIndex((l) => /First Semester/.test(l) && /Second Semester/.test(l));
  if (hi < 0) return [];
  const split = lines[hi].indexOf('Second Semester') - 1;
  let end = lines.findIndex((l, i) => i > hi && /LEGEND|Column No/.test(l));
  if (end < 0) end = lines.length;
  const body = lines.slice(hi + 1, end);
  const iso = (mo, d, right) => `${right || mo < 7 ? y + 1 : y}-${String(mo).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
  const events = [];
  for (const right of [false, true]) {
    let part = right ? 'sem2' : 'sem1';
    let pending = [];
    let last = null;
    let open = null;
    for (const raw of body) {
      const t = (right ? raw.slice(split) : raw.slice(0, split)).trim();
      if (!t) continue;
      if (/^(Summer Term|Second Semester|First Semester)/i.test(t)) {
        part = /^Summer/i.test(t) ? 'summer' : /^Second/i.test(t) ? 'sem2' : 'sem1';
        pending = []; last = null; open = null;
        continue;
      }
      if (open) {
        const cm = t.match(CONT);
        open.item.end = iso(cm?.[1] ? monthNo(cm[1]) : open.endMonth, cm?.[2] ?? open.endDay, right);
        if (cm) open.item.parts.push(cm[3]);
        open = null;
        continue;
      }
      const dm = t.match(FIRST_DATE);
      if (dm) {
        const mo = monthNo(dm[1]);
        const item = { date: iso(mo, dm[2], right), part, parts: [], own: '' };
        let rest = dm[3];
        const rm = rest.match(RANGE);
        if (rm) {
          const em = rm[1] ? monthNo(rm[1]) : mo;
          if (rm[2]) item.end = iso(em, rm[2], right);
          else open = { item, endMonth: em, endDay: dm[2] };
          rest = rm[3];
        }
        item.own = rest.trim();
        item.parts = [...pending, item.own].filter(Boolean);
        pending = [];
        events.push(item);
        last = item;
        continue;
      }
      if (/^\([A-Za-z]{1,2}\)$/.test(t)) continue;
      if (last && !last.own) last.parts.push(t);
      else pending.push(t);
    }
  }
  return events.map(({ parts, own, ...e }) => {
    const raw = parts.join(' ').replace(/\s+/g, ' ');
    const holiday = /\(H\)/.test(raw);
    const title = raw.replace(/\s*\(H\)/g, '').replace(/\*/g, '').trim();
    return { ...e, title, kind: kindOf(title, holiday) };
  }).sort((a, b) => a.date.localeCompare(b.date));
}

/** Everything in one call: the text of the whole PDF -> {courses, events, hours, unparsed, conflicts}. */
export function parseTimetable(text, sem) {
  const hours = parseHours(text);
  const { rows, unparsed } = parseTable(text, hours);
  const { courses, conflicts } = groupCourses(rows);
  return { courses, events: parseCalendar(text, sem), hours, unparsed, conflicts };
}
