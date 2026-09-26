/// What importing a performance sheet changes in the course box. Pure: the
/// Settings page shows the plan, then applies it.
library;

import 'package:cgpa_calculator/core/grading/cgpa.dart';
import 'package:cgpa_calculator/core/grading/grade_scale.dart';
import 'package:cgpa_calculator/core/grading/requirements.dart';
import 'package:cgpa_calculator/core/models/course_names.dart';
import 'package:cgpa_calculator/core/models/elective.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/import/performance_sheet.dart';
import 'package:cgpa_calculator/features/semester/add_course_controller.dart';
import 'package:cgpa_calculator/mastercourselist.dart';

class ImportPlan {
  const ImportPlan({
    required this.put,
    required this.add,
    required this.remove,
    required this.graded,
    required this.moved,
    required this.unchanged,
    required this.retakes,
    required this.renumbered,
    required this.unknownGrades,
    required this.dropped,
    required this.cleared,
    required this.running,
    required this.cgpaAfter,
  });

  /// Stored courses to overwrite, by their existing key.
  final Map<dynamic, Course> put;

  /// Courses the box does not have yet.
  final List<Course> add;

  /// Keys of earlier attempts that a retake replaces, and of chart courses
  /// the sheet has under a new code.
  final List<dynamic> remove;

  /// Courses whose Actual grade the import sets or changes.
  final int graded;

  /// Chart courses taken in a different semester than the chart puts them.
  final int moved;
  final int unchanged;
  final int retakes;

  /// Chart courses replaced by the code the sheet has for them.
  final int renumbered;

  /// "CS F211: I", for grades the app has no code for. Left ungraded.
  final List<String> unknownGrades;

  /// "ME F110 (1 - 1)": graded courses not on the sheet, removed from a
  /// semester it covers.
  final List<String> dropped;

  /// Courses in semesters still to come whose Actual grade is cleared.
  final List<String> cleared;

  /// Courses still running whose Actual grade is cleared until results.
  final List<String> running;

  /// Actual CGPA once applied, to hold against the sheet's own.
  final double? cgpaAfter;

  bool get isEmpty => put.isEmpty && add.isEmpty && remove.isEmpty;
}

/// "MECH OSCIL & WAVES" → "Mech Oscil & Waves", for a code the master list
/// does not know.
String _titleCase(String s) => s
    .toLowerCase()
    .split(' ')
    .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
    .join(' ');

/// A title reduced to letters and digits, for matching across spellings.
String _key(String title) =>
    title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// The category a sheet row goes under. A tagged elective is placed by
/// [electiveFor]; an untagged course is core, in the half whose department
/// offers it, or in neither.
String _category(String? tag, String id, String discipline) {
  final elective = switch (tag) {
    'HEL' => Elective.humanity,
    'EL' => Elective.open,
    'DEL' => Elective.del1,
    _ => null,
  };
  if (elective != null) return electiveFor(id, elective, discipline).tag;
  final dept = id.split(' ').first;
  if (departments[discipline.substring(2, 4)]?.contains(dept) ?? false) {
    return Elective.cdc2.tag;
  }
  if (departments[discipline.substring(0, 2)]?.contains(dept) ?? false) {
    return Elective.cdc1.tag;
  }
  return noCategory;
}

/// A core category: CDC of either half, or none.
bool _isCore(String tag) => switch (Elective.fromTag(tag)) {
  null || Elective.cdc1 || Elective.cdc2 => true,
  _ => false,
};

