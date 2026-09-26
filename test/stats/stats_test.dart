import 'dart:io';
import 'dart:ui' as ui;

import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/core/grading/cgpa.dart';
import 'package:cgpa_calculator/core/grading/forecast.dart';
import 'package:cgpa_calculator/core/grading/grade_scale.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/stats/stats_controller.dart';
import 'package:cgpa_calculator/features/stats/stats_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fonts.dart';
import '../helpers/transcript.dart';

final _shots = Platform.environment['SHOTS_DIR'];

var _n = 0;
Course _c(String sem, double cr, int g, [String el = 'CDC1']) => Course(
  title: '',
  id: 'C ${_n++}',
  credits: cr,
  grade1: g,
  grade2: GradeCode.clr,
  discipline: 'B3',
  sem: sem,
  elective: el,
);

// Small synthetic record: two graded semesters, one NC, two to come.
final _synthetic = [
  _c('1 - 1', 4, 10),
  _c('1 - 1', 4, 8),
  _c('1 - 2', 3, 9),
  _c('1 - 2', 3, GradeCode.nc, 'Open Elective'),
  _c('2 - 1', 4, GradeCode.clr),
  _c('2 - 2', 4, GradeCode.clr),
];

Future<void> _pump(
  WidgetTester t,
  StatsData d,
  StatsView v, {
  Size size = const Size(320, 640),
  double textScale = 1,
  AppPalette palette = AppPalette.light,
}) async {
  t.view.physicalSize = size * (_shots == null ? 1 : 2);
  t.view.devicePixelRatio = _shots == null ? 1 : 2;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    RepaintBoundary(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: palette.materialTheme,
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
        home: StatsScreen(
          data: d,
          view: v,
          onViewChanged: (_) {},
          onTargetChanged: (_) {},
          onPlanChanged: (_, _) {},
          onBack: () {},
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  group('forecast', () {
    test('required average is the exact formula', () {
      const done = GpaTally(
        points: 1195,
        gradedCredits: 155,
        shownCredits: 158,
      );
      final r = requiredAverage(target: 8, done: done, futureCredits: 68)!;
      expect(r.toStringAsFixed(2), '8.66');
      expect(requiredAverage(target: 8, done: done, futureCredits: 0), isNull);
    });

    test('an NC counts as outstanding until it is retaken', () {
      expect(remainingCredits(_synthetic, 'B3--'), 11);
      final retaken = [
        ..._synthetic,
        Course(
          title: '',
          id: _synthetic[3].id,
          credits: 3,
          grade1: 8,
          grade2: GradeCode.clr,
          discipline: 'B3',
          sem: '2 - 1',
          elective: 'Open Elective',
        ),
      ];
      expect(remainingCredits(retaken, 'B3--'), 8);
    });

    test('planned semesters move the CGPA as the tally would', () {
      final d = StatsData.from(
        all: _synthetic,
        discipline: 'B3--',
        target: 9,
        plan: {'2 - 1': 10, '2 - 2': 6},
      );
      // 99 points over 11 credits, then +40/4, then +24/4.
      expect(d.cgpa, 9);
      expect(d.planned.map((p) => p.cgpaAfter), [139 / 15, 163 / 19]);
      expect(d.finish, 163 / 19);
      expect(d.actual.last.cgpa, d.cgpa);
    });

    test(
      'real transcript: 8.66 over 68 credits, chart ends on the home CGPA',
      skip: transcriptSkip,
      () {
        final d = StatsData.from(
          all: loadTranscript(),
          discipline: 'B3A7',
          target: 8,
        );
        expect(d.remaining, 68);
        expect(d.required!.toStringAsFixed(2), '8.66');
        expect(d.actual.last.cgpa.toStringAsFixed(2), '7.71');
        expect(d.actual.last.cgpa, d.done.gpa);
        expect(d.audit.totalCredits + d.remaining, 226);
      },
    );
  });

  group('StatsScreen', () {
    final d = StatsData.from(all: _synthetic, discipline: 'B3A7', target: 9);

    testWidgets('progression shows the ask and the finish', (t) async {
      await _pump(t, d, StatsView.progression);
      expect(find.text('TO REACH 9.00'), findsOneWidget);
      await t.scrollUntilVisible(
        find.text('Plan the rest'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('CGPA', findRichText: true), findsWidgets);
    });

    testWidgets('degree shows requirement cards', (t) async {
      await _pump(t, d, StatsView.degree);
      expect(find.text('CREDITS EARNED'), findsOneWidget);
      expect(find.text('CDC (B3)'), findsOneWidget);
    });

    testWidgets('no overflow at 320, 768, 1440 or 200% text', (t) async {
      for (final v in StatsView.values) {
        for (final size in const [
          Size(320, 640),
          Size(768, 1024),
          Size(1440, 900),
        ]) {
          await _pump(t, d, v, size: size);
          expect(t.takeException(), isNull, reason: '$v $size');
        }
        await _pump(t, d, v, textScale: 2);
        expect(t.takeException(), isNull, reason: '$v 200%');
      }
    });
  });

  group('screenshots', skip: _shots == null || transcriptSkip != null, () {
    for (final palette in [AppPalette.light, AppPalette.dark]) {
      for (final v in StatsView.values) {
        testWidgets('stats ${palette.name} ${v.name}', (t) async {
          final real = StatsData.from(
            all: loadTranscript(),
            discipline: 'B3A7',
            target: 8,
          );
          await _pump(t, real, v, size: const Size(390, 844), palette: palette);
          await t.runAsync(() async {
            final img = await captureImage(
              t.element(find.byType(RepaintBoundary).first),
            );
            final png = await img.toByteData(format: ui.ImageByteFormat.png);
            File(
              '$_shots/stats_${palette.name.toLowerCase()}_${v.name}.png',
            ).writeAsBytesSync(png!.buffer.asUint8List());
          });
        });
      }
    }
  });
}
