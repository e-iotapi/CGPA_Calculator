import 'dart:io';
import 'dart:ui' as ui;

import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/core/grading/grade_scale.dart';
import 'package:cgpa_calculator/core/grading/marks.dart';
import 'package:cgpa_calculator/core/models/marks.dart';
import 'package:cgpa_calculator/core/storage/marks.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/calendar/calendar_controller.dart';
import 'package:cgpa_calculator/features/marks/add_evaluative_page.dart';
import 'package:cgpa_calculator/features/marks/marks_format.dart';
import 'package:cgpa_calculator/features/marks/course_setup_page.dart';
import 'package:cgpa_calculator/features/marks/marks_page.dart';
import 'package:cgpa_calculator/features/semester/semester_controller.dart';
import 'package:cgpa_calculator/features/semester/widgets/course_row.dart';
import 'package:cgpa_calculator/sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import '../helpers/fonts.dart';

EvalPart _p(String n, double? m, double o, [String? d]) =>
    EvalPart(name: n, marks: m, outOf: o, date: d);

// The spreadsheet's components (parts reconstructed to give its figures).
Evaluative _assignment0() => Evaluative(
  courseId: 'CS F372',
  name: 'Assignment 0',
  weight: 6,
  parts: [_p('Breaking System', 2, 2), _p('Shell', 4, 4)],
);
Evaluative _kernel() => Evaluative(
  courseId: 'CS F372',
  name: 'Kernel Assignments',
  weight: 20,
  countBest: 2,
  parts: [
    _p('CPU Scheduling', 8, 10),
    _p('Memory Management', 6, 10),
    _p('Concurrency', 3, 10),
  ],
);
Evaluative _evalLabs() => Evaluative(
  courseId: 'CS F372',
  name: 'Eval Labs',
  weight: 15,
  countBest: 3,
  parts: [
    _p('Lab 1', 1, 5, '2026-09-08'),
    _p('Lab 2', 0.92, 5, '2026-10-06'),
    _p('Lab 3', 0.84, 5, '2026-10-27'),
    _p('Lab 4', 0.5, 5, '2026-11-17'),
  ],
);
Evaluative _quiz() => Evaluative(
  courseId: 'CS F372',
  name: 'In-Lab Quiz',
  weight: 4,
  countBest: 4,
  parts: [
    for (final (i, m) in [4.0, 3.0, 3.0, 3.0, 2.0, 1.0].indexed)
      _p('Quiz ${i + 1}', m, 5, '2026-0${8 + i ~/ 3}-1${i % 3}'),
  ],
);
Evaluative _single(String n, double w, [double? m]) => Evaluative(
  courseId: 'CS F372',
  name: n,
  weight: w,
  parts: [_p('', m, 100)],
);

List<Evaluative> get _sheet => [
  _assignment0(),
  _kernel(),
  _evalLabs(),
  _quiz(),
  _single('Mid Semester', 25),
  _single('Compre', 30),
];

final _os = Course(
  title: 'Operating Systems',
  id: 'CS F372',
  credits: 3,
  grade1: 9,
  grade2: GradeCode.clr,
  discipline: 'A7',
  sem: '4 - 1',
  elective: 'CDC2',
);