/// Sets Actual grades from [sheet] on [stored] (the course box as key →
/// course). A course already in the right semester is updated in place; an
/// ungraded chart course in another semester moves to where it was taken; a
/// retake replaces the earlier attempt; anything else is added.
ImportPlan planImport(
  PerformanceSheet sheet,
  Map<dynamic, Course> stored, {
  required String discipline,
}) {
  final claimed = <dynamic>{};
  final put = <dynamic, Course>{};
  final add = <Course>[];
  final remove = <dynamic>[];
  final unknown = <String>[];
  final dropped = <String>[], cleared = <String>[], running = <String>[];
  var graded = 0, moved = 0, unchanged = 0, retakes = 0, renumberedCount = 0;

  Iterable<MapEntry<dynamic, Course>> free(String id) => stored.entries.where(
    (e) => !claimed.contains(e.key) && sameCourseId(e.value.id, id),
  );

  for (final r in sheet.rows) {
    var grade = gradeValueOf(r.grade);
    if (grade == null) {
      unknown.add('${r.id}: ${r.grade}');
      grade = GradeCode.clr;
    }
    final category = _category(r.tag, r.id, discipline);

    final match =
        free(r.id).where((e) => e.value.sem == r.sem).firstOrNull ??
        free(r.id).where((e) => e.value.grade1 == GradeCode.clr).firstOrNull ??
        (r.retake ? free(r.id).firstOrNull : null);

    if (match == null) {
      final master =
          mcourselist.where((m) => sameCourseId(m.id, r.id)).firstOrNull;
      // A chart course renumbered since ("ME F110" taken as "ME F112"): same
      // semester, same title, never graded. The sheet's code replaces it.
      final names = {_key(r.title), if (master != null) _key(master.title)};
      final renumbered =
          stored.entries
              .where(
                (e) =>
                    !claimed.contains(e.key) &&
                    e.value.sem == r.sem &&
                    e.value.grade1 == GradeCode.clr &&
                    names.contains(_key(e.value.title)),
              )
              .firstOrNull;
      if (renumbered != null) {
        claimed.add(renumbered.key);
        remove.add(renumbered.key);
        renumberedCount++;
      }
      add.add(
        Course(
          title: master?.title ?? _titleCase(r.title),
          id: r.id,
          credits: r.units,
          sem: r.sem,
          elective: category,
          discipline:
              discipline.substring(0, 2) != '--'
                  ? discipline.substring(0, 2)
                  : discipline.substring(2, 4),
          grade1: grade,
          grade2: GradeCode.clr,
        ),
      );
      if (grade != GradeCode.clr) graded++;
      continue;
    }

    claimed.add(match.key);
    final c = match.value;
    if (r.retake) {
      retakes++;
      // Only the latest attempt stays.
      for (final e in free(r.id).toList()) {
        claimed.add(e.key);
        remove.add(e.key);
      }
    }
    if (c.sem != r.sem && !r.retake) moved++;
    // A core course keeps its own half; one charted as an elective is core
    // once the sheet lists it untagged.
    final next = c
        .copyWith(
          sem: r.sem,
          credits: r.units,
          elective: r.tag == null && _isCore(c.elective) ? null : category,
        )
        .withGrade(1, grade);
    final same =
        next.sem == c.sem &&
        next.credits == c.credits &&
        next.elective == c.elective &&
        next.grade1 == c.grade1;
    if (same) {
      unchanged++;
    } else {
      put[match.key] = next;
      if (next.grade1 != c.grade1) {
        next.grade1 == GradeCode.clr ? running.add(c.id) : graded++;
      }
    }
  }

  // The sheet is the whole record. A graded course it does not list is
  // removed from a semester the sheet covers, and loses its Actual grade in
  // one still to come, so the CGPA comes out as the sheet's.
  final covered = {for (final r in sheet.rows) r.sem};
  for (final e in stored.entries) {
    final c = e.value;
    if (claimed.contains(e.key) || c.grade1 == GradeCode.clr) continue;
    if (covered.contains(c.sem)) {
      remove.add(e.key);
      dropped.add('${c.id} (${c.sem})');
    } else {
      put[e.key] = c.withGrade(1, GradeCode.clr);
      cleared.add('${c.id} (${c.sem})');
    }
  }

  final after = {...stored, ...put}..removeWhere((k, _) => remove.contains(k));
  final tally = cumulativeTally(
    [...after.values, ...add],
    discipline: discipline,
    profile: Profile.actual,
  );
  return ImportPlan(
    put: put,
    add: add,
    remove: remove,
    graded: graded,
    moved: moved,
    unchanged: unchanged,
    retakes: retakes,
    renumbered: renumberedCount,
    unknownGrades: unknown,
    dropped: dropped,
    cleared: cleared,
    running: running,
    cgpaAfter: tally.gradedCredits == 0 ? null : tally.rounded,
  );
}
