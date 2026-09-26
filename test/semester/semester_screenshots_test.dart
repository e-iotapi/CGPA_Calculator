// SHOTS_DIR=/some/dir flutter test test/semester/semester_screenshots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/core/grading/grade_scale.dart';
import 'package:cgpa_calculator/core/grading/offshoot.dart';
import 'package:cgpa_calculator/core/models/semesters.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/offshoot/offshoot_panel.dart';
import 'package:cgpa_calculator/features/semester/semester_controller.dart';
import 'package:cgpa_calculator/features/semester/semester_page.dart';
import 'package:cgpa_calculator/shared/layout/responsive.dart';
import 'package:cgpa_calculator/shared/widgets/app_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fonts.dart';

final _out = Platform.environment['SHOTS_DIR'];

Course _c(String t, String id, double cr, int g1, [int g2 = GradeCode.clr]) =>
    Course(
      title: t,
      id: id,
      credits: cr,
      grade1: g1,
      grade2: g2,
      discipline: 'B3',
      sem: '4 - 1',
      elective: 'CDC',
    );

final _courses = [
  _c('Principles of Programming Languages', 'CS F301', 2, 7, 8),
  _c('Business Analysis and Valuation', 'BITS F493', 3, 10, 10),
  _c('Theory of Computation', 'CS F351', 3, 8, 9),
  _c('Operating Systems', 'CS F372', 4, 10),
  _c(
    'Financial Risk Analytics and Modelling for Derivative Markets',
    'FIN F414',
    3,
    9,
  ),
  _c('Technical Report Writing', 'BITS F112', 2, GradeCode.clr),
];

// A, A, A, A-, B, B-: 47 / 50 with ECON F412 dropped.
final _offshoot = OffshootScore([
  for (final (i, c) in offshootCourses.indexed)
    OffshootRow(c, const [9, 10, 8, 7, 10, 10][i], false),
], 50);

void main() {
  setUpAll(() async {
    if (_out != null) await loadAppFonts();
  });
  for (final palette in [AppPalette.light, AppPalette.dark]) {
    for (final mode in [
      SemesterMode.actual,
      SemesterMode.compare,
      SemesterMode.offshoot,
    ]) {
      for (final (name, size) in const [
        ('320', Size(320, 640)),
        ('768', Size(768, 1024)),
        ('1440', Size(1440, 900)),
      ]) {
        testWidgets('${palette.name} ${mode.name} $name', skip: _out == null, (
          t,
        ) async {
          t.view.physicalSize = size * 2;
          t.view.devicePixelRatio = 2;
          addTearDown(t.view.reset);
          await t.pumpWidget(
            RepaintBoundary(
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: palette.materialTheme,
                home: ResponsiveScaffold(
                  destinations: const [
                    NavDestination(icon: Icons.home_outlined, label: 'Actual'),
                    NavDestination(
                      icon: Icons.bar_chart_rounded,
                      label: 'Expected',
                    ),
                    NavDestination(
                      icon: Icons.compare_arrows_rounded,
                      label: 'Compare',
                    ),
                    NavDestination(
                      icon: Icons.workspace_premium_outlined,
                      label: 'Offshoot',
                    ),
                  ],
                  selectedIndex: mode.index,
                  onSelected: (_) {},
                  body: SemesterView(
                    data: SemesterData.from(
                      allCourses: _courses,
                      visible: _courses,
                      sem: '4 - 1',
                      semesters: semestersFor('B3A7'),
                      discipline: 'B3A7',
                      mode: mode,
                      sort: CourseSort.creditsAsc,
                      profileNames: ('Actual', 'Expected'),
                    ),
                    greeting: 'Good evening',
                    name: 'Siddharth',
                    onSemesterSelected: (_) {},
                    onSortSelected: (_) {},
                    onExport: () {},
                    onAddCourse: () {},
                    onCourseTap: (_, _) {},
                    onGradePicked: (_, _) {},
                    onClearRequested: () {},
                    onSwipe: (_) {},
                    onOpenAnalytics: () {},
                    onOpenCalendar: () {},
                    onOpenSettings: () {},
                    onToggleTheme: () {},
                    offshoot:
                        mode == SemesterMode.offshoot
                            ? OffshootPanel(
                              score: _offshoot,
                              onToggleCourse: (_) {},
                              onOutOfSelected: (_) {},
                            )
                            : null,
                  ),
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
          await t.runAsync(() async {
            final img = await captureImage(
              t.element(find.byType(RepaintBoundary).first),
            );
            final png = await img.toByteData(format: ui.ImageByteFormat.png);
            File(
              '$_out/sem_${palette.name.toLowerCase()}_${mode.name}_$name.png',
            ).writeAsBytesSync(png!.buffer.asUint8List());
          });
        });
      }
    }
  }
}
