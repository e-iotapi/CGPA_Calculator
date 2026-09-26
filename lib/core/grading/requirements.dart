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

/// What a performance sheet says one degree needs. [cdc] is every core
/// course, taken and pending, with one PS II; the sheet's [del] is both
/// halves of a dual degree together.
class DegreeNeeds {
  const DegreeNeeds({
    required this.degree,
    this.cdc,
    this.hel,
    this.del,
    this.el,
  });

  /// The discipline these are for, e.g. "B3A7"; ignored under another.
  final String degree;
  final Need? cdc, hel, del, el;

  Map<String, Object> toJson() => {
    'degree': degree,
    for (final (k, n) in [('CDC', cdc), ('HEL', hel), ('DEL', del), ('EL', el)])
      if (n != null) k: [n.courses, n.units],
  };

  static DegreeNeeds? fromJson(Map<String, dynamic> m) {
    if (m['degree'] is! String) return null;
    Need? need(String k) => switch (m[k]) {
      [final num c, final num u] => (courses: c.toInt(), units: u.toInt()),
      _ => null,
    };
    return DegreeNeeds(
      degree: m['degree'] as String,
      cdc: need('CDC'),
      hel: need('HEL'),
      del: need('DEL'),
      el: need('EL'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DegreeNeeds &&
      other.degree == degree &&
      other.cdc == cdc &&
      other.hel == hel &&
      other.del == del &&
      other.el == el;

  @override
  int get hashCode => Object.hash(degree, cdc, hel, del, el);
}

/// The department whose codes each discipline's own courses carry.
const departments = {
  'A1': 'CHE',
  'A2': 'CE',
  'A3': 'EEE',
  'A4': 'ME',
  'A5': 'PHA',
  'A7': 'CS',
  'A8': 'INSTR',
  'A9': 'BIOT',
  'AA': 'ECE',
  'AB': 'MF',
  'AC': 'ECOM',
  'AD': 'MAC',
  'AJ': 'ENVS',
  'B1': 'BIO',
  'B2': 'CHEM',
  'B3': 'ECON',
  'B4': 'MATH',
  'B5': 'PHY',
  'B7': 'SNS',
};

bool _isElective(Elective? e) =>
    e != null && e != Elective.cdc1 && e != Elective.cdc2;

/// Which elective [id], taken as [taken], counts as under [discipline]. A
/// GS or HSS code is a humanity; a disciplinary elective belongs to the half
/// whose department offers it, or whose list has it; one from any other
/// department is an open elective. Core courses never pass through here,
/// and an id that is not a course code keeps [taken].
Elective electiveFor(String id, Elective taken, String discipline) {
  // Only a course code says where a course belongs.
  final dept = RegExp(r'^([A-Z]{2,5})\s+[A-Z]\d{3}').firstMatch(id.trim());
  if (dept == null) return taken;
  return _placed(dept.group(1)!, id, taken, discipline);
}

Elective _placed(String dept, String id, Elective taken, String discipline) {
  if (dept == 'GS' || dept == 'HSS') return Elective.humanity;
  if (taken == Elective.humanity || taken == Elective.open) return taken;
  final a = discipline.substring(2, 4), b = discipline.substring(0, 2);
  if (departments[a] == dept) return Elective.del2;
  if (departments[b] == dept) return Elective.del1;
  if (del[a]?.contains(id) ?? false) return Elective.del2;
  if (del[b]?.contains(id) ?? false) return Elective.del1;
  return Elective.open;
}

/// The category [c] counts toward in the audit: its own for a core course
/// (null when it has none), [electiveFor] for an elective. With no
/// discipline, its own.
Elective? auditCategory(Course c, String discipline) {
  final e = Elective.fromTag(c.elective);
  if (!_isElective(e) || discipline == '----') return e;
  return electiveFor(c.id, e!, discipline);
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

/// Passed courses whose [auditCategory] is in [categories]; null stands for
/// a core course with no half.
Iterable<Course> _passed(
  Iterable<Course> courses,
  String discipline,
  Set<Elective?> categories,
) => courses.where(
  (c) =>
      countsTowardDegree(c) &&
      categories.contains(auditCategory(c, discipline)),
);

/// Passed credits in [category], under [discipline]'s elective rules.
double earnedCredits(
  Elective category,
  Iterable<Course> courses, {
  String discipline = '----',
}) => _passed(courses, discipline, {
  category,
}).fold(0.0, (sum, c) => sum + c.credits);

/// Passed courses in [category]. Ids that differ only by a lowercase `l`
/// for `1` are one course (§2.10).
int earnedCourses(
  Elective category,
  Iterable<Course> courses, {
  String discipline = '----',
}) =>
    _passed(courses, discipline, {
      category,
    }).map((c) => normalizeCourseId(c.id)).toSet().length;

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

  /// The card's category; CDC1 for the one core card a sheet gives.
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
  const DegreeAudit(this.totalCredits, this.categories, {this.creditsLeft});

  /// Credits shown on the home screen's CGPA card, out of
  /// [degreeTotalCredits].
  final double totalCredits;
  final List<AuditCategory> categories;

  /// With a sheet's needs: what every card still lacks, added up.
  final double? creditsLeft;
}

/// The audit for [discipline] ("B3A7", "--A7", "----" for none), in the order
/// the old analytics page showed it. Empty when no discipline is chosen.
/// [needs] from the student's own sheet win over the reference data, and
/// bring one card for every core course in place of one per half.
DegreeAudit degreeAudit(
  Iterable<Course> all,
  String discipline, {
  DegreeNeeds? needs,
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
  AuditCategory card(
    Elective e,
    String label,
    Need? need, {
    Set<Elective?>? counts,
  }) {
    final passed = _passed(mine, discipline, counts ?? {e});
    final set = need != null && (need.courses > 0 || need.units > 0);
    return AuditCategory(
      category: e,
      label: label,
      courses: passed.map((c) => normalizeCourseId(c.id)).toSet().length,
      credits: passed.fold(0.0, (s, c) => s + c.credits),
      requiredCourses: set ? need.courses : null,
      requiredCredits: set ? need.units : null,
    );
  }

  Need? cdc(Requirement? r) =>
      r == null ? null : (courses: r.cdcCourses, units: r.cdcCredits);
  Need? del(Requirement? r) =>
      r == null ? null : (courses: r.delCourses, units: r.delCredits);

  final a = requirements[second];
  final b = noReq ? null : requirements[first];
  final hasA = second.startsWith('A'), hasB = discipline.startsWith('B');
  // A dual's sheet gives one DEL total; each half keeps its own card, with
  // the reference data's share.
  final dual = hasA && hasB;
  final core = sheet?.cdc;
  final cards = [
    if (core != null)
      card(
        Elective.cdc1,
        'Core courses (CDC)',
        core,
        counts: {null, Elective.cdc1, Elective.cdc2},
      ),
    if (hasA) ...[
      if (core == null) card(Elective.cdc2, 'CDC ($second)', cdc(a)),
      card(
        Elective.del2,
        'Disciplinary Electives ($second)',
        dual ? del(a) : sheet?.del ?? del(a),
      ),
    ],
    if (hasB) ...[
      if (core == null) card(Elective.cdc1, 'CDC ($first)', cdc(b)),
      card(
        Elective.del1,
        'Disciplinary Electives ($first)',
        dual || noReq ? del(b) : sheet?.del ?? del(b),
      ),
    ],
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
  ];
  return DegreeAudit(
    cumulativeTally(
      all,
      discipline: discipline,
      profile: Profile.actual,
    ).shownCredits,
    cards,
    creditsLeft:
        core == null
            ? null
            : cards.fold<double>(
              0,
              (s, c) =>
                  s +
                  ((c.requiredCredits ?? 0) - c.credits).clamp(
                    0,
                    double.infinity,
                  ),
            ),
  );
}
