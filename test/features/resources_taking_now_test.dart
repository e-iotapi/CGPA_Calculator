// BUG-11: "Your courses this semester" listed courses cleared or ongoing
// from any semester, not just the current one.
import 'dart:io';

import 'package:cgpa_calculator/core/models/programmes.dart';
import 'package:cgpa_calculator/core/storage/courses.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/resources/resources_page.dart';
import 'package:cgpa_calculator/script.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

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
    // Batch 24, "today" per currentTerm's clock falls in "3 - 1" (2026-27-1).
    await box.putAll({
      // Current semester, in progress: included.
      'a': _c('EEE F311', '3 - 1', -8), // ongoing
      // Current semester, cleared without a grade: included.
      'b': _c('EEE F313', '3 - 1', -2), // clr
      // A past semester's course, cleared: BUG-11 wrongly included this.
      'c': _c('PHY F111', '1 - 1', -2),
      'd': _c('ECON F315', '2 - 1', -2),
      // A past semester's course that was actually graded: never included.
      'e': _c('CS F111', '1 - 1', 10),
    });

    expect(takingNow(), {'EEE F311', 'EEE F313'});
  });
}
