import 'dart:io';

import 'package:cgpa_calculator/core/grading/cgpa.dart';
import 'package:cgpa_calculator/core/grading/grade_scale.dart';
import 'package:cgpa_calculator/core/models/course_names.dart';
import 'package:cgpa_calculator/core/storage/courses.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/settings/settings_controller.dart';
import 'package:cgpa_calculator/mastercourselist.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import '../helpers/transcript.dart';

Set<String> _ids(List<Course> list, String d) => {
  for (final c in list)
    if (c.discipline == d) normalizeCourseId(c.id),
};

/// The B.E. Computer Science chart, less the three thesis variants (search
/// only) and BITS F112, which the app carries as HSS F101.
const _a7Chart = [
  'BITS F103', 'BIO F101', 'CHEM F101', 'MATH F101', 'PHY F101', //
  'BITS F101', 'BITS K101', 'BITS F111', 'CS F111', 'MATH F113',
  'MATH F102', 'EEE F111', 'BITS F102', 'MATH F211', 'CS F214',
  'CS F222', 'CS F213', 'CS F215', 'ECON F211', 'MGTS F211', 'CS F211',
  'CS F241', 'CS F212', 'BITS F225', 'CS F351', 'CS F372', 'CS F301',
  'CS F342', 'CS F363', 'CS F364', 'CS F303', 'BITS F412',
];

void main() {
  test('A7 carries every course on its chart', () {
    expect(_ids(hydCourseListNew, 'A7'), containsAll(_a7Chart));
  });

  test('PS-II in every discipline, old and new lists', () {
    for (final list in [hydCourseList, hydCourseListNew]) {
      for (final d in {for (final c in list) c.discipline}) {
        expect(_ids(list, d), contains('BITS F412'), reason: d);
      }
    }
  });

  test('ECON F211 and MGTS F211 are two separate courses', () {
    for (final d in ['A1', 'A7', 'AC', 'AJ', 'B3', 'B7']) {
      expect(
        _ids(hydCourseListNew, d),
        containsAll(['ECON F211', 'MGTS F211']),
        reason: d,
      );
    }
    expect(sameCourseId('ECON F211', 'MGTS F211'), isFalse);
  });

  test('AC has the current first year; AJ has its core', () {
    expect(_ids(hydCourseListNew, 'AC'), containsAll(['MATH F101', 'CS F111']));
    expect(
      _ids(hydCourseListNew, 'AJ'),
      containsAll([
        for (final n in [211, 212, 221, 311, 324]) 'ENVS F$n',
      ]),
    );
  });

  test('thesis variants are searchable', () {
    final ids = {for (final m in mcourselist) m.id};
    expect(
      ids,
      containsAll(['BITS F412', 'BITS F421T', 'BITS F425T', 'BITS F424T']),
    );
  });

  test('every seed row is ungraded, so no one’s CGPA moves', () {
    for (final c in [...hydCourseList, ...hydCourseListNew]) {
      expect(c.grade1, GradeCode.clr, reason: c.id);
      expect(c.grade2, GradeCode.clr, reason: c.id);
    }
  });

  test('the transcript’s CGPA is unchanged with the new rows added', () {
    final mine = loadTranscript();
    final held = {for (final c in mine) normalizeCourseId(c.id)};
    final seeded = [
      for (final c in hydCourseListNew)
        if (c.discipline == mine.first.discipline &&
            !held.contains(normalizeCourseId(c.id)))
          c,
    ];
    final d =
        mine.first.discipline.length == 2
            ? '--${mine.first.discipline}'
            : mine.first.discipline;
    for (final p in Profile.values) {
      expect(
        cumulativeTally(
          [...mine, ...seeded],
          discipline: d,
          profile: p,
        ).rounded,
        cumulativeTally(mine, discipline: d, profile: p).rounded,
      );
    }
  }, skip: transcriptSkip);

  test('A9 and AB are offered only to those already on them', () {
    final codes = [for (final o in disciplineOptions(dual: false)) o.$1];
    expect(codes, isNot(contains('A9')));
    expect(codes, isNot(contains('AB')));
    expect([
      for (final o in disciplineOptions(dual: false, current: 'A9')) o.$1,
    ], contains('A9'));
  });

  group('dual degree PS-II', () {
    late Directory dir;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('hive_ps2');
      Hive.init(dir.path);
      if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(CourseAdapter());
    });
    tearDown(() async {
      await Hive.deleteFromDisk();
      await dir.delete(recursive: true);
    });

    Course ps(int g) => Course(
      title: 'Practice School-II',
      id: 'BITS F412',
      credits: 20,
      grade1: g,
      grade2: GradeCode.clr,
      discipline: 'B3',
      sem: '4 - 2',
      elective: 'CDCN',
    );

    test('moves to 5 − 2 for a dual, stays for a single degree', () async {
      final box = await Hive.openBox<Course>('ps');
      await box.put('BITS F412', ps(GradeCode.clr));
      await placeDualPracticeSchool(box, 'B3--');
      expect(box.get('BITS F412')!.sem, '4 - 2');
      await placeDualPracticeSchool(box, 'B3A7');
      expect(box.get('BITS F412')!.sem, '5 - 2');
    });

    test('a graded row is never moved', () async {
      final box = await Hive.openBox<Course>('ps');
      await box.put('BITS F412', ps(10));
      await placeDualPracticeSchool(box, 'B3A7');
      expect(box.get('BITS F412')!.sem, '4 - 2');
    });
  });
}
