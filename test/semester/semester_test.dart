import 'dart:io';

import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/core/grading/grade_scale.dart';
import 'package:cgpa_calculator/core/models/semesters.dart';
import 'package:cgpa_calculator/core/storage/courses.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/semester/semester_controller.dart';
import 'package:cgpa_calculator/features/semester/semester_page.dart';
import 'package:cgpa_calculator/shared/widgets/grade_chip.dart';
import 'package:cgpa_calculator/shared/widgets/stat_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import '../helpers/fonts.dart';

Course _c(
  String title,
  String id,
  double credits,
  int g1, {
  int g2 = GradeCode.clr,
  String sem = '4 - 1',
}) => Course(
  title: title,
  id: id,
  credits: credits,
  grade1: g1,
  grade2: g2,
  discipline: 'B3',
  sem: sem,
  elective: 'CDC',
);

final _courses = [
  _c(
    'Principles of Programming Languages and Compiler Construction With A '
        'Very Long Subtitle',
    'CS F301',
    2,
    7,
  ),
  _c('Business Analysis and Valuation', 'BITS F493', 3, 10, g2: 9),
  _c('Theory of Computation', 'CS F351', 3, 8),
  _c('Operating Systems', 'CS F372', 4, GradeCode.clr),
  _c('Older course', 'CS F211', 4, 6, sem: '2 - 1'),
];

SemesterData _data(SemesterMode mode, {String sem = '4 - 1'}) =>
    SemesterData.from(
      allCourses: _courses,
      visible: _courses.where((c) => c.sem == sem).toList(),
      sem: sem,
      semesters: semestersFor('B3A7'),
      discipline: 'B3A7',
      mode: mode,
      sort: CourseSort.creditsAsc,
      profileNames: ('Actual', 'Expected'),
    );

