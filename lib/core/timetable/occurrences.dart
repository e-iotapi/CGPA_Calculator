/// Pure expansion of the published timetable plus a student's overrides into
/// dated occurrences (B8b). No I/O, no clock: every date is an argument.
library;

import 'package:cgpa_calculator/core/timetable/calendar_store.dart';
import 'package:cgpa_calculator/core/timetable/timetable.dart';

/// [mark]: a dated part the student entered in Marks, given a time on the
/// calendar page.
enum OccKind { cls, midsem, compre, custom, event, mark }

class Occurrence {
  const Occurrence({
    required this.id,
    required this.courseId,
    required this.title,
    required this.kind,
    required this.date,
    required this.start,
    required this.end,
    this.room,
    this.sectionKey,
    this.prof = const [],
    this.edited = false,
    this.stale = false,
  });

  /// Unique and stable: `<slotId>|<date>` for a class (what `removed` stores).
  final String id, courseId, title, date;
  final OccKind kind;
  final int start, end;
  final String? room, sectionKey;
  final List<String> prof;

  /// The student moved it; [stale]: the published slot it was moved from is gone.
  final bool edited, stale;
}

/// [c]'s published [x] (its midsem or compre) as an occurrence.
Occurrence examOccurrence(TtCourse c, TtExam x, OccKind kind) {
  final tag = kind == OccKind.midsem ? 'mid' : 'comp';
  return Occurrence(
    id: '${c.id}|$tag|${x.d}',
    courseId: c.id,
    title: '${c.title} ${kind == OccKind.midsem ? 'Midsem' : 'Compre'}',
    kind: kind,
    date: x.d,
    start: x.s,
    end: x.e,
  );
}

/// Each date in [lo, hi] (inclusive) that falls on ISO weekday [d].
Iterable<String> _weekly(int d, String lo, String hi) sync* {
  var x = parseDate(lo);
  final end = parseDate(hi);
  x = x.add(Duration(days: (d - x.weekday) % 7));
  for (; !x.isAfter(end); x = x.add(const Duration(days: 7))) {
    yield fmtDate(x);
  }
}

String _max(String a, String b) => a.compareTo(b) >= 0 ? a : b;
String _min(String a, String b) => a.compareTo(b) <= 0 ? a : b;

bool _live(Timetable? t, CalendarState s) =>
    t != null && (s.sem.isEmpty || s.sem == t.sem);

/// Section keys the student picked that the published timetable no longer has.
List<String> staleSections(Timetable t, CalendarState s) {
  final out = <String>[];
  for (final e in s.picks.entries) {
    final have = {for (final x in t.courses[e.key]?.sections ?? const <TtSection>[]) x.key(e.key)};
    out.addAll(e.value.where((k) => !have.contains(k)));
  }
  return out;
}

/// Everything on the calendar from [from] to [to] (inclusive `YYYY-MM-DD`),
/// sorted by date, start, id. [t] null: only custom items.
List<Occurrence> expandOccurrences(
  Timetable? t,
  CalendarState s, {
  required String from,
  required String to,
}) {
  final out = <Occurrence>[];
  if (_live(t, s)) {
    final tt = t!;
    final lo = _max(from, tt.semStart());
    for (final pick in s.picks.entries) {
      final c = tt.courses[pick.key];
      if (c == null) continue;
      final hi = _min(to, s.repeatUntil[c.id] ?? tt.lastClassworkDay());
      for (final sec in c.sections) {
        final sk = sec.key(c.id);
        if (!pick.value.contains(sk)) continue;
        void emit(String slotId, int d, int st, int en, {required bool edited, required bool stale}) {
          for (final date in _weekly(d, lo, hi)) {
            final id = '$slotId|$date';
            if (s.removed.contains(id)) continue;
            out.add(Occurrence(
              id: id, courseId: c.id, title: c.title, kind: OccKind.cls,
              date: date, start: st, end: en, room: sec.room, sectionKey: sk,
              prof: sec.prof, edited: edited, stale: stale,
            ));
          }
        }

        final published = <String>{};
        for (final sl in sec.slots) {
          final slotId = '$sk|${sl.id}';
          published.add(slotId);
          final o = s.slotOverrides[slotId];
          emit(slotId, o?.d ?? sl.d, o?.s ?? sl.s, o?.e ?? sl.e, edited: o != null, stale: false);
        }
        // K23: a republish dropped the slot the student edited; keep their time.
        for (final e in s.slotOverrides.entries) {
          if (e.key.startsWith('$sk|') && !published.contains(e.key)) {
            emit(e.key, e.value.d, e.value.s, e.value.e, edited: true, stale: true);
          }
        }
      }
      if (s.examsOff.contains(c.id)) continue;
      for (final (x, kind) in [(c.mid, OccKind.midsem), (c.compre, OccKind.compre)]) {
        if (x == null || x.d.compareTo(from) < 0 || x.d.compareTo(to) > 0) continue;
        out.add(examOccurrence(c, x, kind));
      }
    }
    for (final ev in tt.events) {
      if (ev.kind == 'holiday') continue;
      final a = _max(ev.from, from), b = _min(ev.last, to);
      if (a.compareTo(b) > 0) continue;
      for (var x = parseDate(a); !x.isAfter(parseDate(b)); x = x.add(const Duration(days: 1))) {
        final date = fmtDate(x);
        out.add(Occurrence(
          id: 'event|${ev.from}|${ev.title}|$date', courseId: '', title: ev.title,
          kind: OccKind.event, date: date, start: 0, end: 1440,
        ));
      }
    }
  }
  for (final c in s.custom) {
    final dates = c.once
        ? [c.from]
        : _weekly(c.d, _max(c.from, from), _min(c.until ?? to, to)).toList();
    for (final date in dates) {
      if (date.compareTo(from) < 0 || date.compareTo(to) > 0) continue;
      out.add(Occurrence(
        id: 'custom|${c.id}|$date', courseId: c.course, title: c.title,
        kind: OccKind.custom, date: date, start: c.s, end: c.e, room: c.room,
      ));
    }
  }
  out.sort((a, b) {
    final r = a.date.compareTo(b.date);
    if (r != 0) return r;
    return a.start != b.start ? a.start.compareTo(b.start) : a.id.compareTo(b.id);
  });
  return out;
}

List<Occurrence> occurrencesOn(Timetable? t, CalendarState s, String date) =>
    expandOccurrences(t, s, from: date, to: date);

/// Academic events (holidays included) that cover [date].
List<AcademicEvent> eventsOn(Timetable? t, String date) => [
  for (final e in t?.events ?? const <AcademicEvent>[])
    if (e.from.compareTo(date) <= 0 && e.last.compareTo(date) >= 0) e,
];
