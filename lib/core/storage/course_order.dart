import 'package:cgpa_calculator/course.dart';
import 'package:hive/hive.dart';

/// The order a student dragged each semester's courses into, as semester →
/// course ids. One order for every grade profile: it is a view preference,
/// not a scenario. Synced with the rest of settingsBox.
const _key = 'course_order';

/// `currentsort` while the saved order applies.
const customSortKey = 'Custom';

Box get _settings => Hive.box('settingsBox');

/// The saved order for [sem]; empty when never dragged.
List<String> courseOrderFor(String sem) {
  final all = _settings.get(_key);
  final ids = all is Map ? all[sem] : null;
  return ids is List ? [for (final id in ids) '$id'] : const [];
}

Future<void> setCourseOrder(String sem, List<String> ids) {
  final all = _settings.get(_key);
  return _settings.put(_key, {
    if (all is Map)
      for (final e in all.entries) '${e.key}': e.value,
    sem: ids,
  });
}

/// [courses] in [order]; any course not in it keeps its place relative to
/// the others and goes after, so a new course joins at the end.
List<Course> orderCourses(List<Course> courses, List<String> order) {
  final pos = {for (final (i, id) in order.indexed) id: i};
  final indexed =
      courses.indexed.toList()..sort((a, b) {
        final pa = pos[a.$2.id], pb = pos[b.$2.id];
        if (pa != null && pb != null) return pa.compareTo(pb);
        if (pa != null) return -1;
        if (pb != null) return 1;
        return a.$1.compareTo(b.$1);
      });
  return [for (final (_, c) in indexed) c];
}
