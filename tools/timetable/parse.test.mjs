// Hand-written synthetic fixtures only: nothing here is copied from the PDF.
import assert from 'node:assert/strict';
import { test } from 'node:test';

import { parseCalendar, parseCompre, parseHours, parseMidsem, parseSchedule, parseTable, parseTimetable } from './parse.mjs';

// A header and rows placed at fixed columns, like pdftotext -layout prints them.
const HEADER = 'COURSE NO   COURSE TITLE           LPU   CREDIT   STAT   SEC   INSTRUCTOR IN CHARGE/Instructor      SCHEDULE   ROOM   COMPRE SCHEDULE MIDSEM DATE   MIDSEM TIME';
const at = (pairs) => {
  let s = '';
  for (const [col, txt] of pairs) s = s.padEnd(col) + txt;
  return s;
};
const H = (name) => HEADER.indexOf(name);
const COL = { title: H('COURSE TITLE'), lpu: H('LPU'), stat: H('STAT') + 1, sec: H('SEC') + 1, instr: H('INSTRUCTOR'), sched: H('SCHEDULE'), room: H('ROOM') + 1, compre: H('COMPRE'), mid: H('MIDSEM DATE'), midt: H('MIDSEM TIME') };
const row = (id, o = {}) =>
  at([[0, id], [COL.title, o.title ?? ''], [COL.lpu, o.lpu ?? ''], [COL.stat, o.stat ?? ''], [COL.sec, String(o.sec ?? '')], [COL.instr, o.instr ?? ''], [COL.sched, o.sched ?? ''], [COL.room, o.room ?? ''], [COL.compre, o.compre ?? ''], [COL.mid, o.mid ?? ''], [COL.midt, o.midt ?? '']]);
const cont = (o) =>
  at([[COL.title, o.title ?? ''], [COL.instr, o.instr ?? ''], [COL.mid, o.mid ?? ''], [COL.midt, o.midt ?? '']]);
const page = (...lines) => ['     SOME TIMETABLE', HEADER, '', '', ...lines].join('\n');

test('schedule codes: days, multi-hour blocks, merged hours, TBA', () => {
  const s = (t) => parseSchedule(t);
  assert.deepEqual(s('MWF9'), ['M', 'W', 'F'].map((day) => ({ day, start: '16:00', end: '17:00' })));
  assert.deepEqual(s('T TH 4 W 1'), [
    { day: 'T', start: '11:00', end: '12:00' }, { day: 'TH', start: '11:00', end: '12:00' }, { day: 'W', start: '08:00', end: '09:00' },
  ]);
  assert.deepEqual(s('F 4 5'), [{ day: 'F', start: '11:00', end: '13:00' }]);
  assert.deepEqual(s('TH 11 12'), [{ day: 'TH', start: '18:00', end: '20:00' }]);
  assert.deepEqual(s('T789'), [{ day: 'T', start: '14:00', end: '17:00' }]);
  assert.deepEqual(s('M 7 T TH 10'), [
    { day: 'M', start: '14:00', end: '15:00' }, { day: 'T', start: '17:00', end: '18:00' }, { day: 'TH', start: '17:00', end: '18:00' },
  ]);
  assert.deepEqual(s('W 9 10'), [{ day: 'W', start: '16:00', end: '18:00' }]);
  assert.deepEqual(s('MW89'), [{ day: 'M', start: '15:00', end: '17:00' }, { day: 'W', start: '15:00', end: '17:00' }]);
  assert.deepEqual(s('F 1 3'), [{ day: 'F', start: '08:00', end: '09:00' }, { day: 'F', start: '10:00', end: '11:00' }]);
  assert.deepEqual(s('TBA'), []);
  assert.deepEqual(s('M1W7'), [{ day: 'M', start: '08:00', end: '09:00' }, { day: 'W', start: '14:00', end: '15:00' }]);
  assert.deepEqual(s('T TH 12 to 1.15 PM'), ['T', 'TH'].map((day) => ({ day, start: '12:00', end: '13:15' })));
  assert.deepEqual(s('F 5 to 6.15 PM'), [{ day: 'F', start: '17:00', end: '18:15' }]);
  assert.equal(s('banana 4'), null);
  assert.equal(s('T'), null);
});

