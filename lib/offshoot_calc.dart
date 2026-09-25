import 'package:cgpa_calculator/course.dart';
import 'package:hive/hive.dart';

/// The six finance courses that make up the offshoot.
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
  OffshootCourse('BITS F493', 'Business Analysis and Valuation'),
  OffshootCourse('FIN F414', 'Financial Risk Analytics and Risk Management'),
];

/// Courses the user has excluded from the calculation, by id.
Set<String> get offshootExcluded {
  final raw = Hive.box('settingsBox').get('offshoot_excluded', defaultValue: '');
  final s = (raw is String) ? raw : '';
  return s.isEmpty ? <String>{} : s.split(',').toSet();
}

Future<void> setOffshootExcluded(Set<String> ids) async =>
    Hive.box('settingsBox').put('offshoot_excluded', ids.join(','));

/// Denominator the user is calculating against: 50 (best 5) or 60 (all 6).
int get offshootOutOf {
  final v = Hive.box('settingsBox').get('offshoot_outof', defaultValue: 50);
  return (v is int && (v == 50 || v == 60)) ? v : 50;
}

Future<void> setOffshootOutOf(int v) async =>
    Hive.box('settingsBox').put('offshoot_outof', v);

/// How many courses count toward the total: 5 for /50, 6 for /60.
int get offshootTakeCount => offshootOutOf ~/ 10;

/// The Actual-profile grade for [id], or null if that course isn't in the
/// user's list at all.
int? offshootGradeFor(String id) {
  for (final c in Hive.box<Course>('coursesBox').values) {
    if (c.id == id) return c.grade1;
  }
  return null;
}

/// One row of the offshoot panel.
class OffshootRow {
  final OffshootCourse course;
  final int? grade; // null = not in the user's course list
  final bool excluded; // user unticked it
  const OffshootRow(this.course, this.grade, this.excluded);

  /// Only positive grades score. NC/CLR/GD and the withdrawn statuses
  /// (RC, W) carry no points and never occupy one of the counted slots.
  bool get scorable => !excluded && (grade ?? 0) > 0;
}

List<OffshootRow> offshootRows() => [
  for (final oc in offshootCourses)
    OffshootRow(oc, offshootGradeFor(oc.id), offshootExcluded.contains(oc.id)),
];

/// Ids of the rows that actually contributed, best-first.
List<String> offshootCountedIds([List<OffshootRow>? rows]) {
  final r = (rows ?? offshootRows()).where((x) => x.scorable).toList()
    ..sort((a, b) => b.grade!.compareTo(a.grade!));
  return r.take(offshootTakeCount).map((x) => x.course.id).toList();
}

/// Total points, taking the best [offshootTakeCount] scorable grades.
int offshootTotal([List<OffshootRow>? rows]) {
  final r = (rows ?? offshootRows()).where((x) => x.scorable).toList()
    ..sort((a, b) => b.grade!.compareTo(a.grade!));
  return r.take(offshootTakeCount).fold(0, (sum, x) => sum + x.grade!);
}
