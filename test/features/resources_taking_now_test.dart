// BUG-11: "Your courses this semester" listed courses cleared or ongoing
// from any semester, not just the current one.
import 'dart:io';

import 'package:cgpa_calculator/core/models/programmes.dart';
import 'package:cgpa_calculator/core/storage/courses.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/marks/official.dart';
import 'package:cgpa_calculator/features/resources/resources_page.dart';
import 'package:cgpa_calculator/script.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

Course _c(String id, String sem, int grade1) => Course(
  title: id,
  id: id,
  credits: 3,
  sem: sem,
  discipline: 'A3',
  elective: 'CDC',
  grade1: grade1,
  grade2: -2,
);

// Batch 24's chart semester for today's term.
String _semNow() {
  final t = currentTerm(DateTime.now()).split('-');
  return '${int.parse(t[0]) - 2024 + 1} - ${t[2] == '1' ? 1 : 2}';
}

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('taking_now');
    Hive.init(dir.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(CourseAdapter());
    await Hive.openBox<Course>(coursesBoxName);
    app.campus = Campus.goa;
    app.batch = 24;
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('only the current semester counts as taking now', () async {
    final box = Hive.box<Course>(coursesBoxName);
    final now = _semNow();
    await box.putAll({
      // Current semester, in progress: included.
      'a': _c('EEE F311', now, -8), // ongoing
      // Current semester, cleared without a grade: included.
      'b': _c('EEE F313', now, -2), // clr
      // A past semester's course, cleared: BUG-11 wrongly included this.
      'c': _c('PHY F111', '1 - 1', -2),
      'd': _c('ECON F315', '2 - 1', -2),
      // A past semester's course that was actually graded: never included.
      'e': _c('CS F111', '1 - 1', 10),
    });

    expect(takingNow(), {'EEE F311', 'EEE F313'});
  });

  test('a course outside the catalogue keeps the title you gave it', () async {
    await Hive.box<Course>(
      coursesBoxName,
    ).put('a', _c('ZZZ F999', '1 - 1', -8));
    expect(courseTitle('ZZZ F999'), 'ZZZ F999');
    expect(courseTitle('NOPE F000'), '');
  });
}
