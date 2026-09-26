import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/core/grading/cgpa.dart';
import 'package:cgpa_calculator/core/grading/grade_scale.dart';
import 'package:cgpa_calculator/core/models/elective.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/semester/add_course_controller.dart';
import 'package:cgpa_calculator/features/semester/add_course_sheet.dart';
import 'package:cgpa_calculator/features/semester/semester_controller.dart';
import 'package:cgpa_calculator/features/semester/widgets/course_row.dart';
import 'package:cgpa_calculator/features/semester/widgets/grade_scrubber.dart';
import 'package:cgpa_calculator/mastercourselist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _long = 'A' * 30 + ' ' + 'B' * 29; // 60 characters

final _master = [
  Mastercourselist(
    title: 'Principles of Aerodynamics',
    id: 'AN F311',
    credits: 3,
  ),
  Mastercourselist(title: 'Aerodynamics Lab', id: 'AN F312', credits: 1),
  Mastercourselist(title: 'Aerospace Propulsion', id: 'AN F341', credits: 3),
  Mastercourselist(title: _long, id: 'LONG F101', credits: 4),
];

Course _c(String id, int g, String sem, [String? title]) => Course(
  title: title ?? id,
  id: id,
  credits: 3,
  grade1: g,
  grade2: GradeCode.clr,
  discipline: 'A7',
  sem: sem,
  elective: 'CDCN',
);

final _held = [_c('AN F341', 9, '3 - 2'), _c('CS F372', 9, '4 - 1')];

Widget _app(Widget w) =>
    MaterialApp(theme: AppPalette.light.materialTheme, home: Scaffold(body: w));

void main() {
  test('search matches code or name and flags courses already held', () {
    final hits = searchCourses(
      'aero',
      held: _held,
      discipline: 'A7--',
      master: _master,
    );
    expect(hits.map((h) => h.id), ['AN F311', 'AN F312', 'AN F341']);
    expect(hits.last.heldIn, '3 - 2');
    expect(hits.first.heldIn, isNull);
    expect(
      searchCourses(
        'anf31',
        held: _held,
        discipline: 'A7--',
        master: _master,
      ).length,
      2,
    );
    expect(
      searchCourses('  ', held: _held, discipline: 'A7--', master: _master),
      isEmpty,
    );
  });

  test('category defaults follow the legacy rules', () {
    expect(categoryFor('HSS F222', 'A7--'), Elective.humanity.tag);
    expect(categoryFor('ZZZ F999', 'A7--'), Elective.open.tag);
    expect(categoryOptions('A7--'), isNot(contains(Elective.cdc2.tag)));
    expect(categoryLabel(Elective.cdc1.tag, 'A7--'), 'CDC (A7)');
  });

  test('SGPA change is before and after, via the one tally', () {
    final hit =
        searchCourses(
          'AN F311',
          held: _held,
          discipline: 'A7--',
          master: _master,
        ).first;
    final c = newCourse(
      hit,
      sem: '4 - 1',
      discipline: 'A7--',
      category: hit.category,
      profile: Profile.actual,
      grade: 10,
    );
    expect(c.discipline, 'A7');
    final (before, after) = sgpaChange(
      _held,
      c,
      sem: '4 - 1',
      discipline: 'A7--',
      profile: Profile.actual,
    );
    expect(before, 9.0);
    expect(after, 9.5);
  });

  testWidgets('grade chip opens the menu and never the row', (t) async {
    var rowTaps = 0;
    int? picked;
    await t.pumpWidget(
      _app(
        CourseRow(
          course: _held.last,
          mode: SemesterMode.actual,
          onTap: () => rowTaps++,
          onGradePicked: (g) => picked = g,
        ),
      ),
    );
    final chip = find.byType(GradeScrubber);
    expect(t.getSize(chip).height, greaterThanOrEqualTo(44));
    expect(t.getSize(chip).width, greaterThanOrEqualTo(44));
    await t.tap(chip);
    await t.pumpAndSettle();
    expect(rowTaps, 0);
    expect(find.text('Not graded yet'), findsOneWidget);
    expect(find.textContaining('leave the CGPA entirely'), findsNWidgets(2));
    await t.ensureVisible(find.text('GD'));
    await t.pumpAndSettle();
    await t.tap(find.text('GD'));
    await t.pumpAndSettle();
    expect(picked, GradeCode.gd);
    expect(rowTaps, 0);
    await t.tap(find.text('CS F372').first);
    expect(rowTaps, 1);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('60-character title ellipsizes at 320px, text ×$scale', (
      t,
    ) async {
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: AppPalette.light.materialTheme,
          builder:
              (c, child) => MediaQuery(
                data: MediaQuery.of(
                  c,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
          home: Scaffold(
            // The row, then the sheet at its real height: 88% of 640 less
            // the drag handle.
            body: ListView(
              children: [
                CourseRow(
                  course: _c('LONG F101', 10, '4 - 1', _long),
                  mode: SemesterMode.actual,
                ),
                SizedBox(
                  height: 515,
                  child: AddCourseSheet(
                    held: _held,
                    sem: '4 - 1',
                    discipline: 'A7--',
                    profile: Profile.actual,
                    onManual: () {},
                    master: _master,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await t.enterText(find.byType(TextField), 'long');
      await t.pump();
      await t.tap(find.text(_long).last);
      await t.pump();
      expect(t.takeException(), isNull);
      final texts = t.widgetList<Text>(find.text(_long)).toList();
      expect(texts.length, 3); // row, result, selected card
      expect(texts.every((x) => x.overflow == TextOverflow.ellipsis), isTrue);
      expect(
        find.textContaining('Add to 4 − 1', findRichText: true),
        findsOneWidget,
      );
    });
  }
}
