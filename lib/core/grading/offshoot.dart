/// The finance offshoot score: the best five (or all six) grades from a fixed
/// set of finance courses, out of 50 (or 60). Pure — storage lives in
/// core/storage/offshoot.dart.
library;

/// One of the six courses that make up the offshoot.
///
/// Matched by course code, not title — three of the six are commonly written
/// with slightly different names than the ones stored in the course list.
class OffshootCourse {
  final String id;
  final String title;
  const OffshootCourse(this.id, this.title);
}

const List<OffshootCourse> offshootCourses = [
  OffshootCourse('ECON F212', 'Fundamentals of Finance and Accounts'),
  OffshootCourse('ECON F315', 'Financial Management'),
  OffshootCourse('ECON F354', 'Derivatives and Risk Management'),
  OffshootCourse('ECON F412', 'Security Analysis and Portfolio Management'),
  // Cross-listed as BITS F493; the course graph links the two.
  OffshootCourse('ECON F355', 'Business Analysis and Valuation'),
  OffshootCourse('FIN F414', 'Financial Risk Analytics and Risk Management'),
];

/// The two denominators: best 5 of the six, or all 6.
const offshootDenominators = [50, 60];

/// One course's line in the calculation.
class OffshootRow {
  final OffshootCourse course;
  final int? grade; // null = not in the user's course list
  final bool excluded; // user unticked it
  const OffshootRow(this.course, this.grade, this.excluded);

  /// Only positive grades score. NC/CLR/GD and the withdrawn statuses
  /// (RC, W) carry no points and never occupy one of the counted slots.
  bool get scorable => !excluded && (grade ?? 0) > 0;
}

/// The offshoot total for [rows] out of [outOf].
class OffshootScore {
  OffshootScore(this.rows, this.outOf) {
    final best =
        rows.where((r) => r.scorable).toList()
          ..sort((a, b) => b.grade!.compareTo(a.grade!));
    scorableCount = best.length;
    counted = best.take(takeCount).map((r) => r.course.id).toList();
    total = best.take(takeCount).fold(0, (sum, r) => sum + r.grade!);
  }

  final List<OffshootRow> rows;

  /// 50 or 60.
  final int outOf;

  /// Ids of the rows that contributed, best first.
  late final List<String> counted;
  late final int total;

  /// Rows that could score: ticked and with a letter grade.
  late final int scorableCount;

  /// How many courses count toward the total: 5 for /50, 6 for /60.
  int get takeCount => outOf ~/ 10;

  bool isCounted(OffshootRow r) => counted.contains(r.course.id);

  /// Graded and ticked, but outside the best [takeCount].
  List<OffshootRow> get dropped =>
      rows.where((r) => r.scorable && !isCounted(r)).toList();
}
