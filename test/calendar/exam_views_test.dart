import 'dart:io';

import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/core/models/marks.dart';
import 'package:cgpa_calculator/core/storage/marks.dart';
import 'package:cgpa_calculator/core/timetable/calendar_store.dart';
import 'package:cgpa_calculator/core/timetable/occurrences.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/calendar/calendar_controller.dart';
import 'package:cgpa_calculator/features/calendar/calendar_page.dart';
import 'package:cgpa_calculator/sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import '../helpers/fake_timetable.dart';

// Mon 12 Oct 2026 is AAA F111's published midsem (9:30-11:00).
final _now = DateTime(2026, 10, 12, 8);
const _aaa = 'AAA F111';

Evaluative _marks() => Evaluative(
  courseId: _aaa,
  name: 'Tests',
  weight: 30,
  parts: [
    EvalPart(name: 'Midsem', outOf: 90, date: '2026-10-12'),
    EvalPart(name: 'Quiz 1', outOf: 10, date: '2026-10-14'),
  ],
);

Evaluative _other() => Evaluative(
  courseId: 'ZZZ F999',
  name: 'Midsem',
  weight: 30,
  parts: [EvalPart(name: 'Midsem', outOf: 90, date: '2026-10-12')],
);

CalendarEntry _entry(String course, String label, String date) => CalendarEntry(
  date: DateTime.parse(date),
  label: label,
  courseId: course,
  weight: 10,
  graded: false,
);

