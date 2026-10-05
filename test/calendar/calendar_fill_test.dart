import 'dart:convert';

import 'package:cgpa_calculator/core/timetable/calendar_store.dart';
import 'package:cgpa_calculator/core/timetable/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_timetable.dart';

void main() {
  const a = {
    'AAA F111': ['AAA F111|L1'],
  };
  const b = {
    'BBB U101': ['BBB U101|L1'],
  };

  Future<CalendarStore> store([CalendarState? saved]) async {
    final box = MemBox();
    if (saved != null) await box.put('profile.1', jsonEncode(saved.toJson()));
    final c = CalendarStore(box, profile: 1);
    if (saved == null) await c.adopt('goa', '2026-1');
    return c;
  }

  test(
    'a course added to the semester later goes in on the next visit',
    () async {
      final c = await store();
      await c.autoFill(const {});
      expect(c.state.picks, isEmpty);
      await c.autoFill(a);
      expect(c.state.picks.keys, ['AAA F111']);
      await c.autoFill({...a, ...b});
      expect(c.state.picks.keys, ['AAA F111', 'BBB U101']);
    },
  );

  test('a course taken out of the calendar stays out', () async {
    final c = await store();
    await c.autoFill({...a, ...b});
    await c.removeCourse('BBB U101');
    await c.autoFill({...a, ...b});
    expect(c.state.picks.keys, ['AAA F111']);
    // Picked by hand, then removed: also stays out.
    await c.addCourse(const TtCourse(id: 'CCC F222', title: 'C'), [
      'CCC F222|L1',
    ]);
    await c.removeCourse('CCC F222');
    await c.autoFill({
      'CCC F222': ['CCC F222|L1'],
    });
    expect(c.state.picks.keys, ['AAA F111']);
  });

  test('filled survives a save', () async {
    final c = await store();
    await c.autoFill(a);
    final again = CalendarStore(c.box, profile: 1);
    expect(again.state.filled, {'AAA F111'});
  });

  test(
    'a calendar saved before filled was kept: filled keeps what it has; empty fills',
    () async {
      final had = await store(
        const CalendarState(
          campus: 'goa',
          sem: '2026-1',
          picks: a,
          autoFilled: true,
        ),
      );
      await had.autoFill({...a, ...b});
      expect(had.state.picks.keys, [
        'AAA F111',
      ], reason: 'BBB may have been taken out');
      final empty = await store(
        const CalendarState(campus: 'goa', sem: '2026-1', autoFilled: true),
      );
      await empty.autoFill(b);
      expect(empty.state.picks.keys, ['BBB U101']);
    },
  );
}
