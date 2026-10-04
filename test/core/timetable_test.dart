import 'dart:convert';
import 'dart:io';

import 'package:cgpa_calculator/core/timetable/calendar_store.dart';
import 'package:cgpa_calculator/core/timetable/occurrences.dart';
import 'package:cgpa_calculator/core/timetable/timetable.dart';
import 'package:cgpa_calculator/core/timetable/timetable_store.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

// Invented data only.
Map<String, Object?> doc({int marker = 1, Object? extraSlot}) => {
  'v': 1,
  'campus': 'goa',
  'sem': '2026-1',
  'publishedAt': 1790000000000,
  'marker': marker,
  'hours': {'1': [480, 540]},
  'examSlots': {'FN': [570, 750]},
  'events': [
    {'from': '2026-08-03', 'title': 'Instruction begins', 'kind': 'term'},
    {'from': '2026-09-05', 'title': 'Founders day', 'kind': 'holiday'},
    {'from': '2026-11-28', 'title': 'Last day of classes', 'kind': 'term'},
  ],
  'courses': {
    'AAA F111': {
      't': 'Intro Widgets',
      'cr': 4.0,
      'sec': [
        {
          'ty': 'L', 'no': 1, 'prof': ['A'], 'room': 'F101',
          'slots': [
            {'d': 1, 's': 540, 'e': 600},
            {'d': 3, 's': 540, 'e': 600},
          ],
        },
        {'ty': 'T', 'no': 1, 'prof': [], 'slots': [{'d': 4, 's': 600, 'e': 660}]},
      ],
      'compre': {'d': '2026-12-10', 'slot': 'FN', 's': 570, 'e': 750},
      'mid': {'d': '2026-10-12', 's': 570, 'e': 660},
    },
    'BBB F211': {'t': 'Gadgets', 'sec': <Object>[]},
  },
};

Timetable tt([Map<String, Object?>? m]) => Timetable.fromJson(m ?? doc());

CalendarState picked([List<String> keys = const ['AAA F111|L1']]) =>
    CalendarState(sem: '2026-1', picks: {'AAA F111': keys});

