import 'package:cgpa_calculator/core/grading/grade_scale.dart';
import 'package:cgpa_calculator/course.dart';

/// The single implementation of SGPA and CGPA. Anything that shows a GPA or a
/// credit count calls this, or it will silently disagree with the home screen.
///
/// The rule, which is not the obvious sum/credits:
///  * points      = Σ grade × credits over courses with a letter grade (> 0)
///  * denominator = credits of letter-graded and GD courses, minus the GD
///    credits — i.e. GD passes but carries no weight
///  * shown       = every credit except those with a non-GD negative code
///                  (NC, CLR, RC, W…)
/// On a real transcript this is 1195 / 155 = 7.71 with 158 credits shown,
/// where 1195 / 158 would give 7.56.

/// Which grade column to read. The values match the `selectedprofile` global.
enum Profile {
  actual(1),
  expected(2);

  const Profile(this.id);
  final int id;

  static Profile? fromId(int id) =>
      Profile.values.where((p) => p.id == id).firstOrNull;
}

int gradeOf(Course c, Profile profile) =>
    profile == Profile.actual ? c.grade1 : c.grade2;

/// A discipline code is two two-letter halves ("B3A7"); a course counts when
/// it belongs to either.
bool inDiscipline(Course c, String discipline) =>
    c.discipline == discipline.substring(0, 2) ||
    c.discipline == discipline.substring(2, 4);

class GpaTally {
  const GpaTally({
    required this.points,
    required this.gradedCredits,
    required this.shownCredits,
  });

  static const empty = GpaTally(points: 0, gradedCredits: 0, shownCredits: 0);

  final double points;

  /// The denominator.
  final double gradedCredits;

  /// The credit count the UI displays beside the GPA.
  final double shownCredits;

  /// Unrounded. 0 when nothing is graded.
  double get gpa => gradedCredits != 0 ? points / gradedCredits : 0;

  /// Rounded to two places, as a double, the way the home screen stores it.
  double get rounded =>
      gradedCredits != 0 ? double.parse(gpa.toStringAsFixed(2)) : 0;

  /// Two places as text, "0" when nothing is graded.
  String get fixed => gradedCredits != 0 ? gpa.toStringAsFixed(2) : '0';

  GpaTally operator +(GpaTally o) => GpaTally(
    points: points + o.points,
    gradedCredits: gradedCredits + o.gradedCredits,
    shownCredits: shownCredits + o.shownCredits,
  );
}

GpaTally tally(Iterable<Course> courses, Profile profile) {
  double s1 = 0, dontCount = 0, points = 0, shown = 0;
  for (final c in courses) {
    final g = gradeOf(c, profile);
    // Kept in the original's shape — GD added then subtracted — so the
    // floating-point result is identical to what the app always showed.
    if (g > 0 || g == GradeCode.gd) s1 += c.credits;
    if (g == GradeCode.gd) dontCount += c.credits;
    if (g > 0) points += g * c.credits;
    if (!(g < 0 && g != GradeCode.gd)) shown += c.credits;
  }
  return GpaTally(
    points: points,
    gradedCredits: s1 - dontCount,
    shownCredits: shown,
  );
}

GpaTally semesterTally(
  Iterable<Course> courses, {
  required String sem,
  required String discipline,
  required Profile profile,
}) => tally(
  courses.where((c) => c.sem == sem && inDiscipline(c, discipline)),
  profile,
);

GpaTally cumulativeTally(
  Iterable<Course> courses, {
  required String discipline,
  required Profile profile,
}) => tally(courses.where((c) => inDiscipline(c, discipline)), profile);

/// CGPA as it stood after each semester in [semesters], which must be in
/// chronological order. Semesters with nothing graded are left out.
List<({String sem, GpaTally term, GpaTally running})> progression(
  Iterable<Course> courses, {
  required List<String> semesters,
  required String discipline,
  required Profile profile,
}) {
  final out = <({String sem, GpaTally term, GpaTally running})>[];
  var running = GpaTally.empty;
  for (final sem in semesters) {
    final term = semesterTally(
      courses,
      sem: sem,
      discipline: discipline,
      profile: profile,
    );
    if (term.gradedCredits == 0) continue;
    running += term;
    out.add((sem: sem, term: term, running: running));
  }
  return out;
}
