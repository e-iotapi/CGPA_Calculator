// The Calendar's screens and sheets over a fake published timetable, for
// the board comparison:
//
//   SHOTS_DIR=/some/dir flutter test test/ui/calendar_screens_test.dart
import 'package:cgpa_calculator/core/models/marks.dart';
import 'package:cgpa_calculator/core/storage/marks.dart';
import 'package:cgpa_calculator/core/timetable/calendar_store.dart';
import 'package:cgpa_calculator/core/timetable/timetable.dart';
import 'package:cgpa_calculator/features/calendar/calendar_page.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_data.dart';
import '../helpers/fake_timetable.dart';
import '../helpers/fonts.dart';

// Wednesday 23 Sep 2026; its week is Mon 21 to Sun 27.
final _now = DateTime(2026, 9, 23, 10, 30);
const _aaa = 'AAA F111';

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await seedAll();
  });

  Future<CalendarStore> store({bool second = false}) async {
    final cal = CalendarStore(MemBox(), profile: 1);
    await cal.adopt('goa', '2026-1');
    await cal.addCourse(fakeTimetable().courses[_aaa]!, [
      '$_aaa|L1',
      '$_aaa|T1',
    ]);
    return cal;
  }

  Timetable two() {
    final j = fakeTimetable().toJson();
    ((((j['courses'] as Map)[_aaa] as Map)['sec']) as List).add({
      'ty': 'L',
      'no': 2,
      'prof': ['B Teacher'],
      'room': 'F202',
      'slots': [
        {'d': 2, 's': 660, 'e': 720},
      ],
    });
    return Timetable.fromJson(j);
  }

  Future<void> run(
    WidgetTester t,
    String name, {
    Timetable? tt,
    bool published = true,
    DateTime? now,
    Future<void> Function(WidgetTester t)? open,
  }) async {
    final cal = await store();
    final errors = await renderScreen(
      t,
      name,
      () => CalendarPage(
        today: now ?? _now,
        timetables: FakeTimetableStore(
          published ? (tt ?? fakeTimetable()) : null,
        ),
        campus: 'goa',
        calendar: cal,
        prefs: MemBox(),
      ),
      open: open,
    );
    expect(errors, isEmpty, reason: name);
  }

  Future<void> tab(WidgetTester t, String n) => t.tap(find.text(n));

  testWidgets(
    'cal_month',
    (t) => run(
      t,
      'cal_month',
      // An upcoming campus date joins Next up.
      open: (t) async =>
          expect(find.text('Founders day'), findsOneWidget),
    ),
  );
  testWidgets(
    'cal_unpublished',
    (t) => run(t, 'cal_unpublished', published: false),
  );
  testWidgets(
    'cal_week',
    (t) => run(t, 'cal_week', open: (t) => tab(t, 'Week')),
  );
  testWidgets('cal_day', (t) => run(t, 'cal_day', open: (t) => tab(t, 'Day')));
  testWidgets(
    'cal_class',
    (t) => run(
      t,
      'cal_class',
      tt: two(),
      open: (t) async {
        await tab(t, 'Week');
        await settle(t);
        await t.tap(find.text(_aaa).first);
      },
    ),
  );
  testWidgets(
    'cal_change_time',
    (t) => run(
      t,
      'cal_change_time',
      open: (t) async {
        await tab(t, 'Week');
        await settle(t);
        await t.tap(find.text(_aaa).first);
        await settle(t);
        await t.tap(find.text('Change time, only for me'));
      },
    ),
  );
  testWidgets(
    'cal_remove',
    (t) => run(
      t,
      'cal_remove',
      open: (t) async {
        await tab(t, 'Week');
        await settle(t);
        await t.tap(find.text(_aaa).first);
        await settle(t);
        await t.tap(find.text('Remove from my timetable'));
      },
    ),
  );
  testWidgets(
    'cal_add',
    (t) => run(t, 'cal_add', open: (t) => t.tap(find.text('Add'))),
  );

  // Exam week (Mon 12 Oct is AAA F111's published midsem). These run last:
  // they leave dated Marks parts in the shared box, which Month would list.
  final examWeek = DateTime(2026, 10, 12, 8);

  Future<void> examParts(WidgetTester t) => t.runAsync(
    () => saveEvaluative(
      Evaluative(
        courseId: 'ZZZ F999',
        name: 'Midsem',
        weight: 30,
        parts: [EvalPart(name: 'Midsem', outOf: 90, date: '2026-10-12')],
      ),
      key: 'zzz-midsem',
    ),
  );

  testWidgets('cal_exam_week', (t) async {
    await examParts(t);
    await run(
      t,
      'cal_exam_week',
      now: examWeek,
      tt: fakeTimetable(midsemWeek: true),
      open: (t) => tab(t, 'Week'),
    );
  });
  testWidgets('cal_exam_time', (t) async {
    await examParts(t);
    await run(
      t,
      'cal_exam_time',
      now: examWeek,
      tt: fakeTimetable(midsemWeek: true),
      open: (t) async {
        await tab(t, 'Week');
        await settle(t);
        await t.tap(find.textContaining('ZZZ F999 · Midsem'));
        await settle(t);
        await t.tap(find.text('ZZZ F999 · Midsem').last);
      },
    );
  });
  testWidgets('cal_exam_campus', (t) async {
    await examParts(t);
    await run(
      t,
      'cal_exam_campus',
      now: examWeek,
      tt: fakeTimetable(midsemWeek: true),
      open: (t) async {
        await tab(t, 'Week');
        await settle(t);
        await t.tap(find.textContaining('Midsem exams').first);
      },
    );
  });
}
