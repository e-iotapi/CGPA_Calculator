// The Calendar's screens and sheets over a fake published timetable, for
// the board comparison:
//
//   SHOTS_DIR=/some/dir flutter test test/ui/calendar_screens_test.dart
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
    Future<void> Function(WidgetTester t)? open,
  }) async {
    final cal = await store();
    final errors = await renderScreen(
      t,
      name,
      () => CalendarPage(
        today: _now,
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

  testWidgets('cal_month', (t) => run(t, 'cal_month'));
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
}
