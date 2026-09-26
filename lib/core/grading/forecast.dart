import 'package:cgpa_calculator/core/grading/cgpa.dart';
import 'package:cgpa_calculator/core/grading/grade_scale.dart';
import 'package:cgpa_calculator/core/models/course_names.dart';
import 'package:cgpa_calculator/course.dart';

/// Forecasting on the Actual profile. Exact arithmetic on the same tally the
/// home screen uses (§2.1) — no fitted curves.

/// Courses still to earn: ungraded (CLR), plus any NC with no later passing
/// or pending attempt under the same code — an NC has to be repeated.
List<Course> outstandingCourses(Iterable<Course> all, String discipline) {
  final mine = all.where((c) => inDiscipline(c, discipline)).toList();
  final covered = {
    for (final c in mine)
      if (c.grade1 > 0 || c.grade1 == GradeCode.gd || c.grade1 == GradeCode.clr)
        normalizeCourseId(c.id),
  };
  return [
    for (final c in mine)
      if (c.grade1 == GradeCode.clr ||
          (c.grade1 == GradeCode.nc &&
              !covered.contains(normalizeCourseId(c.id))))
        c,
  ];
}

double remainingCredits(Iterable<Course> all, String discipline) =>
    outstandingCourses(all, discipline).fold(0.0, (s, c) => s + c.credits);

/// Semesters with ungraded courses, in [order], with their credits.
List<({String sem, double credits})> futureSemesters(
  Iterable<Course> all,
  String discipline,
  List<String> order,
) {
  final bySem = <String, double>{};
  for (final c in all) {
    if (c.grade1 == GradeCode.clr && inDiscipline(c, discipline)) {
      bySem[c.sem] = (bySem[c.sem] ?? 0) + c.credits;
    }
  }
  return [
    for (final s in order)
      if (bySem[s] != null) (sem: s, credits: bySem[s]!),
  ];
}

/// The average needed over [futureCredits] to finish at [target]:
/// (target × (done + future) − earned) / future. Null when nothing is left.
double? requiredAverage({
  required double target,
  required GpaTally done,
  required double futureCredits,
}) {
  if (futureCredits <= 0) return null;
  return (target * (done.gradedCredits + futureCredits) - done.points) /
      futureCredits;
}

/// [done] plus a planned SGPA over some credits.
GpaTally withPlanned(GpaTally done, double credits, double sgpa) => GpaTally(
  points: done.points + sgpa * credits,
  gradedCredits: done.gradedCredits + credits,
  shownCredits: done.shownCredits + credits,
);
