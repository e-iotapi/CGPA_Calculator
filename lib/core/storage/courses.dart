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

/// [course] with the grade for profile 1 or 2 replaced.
Course withGrade(Course course, int profileId, int grade) => Course(
  title: course.title,
  id: course.id,
  credits: course.credits,
  grade1: profileId == 1 ? grade : course.grade1,
  grade2: profileId == 2 ? grade : course.grade2,
  discipline: course.discipline,
  sem: course.sem,
  elective: course.elective,
);

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
      await box.put(
        e.key,
        Course(
          title: c.title,
          id: c.id,
          credits: c.credits,
          grade1: c.grade1,
          grade2: c.grade2,
          discipline: c.discipline,
          sem: '5 - 2',
          elective: c.elective,
        ),
      );
    }
  }
}