test('compre: FN/AN with the notes times, TBA, junk', () => {
  assert.deepEqual(parseCompre('14/12/26 (FN)'), { date: '2026-12-14', session: 'FN', start: '10:00', end: '13:00' });
  assert.deepEqual(parseCompre('05/12/26 (AN)'), { date: '2026-12-05', session: 'AN', start: '14:00', end: '17:00' });
  assert.equal(parseCompre('TBA'), 'tba');
  assert.equal(parseCompre('   '), 'tba');
  assert.equal(parseCompre('sometime'), null);
});

test('midsem: wrapped across lines, weekday between, BETWEEN, TBA', () => {
  assert.deepEqual(parseMidsem('10/10/2026, 11:30 AM - Sat 01:00 PM'), { date: '2026-10-10', start: '11:30', end: '13:00' });
  assert.deepEqual(parseMidsem('03/10/2026, BETWEEN Sat 04:00 PM - 07:00 PM'), { date: '2026-10-03', start: '16:00', end: '19:00' });
  assert.deepEqual(parseMidsem('07/10/2026'), { date: '2026-10-07' });
  assert.deepEqual(parseMidsem('03/10/2026, Forenoon Sat'), { date: '2026-10-03', note: 'Forenoon' });
  assert.equal(parseMidsem('TBA'), 'tba');
  assert.equal(parseMidsem('whenever'), null);
});

test('hours: defaults, then the PDF grid and FN/AN notes win', () => {
  assert.equal(parseHours('nothing here').periods[1][0], '08:00');
  const notes = [
    'Hr   1        2         3        4        5        6        7        8',
    'Day  8 - 8:50  9 - 9:50  10 - 10:50  11 - 11:50  12 - 12:50  1-2  2 - 2:50  3 - 3:50',
    '       am       am     am       am       pm      pm     pm      pm',
    'FN: 9:30 AM to 12:30 PM',
    'AN: 2 PM to 5 PM',
  ].join('\n');
  const h = parseHours(notes);
  assert.deepEqual(h.periods[1], ['08:00', '08:50']);
  assert.deepEqual(h.periods[5], ['12:00', '12:50']);
  assert.deepEqual(h.periods[6], ['13:00', '14:00']);
  assert.deepEqual(h.compre, { FN: ['09:30', '12:30'], AN: ['14:00', '17:00'] });
  assert.deepEqual(parseSchedule('M 5 6', h), [{ day: 'M', start: '12:00', end: '14:00' }]);
});

test('table: wrapped instructors and titles, midsem wrap, instructor overflowing into schedule', () => {
  const text = page(
    row('ZZZ F101', { title: 'ALPHA STUDIES', lpu: '303', stat: 'L', sec: 1, instr: 'ALDER QUILL/ Birch Moss', sched: 'T TH 5 M 10', room: 'C404', compre: '14/12/26 (FN)', mid: '10/10/2026,', midt: '11:30 AM -' }),
    cont({ mid: 'Sat', midt: '01:00 PM' }),
    row('ZZZ F101', { stat: 'P', sec: 2, instr: 'Alder Quill, Birch Moss, Cedar Vale,', sched: 'T789' }),
    cont({ instr: 'Dune Ash, Elm Ford' }),
    row('ZZZ F102', { title: 'BETA STUDIES AND', lpu: '3', stat: 'L', sec: 1, instr: 'FERN GLEN/ Hazel Ivy/', sched: 'M W F 4', room: 'LT4', compre: '05/12/26 (AN)', mid: '07/10/2026,', midt: '04:00 PM -' }),
    cont({ title: 'MORE WORDS', instr: 'Juniper Kay', mid: 'Wed', midt: '05:30 PM' }),
    row('ZZZ F103', { title: 'GAMMA', stat: 'L', sec: 1, instr: 'Lark Moor Reed, Nettle Pip Owl M W F 4', room: 'CC 219', compre: 'TBA', mid: 'TBA' }),
  );
  const { rows, unparsed } = parseTable(text);
  assert.deepEqual(unparsed, []);
  assert.equal(rows.length, 4);
  const [a, b, c, d] = rows;
  assert.deepEqual([a.id, a.type, a.no, a.room], ['ZZZ F101', 'L', 1, 'C404']);
  assert.deepEqual(a.instructors, [{ name: 'ALDER QUILL', ic: true }, { name: 'Birch Moss', ic: false }]);
  assert.equal(a.slots.length, 3);
  assert.deepEqual(a.midsem, { date: '2026-10-10', start: '11:30', end: '13:00' });
  assert.deepEqual(a.compre.session, 'FN');
  assert.equal(b.type, 'P');
  assert.deepEqual(b.instructors.map((i) => i.name), ['Alder Quill', 'Birch Moss', 'Cedar Vale', 'Dune Ash', 'Elm Ford']);
  assert.deepEqual(b.slots, [{ day: 'T', start: '14:00', end: '17:00' }]);
  assert.equal(b.room, undefined);
  assert.equal(c.title, 'BETA STUDIES AND MORE WORDS');
  assert.deepEqual(c.instructors.map((i) => i.name), ['FERN GLEN', 'Hazel Ivy', 'Juniper Kay']);
  assert.deepEqual(c.midsem, { date: '2026-10-07', start: '16:00', end: '17:30' });
  assert.deepEqual(d.instructors.map((i) => i.name), ['Lark Moor Reed', 'Nettle Pip Owl']);
  assert.equal(d.slots.length, 3);
  assert.equal(d.room, 'CC 219');
  assert.equal(d.compre, undefined);
  assert.equal(d.midsem, undefined);
});

