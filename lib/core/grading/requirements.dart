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

/// A count of courses and of units.
typedef Need = ({int courses, int units});

/// What a performance sheet says one degree needs, per elective tag. The
/// sheet's DEL is both halves of a dual degree together.
class ElectiveNeeds {
  const ElectiveNeeds({required this.degree, this.hel, this.del, this.el});

  /// The discipline these are for, e.g. "B3A7"; ignored under another.
  final String degree;
  final Need? hel, del, el;

  Map<String, Object> toJson() => {
    'degree': degree,
    for (final (k, n) in [('HEL', hel), ('DEL', del), ('EL', el)])
      if (n != null) k: [n.courses, n.units],
  };

  static ElectiveNeeds? fromJson(Map<String, dynamic> m) {
    if (m['degree'] is! String) return null;
    Need? need(String k) => switch (m[k]) {
      [final num c, final num u] => (courses: c.toInt(), units: u.toInt()),
      _ => null,
    };
    return ElectiveNeeds(
      degree: m['degree'] as String,
      hel: need('HEL'),
      del: need('DEL'),
      el: need('EL'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ElectiveNeeds &&
      other.degree == degree &&
      other.hel == hel &&
      other.del == del &&
      other.el == el;

  @override
  int get hashCode => Object.hash(degree, hel, del, el);
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
    this.also,
  });
  final Elective category;

  /// A second category counted in the same card: a dual degree's two
  /// disciplinary electives, when the sheet gives only their total.
  final Elective? also;

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
/// [needs] from the student's own sheet win over the reference data.
DegreeAudit degreeAudit(
  Iterable<Course> all,
  String discipline, {
  ElectiveNeeds? needs,
}) {
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
  final sheet = needs?.degree == discipline ? needs : null;

  // A need of nothing at all shows the totals alone.
  AuditCategory card(Elective e, String label, Need? need, {Elective? also}) {
    final set = need != null && (need.courses > 0 || need.units > 0);
    return AuditCategory(
      category: e,
      label: label,
      courses:
          earnedCourses(e, mine) +
          (also == null ? 0 : earnedCourses(also, mine)),
      credits:
          earnedCredits(e, mine) +
          (also == null ? 0 : earnedCredits(also, mine)),
      requiredCourses: set ? need.courses : null,
      requiredCredits: set ? need.units : null,
      also: also,
    );
  }

  Need? cdc(Requirement? r) =>
      r == null ? null : (courses: r.cdcCourses, units: r.cdcCredits);
  Need? del(Requirement? r) =>
      r == null ? null : (courses: r.delCourses, units: r.delCredits);

  final a = requirements[second];
  final b = noReq ? null : requirements[first];
  final hasA = second.startsWith('A'), hasB = discipline.startsWith('B');
  final sheetDel = sheet?.del;
  final aDel = del(a), bDel = del(b);
  // A dual's sheet gives one DEL total. It keeps the per-degree split when the
  // reference data adds up to it, and becomes one card when it does not.
  final merge =
      sheetDel != null &&
      hasA &&
      hasB &&
      !(aDel != null &&
          bDel != null &&
          aDel.courses + bDel.courses == sheetDel.courses &&
          aDel.units + bDel.units == sheetDel.units);
  return DegreeAudit(
    cumulativeTally(
      all,
      discipline: discipline,
      profile: Profile.actual,
    ).shownCredits,
    [
      if (hasA) ...[
        card(Elective.cdc2, 'CDC ($second)', cdc(a)),
        if (!merge)
          card(
            Elective.del2,
            'Disciplinary Electives ($second)',
            hasB ? aDel : sheetDel ?? aDel,
          ),
      ],
      if (hasB) ...[
        card(Elective.cdc1, 'CDC ($first)', cdc(b)),
        if (!merge)
          card(
            Elective.del1,
            'Disciplinary Electives ($first)',
            hasA || noReq ? bDel : sheetDel ?? bDel,
          ),
      ],
      if (merge)
        card(
          Elective.del2,
          'Disciplinary Electives',
          sheetDel,
          also: Elective.del1,
        ),
      card(
        Elective.humanity,
        'Humanity Electives',
        sheet?.hel ?? (courses: 3, units: 8),
      ),
      card(
        Elective.open,
        'Open Electives',
        sheet?.el ?? (hasB ? null : (courses: 5, units: 15)),
      ),
    ],
  );
}
