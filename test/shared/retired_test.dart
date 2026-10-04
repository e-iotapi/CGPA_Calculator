// SHOTS_DIR=/some/dir flutter test test/shared/retired_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/core/grading/grade_scale.dart';
import 'package:cgpa_calculator/core/models/course_names.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/semester/add_course_controller.dart';
import 'package:cgpa_calculator/features/semester/semester_controller.dart';
import 'package:cgpa_calculator/features/semester/widgets/course_row.dart';
import 'package:cgpa_calculator/features/stats/stats_controller.dart';
import 'package:cgpa_calculator/features/stats/stats_page.dart';
import 'package:cgpa_calculator/mastercourselist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fonts.dart';

final _shots = Platform.environment['SHOTS_DIR'];

Course _c(String id, String title, String el, [int g = 10]) => Course(
  title: title,
  id: id,
  credits: 3,
  grade1: g,
  grade2: GradeCode.clr,
  discipline: 'A7',
  sem: '2 - 1',
  elective: el,
);

final _os = _c('CS F372', 'Operating Systems', 'CDC2');
final _old = _c('XYZ F101', 'A Course Nobody Offers Any More', '');

Future<void> _shot(WidgetTester t, String name) async {
  if (_shots == null) return;
  await t.runAsync(() async {
    final img = await captureImage(
      t.element(find.byType(RepaintBoundary).first),
    );
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$_shots/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    if (_shots != null) await loadAppFonts();
  });
  setUp(() => retiredCourses.addAll(['CS F372', 'XYZ F101']));
  tearDown(retiredCourses.clear);

  test('matches the id as the course map spells it', () {
    retiredCourses
      ..clear()
      ..add('BITS F101');
    expect(isRetired('BITS F10l'), isTrue);
    expect(isRetired('BITS F111'), isFalse);
  });

  test('Add a course does not offer a retired course', () {
    final master = [
      Mastercourselist(title: 'Operating Systems', id: 'CS F372', credits: 4),
      Mastercourselist(title: 'Operating Theory', id: 'CS F373', credits: 3),
    ];
    final hits = searchCourses(
      'operating',
      held: const [],
      discipline: '--A7',
      master: master,
    );
    expect(hits.map((h) => h.id), ['CS F373']);
  });

  for (final palette in [AppPalette.light, AppPalette.dark]) {
    final theme = palette.name.toLowerCase();

    testWidgets('the semester row says Retired, $theme', (t) async {
      t.view.physicalSize = const Size(390, 200) * 2;
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        RepaintBoundary(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: palette.materialTheme,
            home: Scaffold(
              backgroundColor: palette.background,
              body: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    CourseRow(course: _os, mode: SemesterMode.actual),
                    const SizedBox(height: 8),
                    CourseRow(
                      course: _c('CS F301', 'Principles of Programming', ''),
                      mode: SemesterMode.actual,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Retired'), findsOneWidget);
      // Still graded and still counted: the chip is the grade, not a blank.
      expect(find.text('A'), findsNWidgets(2));
      await _shot(t, 'retired_row_$theme');
    });

    testWidgets('the Degree view says Retired, $theme', (t) async {
      t.view.physicalSize = const Size(390, 844) * 2;
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        RepaintBoundary(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: palette.materialTheme,
            home: StatsScreen(
              data: StatsData.from(all: [_os, _old], discipline: '--A7'),
              view: StatsView.degree,
              onViewChanged: (_) {},
              onTargetChanged: (_) {},
              onPlanChanged: (_, _) {},
              onBack: () {},
              onAssign: (_, _) async {},
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final scroll = find.byType(Scrollable).first;
      for (final label in ['A7 Core', 'Unassigned']) {
        await t.scrollUntilVisible(find.text(label), 200, scrollable: scroll);
        await Scrollable.ensureVisible(
          t.element(find.text(label)),
          alignment: 0.3,
        );
        await t.pumpAndSettle();
        await t.tap(find.text(label));
        await t.pumpAndSettle();
      }
      await _shot(t, 'retired_degree_$theme');
      expect(find.text('Retired'), findsNWidgets(2));
      expect(t.takeException(), isNull);
    });
  }
}
