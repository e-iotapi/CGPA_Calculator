import 'package:cgpa_calculator/core/grading/grade_scale.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:hive/hive.dart';

const coursesBoxName = 'coursesBox';

/// Writes [course] back over the stored course with the same id and semester,
/// under whatever key that one has.
///
/// Courses added through search are stored with `box.add`, so their key is an
/// int; seeded ones are keyed by id. Writing with `put(course.id, …)` over an
/// int-keyed course leaves the old one in place and duplicates it.
Future<void> saveCourse(Course course) async {
  final box = Hive.box<Course>(coursesBoxName);
  final key = box.keys.firstWhere((k) {
    final c = box.get(k);
    return c != null && c.id == course.id && c.sem == course.sem;
  }, orElse: () => course.id);
  await box.put(key, course);
  await box.flush();
}

/// Copies profile [from]'s grade onto profile [to] for every course, in all
/// semesters, under each course's existing key.
Future<void> copyProfile(int from, int to) async {
  final box = Hive.box<Course>(coursesBoxName);
  for (final e in box.toMap().entries) {
    await box.put(e.key, e.value.withGrade(to, e.value.gradeFor(from)));
  }
  await box.flush();
}

/// Whether profile [profile] has no grade on any course yet.
bool profileIsEmpty(int profile) => Hive.box<Course>(
  coursesBoxName,
).values.every((c) => c.gradeFor(profile) == GradeCode.clr);

/// Every stored course, for read-only screens.
Iterable<Course> allCourses() => Hive.box<Course>(coursesBoxName).values;

/// A dual degree takes Practice School-II in its fifth year, not the fourth
/// the chart row is seeded in. Moves only a seeded, ungraded row.
Future<void> placeDualPracticeSchool(Box<Course> box, String discipline) async {
  final dual = discipline.startsWith('B') && discipline.substring(2) != '--';
  if (!dual) return;
  for (final e in box.toMap().entries) {
    final c = e.value;
    if (c.id == 'BITS F412' &&
        c.sem == '4 - 2' &&
        c.grade1 == GradeCode.clr &&
        c.grade2 == GradeCode.clr) {
      await box.put(e.key, c.copyWith(sem: '5 - 2'));
    }
  }
}
