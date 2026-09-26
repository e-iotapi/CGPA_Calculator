import 'package:cgpa_calculator/core/grading/cgpa.dart';
import 'package:cgpa_calculator/core/grading/grade_scale.dart';
import 'package:cgpa_calculator/core/models/course_names.dart';
import 'package:cgpa_calculator/core/models/elective.dart';
import 'package:cgpa_calculator/course.dart';

/// Credits a degree needs in total.
const degreeTotalCredits = 144;

/// CDC and disciplinary-elective requirements for one discipline half.
class Requirement {
  const Requirement(
    this.cdcCourses,
    this.cdcCredits,
    this.delCourses,
    this.delCredits,
  );
  final int cdcCourses;
  final int cdcCredits;
  final int delCourses;
  final int delCredits;
}

/// Reference data, per discipline half ("A7", "B3"…).
const Map<String, Requirement> requirements = {
  'AD': Requirement(15, 48, 4, 12),
  'AA': Requirement(14, 48, 4, 12),
  'AB': Requirement(15, 48, 4, 12),
  'AC': Requirement(14, 48, 4, 12),
  'AJ': Requirement(14, 48, 4, 12),
  'A1': Requirement(15, 45, 5, 15),
  'A2': Requirement(17, 57, 4, 12),
  'A3': Requirement(15, 49, 4, 12),
  'A4': Requirement(16, 56, 4, 12),
  'A5': Requirement(16, 48, 4, 12),
  'A7': Requirement(14, 48, 4, 12),
  'A8': Requirement(14, 48, 4, 12),
  'A9': Requirement(13, 43, 5, 15),
  'B1': Requirement(14, 44, 5, 15),
  'B2': Requirement(12, 37, 5, 15),
  'B3': Requirement(14, 42, 6, 18),
  'B4': Requirement(14, 42, 5, 15),
  'B5': Requirement(15, 45, 4, 15),
  'B7': Requirement(15, 45, 5, 15),
  'B-': Requirement(0, 0, 0, 0),
};

/// Whether [c] has been passed for the audit: a letter grade or GD, read
/// from the Actual profile only — the same rule the CGPA uses (§2.1).
bool countsTowardDegree(Course c) => c.grade1 > 0 || c.grade1 == GradeCode.gd;

/// Passed credits in [category].
double earnedCredits(Elective category, Iterable<Course> courses) => courses
    .where((c) => c.elective == category.tag && countsTowardDegree(c))
    .fold(0.0, (sum, c) => sum + c.credits);

/// Passed courses in [category]. Ids that differ only by a lowercase `l`
/// for `1` are one course (§2.10).
int earnedCourses(Elective category, Iterable<Course> courses) =>
    courses
        .where((c) => c.elective == category.tag && countsTowardDegree(c))
        .map((c) => normalizeCourseId(c.id))
        .toSet()
        .length;

/// One card of the audit. A null requirement means none is shown.
class AuditCategory {
  const AuditCategory({
    required this.category,
    required this.label,
    required this.courses,
    required this.credits,
    this.requiredCourses,
    this.requiredCredits,
  });
  final Elective category;

  /// "CDC (A7)", "Humanity Electives"…
  final String label;
  final int courses;
  final double credits;
  final int? requiredCourses;
  final int? requiredCredits;

  bool get complete =>
      requiredCredits != null &&
      requiredCredits! > 0 &&
      credits >= requiredCredits! &&
      courses >= (requiredCourses ?? 0);
  bool get notStarted => courses == 0;
}

class DegreeAudit {
  const DegreeAudit(this.totalCredits, this.categories);

  /// Credits shown on the home screen's CGPA card, out of
  /// [degreeTotalCredits].
  final double totalCredits;
  final List<AuditCategory> categories;
}

/// The audit for [discipline] ("B3A7", "--A7", "----" for none), in the order
/// the old analytics page showed it. Empty when no discipline is chosen.
DegreeAudit degreeAudit(Iterable<Course> all, String discipline) {
  if (discipline == '----') return const DegreeAudit(0, []);
  final first = discipline.substring(0, 2);
  final second = discipline.substring(2, 4);
  // As the old page filtered: with no first half, only the second counts.
  final mine =
      all
          .where(
            (c) =>
                c.discipline == (first != '--' ? first : second) ||
                c.discipline == (first != '--' ? second : 'ccccc'),
          )
          .toList();
  final noReq = discipline.startsWith('B-');

  AuditCategory card(Elective e, String label, {int? courses, int? credits}) =>
      AuditCategory(
        category: e,
        label: label,
        courses: earnedCourses(e, mine),
        credits: earnedCredits(e, mine),
        requiredCourses: courses,
        requiredCredits: credits,
      );

  final a = requirements[second];
  final b = requirements[first];
  return DegreeAudit(
    cumulativeTally(
      all,
      discipline: discipline,
      profile: Profile.actual,
    ).shownCredits,
    [
      if (second.startsWith('A')) ...[
        card(
          Elective.cdc2,
          'CDC ($second)',
          courses: a?.cdcCourses,
          credits: a?.cdcCredits,
        ),
        card(
          Elective.del2,
          'Disciplinary Electives ($second)',
          courses: a?.delCourses,
          credits: a?.delCredits,
        ),
      ],
      if (discipline.startsWith('B')) ...[
        card(
          Elective.cdc1,
          'CDC ($first)',
          courses: noReq ? null : b?.cdcCourses,
          credits: noReq ? null : b?.cdcCredits,
        ),
        card(
          Elective.del1,
          'Disciplinary Electives ($first)',
          courses: noReq ? null : b?.delCourses,
          credits: noReq ? null : b?.delCredits,
        ),
      ],
      card(Elective.humanity, 'Humanity Electives', courses: 3, credits: 8),
      discipline.startsWith('B')
          ? card(Elective.open, 'Open Electives')
          : card(Elective.open, 'Open Electives', courses: 5, credits: 15),
    ],
  );
}