void main() {
  group('Timetable', () {
    test('reads JS numbers as num and round-trips', () {
      final t = tt();
      expect(t.courses['AAA F111']!.credits, 4);
      expect(Timetable.fromJson(jsonDecode(jsonEncode(t.toJson())) as Map).toJson(), t.toJson());
    });

    test('rejects a newer schema', () {
      expect(() => Timetable.fromJson({...doc(), 'v': 2}), throwsFormatException);
    });

    test('search: ids first, word prefixes', () {
      final t = tt();
      expect(t.search('aaa f1').map((c) => c.id), ['AAA F111']);
      expect(t.search('widg').map((c) => c.id), ['AAA F111']);
      expect(t.search('zzz'), isEmpty);
    });

    test('lastClassworkDay: last-day event, else max term, else 16 weeks', () {
      expect(tt().lastClassworkDay(), '2026-11-28');
      final noLast = doc()..['events'] = [{'from': '2026-08-03', 'to': '2026-12-01', 'title': 'Term', 'kind': 'term'}];
      expect(tt(noLast).lastClassworkDay(), '2026-12-01');
      final none = doc()..['events'] = <Object>[];
      expect(tt(none).lastClassworkDay(), '2026-11-21');
    });
  });

  group('expandOccurrences', () {
    List<Occurrence> classes(CalendarState s, {Timetable? t, String to = '2026-12-31'}) =>
        expandOccurrences(t ?? tt(), s, from: '2026-01-01', to: to)
            .where((o) => o.kind == OccKind.cls)
            .toList();

    test('weekly classes from instruction start to last day, sorted', () {
      final o = classes(picked());
      expect(o.first.date, '2026-08-03'); // Monday
      expect(o.first.start, 540);
      expect(o.first.room, 'F101');
      expect(o.last.date, '2026-11-25'); // last Wednesday on or before Nov 28
      expect(o.length, 2 * 17);
      expect([for (final x in o) x.date], [...o.map((x) => x.date)]..sort());
    });

    test('one slot edit moves every week and is flagged', () {
      final o = classes(picked().copy(slotOverrides: {'AAA F111|L1|1-540': (d: 2, s: 600, e: 660)}));
      final tue = o.where((x) => x.edited).toList();
      expect(tue.first.date, '2026-08-04');
      expect(tue.first.start, 600);
      expect(tue.every((x) => DateTime.parse(x.date).weekday == 2), isTrue);
      expect(tue.length, 17);
    });

    test('repeat-until and removed occurrences', () {
      final s = picked().copy(
        repeatUntil: {'AAA F111': '2026-08-12'},
        removed: {'AAA F111|L1|1-540|2026-08-10'},
      );
      expect([for (final x in classes(s)) x.date], ['2026-08-03', '2026-08-05', '2026-08-12']);
    });

    test('no class inside an exam window; the exams themselves stay', () {
      final m = doc()
        ..['events'] = [
          {'from': '2026-08-03', 'title': 'Classwork begins', 'kind': 'term'},
          {'from': '2026-10-12', 'to': '2026-10-17', 'title': 'Mid-semester Examinations', 'kind': 'exam'},
          {'from': '2026-11-27', 'title': 'Last date for classwork', 'kind': 'deadline'},
          {'from': '2026-12-01', 'title': 'Comprehensive examinations begin', 'kind': 'exam'},
          {'from': '2026-12-16', 'title': 'Comprehensive Examinations end', 'kind': 'exam'},
          {'from': '2026-12-20', 'to': '2027-01-03', 'title': 'Recess for students', 'kind': 'term'},
        ];
      final t = tt(m);
      expect(t.examWindows(), [('2026-10-12', '2026-10-17'), ('2026-12-01', '2026-12-16')]);
      expect(t.semStart(), '2026-08-03');
      expect(t.lastClassworkDay(), '2026-11-27');
      final dates = [for (final x in classes(picked(), t: t)) x.date];
      expect(dates, isNot(contains('2026-10-12')));
      expect(dates, isNot(contains('2026-10-14')));
      expect(dates, containsAll(['2026-10-07', '2026-10-19']));
      expect(dates.last, '2026-11-25');
      final all = expandOccurrences(t, picked(), from: '2026-10-12', to: '2026-10-12');
      expect(all.map((o) => o.kind), contains(OccKind.midsem));
    });

    test('an unpicked section does not show', () {
      final s = picked(['AAA F111|T1']);
      expect({for (final x in classes(s)) x.sectionKey}, {'AAA F111|T1'});
    });

    test('exams show once, examsOff hides them, overrides never apply', () {
      final s = picked().copy(slotOverrides: {'AAA F111|L1|1-540': (d: 2, s: 1, e: 2)});
      final ex = expandOccurrences(tt(), s, from: '2026-01-01', to: '2026-12-31')
          .where((o) => o.kind == OccKind.midsem || o.kind == OccKind.compre)
          .toList();
      expect(ex.map((o) => (o.kind, o.date, o.start)), [
        (OccKind.midsem, '2026-10-12', 570),
        (OccKind.compre, '2026-12-10', 570),
      ]);
      final off = expandOccurrences(tt(), s.copy(examsOff: {'AAA F111'}), from: '2026-01-01', to: '2026-12-31');
      expect(off.where((o) => o.kind == OccKind.midsem || o.kind == OccKind.compre), isEmpty);
    });

    test('holidays are not occurrences but eventsOn finds them', () {
      final all = expandOccurrences(tt(), const CalendarState(), from: '2026-09-05', to: '2026-09-05');
      expect(all, isEmpty);
      expect(eventsOn(tt(), '2026-09-05').single.title, 'Founders day');
    });

    test('customs: once and weekly; null timetable keeps only customs', () {
      const s = CalendarState(custom: [
        CalendarCustom(id: 'a', title: 'Club', d: 3, s: 1020, e: 1080, from: '2026-08-10', until: '2026-08-24'),
        CalendarCustom(id: 'b', title: 'Trip', d: 1, s: 0, e: 60, from: '2026-09-01', once: true),
      ]);
      final o = expandOccurrences(null, s, from: '2026-08-01', to: '2026-12-31');
      expect(o.map((x) => x.date), ['2026-08-12', '2026-08-19', '2026-09-01']);
    });

    test('a course of the student\'s own timings expands weekly under its code', () {
      const s = CalendarState(custom: [
        CalendarCustom(
          id: 'o1', title: 'Data Structures', d: 7, s: 600, e: 660, from: '2026-08-03',
          until: '2026-08-17', course: 'CS F211', room: 'D201',
        ),
      ]);
      final o = expandOccurrences(null, s, from: '2026-08-01', to: '2026-12-31');
      expect(o.map((x) => (x.date, x.courseId, x.room)), [
        ('2026-08-09', 'CS F211', 'D201'),
        ('2026-08-16', 'CS F211', 'D201'),
      ]);
    });

    test('searchCourses matches by code and by title prefix, id first', () {
      final all = [
        const TtCourse(id: 'CS F211', title: 'Data Structures'),
        const TtCourse(id: 'CS F212', title: 'Database Systems'),
        const TtCourse(id: 'MATH F211', title: 'Cs Maths'),
      ];
      expect(searchCourses(all, 'cs f211').map((c) => c.id), ['CS F211', 'MATH F211']);
      expect(searchCourses(all, 'cs').map((c) => c.id), ['CS F211', 'CS F212', 'MATH F211']);
      expect(searchCourses(all, '   '), isEmpty);
    });

    test('republish: vanished slot keeps the student time as stale, vanished section is listed', () {
      final repub = doc();
      final sec = ((repub['courses'] as Map)['AAA F111'] as Map)['sec'] as List;
      (sec[0] as Map)['slots'] = [
        {'d': 3, 's': 540, 'e': 600},
      ]; // Monday slot gone
      sec.removeAt(1); // T1 gone
      final s = picked(['AAA F111|L1', 'AAA F111|T1']).copy(
        slotOverrides: {'AAA F111|L1|1-540': (d: 5, s: 700, e: 760)},
      );
      final t = tt(repub);
      final o = classes(s, t: t);
      final stale = o.where((x) => x.stale).toList();
      expect(stale, isNotEmpty);
      expect(stale.first.start, 700);
      expect(DateTime.parse(stale.first.date).weekday, 5);
      expect(o.where((x) => !x.stale && x.start == 540), isNotEmpty);
      expect(staleSections(t, s), ['AAA F111|T1']);
    });

    test('a different semester shows nothing of the old picks', () {
      final s = picked().copy(sem: '2025-2');
      expect(classes(s), isEmpty);
    });
  });

  group('CalendarStore', () {
    late Box box;
    setUp(() async {
      Hive.init(Directory.systemTemp.createTempSync('cal').path);
      box = await Hive.openBox('calendar');
    });
    tearDown(() => Hive.close());

    test('every edit persists as a JSON string and reloads', () async {
      final c = tt().courses['AAA F111']!;
      final st = CalendarStore(box, profile: 0);
      await st.adopt('goa', '2026-1');
      await st.addCourse(c, ['AAA F111|L1']);
      await st.setSlotOverride('AAA F111|L1|1-540', d: 2, s: 600, e: 660);
      await st.setRepeatUntil('AAA F111', '2026-10-01');
      await st.removeOccurrence('AAA F111|L1|1-540', '2026-08-10');
      await st.addCustom(const CalendarCustom(id: 'x', title: 'T', d: 1, s: 1, e: 2, from: '2026-08-03'));
      expect(box.get('profile.0'), isA<String>());
      final again = CalendarStore(box, profile: 0).state;
      expect(again.toJson(), st.state.toJson());
      expect(again.slotOverrides['AAA F111|L1|1-540']!.d, 2);
      await st.setSlotOverride('AAA F111|L1|1-540', d: 2, s: 600, e: 660);
      await expectLater(st.setSlotOverride('q', d: 1, s: 60, e: 60), throwsStateError);
    });

    test('setOwnCourse replaces the course\'s times; removeCourse takes them with it', () async {
      final st = CalendarStore(box, profile: 3);
      await st.addCustom(const CalendarCustom(id: 'x', title: 'Club', d: 1, s: 1, e: 2, from: '2026-08-03'));
      await st.setOwnCourse('CS F211', 'DSA', [(d: 1, s: 540, e: 600, room: ''), (d: 3, s: 540, e: 600, room: 'D1')],
          from: '2026-08-03', until: '2026-11-28');
      await st.setOwnCourse('CS F211', 'DSA', [(d: 7, s: 600, e: 660, room: '')],
          from: '2026-08-03', until: '2026-11-28');
      expect(st.state.custom.where((c) => c.course == 'CS F211').map((c) => c.d), [7]);
      expect(CalendarStore(box, profile: 3).state.custom.last.course, 'CS F211');
      await expectLater(
        st.setOwnCourse('CS F211', 'DSA', [(d: 1, s: 60, e: 60, room: '')], from: '2026-08-03', until: '2026-11-28'),
        throwsStateError,
      );
      await st.removeCourse('CS F211');
      expect(st.state.custom.map((c) => c.id), ['x']);
    });

    test('setSection swaps the pick and drops the old section\'s edits', () async {
      final c = tt().courses['AAA F111']!;
      final st = CalendarStore(box, profile: 2);
      await st.addCourse(c, ['AAA F111|L1', 'AAA F111|T1']);
      await st.setSlotOverride('AAA F111|L1|1-540', d: 2, s: 600, e: 660);
      await st.setSlotOverride('AAA F111|T1|4-600', d: 2, s: 600, e: 660);
      await st.removeOccurrence('AAA F111|L1|1-540', '2026-08-10');
      await st.setSection('AAA F111', 'AAA F111|L1', 'AAA F111|L2');
      expect(st.state.picks['AAA F111'], ['AAA F111|L2', 'AAA F111|T1']);
      expect(st.state.slotOverrides.keys, ['AAA F111|T1|4-600']);
      expect(st.state.removed, isEmpty);
    });

    test('adding a course clears its stale edits; removing drops everything', () async {
      final c = tt().courses['AAA F111']!;
      final st = CalendarStore(box, profile: 1);
      await st.addCourse(c, ['AAA F111|L1']);
      await st.setSlotOverride('AAA F111|L1|1-540', d: 2, s: 600, e: 660);
      await st.setExamsShown('AAA F111', false);
      await st.addCourse(c, ['AAA F111|L1']);
      expect(st.state.slotOverrides, isEmpty);
      await st.setRepeatUntil('AAA F111', '2026-10-01');
      await st.removeCourse('AAA F111');
      expect(st.state.picks, isEmpty);
      expect(st.state.repeatUntil, isEmpty);
      expect(st.state.examsOff, isEmpty);
    });
  });

  group('TimetableStore', () {
    late Box box;
    setUp(() async {
      Hive.init(Directory.systemTemp.createTempSync('tt').path);
      box = await Hive.openBox('timetable');
      TimetableStore.resetMemo();
    });
    tearDown(() => Hive.close());

    Future<FakeFirebaseFirestore> seeded({int marker = 1}) async {
      final db = FakeFirebaseFirestore();
      final d = doc(marker: marker);
      final courses = d.remove('courses')! as Map<String, Object?>;
      await db.doc('timetable/goa|current').set({'sem': '2026-1', 'marker': marker});
      await db.doc('timetable/goa|2026-1').set({
        ...d,
        'chunks': 2,
        'publishedAt': Timestamp.fromMillisecondsSinceEpoch(1790000000000),
        'auditId': 'a',
      });
      final keys = courses.keys.toList();
      for (var i = 0; i < 2; i++) {
        await db.doc('timetable/goa|2026-1|$i').set({'n': i, 'courses': {keys[i]: courses[keys[i]]}});
      }
      return db;
    }

    test('Firestore chunks assemble to the same timetable', () async {
      final db = await seeded();
      final t = await TimetableStore(db, box: box).current('goa');
      expect(t!.courses.keys, containsAll(['AAA F111', 'BBB F211']));
      expect(t.publishedAt, 1790000000000);
      expect(t.toJson()['events'], tt().toJson()['events']);
    });

    test('null when nothing is published', () async {
      expect(await TimetableStore(FakeFirebaseFirestore(), box: box).current('goa'), isNull);
    });

    test('Worker first; falls back to Firestore when it fails; 404 not published is null', () async {
      final db = await seeded();
      final urls = <String>[];
      final w = TimetableStore(
        db,
        box: box,
        workerBase: 'https://w.example/',
        get: (u) async {
          urls.add(u);
          return (status: 200, body: jsonEncode({...doc(), 'sem': '2026-W'}));
        },
      );
      expect((await w.current('goa'))!.sem, '2026-W');
      expect(urls, ['https://w.example/timetable/goa.json']);

      await box.clear();
      final down = TimetableStore(db, box: box, workerBase: 'https://w.example', get: (u) async => throw Exception('down'));
      expect((await down.current('goa'))!.sem, '2026-1');

      await box.clear();
      final none = TimetableStore(
        db,
        box: box,
        workerBase: 'https://w.example',
        get: (u) async => (status: 404, body: '{"error":"not published"}'),
      );
      expect(await none.current('goa'), isNull);
    });

    test('caches under the marker and peeks synchronously', () async {
      final db = await seeded();
      await db.doc('heads/goa').set({'v': {'timetable': 1}});
      var hits = 0;
      final st = TimetableStore(db, box: box, workerBase: 'https://w.example', get: (u) async {
        hits++;
        return (status: 200, body: jsonEncode(doc()));
      });
      await st.current('goa');
      await st.current('goa');
      expect(hits, 1);
      expect(TimetableStore(db, box: box).peekCurrent('goa')!.marker, 1);
      expect(TimetableStore(db, box: box).peekCurrent('pilani'), isNull);
    });
  });
}