void main() {
  group('marks maths', () {
    test('each component as the spreadsheet shows it', () {
      String f(Evaluative e) => contribution(e)!.toStringAsFixed(2);
      expect(f(_assignment0()), '6.00');
      expect(f(_kernel()), '14.00');
      expect(f(_evalLabs()), '2.76');
      expect(f(_quiz()), '2.60');
      expect(droppedParts(_kernel()).single.name, 'Concurrency');
    });

    test('running total is the sum of the components, over 45 graded', () {
      final s = MarksSummary(_sheet, null);
      expect(s.gradedWeight, 45);
      // 6 + 14 + 2.76 + 2.60. PLAN.md says 11.36, which leaves out Kernel.
      expect(s.secured.toStringAsFixed(2), '25.36');
      expect(contribution(_single('Mid Semester', 25)), isNull);
    });

    test('scaling derives from the parts, not a fixed divisor', () {
      final k = _kernel()..parts[0].outOf = 20; // 8/20 now
      // Best two by ratio: 6/10 and 3/10 vs 8/20 → 6/10 + 8/20.
      expect(contribution(k), closeTo((6 + 8) / (10 + 20) * 20, 1e-9));
    });

    test('ungraded parts never count, even inside best-of', () {
      final e = Evaluative(
        courseId: 'X',
        name: 'Quiz',
        weight: 10,
        countBest: 2,
        parts: [_p('a', 5, 10), _p('b', null, 10), _p('c', null, 10)],
      );
      expect(countedParts(e).length, 1);
      expect(contribution(e), 5);
    });

    test('class delta is yours − average, and absent when unset', () {
      final cfg = CourseConfig(courseId: 'CS F372');
      expect(MarksSummary(_sheet, cfg).classDelta, isNull);
      cfg.classAverage = 23.8;
      expect(MarksSummary(_sheet, cfg).classDelta, closeTo(1.56, 1e-9));
      expect(MarksSummary([], cfg).classDelta, isNull);
    });

    test('total-marks mode rescales only the display', () {
      final s = MarksSummary([
        Evaluative(
          courseId: 'X',
          name: 'Labs',
          weight: 200,
          parts: [_p('', 160, 200)],
        ),
      ], CourseConfig(courseId: 'X', weighted: false, courseTotal: 300));
      expect(s.secured, 160);
      expect(s.shownSecured.toStringAsFixed(1), '53.3');
    });
  });

  group('storage and sync', () {
    late Directory dir;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('hive_marks');
      Hive.init(dir.path);
      if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(CourseAdapter());
      registerMarksAdapters();
      await Sync.openBoxes();
    });
    tearDown(() async {
      await Hive.deleteFromDisk();
      await dir.delete(recursive: true);
    });

    test(
      'evaluatives and config survive the box and a sync round trip',
      () async {
        for (final e in _sheet) {
          await saveEvaluative(e);
        }
        await saveConfig(CourseConfig(courseId: 'CS F372', classAverage: 23.8));
        expect(summaryFor('CS F372').secured.toStringAsFixed(2), '25.36');
        expect(classDeltas()['CS F372'], closeTo(1.56, 1e-9));

        final snap = Sync.snapshot(); // must not throw: JSON-safe only
        await Hive.box(marksBoxName).clear();
        expect(summaryFor('CS F372').evaluatives, isEmpty);
        await Sync.apply(snap);
        expect(summaryFor('CS F372').secured.toStringAsFixed(2), '25.36');
        expect(
          evaluativesFor('CS F372').map((e) => e.$2.name).first,
          'Assignment 0',
        );
        expect(evaluativesFor('CS F372')[2].$2.parts.first.date, '2026-09-08');

        // Grades for the compare-only profiles ride along too.
        final courses = Hive.box<Course>('coursesBox');
        await courses.put('x', _os.withGrade(4, 8));
        final withMore = Sync.snapshot();
        await courses.clear();
        await Sync.apply(withMore);
        expect(courses.get('x')!.gradeFor(4), 8);
        expect(courses.get('x')!.gradeFor(1), _os.grade1);
      },
    );

    Future<void> pump(
      WidgetTester t,
      Widget w,
      Size size, [
      double s = 1,
    ]) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: AppPalette.light.materialTheme,
          builder:
              (c, child) => MediaQuery(
                data: MediaQuery.of(
                  c,
                ).copyWith(textScaler: TextScaler.linear(s)),
                child: child!,
              ),
          home: w,
        ),
      );
      await t.pumpAndSettle();
    }

    testWidgets('the weight is the component\'s, not the course\'s', (t) async {
      await pump(
        t,
        const AddEvaluativePage(courseId: 'X', weighted: true, unassigned: 100),
        const Size(390, 844),
      );
      expect(find.text('Weight of the component'), findsOneWidget);
      expect(find.text('Weight of the course'), findsNothing);
    });

    testWidgets('a one-mark evaluative takes a date and reaches the calendar', (
      t,
    ) async {
      await pump(
        t,
        const AddEvaluativePage(courseId: 'X', weighted: true, unassigned: 100),
        const Size(390, 844),
      );
      final fields = find.byType(TextField);
      await t.enterText(fields.at(0), 'Quiz');
      await t.enterText(fields.at(1), '10');
      await t.enterText(fields.at(3), '20');
      await t.pump();
      expect(
        find.text('Give it a date to see it on the calendar.'),
        findsOneWidget,
      );
      await t.tap(find.text('Add a date'));
      await t.pumpAndSettle();
      await t.tap(find.text('OK'));
      await t.pumpAndSettle();
      final today = isoDate(DateTime.now());
      expect(find.text(shortDate(today)), findsOneWidget);

      await t.tap(find.byTooltip('Clear date'));
      await t.pump();
      expect(find.text('Add a date'), findsOneWidget);
      await t.tap(find.text('Add a date'));
      await t.pumpAndSettle();
      await t.tap(find.text('OK'));
      await t.pumpAndSettle();

      await t.ensureVisible(find.text('Save evaluative'));
      // The save writes to Hive, which needs real time.
      await t.runAsync(() async {
        await t.tap(find.text('Save evaluative'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await t.pumpAndSettle();
      final entries = calendarEntries(allEvaluatives());
      expect(entries.single.label, 'Quiz');
      expect(isoDate(entries.single.date), today);
    });

    testWidgets('each part of a several-part evaluative has a date field', (
      t,
    ) async {
      for (final (size, scale) in const [
        (Size(390, 844), 1.0),
        (Size(320, 640), 2.0),
      ]) {
        await pump(
          t,
          const AddEvaluativePage(
            courseId: 'X',
            weighted: true,
            unassigned: 100,
          ),
          size,
          scale,
        );
        await t.tap(find.text('Several parts'));
        await t.pumpAndSettle();
        final date = find.text('Date');
        await t.scrollUntilVisible(
          find.text('Part 2 name'),
          200,
          scrollable:
              find
                  .ancestor(
                    of: find.text('Several parts'),
                    matching: find.byType(Scrollable),
                  )
                  .first,
        );
        expect(t.takeException(), isNull, reason: '$size ×$scale');
        if (scale == 1) {
          expect(date, findsNWidgets(2));
          expect(find.text('Add a date'), findsNothing);
        }
      }
    });

    testWidgets('screens lay out at 320, 768, 1440 and 200% text', (t) async {
      await loadAppFonts();
      await t.runAsync(() async {
        for (final e in _sheet) {
          await saveEvaluative(e);
        }
        await saveConfig(CourseConfig(courseId: 'CS F372', classAverage: 23.8));
      });
      final (key, kernel) = evaluativesFor('CS F372')[1];
      for (final w in <Widget>[
        MarksPage(course: _os),
        AddEvaluativePage(
          courseId: 'CS F372',
          weighted: true,
          unassigned: 0,
          existing: kernel,
          existingKey: key,
        ),
        CourseSetupPage(course: _os),
      ]) {
        for (final size in const [
          Size(320, 640),
          Size(768, 1024),
          Size(1440, 900),
        ]) {
          await pump(t, w, size);
          expect(t.takeException(), isNull, reason: '${w.runtimeType} $size');
        }
        await pump(t, w, const Size(320, 640), 2);
        expect(t.takeException(), isNull, reason: '${w.runtimeType} 200%');
      }
      await pump(t, MarksPage(course: _os), const Size(390, 844));
      expect(find.text('25.36'), findsOneWidget);
      expect(find.text('1.56 ahead of the class'), findsOneWidget);
      expect(
        find.textContaining('DROPPED', findRichText: true),
        findsOneWidget,
      );
      final shots = Platform.environment['SHOTS_DIR'];
      if (shots != null) {
        for (final dark in [false, true]) {
          await pump(
            t,
            Theme(
              data: (dark ? AppPalette.dark : AppPalette.light).materialTheme,
              child: MarksPage(course: _os),
            ),
            const Size(390, 844),
          );
          await t.runAsync(() async {
            final img = await captureImage(
              t.element(find.byType(RepaintBoundary).first),
            );
            final png = await img.toByteData(format: ui.ImageByteFormat.png);
            File(
              '$shots/marks_${dark ? 'dark' : 'light'}.png',
            ).writeAsBytesSync(png!.buffer.asUint8List());
          });
        }
      }
    });
  });

  testWidgets('course row shows the delta in words, or nothing', (t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: AppPalette.light.materialTheme,
        home: Scaffold(
          body: Column(
            children: [
              CourseRow(
                course: _os,
                mode: SemesterMode.actual,
                classDelta: -4.2,
              ),
              CourseRow(course: _os, mode: SemesterMode.actual),
            ],
          ),
        ),
      ),
    );
    expect(find.text('4.20 behind'), findsOneWidget);
    expect(find.textContaining('ahead'), findsNothing);
  });
}