void main() {
  group('marksInSpan', () {
    final t = fakeTimetable();
    const s = CalendarState();
    List<Occurrence> occs(CalendarState st) =>
        expandOccurrences(t, st, from: '2026-10-12', to: '2026-10-18');

    test('a published exam on the same date hides the all-day duplicate', () {
      final st = s.copy(
        picks: {
          _aaa: ['$_aaa|L1'],
        },
      );
      final r = marksInSpan(
        t,
        st,
        [
          _entry(_aaa, 'Midsem', '2026-10-12'),
          _entry(_aaa, 'Quiz 1', '2026-10-14'),
        ],
        occs(st),
        from: '2026-10-12',
        to: '2026-10-18',
      );
      expect(r.allDay.map((e) => e.label), ['Quiz 1']);
      expect(r.timed, isEmpty);
    });

    test(
      'a course not in my timetable still shows its published exam, once',
      () {
        final o = occs(s);
        expect(o.where((x) => x.kind == OccKind.midsem), isEmpty);
        final r = marksInSpan(
          t,
          s,
          [_entry(_aaa, 'Midsem', '2026-10-12')],
          o,
          from: '2026-10-12',
          to: '2026-10-18',
        );
        expect(r.allDay, isEmpty);
        expect(r.timed.single.kind, OccKind.midsem);
        expect((r.timed.single.start, r.timed.single.end), (570, 660));
      },
    );

    test(
      'other dates and other courses stay all-day; the span bounds apply',
      () {
        final r = marksInSpan(
          t,
          s,
          [
            _entry('ZZZ F999', 'Midsem', '2026-10-12'),
            _entry(_aaa, 'Quiz 1', '2026-10-14'),
            _entry(_aaa, 'Quiz 2', '2026-10-25'),
          ],
          const [],
          from: '2026-10-12',
          to: '2026-10-18',
        );
        expect(r.allDay.map((e) => e.label), ['Midsem', 'Quiz 1']);
        expect(r.timed, isEmpty);
      },
    );

    test('a time the student gave makes a timed mark block', () {
      final st = s.copy(
        markTimes: {
          markKey('ZZZ F999', 'Midsem', '2026-10-12'): (s: 600, e: 660),
        },
      );
      final r = marksInSpan(
        t,
        st,
        [
          _entry('ZZZ F999', 'Midsem', '2026-10-12'),
          _entry(_aaa, 'Quiz 1', '2026-10-14'),
        ],
        const [],
        from: '2026-10-12',
        to: '2026-10-18',
      );
      expect(r.allDay.map((e) => e.label), ['Quiz 1']);
      final m = r.timed.single;
      expect(
        (m.kind, m.courseId, m.title, m.start, m.end),
        (OccKind.mark, 'ZZZ F999', 'Midsem', 600, 660),
      );
    });

    test('hidden exams of a course are not brought back by Marks', () {
      final st = s.copy(examsOff: {_aaa});
      final r = marksInSpan(
        t,
        st,
        [_entry(_aaa, 'Midsem', '2026-10-12')],
        const [],
        from: '2026-10-12',
        to: '2026-10-18',
      );
      expect(r.timed, isEmpty);
      expect(r.allDay, hasLength(1));
    });
  });

  test('a mark time round-trips through the store and clears', () async {
    final box = MemBox();
    final cal = CalendarStore(box, profile: 1);
    await cal.adopt('goa', '2026-1');
    final k = markKey('ZZZ F999', 'Midsem', '2026-10-12');
    await cal.setMarkTime(k, s: 600, e: 660);
    expect(CalendarStore(box, profile: 1).state.markTimes[k], (s: 600, e: 660));
    await expectLater(cal.setMarkTime(k, s: 700, e: 650), throwsStateError);
    await cal.clearMarkTime(k);
    expect(CalendarStore(box, profile: 1).state.markTimes, isEmpty);
  });

  group('Week', () {
    late MemBox box;
    late CalendarStore cal;
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('hive_exam');
      Hive.init(dir.path);
      if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(CourseAdapter());
      registerMarksAdapters();
      await Sync.openBoxes();
      box = MemBox();
      cal = CalendarStore(box, profile: 1);
      await cal.adopt('goa', '2026-1');
      await cal.addCourse(fakeTimetable().courses[_aaa]!, [
        '$_aaa|L1',
        '$_aaa|T1',
      ]);
    });
    tearDown(() async {
      await Hive.deleteFromDisk();
      await dir.delete(recursive: true);
    });

    Future<void> pump(
      WidgetTester t, {
      Size size = const Size(390, 844),
    }) async {
      await t.runAsync(() async {
        await saveEvaluative(_marks());
        await saveEvaluative(_other());
      });
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: AppPalette.light.materialTheme,
          home: CalendarPage(
            today: _now,
            timetables: FakeTimetableStore(fakeTimetable()),
            campus: 'goa',
            calendar: cal,
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Week'));
      await t.pumpAndSettle();
    }

    testWidgets(
      'exams name their course; the published midsem has no all-day twin',
      (t) async {
        await pump(t);
        expect(
          find.text('Intro Widgets Midsem'),
          findsOneWidget,
        ); // the timed block
        expect(find.textContaining('$_aaa · Midsem'), findsNothing);
        expect(find.textContaining('ZZZ F999 · Midsem'), findsOneWidget);
        expect(t.takeException(), isNull);
      },
    );

    testWidgets(
      'a Marks date is "Added by you"; a time moves it onto the grid',
      (t) async {
        await pump(t);
        await t.tap(find.textContaining('ZZZ F999 · Midsem'));
        await t.pumpAndSettle();
        expect(find.text('Added by you'), findsOneWidget);
        expect(t.takeException(), isNull, reason: 'all-day sheet');
        await t.tap(find.text('ZZZ F999 · Midsem').last);
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: 'time sheet');
        expect(find.text('Save time'), findsOneWidget);
        await t.enterText(find.byType(TextField).at(0), '10:00 AM');
        await t.enterText(find.byType(TextField).at(1), '11:00 AM');
        await t.tap(find.text('Save time'));
        await t.pumpAndSettle();
        final k = markKey('ZZZ F999', 'Midsem', '2026-10-12');
        expect(cal.state.markTimes[k], (s: 600, e: 660));
        expect(find.textContaining('ZZZ F999 · Midsem'), findsNothing);
        expect(find.text('ZZZ F999'), findsOneWidget);
        expect(t.takeException(), isNull);
      },
    );

    testWidgets('a bad mark time says so and saves nothing', (t) async {
      await pump(t);
      await t.tap(find.textContaining('ZZZ F999 · Midsem'));
      await t.pumpAndSettle();
      await t.tap(find.text('ZZZ F999 · Midsem').last);
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).at(0), '11:00 AM');
      await t.enterText(find.byType(TextField).at(1), '10:00 AM');
      await t.tap(find.text('Save time'));
      await t.pumpAndSettle();
      expect(find.text('End must be after start'), findsOneWidget);
      expect(cal.state.markTimes, isEmpty);
    });

    testWidgets(
      'the campus Midsem exams sheet is campus-wide and lists my own times',
      (t) async {
        await pump(t);
        await t.tap(find.textContaining('Midsem exams').first);
        await t.pumpAndSettle();
        expect(find.text('Academic calendar · campus-wide'), findsOneWidget);
        expect(find.text('$_aaa · Midsem'), findsOneWidget);
        expect(find.textContaining('9:30 AM'), findsOneWidget);
        expect(t.takeException(), isNull);
      },
    );

    testWidgets('seven columns at 320 with exams leave no overflow', (t) async {
      await pump(t, size: const Size(320, 640));
      expect(t.takeException(), isNull);
    });
  });
}
