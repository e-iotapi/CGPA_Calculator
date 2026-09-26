import 'dart:io';

import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/core/grading/grade_scale.dart';
import 'package:cgpa_calculator/core/models/marks.dart';
import 'package:cgpa_calculator/core/storage/courses.dart';
import 'package:cgpa_calculator/core/storage/marks.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/calendar/calendar_controller.dart';
import 'package:cgpa_calculator/features/calendar/calendar_page.dart';
import 'package:cgpa_calculator/shared/widgets/offline_strip.dart';
import 'package:cgpa_calculator/sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import '../helpers/fonts.dart';

final _today = DateTime(2026, 9, 26);

Evaluative _labs() => Evaluative(
  courseId: 'CS F372',
  name: 'Eval Labs',
  weight: 15,
  parts: [
    EvalPart(name: 'Eval Lab 1', marks: 4, outOf: 5, date: '2026-09-08'),
    EvalPart(name: 'Eval Lab 2', outOf: 5, date: '2026-09-29'),
    EvalPart(name: 'Eval Lab 3', outOf: 5, date: '2026-10-27'),
    EvalPart(name: 'Eval Lab 4', outOf: 5),
  ],
);

void main() {
  test('entries come from part dates, soonest first', () {
    final all = calendarEntries([_labs()]);
    expect(all.map((e) => e.label), ['Eval Lab 1', 'Eval Lab 2', 'Eval Lab 3']);
    expect(upcoming(all, _today).first.label, 'Eval Lab 2');
    expect(soonLabel(DateTime(2026, 9, 29), _today), 'IN 3 DAYS');
    expect(soonLabel(DateTime(2026, 9, 26), _today), 'TODAY');
    expect(soonLabel(DateTime(2026, 10, 27), _today), isNull);
  });

  group('with storage', () {
    late Directory dir;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('hive_cal');
      Hive.init(dir.path);
      if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(CourseAdapter());
      registerMarksAdapters();
      await Sync.openBoxes();
      await Hive.box<Course>(coursesBoxName).add(
        Course(
          title: 'Operating Systems',
          id: 'CS F372',
          credits: 3,
          grade1: GradeCode.clr,
          grade2: GradeCode.clr,
          discipline: 'A7',
          sem: '4 - 1',
          elective: 'CDC2',
        ),
      );
    });
    tearDown(() async {
      await Hive.deleteFromDisk();
      await dir.delete(recursive: true);
    });

    Future<void> pump(WidgetTester t, Widget w, Size s, [double k = 1]) async {
      t.view.physicalSize = s;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: AppPalette.light.materialTheme,
          builder:
              (c, child) => MediaQuery(
                data: MediaQuery.of(
                  c,
                ).copyWith(textScaler: TextScaler.linear(k)),
                child: child!,
              ),
          home: w,
        ),
      );
      await t.pumpAndSettle();
    }

    testWidgets('a date entered in Marks appears without a second entry', (
      t,
    ) async {
      await loadAppFonts();
      await t.runAsync(() => saveEvaluative(_labs()));
      await pump(t, CalendarPage(today: _today), const Size(390, 844));
      expect(find.text('September 2026'), findsOneWidget);
      expect(find.text('Eval Lab 2'), findsOneWidget);
      expect(find.text('IN 3 DAYS'), findsOneWidget);
      expect(find.text('Operating Systems · CS F372'), findsWidgets);
      expect(find.text('2 remaining'), findsOneWidget);
      await t.tap(find.bySemanticsLabel(RegExp('^8 September')));
      await t.pumpAndSettle();
      expect(find.text('Eval Lab 1'), findsOneWidget);
    });

    testWidgets('no overflow at 320, 768, 1440 or 200% text', (t) async {
      await loadAppFonts();
      await t.runAsync(() => saveEvaluative(_labs()));
      for (final s in const [
        Size(320, 640),
        Size(768, 1024),
        Size(1440, 900),
      ]) {
        await pump(t, CalendarPage(today: _today), s);
        expect(t.takeException(), isNull, reason: '$s');
      }
      await pump(t, CalendarPage(today: _today), const Size(320, 640), 2);
      expect(t.takeException(), isNull, reason: '200%');
    });
  });

  testWidgets('offline strip says work is saved, and hides when online', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        theme: AppPalette.light.materialTheme,
        home: Scaffold(
          body: Column(
            children: [
              OfflineStrip(forceOffline: true, pending: () => true),
              const OfflineStrip(),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Working offline'), findsOneWidget);
    expect(find.textContaining('will sync'), findsOneWidget);
  });
}
