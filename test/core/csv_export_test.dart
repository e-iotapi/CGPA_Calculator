import 'dart:io';

import 'package:cgpa_calculator/core/storage/courses.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/script.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  group('buildGradesCsv', () {
    late Directory dir;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('hive_test');
      Hive.init(dir.path);
      if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(CourseAdapter());
      await Hive.openBox<Course>(coursesBoxName);
    });
    tearDown(() async {
      await Hive.deleteFromDisk();
      await dir.delete(recursive: true);
    });

    test('a title that looks like a formula is neutralised (BUG-45)', () async {
      final box = Hive.box<Course>(coursesBoxName);
      await box.put(
        'CS F111',
        Course(
          title: '=1+2, "quoted" title',
          id: 'CS F111',
          credits: 3,
          grade1: GradeCode.clr,
          grade2: GradeCode.clr,
          discipline: 'B3',
          sem: '1 - 1',
          elective: 'CDC',
        ),
      );
      final csv = buildGradesCsv();
      // Every leading-formula cell is prefixed with a plain quote so Excel
      // and Sheets read it as text, not run it as a formula.
      expect(csv, contains("'=1+2"));
      expect(csv.contains('"=1+2'), isFalse);
    });
  });
}