test('table: R and I rows, TBA schedule, wrapped title repeat, row split by a page break', () => {
  const p1 = page(
    row('YYY C790T', { title: 'RESEARCH WORK', lpu: '2', stat: 'R', sec: 1, instr: 'OAK PINE' }),
    row('YYY G520', { title: 'WORDS ON LINE ONE', lpu: '325', stat: 'I', sec: 1, instr: 'Quince Rowan' }),
    cont({ title: 'WORDS ON LINE ONE' }),
    cont({ title: 'AND TWO' }),
    row('YYY F200', { title: 'DELTA', lpu: '3', stat: 'L', sec: 1, instr: 'SAGE TEAL/ Umber Vine,', sched: 'TBA', compre: '30/11/26 (AN)', mid: 'TBA' }),
  );
  const p2 = page(cont({ instr: 'Willow Xylem' }), row('YYY F201', { title: 'EPSILON', lpu: '3', stat: 'T', sec: 3, instr: 'Yarrow Zinnia', sched: 'F7', room: 'A505' }));
  const { rows, unparsed } = parseTable(`${p1}\f${p2}`);
  assert.deepEqual(unparsed, []);
  assert.deepEqual(rows.map((r) => [r.id, r.type]), [['YYY C790T', 'R'], ['YYY G520', 'I'], ['YYY F200', 'L'], ['YYY F201', 'T']]);
  assert.deepEqual(rows[0].slots, []);
  assert.equal(rows[1].title, 'WORDS ON LINE ONE AND TWO');
  assert.deepEqual(rows[2].slots, []);
  assert.deepEqual(rows[2].instructors.map((i) => i.name), ['SAGE TEAL', 'Umber Vine', 'Willow Xylem']);
  assert.equal(rows[3].page, 2);
});

test('table: unreadable rows are reported with page and line, the rest still parse', () => {
  const text = [
    page(
      row('XXX F100', { title: 'OK', stat: 'L', sec: 1, instr: 'Pine Ash', sched: 'M1', room: 'A101', compre: '14/12/26 (FN)' }),
      row('XXX F101', { title: 'BAD COMPRE', stat: 'L', sec: 1, instr: 'Pine Ash', sched: 'M1', compre: 'someday' }),
      row('XXX F102', { title: 'BAD SCHED', stat: 'L', sec: 1, instr: 'Pine Ash', sched: 'M 4 junk' }),
    ),
  ].join('\f');
  const { rows, unparsed } = parseTable(text);
  assert.deepEqual(rows.map((r) => r.id), ['XXX F100']);
  assert.deepEqual(unparsed.map((u) => [u.page, u.line]), [[1, 6], [1, 7]]);
  assert.match(unparsed[0].why, /compre/);
  assert.match(unparsed[1].why, /schedule/);
});

