import 'dart:io';
import 'dart:ui' as ui;

import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/core/grading/cgpa.dart';
import 'package:cgpa_calculator/core/grading/forecast.dart';
import 'package:cgpa_calculator/core/grading/grade_scale.dart';
import 'package:cgpa_calculator/core/grading/requirements.dart';
import 'package:cgpa_calculator/core/models/elective.dart';
import 'package:cgpa_calculator/core/storage/courses.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/stats/stats_controller.dart';
import 'package:cgpa_calculator/features/stats/stats_page.dart';
import 'package:cgpa_calculator/features/stats/widgets/degree_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

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
  VoidCallback? onEditTotal,
  AssignCourse? onAssign,
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
          onAssign: onAssign,
          onEditTotal: onEditTotal,
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

    test('a total set by hand decides what is left', () {
      final set = StatsData.from(
        all: _synthetic,
        discipline: 'B3A7',
        totalSet: 50,
      );
      expect(set.degreeLeft, 50 - set.audit.totalCredits);
      final low = StatsData.from(
        all: _synthetic,
        discipline: 'B3A7',
        totalSet: 1,
      );
      expect(low.degreeLeft, 0);
    });

    testWidgets('the credits card opens the total, and says it was set', (
      t,
    ) async {
      var taps = 0;
      final set = StatsData.from(
        all: _synthetic,
        discipline: 'B3A7',
        totalSet: 50,
      );
      await _pump(t, set, StatsView.degree, onEditTotal: () => taps++);
      expect(find.text('of 50'), findsOneWidget);
      expect(find.textContaining('total set by you'), findsOneWidget);
      await t.tap(find.text('CREDITS EARNED'));
      expect(taps, 1);
    });

    group('Ongoing and Unassigned', () {
      Course c(String id, int g, String tag, {double cr = 3}) => Course(
        title: id,
        id: id,
        credits: cr,
        grade1: g,
        grade2: GradeCode.clr,
        discipline: 'A7',
        sem: '3 - 1',
        elective: tag,
      );
      final all = [
        c('CS F211', 9, 'CDC2', cr: 4),
        c('CS F212', GradeCode.ongoing, 'CDC2', cr: 4),
        // Common core: no tag, and not unassigned.
        c('MATH F111', 8, 'CDCN'),
        c('BITS F111', 8, 'CDCN'),
        // Added by hand with no category.
        c('XYZ F101', 7, 'CDCN', cr: 2),
      ];
      final d = StatsData.from(all: all, discipline: '--A7');

      test('Ongoing counts for the degree, never the CGPA', () {
        expect(tally(all, Profile.actual).gradedCredits, 4 + 3 + 3 + 2);
        expect(d.audit.ongoingCredits, 4);
        expect(d.audit.totalCredits, 4 + 4 + 3 + 3 + 2);
        final core = d.audit.categories.firstWhere(
          (a) => a.label == 'CDC (A7)',
        );
        // Its own core, and the common courses as the first degree's.
        expect(core.credits, 14);
        expect(core.members.map((m) => m.id), [
          'CS F211',
          'CS F212',
          'MATH F111',
          'BITS F111',
        ]);
        // Still to be graded, for the CGPA forecast.
        expect(outstandingCourses(all, '--A7').map((m) => m.id), ['CS F212']);
      });

      test('a course in no requirement lands in Unassigned', () {
        expect(d.audit.unassigned.map((m) => m.id), ['XYZ F101']);
      });

      testWidgets('requirements open to their courses and reassign', (t) async {
        final moved = <(String, String)>[];
        await _pump(
          t,
          d,
          StatsView.degree,
          size: const Size(390, 844),
          onAssign: (course, tag) async => moved.add((course.id, tag)),
        );
        expect(
          find.textContaining('4 of these credits are ongoing'),
          findsOneWidget,
        );
        final scroll = find.byType(Scrollable).first;
        await t.scrollUntilVisible(
          find.text('CDC (A7)'),
          200,
          scrollable: scroll,
        );
        await t.tap(find.text('CDC (A7)'));
        await t.pumpAndSettle();
        expect(
          find.textContaining('CS F212', findRichText: true),
          findsWidgets,
        );
        await t.scrollUntilVisible(
          find.text('Unassigned'),
          200,
          scrollable: scroll,
        );
        await Scrollable.ensureVisible(
          t.element(find.text('Unassigned')),
          alignment: 0.5,
        );
        await t.pumpAndSettle();
        await t.tap(find.text('Unassigned'));
        await t.pumpAndSettle();
        final field = find.bySemanticsLabel(RegExp('^Counts as')).last;
        // Mid-screen, clear of the pinned footer.
        await Scrollable.ensureVisible(t.element(field), alignment: 0.5);
        await t.pumpAndSettle();
        await t.tap(field);
        await t.pumpAndSettle();
        await t.tap(find.text('Open Elective').last);
        await t.pumpAndSettle();
        expect(moved, [('XYZ F101', 'Open Elective')]);
        expect(t.takeException(), isNull);
      });

      test('common courses count as the first degree\'s core', () {
        final dual = StatsData.from(
          all: [
            for (final m in all)
              Course(
                title: m.title,
                id: m.id,
                credits: m.credits,
                grade1: m.grade1,
                grade2: m.grade2,
                discipline: m.id.startsWith('CS') ? 'A7' : 'B3',
                sem: m.sem,
                elective: m.elective,
              ),
          ],
          discipline: 'B3A7',
        );
        final b3 = dual.audit.categories.firstWhere(
          (a) => a.label == 'CDC (B3)',
        );
        expect(b3.members.map((m) => m.id), ['MATH F111', 'BITS F111']);
        final a7 = d.audit.categories.firstWhere((a) => a.label == 'CDC (A7)');
        expect(a7.members.map((m) => m.id), containsAll(['MATH F111']));
      });

      test('no bucket when every course has a home', () {
        final clean = StatsData.from(
          all: all.where((m) => m.id != 'XYZ F101').toList(),
          discipline: '--A7',
        );
        expect(clean.audit.unassigned, isEmpty);
      });
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

  group('reassigning on the Degree page', () {
    late Directory dir;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('hive_assign');
      Hive.init(dir.path);
      if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(CourseAdapter());
      await Hive.openBox('settingsBox');
      final box = await Hive.openBox<Course>(coursesBoxName);
      Course c(String id, String tag) => Course(
        title: id,
        id: id,
        credits: 3,
        grade1: 8,
        grade2: GradeCode.clr,
        discipline: 'A7',
        sem: '3 - 1',
        elective: tag,
      );
      // Taken as a DEL, but another department's: the rules say OPEL.
      await box.add(c('EEE F311', 'Disciplinary Elective2'));
      await box.add(c('XYZ F101', 'CDCN'));
      pinnedCategories = {};
    });
    tearDown(() async {
      await Hive.deleteFromDisk();
      await dir.delete(recursive: true);
      pinnedCategories = {};
    });

    List<String> idsIn(String label) => [
      for (final a in degreeAudit(allCourses(), '--A7').categories)
        if (a.label == label) ...a.members.map((m) => m.id),
    ];

    test('a category set by hand stays where it was put', () async {
      expect(idsIn('Open Electives'), ['EEE F311']);
      final eee = allCourses().firstWhere((m) => m.id == 'EEE F311');
      await setCourseCategory(eee, Elective.del2.tag);
      expect(idsIn('Disciplinary Electives (A7)'), ['EEE F311']);
      expect(idsIn('Open Electives'), isEmpty);
      // Survives a reload of the settings.
      pinnedCategories = {};
      loadPinnedCategories(Hive.box('settingsBox'));
      expect(idsIn('Disciplinary Electives (A7)'), ['EEE F311']);
    });

    testWidgets('the Unassigned course moves once assigned', (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      // Courses in memory: this checks the page rebuilds with the course
      // in its new place; the test above checks what is stored.
      var courses = allCourses().toList();
      await t.pumpWidget(
        MaterialApp(
          theme: AppPalette.light.materialTheme,
          home: StatefulBuilder(
            builder:
                (context, setState) => StatsScreen(
                  data: StatsData.from(all: courses, discipline: '--A7'),
                  view: StatsView.degree,
                  onViewChanged: (_) {},
                  onTargetChanged: (_) {},
                  onPlanChanged: (_, _) {},
                  onBack: () {},
                  onAssign: (course, tag) async {
                    pinnedCategories = {...pinnedCategories, course.id};
                    setState(
                      () =>
                          courses = [
                            for (final m in courses)
                              m == course ? m.copyWith(elective: tag) : m,
                          ],
                    );
                  },
                ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final scroll = find.byType(Scrollable).first;
      await t.scrollUntilVisible(
        find.text('Unassigned'),
        200,
        scrollable: scroll,
      );
      await Scrollable.ensureVisible(
        t.element(find.text('Unassigned')),
        alignment: 0.5,
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Unassigned'));
      await t.pumpAndSettle();
      final field = find.bySemanticsLabel(RegExp('^Counts as')).last;
      await Scrollable.ensureVisible(t.element(field), alignment: 0.5);
      await t.pumpAndSettle();
      await t.tap(field);
      await t.pumpAndSettle();
      await t.tap(find.text('Open Elective').last);
      await t.pumpAndSettle();
      expect(find.text('Unassigned'), findsNothing);
      await t.tap(find.text('Open Electives'));
      await t.pumpAndSettle();
      expect(find.textContaining('XYZ F101', findRichText: true), findsWidgets);
    });
  });
}
