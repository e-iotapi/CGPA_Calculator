/// Which courses a student's calendar starts with for a published timetable:
/// the ones on their performance sheet for that term that have no grade yet
/// (taking now), else the core courses their discipline charts for it. The
/// first section of each type; a course the timetable lacks is skipped.
library;

import 'package:cgpa_calculator/core/grading/grade_scale.dart';
import 'package:cgpa_calculator/core/models/elective.dart';
import 'package:cgpa_calculator/core/models/offering.dart' show termOf;
import 'package:cgpa_calculator/core/timetable/timetable.dart';
import 'package:cgpa_calculator/course.dart';

/// Course id -> section keys, in id order. [batch] is the two-digit entry year.
Map<String, List<String>> autoPicks(
  Timetable t,
  Iterable<Course> mine,
  int batch,
) {
  final year = int.tryParse(t.sem.split('-').first);
  final k = t.sem.split('-').last;
  if (year == null) return const {};
  final term = '$year-${((year + 1) % 100).toString().padLeft(2, '0')}-$k';
  final here = [
    for (final c in mine)
      if (termOf(batch, c.sem) == term) c,
  ];
  var ids = {
    for (final c in here)
      if (c.grade1 == GradeCode.ongoing || c.grade1 == GradeCode.clr) c.id,
  };
  if (ids.isEmpty) {
    ids = {
      for (final c in here)
        if (c.elective == Elective.cdc1.tag || c.elective == Elective.cdc2.tag)
          c.id,
    };
  }
  final out = <String, List<String>>{};
  for (final id in ids.toList()..sort()) {
    final c = t.courses[id];
    if (c == null) continue;
    final keys = <String>[];
    final types = <String>{};
    for (final s in c.sections) {
      if (types.add(s.ty)) keys.add(s.key(id));
    }
    if (keys.isNotEmpty) out[id] = keys;
  }
  return out;
}
