import 'package:cgpa_calculator/core/models/marks.dart';

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