test('table: no STAT/SEC is section 1 (L); a type alone, or "P P", keeps the type', () => {
  const text = page(
    row('XXX F103', { title: 'NO STAT', instr: 'Pine Ash', sched: 'M1' }),
    row('XXX F103', { title: 'NO STAT', stat: 'P', sec: 'P', instr: 'Pine Ash' }),
    row('XXX F104', { title: 'TYPE ONLY', stat: 'T', instr: 'Pine Ash' }),
  );
  const { rows, unparsed } = parseTable(text);
  assert.deepEqual(unparsed, []);
  assert.deepEqual(rows.map((r) => [r.type, r.no]), [['L', 1], ['P', 1], ['T', 1]]);
});

test('table: credits come from LPU (the last of three digits, or the lone number), none when blank', () => {
  const { rows } = parseTable(page(
    row('XXX F201', { title: 'THREE DIGITS', lpu: '303', stat: 'L', sec: 1, instr: 'Pine Ash' }),
    row('XXX F202', { title: 'ONE NUMBER', lpu: '4', stat: 'L', sec: 1, instr: 'Pine Ash' }),
    row('XXX F203', { title: 'BLANK', stat: 'L', sec: 1, instr: 'Pine Ash' }),
  ));
  assert.deepEqual(rows.map((r) => [r.credits, r.lpu3]), [[3, true], [4, false], [undefined, false]]);
});

// Two columns split at "Second Semester"; invented dates and titles.
const CAL = [
  'First Semester 2026-2027'.padEnd(69) + 'Second Semester 2026-2027',
  'July 3 (F)'.padEnd(22) + 'Alpha day'.padEnd(47) + 'January 4 (M)'.padEnd(21) + 'Spring starts',
  'July 28 (T) - 30 (Th)'.padEnd(22) + 'Gather again'.padEnd(47) + 'January 14 (Th)'.padEnd(21) + 'Kite Day (H)',
  ' '.repeat(22) + 'Notice and welcome'.padEnd(47) + 'March 08 (M)-'.padEnd(21) + 'Mid-semester exams (classwork',
  'July 30 (Th)'.padEnd(69) + 'March 15 (M)'.padEnd(21) + 'suspended)',
  ' '.repeat(22) + 'with the team'.padEnd(47) + 'May 18 (T)-May'.padEnd(21) + 'Phd test for',
  'September 21 (M)'.padEnd(69) + '19 (W)'.padEnd(21) + 'admissions',
  ' '.repeat(22) + 'Last date for withdrawal'.padEnd(47),
  ' '.repeat(22) + '(tentative)'.padEnd(47) + ' '.repeat(21) + 'Summer Term 2026-27',
  'October 5 (M) -10 (S)'.padEnd(69) + 'May 24 (M)'.padEnd(21) + 'Summer term begins',
  'Dec 20 (Su) -- Jan 3'.padEnd(69),
  ' '.repeat(22) + 'Winter recess'.padEnd(47),
  '(Su)',
  'December 25 (F)'.padEnd(22) + 'Merry Day (H)',
  '',
  'LEGEND',
];
const CAL_TEXT = ['title page', 'x', 'y'].join('\n') + '\n' + CAL.join('\n');