Future<void> _pump(
  WidgetTester t,
  SemesterData data, {
  Size size = const Size(320, 640),
  double textScale = 1,
  void Function(Course, int)? onTap,
  VoidCallback? onAdd,
  Widget? offshoot,
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
        body: SemesterView(
          data: data,
          greeting: 'Good evening',
          name: 'Siddharth',
          onSemesterSelected: (_) {},
          onSortSelected: (_) {},
          onExport: () {},
          onAddCourse: onAdd ?? () {},
          onCourseTap: onTap ?? (_, _) {},
          onGradePicked: (_, _) {},
          onClearRequested: () {},
          onSwipe: (_) {},
          onOpenAnalytics: () {},
          onOpenSettings: () {},
          onInstall: () {},
          offshoot: offshoot,
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

/// The page's vertical scrollable, not the semester pill strip.
final _page =
    find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first;

void main() {
  setUpAll(loadAppFonts);

  group('SemesterData', () {
    test('figures come from core/grading, rounded as the home screen was', () {
      final d = _data(SemesterMode.actual);
      // 4-1: 2×7 + 3×10 + 3×8 = 68 over 8 graded credits; OS ungraded.
      expect(formatGpa(d.current.term), '8.50');
      expect(formatCredits(d.current.term.shownCredits), '8');
      // Overall adds 2-1's 4 credits at 6: 92 / 12.
      expect(formatGpa(d.current.overall), '7.67');
    });

    test('editorial states the gap to the running CGPA', () {
      expect(
        _data(SemesterMode.actual).editorial,
        'This semester you are 0.83 above your running CGPA.',
      );
      expect(_data(SemesterMode.actual).editorialEmphasis, '0.83 above');
      expect(
        _data(SemesterMode.actual, sem: '4 - 2').editorial,
        'Nothing graded in 4 - 2 yet.',
      );
      expect(
        _data(SemesterMode.compare).editorial,
        'Comparing Actual and Expected grades',
      );
    });

    test('semester list gains the fifth year for dual degrees only', () {
      expect(semestersFor('B3A7'), contains('5 - 2'));
      expect(semestersFor('A7'), isNot(contains('ST 2')));
      expect(semestersFor('A7'), baseSemesters);
    });

    test('credits and GPA formatting', () {
      expect(formatCredits(0.5), '0.5');
      expect(formatCredits(24), '24');
    });
  });

  group('SemesterView', () {
    testWidgets('320px: long title ellipsizes, grade chip stays on screen', (
      t,
    ) async {
      await _pump(t, _data(SemesterMode.actual));
      expect(t.takeException(), isNull);
      final title = find.textContaining('Principles of Programming');
      expect(t.renderObject<RenderParagraph>(title).didExceedMaxLines, isTrue);
      final chip = find.byType(GradeChip).first;
      expect(t.getRect(chip).right, lessThanOrEqualTo(320 - 20 + 0.5));
      expect(find.text('B-'), findsOneWidget);
    });

    testWidgets('stat cards show SGPA and CGPA side by side on a phone', (
      t,
    ) async {
      await _pump(t, _data(SemesterMode.actual));
      expect(find.text('8.50'), findsOneWidget);
      expect(find.text('7.67'), findsOneWidget);
      final cards = find.byType(StatCard);
      expect(t.getRect(cards.at(0)).top, t.getRect(cards.at(1)).top);
    });

    testWidgets('768px: stat cards move into a right rail', (t) async {
      await _pump(t, _data(SemesterMode.actual), size: const Size(768, 1024));
      expect(t.takeException(), isNull);
      final cards = find.byType(StatCard);
      expect(t.getRect(cards.at(0)).left, greaterThan(768 - 280));
      expect(
        t.getRect(cards.at(1)).top,
        greaterThan(t.getRect(cards.at(0)).bottom),
      );
    });

    testWidgets('ungraded course shows a muted dash, not "CLR"', (t) async {
      await _pump(t, _data(SemesterMode.actual));
      await t.scrollUntilVisible(
        find.text('Operating Systems'),
        200,
        scrollable: _page,
      );
      expect(find.text('CLR'), findsNothing);
      final dash = find.widgetWithText(GradeChip, '–');
      expect(dash, findsOneWidget);
      expect(
        t.getSemantics(dash).getSemanticsData().label,
        contains('No grade'),
      );
    });

    testWidgets('compare shows both grades and no sort/export', (t) async {
      await _pump(t, _data(SemesterMode.compare));
      expect(t.takeException(), isNull);
      expect(find.text('A'), findsOneWidget); // Actual
      expect(find.text('A-'), findsOneWidget); // Expected
      expect(find.bySemanticsLabel('Export gradesheet'), findsNothing);
      expect(find.text('Add courses'), findsNothing);
    });

    testWidgets('offshoot tab shows the supplied panel instead of the list', (
      t,
    ) async {
      await _pump(
        t,
        _data(SemesterMode.offshoot),
        offshoot: const Expanded(child: Text('offshoot panel')),
      );
      expect(find.text('offshoot panel'), findsOneWidget);
      expect(find.byType(StatCard), findsNothing);
    });

    testWidgets('tapping a row reports the course and its index', (t) async {
      final taps = <(String, int)>[];
      await _pump(
        t,
        _data(SemesterMode.actual),
        onTap: (c, i) => taps.add((c.id, i)),
      );
      await t.tap(find.text('Theory of Computation'));
      expect(taps, [('CS F351', 2)]);
    });

    testWidgets('add card is reachable and fires', (t) async {
      var adds = 0;
      await _pump(t, _data(SemesterMode.actual), onAdd: () => adds++);
      await t.scrollUntilVisible(
        find.text('Add courses'),
        200,
        scrollable: _page,
      );
      await t.tap(find.text('Add courses'));
      expect(adds, 1);
    });

    testWidgets('no overflow at 320, 768, 1440 or 200% text', (t) async {
      for (final mode in [SemesterMode.actual, SemesterMode.compare]) {
        for (final size in const [
          Size(320, 640),
          Size(768, 1024),
          Size(1440, 900),
        ]) {
          await _pump(t, _data(mode), size: size);
          expect(t.takeException(), isNull, reason: '$mode $size');
        }
        await _pump(t, _data(mode), textScale: 2);
        expect(t.takeException(), isNull, reason: '$mode 200%');
      }
    });
  });

  group('saveCourse', () {
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

    test('writes back under an int key instead of duplicating', () async {
      final box = Hive.box<Course>(coursesBoxName);
      await box.add(_courses[2]); // int key, as addCourse does
      await box.put(_courses[1].id, _courses[1]); // id key, as seeding does
      await saveCourse(withGrade(_courses[2], 1, 10));
      await saveCourse(withGrade(_courses[1], 2, 4));
      expect(box.length, 2);
      expect(box.values.firstWhere((c) => c.id == 'CS F351').grade1, 10);
      expect(box.values.firstWhere((c) => c.id == 'BITS F493').grade2, 4);
      expect(box.values.firstWhere((c) => c.id == 'BITS F493').grade1, 10);
    });

    test('a course not yet stored is keyed by its id', () async {
      await saveCourse(_courses[0]);
      expect(Hive.box<Course>(coursesBoxName).get('CS F301'), isNotNull);
    });
  });
}
