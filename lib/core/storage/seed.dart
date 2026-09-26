/// What goes into the course box when a discipline is chosen or changed.
/// Pure: [initializeCourses] applies the plan.
library;

import 'package:cgpa_calculator/core/models/elective.dart';
import 'package:cgpa_calculator/course.dart';

/// The chart rows for a batch. The Goa and Hyderabad charts are one list;
/// 2025 onwards follow the current first-year scheme.
List<Course> chartRows(int batch) =>
    batch < 25 ? hydCourseList : hydCourseListNew;

/// Duals whose M.Sc. half already teaches these B.E. courses, so they are not
/// seeded a second time.
const _overlapDuals = {'B5AA', 'B5A3', 'B5A8', 'B2AA', 'B2A3', 'B2A8', 'B4AD'};
const _overlapTitles = {
  'Algebra I',
  'Discrete Mathematics',
  'Elementary Real Analysis',
  'Numerical Analysis',
  'Electromagnetic Theory',
};

/// [c] a year later: a dual takes its B.E. half's courses one year behind
/// the chart. Null for a row with no year to move ("PS 1").
Course? _yearLater(Course c) {
  final year = int.tryParse(c.sem.substring(0, 1));
  if (year == null) return null;
  return Course(
    title: c.title,
    sem: '${year + 1}${c.sem.substring(1)}',
    id: c.id,
    grade1: c.grade1,
    grade2: c.grade2,
    discipline: c.discipline,
    credits: c.credits,
    elective: c.elective,
  );
}

/// The B.E. half's core course [c], as a dual seeds it; null when the dual
/// does not take it. [taken] holds titles the M.Sc. half already has.
Course? _dualCourse(Course c, String discipline, Set<String> taken) {
  if (c.elective != Elective.cdc2.tag || taken.contains(c.title)) return null;
  if (_overlapDuals.contains(discipline) && _overlapTitles.contains(c.title)) {
    return null;
  }
  return _yearLater(c);
}

/// A fresh course list for [discipline] ("B3A7", "--A7", "B3--"): every row
/// of the first half as charted, then the second half's core a year later.
/// Written in order under each row's id, so a later row replaces an earlier
/// one with the same id.
List<Course> seedCourses(String discipline, List<Course> rows) {
  final first = discipline.substring(0, 2), second = discipline.substring(2);
  final primary = first != '--' ? first : second;
  final dual = first != '--' ? second : null;
  final taken = <String>{};
  final out = <Course>[];
  for (final c in rows) {
    if (c.discipline == primary) {
      out.add(c);
      taken.add(c.title);
    }
    if (c.discipline == dual) {
      final d = _dualCourse(c, discipline, taken);
      if (d != null) out.add(d);
    }
  }
  return out;
}

/// Changing only the B.E. half of a dual: which stored courses to drop
/// (the old half's core past the first year) and which to add (the new
/// half's core a year later, less what the M.Sc. half already has).
({List<dynamic> drop, List<Course> add}) reseedSecondHalf(
  String discipline,
  Map<dynamic, Course> stored,
  List<Course> rows,
) {
  final msc = {
    for (final c in stored.values)
      if (c.discipline.startsWith('B')) c.title,
  };
  final drop = [
    for (final e in stored.entries)
      if (e.value.discipline.startsWith('A') &&
          e.value.elective == Elective.cdc2.tag &&
          !e.value.sem.startsWith('1'))
        e.key,
  ];
  final second = discipline.substring(2);
  final add = [
    if (discipline.startsWith('B'))
      for (final c in rows)
        if (c.discipline == second)
          if (_dualCourse(c, discipline, msc) case final d?) d,
  ];
  return (drop: drop, add: add);
}

/// Whether the box holds nothing yet for [discipline], so a first run seeds.
bool needsSeed(String discipline, Iterable<Course> stored) {
  final b = discipline.startsWith('B');
  final halves = {
    b ? discipline.substring(0, 2) : discipline.substring(2),
    if (b) discipline.substring(2),
  };
  return !stored.any((c) => halves.contains(c.discipline));
}