test('calendar: two columns, ranges, wrapped titles above and below, holidays, years from the sem', () => {
  const ev = parseCalendar(CAL_TEXT, '2026-1');
  const find = (t) => ev.find((e) => e.title.includes(t));
  assert.deepEqual(find('Alpha day'), { date: '2026-07-03', title: 'Alpha day', kind: 'term', part: 'sem1' });
  assert.deepEqual(find('Gather again'), { date: '2026-07-28', end: '2026-07-30', title: 'Gather again', kind: 'term', part: 'sem1' });
  assert.deepEqual(find('Notice and welcome'), { date: '2026-07-30', title: 'Notice and welcome with the team', kind: 'term', part: 'sem1' });
  assert.deepEqual(find('withdrawal'), { date: '2026-09-21', title: 'Last date for withdrawal (tentative)', kind: 'deadline', part: 'sem1' });
  assert.deepEqual(find('Winter'), { date: '2026-12-20', end: '2027-01-03', title: 'Winter recess', kind: 'term', part: 'sem1' });
  assert.deepEqual(find('Merry'), { date: '2026-12-25', title: 'Merry Day', kind: 'holiday', part: 'sem1' });
  assert.deepEqual(find('Spring'), { date: '2027-01-04', title: 'Spring starts', kind: 'term', part: 'sem2' });
  assert.equal(find('Kite').kind, 'holiday');
  assert.deepEqual(find('Mid-semester'), { date: '2027-03-08', end: '2027-03-15', title: 'Mid-semester exams (classwork suspended)', kind: 'exam', part: 'sem2' });
  assert.deepEqual(find('Phd test'), { date: '2027-05-18', end: '2027-05-19', title: 'Phd test for admissions', kind: 'term', part: 'sem2' });
  assert.deepEqual(find('Summer term'), { date: '2027-05-24', title: 'Summer term begins', kind: 'term', part: 'summer' });
  assert.deepEqual(ev.map((e) => e.date), [...ev.map((e) => e.date)].sort());
});

test('parseTimetable: the whole text in one call', () => {
  const text = `${CAL_TEXT}\f${page(row('QQQ F100', { title: 'ONE', stat: 'L', sec: 1, instr: 'Pine Ash', sched: 'M1', room: 'A101' }))}`;
  const r = parseTimetable(text, '2026-1');
  assert.deepEqual(Object.keys(r.courses), ['QQQ F100']);
  assert.ok(r.events.length > 5);
  assert.deepEqual(r.unparsed, []);
});

test('table: timed schedule wrapped onto a second line, 5-letter prefix, lowercase stat, TBA room', () => {
  const text = page(
    row('ABCDE F300', { title: 'TIMED', stat: 'L', sec: 1, instr: 'ROWAN FIR', sched: 'T TH 12 to', room: 'C403', compre: 'TBA', mid: 'TBA' }),
    cont({ title: '', instr: '', sched: '' }).replace(/\s+$/, '') + ' '.repeat(COL.sched - 1) + '1.15 PM',
    row('ABCDE F301', { title: 'LOWER', stat: 'p', sec: 4, instr: 'Sorrel Tansy', sched: 'TBA', room: 'TBA' }),
  );
  const { rows, unparsed } = parseTable(text);
  assert.deepEqual(unparsed, []);
  assert.deepEqual(rows.map((r) => r.id), ['ABCDE F300', 'ABCDE F301']);
  assert.deepEqual(rows[0].slots, [{ day: 'T', start: '12:00', end: '13:15' }, { day: 'TH', start: '12:00', end: '13:15' }]);
  assert.equal(rows[1].type, 'P');
  assert.deepEqual(rows[1].instructors.map((i) => i.name), ['Sorrel Tansy']);
  assert.deepEqual(rows[1].slots, []);
});

test('courses: a second line for the same section joins it, with its own room', () => {
  const text = page(
    row('WWW U103', { title: 'DESIGN', stat: 'P', sec: 1, instr: 'Thyme Uva, Vetch Yew', sched: 'M23', room: 'CC 219', compre: '15/12/26 (AN)' }),
    row('WWW U103', { title: 'DESIGN', stat: 'P', sec: 1, sched: 'F23', room: 'WS' }),
    row('WWW U103', { title: 'DESIGN', stat: 'P', sec: 2, instr: 'Thyme Uva', sched: 'T23', room: 'CC 219', compre: '16/12/26 (AN)' }),
  );
  const { courses, conflicts } = parseTimetable(text, '2026-1');
  const secs = courses['WWW U103'].sections;
  assert.equal(secs.length, 2);
  assert.deepEqual(secs[0].slots, [{ day: 'M', start: '09:00', end: '11:00' }, { day: 'F', start: '09:00', end: '11:00', room: 'WS' }]);
  assert.equal(secs[0].room, 'CC 219');
  assert.deepEqual(conflicts.map((c) => c.field), ['compre']);
  assert.equal(courses['WWW U103'].compre.date, '2026-12-15'); // the first value stays
});
