import 'dart:io';

import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/core/grading/grade_scale.dart';
import 'package:cgpa_calculator/core/grading/offshoot.dart';
import 'package:cgpa_calculator/core/storage/courses.dart';
import 'package:cgpa_calculator/core/storage/offshoot.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/offshoot/offshoot_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import '../helpers/fonts.dart';

// The verified transcript: A, A, A, A-, B and B- across the six.
const _grades = {
  'ECON F315': 10,
  'FIN F414': 10,
  'ECON F355': 10,
  'ECON F212': 9,
  'ECON F354': 8,
  'ECON F412': 7,
};

List<OffshootRow> _rows({
  Map<String, int?> grades = _grades,
  Set<String> excluded = const {},
}) => [
  for (final c in offshootCourses)
    OffshootRow(c, grades[c.id], excluded.contains(c.id)),
];

Future<void> _pump(
  WidgetTester t,
  OffshootScore score, {
  Size size = const Size(320, 640),
  double textScale = 1,
  ValueChanged<String>? onToggle,
  ValueChanged<int>? onOutOf,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: AppPalette.light.materialTheme,
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
      home: Scaffold(
        body: OffshootPanel(
          score: score,
          onToggleCourse: onToggle ?? (_) {},
          onOutOfSelected: onOutOf ?? (_) {},
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  group('OffshootScore', () {
    test('best 5 of the verified grades is 47 / 50', () {
      final s = OffshootScore(_rows(), 50);
      expect(s.total, 47);
      expect(s.counted, isNot(contains('ECON F412')));
      expect(s.dropped.single.course.id, 'ECON F412');
    });

    test('all 6 is 54 / 60', () {
      final s = OffshootScore(_rows(), 60);
      expect(s.total, 54);
      expect(s.dropped, isEmpty);
    });

    test('an unticked course frees its slot for the next best', () {
      final s = OffshootScore(_rows(excluded: {'FIN F414'}), 50);
      expect(s.total, 44); // 10 + 10 + 9 + 8 + 7
      expect(s.counted, contains('ECON F412'));
    });

    test('NC, RC, W, CLR, GD and missing courses never take a slot', () {
      final s = OffshootScore(
        _rows(
          grades: {
            ..._grades,
            'ECON F315': GradeCode.nc,
            'FIN F414': GradeCode.rc,
            'ECON F355': null,
          },
        ),
        50,
      );
      expect(s.scorableCount, 3);
      expect(s.total, 24);
    });
  });

  group('storage', () {
    late Directory dir;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('hive_offshoot');
      Hive.init(dir.path);
      if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(CourseAdapter());
      final box = await Hive.openBox<Course>(coursesBoxName);
      await Hive.openBox('settingsBox');
      for (final e in _grades.entries) {
        await box.add(
          Course(
            title: e.key,
            id: e.key,
            credits: 3,
            grade1: e.value,
            grade2: GradeCode.clr,
            discipline: 'B3',
            sem: '4 - 1',
            elective: 'Open Elective',
          ),
        );
      }
    });
    tearDown(() async {
      await Hive.deleteFromDisk();
      await dir.delete(recursive: true);
    });

    test('reads Actual grades and the saved settings', () async {
      expect(loadOffshootScore().total, 47);
      await setOffshootOutOf(60);
      expect(loadOffshootScore().total, 54);
      await toggleOffshootExcluded('ECON F412');
      expect(loadOffshootScore().total, 47);
      await toggleOffshootExcluded('ECON F412');
      expect(offshootExcluded, isEmpty);
    });

    test('a grade under a cross-listed code counts', () async {
      final box = Hive.box<Course>(coursesBoxName);
      final key = box.keys.firstWhere((k) => box.get(k)!.id == 'ECON F355');
      await box.put(
        key,
        Course(
          title: 'Business Analysis and Valuation',
          id: 'BITS F493',
          credits: 3,
          grade1: 10,
          grade2: GradeCode.clr,
          discipline: 'B3',
          sem: '4 - 1',
          elective: 'Open Elective',
        ),
      );
      expect(offshootGradeFor('ECON F355'), 10);
      expect(loadOffshootScore().total, 47);
    });

    test('a corrupt denominator falls back to 50', () async {
      await Hive.box('settingsBox').put('offshoot_outof', 55);
      expect(offshootOutOf, 50);
    });
  });

  group('OffshootPanel', () {
    testWidgets('shows 47 / 50 and says which course is dropped', (t) async {
      await _pump(t, OffshootScore(_rows(), 50));
      expect(find.text('47'), findsOneWidget);
      expect(find.text('/ 50'), findsOneWidget);
      expect(
        find.text('Best 5 of 6 graded courses · dropping ECON F412'),
        findsOneWidget,
      );
      await t.scrollUntilVisible(find.text('ECON F412'), 200);
      expect(find.text('Not counted · lowest of the six'), findsOneWidget);
    });

    testWidgets('all 6 shows 54 / 60', (t) async {
      await _pump(t, OffshootScore(_rows(), 60));
      expect(find.text('54'), findsOneWidget);
      expect(find.text('/ 60'), findsOneWidget);
    });

    testWidgets('taps report the course and the denominator', (t) async {
      final toggled = <String>[];
      final outOf = <int>[];
      await _pump(
        t,
        OffshootScore(_rows(), 50),
        onToggle: toggled.add,
        onOutOf: outOf.add,
      );
      await t.tap(find.text('All 6 · / 60'));
      await t.scrollUntilVisible(find.text('ECON F315'), 200);
      await t.tap(find.text('ECON F315'));
      expect(outOf, [60]);
      expect(toggled, ['ECON F315']);
    });

    testWidgets('rows announce ticked state and whether they count', (t) async {
      await _pump(t, OffshootScore(_rows(), 50), size: const Size(768, 1024));
      final data = t.getSemantics(find.text('ECON F412')).getSemanticsData();
      expect(data.label, contains('not counted'));
      expect(data.label, contains('grade B-'));
    });

    testWidgets('no overflow at 320, 768, 1440 or 200% text', (t) async {
      final s = OffshootScore(_rows(excluded: {'ECON F212'}), 50);
      for (final size in const [
        Size(320, 640),
        Size(768, 1024),
        Size(1440, 900),
      ]) {
        await _pump(t, s, size: size);
        expect(t.takeException(), isNull, reason: '$size');
      }
      await _pump(t, s, textScale: 2);
      expect(t.takeException(), isNull, reason: '200%');
    });
  });
}
