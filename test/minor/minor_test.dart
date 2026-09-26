import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/core/grading/grade_scale.dart';
import 'package:cgpa_calculator/core/grading/minor_progress.dart';
import 'package:cgpa_calculator/core/models/course_graph.dart';
import 'package:cgpa_calculator/core/models/minors.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/offshoot/minor_panel.dart';
import 'package:cgpa_calculator/features/stats/stats_controller.dart';
import 'package:cgpa_calculator/features/stats/stats_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Course _c(
  String id,
  int g, {
  String el = 'Open Elective',
  double cr = 3,
  String d = 'B3',
}) => Course(
  title: id,
  id: id,
  credits: cr,
  grade1: g,
  grade2: GradeCode.clr,
  discipline: d,
  sem: '3 - 1',
  elective: el,
);

Minor _named(String name) => minorNamed(name)!;

void main() {
  group('course graph', () {
    test('joins codes cross-listed under one title', () {
      expect(courseGraph.same('BITS F493', 'ECON F355'), isTrue);
      expect(courseGraph.same('ECON F315', 'FIN F315'), isTrue);
      expect(
        courseGraph.canonical('BITS F493'),
        courseGraph.canonical('ECON F355'),
      );
      expect(courseGraph.neighbours('ECON F355'), isNotEmpty);
    });

    test('keeps each department\'s projects apart', () {
      expect(courseGraph.same('CS F376', 'ME F376'), isFalse);
      expect(courseGraph.same('CS F266', 'ECON F266'), isFalse);
    });

    test('reads a lowercase l as 1, and prefers the degree\'s code', () {
      expect(courseGraph.same('BITS F10l', 'BITS F101'), isTrue);
      expect(courseGraph.preferred('BITS F493', {'ECON'}), 'ECON F355');
      expect(courseGraph.preferred('BITS F493', {'CS'}), 'BITS F493');
    });

    test('a group is everything reachable, not only direct neighbours', () {
      final g = CourseGraph([('A F101', 'B F101'), ('B F101', 'C F101')]);
      expect(g.same('A F101', 'C F101'), isTrue);
      expect(g.neighbours('A F101'), {'B F101'});
      expect(g.linked('D F101'), {'D F101'});
    });
  });

  group('minors', () {
    test('all 23, each coherent', () {
      expect(minors, hasLength(23));
      final code = RegExp(r'^[A-Z]{2,5} [A-Z]\d{3}[A-Z]?$');
      for (final m in minors) {
        final ids = [...m.core, ...m.electiveSlots].expand((s) => s);
        expect(ids.every(code.hasMatch), isTrue, reason: m.name);
        expect(m.core.length + m.electives, lessThanOrEqualTo(m.courses + 1));
        expect(
          m.pools.fold(0, (s, p) => s + p.min),
          lessThanOrEqualTo(m.electives),
        );
      }
    });

    test('Computing and Intelligence is not open to CS', () {
      final m = _named('Computing and Intelligence');
      expect(minorOpenTo(m, '--A7'), isFalse);
      expect(minorOpenTo(m, 'B3A7'), isFalse);
      expect(minorOpenTo(m, 'B3A3'), isTrue);
    });
  });

  group('minorProgress', () {
    test('counts cross-listed codes, and completes', () {
      final all = [
        _c('ECON F212', 9, el: 'CDC1'),
        // FIN F315 taken as ECON F315.
        _c('ECON F315', 10, el: 'Disciplinary Elective1'),
        _c('FIN F414', 10, el: 'Disciplinary Elective1'),
        // FIN F313 as ECON F412, FIN F311 as ECON F354.
        _c('ECON F412', 7, el: 'Disciplinary Elective1'),
        _c('ECON F354', 8, el: 'Disciplinary Elective1'),
      ];
      final pr = minorProgress(_named('Finance'), all, 'B3A7');
      expect(pr.coreDone, 2);
      expect(pr.electivesDone, 3);
      expect((pr.courses, pr.units), (5, 15.0));
      expect(pr.core.first.overlap, isTrue, reason: 'ECON F212 is B3 core');
      expect(pr.gpa, closeTo(44 / 5, 1e-9));
      expect(pr.complete, isTrue);
    });

    test('an ungraded course is planned, a missing one missing', () {
      final pr = minorProgress(_named('Data Science'), [
        _c('BITS F464', GradeCode.clr),
      ], '--A7');
      expect(pr.core[0].state, MinorState.planned);
      expect(pr.core[1].state, MinorState.missing);
      expect(pr.courses, 0);
      expect(pr.complete, isFalse);
    });

    test('at most two of the degree\'s own courses count', () {
      final all = [
        for (final id in ['BITS F464', 'CS F320', 'MATH F432'])
          _c(id, 8, el: 'CDC2', d: 'A7'),
      ];
      final pr = minorProgress(_named('Data Science'), all, '--A7');
      expect(pr.overlapDropped, 1);
      expect(pr.courses, 2);
    });

    test('only one project counts', () {
      final all = [
        _c('BIO F216', 8),
        _c('BIO F217', 8),
        _c('BIO F266', 9),
        // Not a project: counts.
        _c('SAN G511', 8, cr: 5),
      ];
      final m = Minor(
        name: 'Test',
        courses: 4,
        units: 12,
        core: _named('Water and Sanitation').core,
        pools: _named('Water and Sanitation').pools,
        projects: {'BIO F266', 'SAN G511'},
      );
      final pr = minorProgress(m, all, '--A7');
      expect(pr.projectsDropped, 1);
      expect(pr.courses, 3);
    });
  });

  group('screens', () {
    Future<void> pump(WidgetTester t, Widget child) async {
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: AppPalette.light.materialTheme,
          home: Scaffold(body: child),
        ),
      );
      await t.pumpAndSettle();
    }

    testWidgets('with no minor, the list; a tap chooses', (t) async {
      Minor? chosen;
      await pump(
        t,
        MinorPanel(
          progress: null,
          discipline: '--A7',
          onChoose: (m) => chosen = m,
        ),
      );
      expect(find.text('Aeronautics'), findsOneWidget);
      await t.tap(find.text('Aeronautics'));
      expect(chosen?.name, 'Aeronautics');
      await t.scrollUntilVisible(find.text('Computing and Intelligence'), 200);
      expect(find.text('Not open to your degree'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('with one, its courses and where each stands', (t) async {
      final pr = minorProgress(_named('Finance'), [
        _c('ECON F212', 9, el: 'CDC1'),
      ], 'B3A7');
      await pump(
        t,
        MinorPanel(progress: pr, discipline: 'B3A7', onChoose: (_) {}),
      );
      expect(find.text('Finance'), findsOneWidget);
      expect(find.text('ECON F212'), findsOneWidget);
      expect(find.textContaining('1 of 5 courses'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('the switch moves between offshoot and minor', (t) async {
      bool? saved;
      await pump(
        t,
        OffshootTab(
          showMinor: false,
          onShowMinor: (v) => saved = v,
          offshoot: const Text('offshoot view'),
          minor: const Text('minor view'),
        ),
      );
      expect(find.text('offshoot view'), findsOneWidget);
      await t.tap(find.text('Minor'));
      await t.pump();
      expect(find.text('minor view'), findsOneWidget);
      expect(saved, isTrue);
    });

    testWidgets('the Degree page shows a Minor tab only with a minor', (
      t,
    ) async {
      final data = StatsData.from(all: const [], discipline: 'B3A7');
      Widget screen(MinorProgress? minor, StatsView view) => StatsScreen(
        data: data,
        view: view,
        onViewChanged: (_) {},
        onTargetChanged: (_) {},
        onPlanChanged: (_, _) {},
        onBack: () {},
        minor: minor,
      );
      await pump(t, screen(null, StatsView.minor));
      expect(find.text('Minor'), findsNothing);
      expect(find.text('Degree progress'), findsOneWidget);

      final pr = minorProgress(_named('Finance'), const [], 'B3A7');
      await pump(t, screen(pr, StatsView.minor));
      expect(find.text('Minor'), findsOneWidget);
      expect(find.text('Minor requirements'), findsOneWidget);
      expect(find.text('Core courses'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });
}
