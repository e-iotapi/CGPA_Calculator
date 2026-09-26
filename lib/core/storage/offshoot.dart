import 'package:cgpa_calculator/core/grading/offshoot.dart';
import 'package:cgpa_calculator/core/storage/courses.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:hive/hive.dart';

Box get _settings => Hive.box('settingsBox');

/// Courses the user has excluded from the calculation, by id.
Set<String> get offshootExcluded {
  final raw = _settings.get('offshoot_excluded', defaultValue: '');
  final s = (raw is String) ? raw : '';
  return s.isEmpty ? <String>{} : s.split(',').toSet();
}

Future<void> setOffshootExcluded(Set<String> ids) async =>
    _settings.put('offshoot_excluded', ids.join(','));

Future<void> toggleOffshootExcluded(String id) async {
  final ex = offshootExcluded;
  ex.contains(id) ? ex.remove(id) : ex.add(id);
  await setOffshootExcluded(ex);
}

/// Denominator the user is calculating against: 50 (best 5) or 60 (all 6).
int get offshootOutOf {
  final v = _settings.get('offshoot_outof', defaultValue: 50);
  return (v is int && offshootDenominators.contains(v)) ? v : 50;
}

Future<void> setOffshootOutOf(int v) async =>
    _settings.put('offshoot_outof', v);

/// The Actual-profile grade for [id], or null if that course isn't in the
/// user's list at all.
int? offshootGradeFor(String id) {
  for (final c in Hive.box<Course>(coursesBoxName).values) {
    if (c.id == id) return c.grade1;
  }
  return null;
}

/// The score from the stored grades and settings.
OffshootScore loadOffshootScore() {
  final ex = offshootExcluded;
  return OffshootScore([
    for (final oc in offshootCourses)
      OffshootRow(oc, offshootGradeFor(oc.id), ex.contains(oc.id)),
  ], offshootOutOf);
}
