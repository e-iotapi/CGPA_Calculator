import 'package:cgpa_calculator/core/models/marks.dart';
import 'package:cgpa_calculator/core/timetable/calendar_store.dart';
import 'package:cgpa_calculator/core/timetable/occurrences.dart';
import 'package:cgpa_calculator/core/timetable/timetable.dart';
import 'package:cgpa_calculator/features/calendar/calendar_time.dart';

/// One dated part, read straight from [EvalPart.date] — nothing is stored
/// twice.
class CalendarEntry {
  const CalendarEntry({
    required this.date,
    required this.label,
    required this.courseId,
    required this.weight,
    required this.graded,
  });

  final DateTime date;

  /// The part's name, or the evaluative's for a single-mark one.
  final String label;
  final String courseId;
  final double weight;
  final bool graded;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// One calendar entry per dated part of each of [evals].
List<CalendarEntry> calendarEntries(Iterable<Evaluative> evals) => [
  for (final e in evals)
    for (final p in e.parts)
      if (DateTime.tryParse(p.date ?? '') case final d?)
        CalendarEntry(
          date: _day(d),
          label: p.name.isEmpty || e.parts.length == 1 ? e.name : p.name,
          courseId: e.courseId,
          weight: e.weight,
          graded: p.marks != null,
        ),
]..sort((a, b) => a.date.compareTo(b.date));

/// Entries on or after [today], soonest first.
List<CalendarEntry> upcoming(List<CalendarEntry> all, DateTime today) =>
    all.where((e) => !e.date.isBefore(_day(today))).toList();

/// "TODAY", "TOMORROW", "IN 3 DAYS" within a week; null further out.
String? soonLabel(DateTime date, DateTime today) {
  final n = _day(date).difference(_day(today)).inDays;
  if (n < 0 || n > 7) return null;
  return switch (n) {
    0 => 'TODAY',
    1 => 'TOMORROW',
    _ => 'IN $n DAYS',
  };
}

bool _isExam(Occurrence o) => o.kind == OccKind.midsem || o.kind == OccKind.compre;

/// The dated parts of Marks that fall in [from]..[to] (`YYYY-MM-DD`), as the
/// Week shows them. [occs] are the timetable's own occurrences in that span.
///
/// - A course whose published midsem or compre falls on the part's date gets
///   that timed block (added here when the course is not in the student's
///   timetable, so it still shows); the part itself is not repeated all-day.
/// - A part the student gave a time on the calendar page is a timed
///   [OccKind.mark] block; the rest stay all-day.
({List<Occurrence> timed, List<CalendarEntry> allDay}) marksInSpan(
  Timetable? t,
  CalendarState s,
  List<CalendarEntry> entries,
  List<Occurrence> occs, {
  required String from,
  required String to,
}) {
  final timed = <Occurrence>[];
  final allDay = <CalendarEntry>[];
  final seen = {for (final o in occs) if (_isExam(o)) o.id};
  for (final e in entries) {
    final d = dayStr(e.date);
    if (d.compareTo(from) < 0 || d.compareTo(to) > 0) continue;
    if (occs.any((o) => _isExam(o) && o.courseId == e.courseId && o.date == d)) continue;
    final c = t?.courses[e.courseId];
    if (c != null && !s.examsOff.contains(c.id)) {
      final published = [
        if (c.mid != null && c.mid!.d == d) examOccurrence(c, c.mid!, OccKind.midsem),
        if (c.compre != null && c.compre!.d == d) examOccurrence(c, c.compre!, OccKind.compre),
      ];
      if (published.isNotEmpty) {
        timed.addAll(published.where((o) => seen.add(o.id)));
        continue;
      }
    }
    final own = s.markTimes[markKey(e.courseId, e.label, d)];
    if (own == null) {
      allDay.add(e);
    } else {
      timed.add(Occurrence(
        id: 'mark|${markKey(e.courseId, e.label, d)}',
        courseId: e.courseId,
        title: e.label,
        kind: OccKind.mark,
        date: d,
        start: own.s,
        end: own.e,
        edited: true,
      ));
    }
  }
  return (timed: timed, allDay: allDay);
}
