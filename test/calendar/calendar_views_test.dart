import 'dart:io';

import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/core/storage/cache_boxes.dart';
import 'package:cgpa_calculator/core/timetable/calendar_store.dart';
import 'package:cgpa_calculator/core/timetable/timetable.dart';
import 'package:cgpa_calculator/features/calendar/add_course_sheet.dart';
import 'package:cgpa_calculator/features/calendar/calendar_page.dart';
import 'package:cgpa_calculator/features/calendar/calendar_time.dart';
import 'package:cgpa_calculator/features/calendar/week_view.dart';
import 'package:cgpa_calculator/core/grading/grade_scale.dart';
import 'package:cgpa_calculator/core/models/elective.dart';
import 'package:cgpa_calculator/core/models/marks.dart';
import 'package:cgpa_calculator/core/storage/courses.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/shared/widgets/notice.dart';
import 'package:cgpa_calculator/sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import '../helpers/fake_timetable.dart';

// Wednesday 23 Sep 2026; its week is Mon 21 to Sun 27.
final _now = DateTime(2026, 9, 23, 10, 30);
const _aaa = 'AAA F111';

void main() {
  group('helpers', () {
    test('layoutLanes puts overlapping blocks side by side', () {
      expect(
        layoutLanes([(s: 540, e: 600), (s: 570, e: 630), (s: 700, e: 760)]),
        [(0, 2), (1, 2), (0, 1)],
      );
      expect(layoutLanes(const []), isEmpty);
    });

    test('parseClock reads what students type', () {
      expect(parseClock('9'), 540);
      expect(parseClock('2'), 14 * 60);
      expect(parseClock('9:30 pm'), 21 * 60 + 30);
      expect(parseClock('12:15 AM'), 15);
      expect(parseClock('14:00'), 840);
      expect(parseClock('25'), isNull);
      expect(parseClock('9:75'), isNull);
      expect(parseClock('soon'), isNull);
    });

    test('dates: Monday of a week, across a month end', () {
      expect(mondayOf('2026-09-23'), '2026-09-21');
      expect(mondayOf('2026-09-27'), '2026-09-21');
      expect(addDays('2026-09-30', 1), '2026-10-01');
      expect(dateLabel('2026-09-23'), 'Wed 23 Sep');
      expect(clock(0), '12:00 AM');
      expect(clock(780), '1:00 PM');
    });

    test(
      'the calendar boxes are emptied on sign-out even when not open',
      () async {
        Hive.init(Directory.systemTemp.createTempSync('cal').path);
        for (final n in ['calendar', 'timetable']) {
          await (await Hive.openBox(n)).put('k', 'v');
          await Hive.box(n).close();
        }
        expect(cacheBoxes, containsAll(['calendar', 'timetable']));
        await clearAccountCaches();
        for (final n in ['calendar', 'timetable']) {
          expect((await Hive.openBox(n)).get('k'), isNull, reason: n);
        }
        await Hive.close();
      },
    );
  });

  group('views', () {
    late MemBox box;
    late CalendarStore cal;
    late FakeTimetableStore store;
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('hive_calv');
      Hive.init(dir.path);
      if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(CourseAdapter());
      registerMarksAdapters();
      await Sync.openBoxes();
      box = MemBox();
      cal = CalendarStore(box, profile: 1);
      store = FakeTimetableStore(fakeTimetable());
      await cal.adopt('goa', '2026-1');
      await cal.addCourse(store.t!.courses[_aaa]!, ['$_aaa|L1', '$_aaa|T1']);
    });
    tearDown(() async {
      await Hive.deleteFromDisk();
      await dir.delete(recursive: true);
    });

    Future<void> pump(
      WidgetTester t, {
      Size size = const Size(390, 844),
      double k = 1,
      bool settle = true,
      Widget? home,
    }) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: AppPalette.light.materialTheme,
          builder:
              (c, child) => MediaQuery(
                data: MediaQuery.of(
                  c,
                ).copyWith(textScaler: TextScaler.linear(k)),
                child: child!,
              ),
          home:
              home ??
              CalendarPage(
                today: _now,
                timetables: store,
                campus: 'goa',
                calendar: cal,
              ),
        ),
      );
      if (settle) await t.pumpAndSettle();
    }

    Future<void> tab(WidgetTester t, String name) async {
      await t.tap(find.text(name));
      await t.pumpAndSettle();
    }

    testWidgets('Month, Week and Day switch; Month keeps its grid', (t) async {
      await pump(t);
      expect(find.text('September 2026'), findsOneWidget);
      expect(find.text('Next up'), findsOneWidget);
      await tab(t, 'Week');
      expect(find.text('21 – 27 Sep 2026'), findsOneWidget);
      expect(find.text('Next up'), findsNothing);
      await tab(t, 'Day');
      expect(find.text('Wed 23 Sep 2026'), findsOneWidget);
      await t.tap(find.byTooltip('Next day'));
      await t.pumpAndSettle();
      expect(find.text('Thu 24 Sep 2026'), findsOneWidget);
      await tab(t, 'Month');
      expect(find.text('September 2026'), findsOneWidget);
    });

    testWidgets(
      'Week: Mon to Sat, classes, holiday and dates in the all-day strip',
      (t) async {
        await pump(t);
        await tab(t, 'Week');
        for (final d in ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT']) {
          expect(find.text(d), findsOneWidget);
        }
        expect(find.text('SUN'), findsNothing);
        // L1 on Mon, Wed, Fri and the tutorial on Thu.
        expect(find.text(_aaa), findsNWidgets(4));
        expect(find.text('Founders day'), findsOneWidget);
        expect(find.text('Fees due'), findsOneWidget);
        expect(t.takeException(), isNull);
      },
    );

    testWidgets('a Sunday shows only when it has something', (t) async {
      await cal.addCustom(
        const CalendarCustom(
          id: 'x1',
          title: 'Study group',
          d: 7,
          s: 600,
          e: 660,
          from: '2026-09-27',
          once: true,
        ),
      );
      await pump(t);
      await tab(t, 'Week');
      expect(find.text('SUN'), findsOneWidget);
      expect(find.text('Study group'), findsOneWidget);
      await t.tap(find.byTooltip('Next week'));
      await t.pumpAndSettle();
      expect(find.text('SUN'), findsNothing);
      expect(find.text('28 Sep – 4 Oct 2026'), findsOneWidget);
    });

    testWidgets(
      'the Now line sits in today\'s column and Today returns to it',
      (t) async {
        await pump(t);
        await tab(t, 'Week');
        expect(find.bySemanticsLabel('Now, 10:30 AM'), findsOneWidget);
        await t.tap(find.byTooltip('Next week'));
        await t.pumpAndSettle();
        expect(find.bySemanticsLabel(RegExp('^Now')), findsNothing);
        await t.tap(find.text('Today'));
        await t.pumpAndSettle();
        expect(find.text('21 – 27 Sep 2026'), findsOneWidget);
      },
    );

    testWidgets('swiping moves a week', (t) async {
      await pump(t);
      await tab(t, 'Week');
      await t.fling(find.byType(WeekView), const Offset(-300, 0), 1000);
      await t.pumpAndSettle();
      expect(find.text('28 Sep – 4 Oct 2026'), findsOneWidget);
    });

    testWidgets('one edit moves every weekly time, Reset puts them back', (
      t,
    ) async {
      await pump(t);
      await tab(t, 'Week');
      await t.tap(find.text(_aaa).first);
      await t.pumpAndSettle();
      expect(find.textContaining('Mon 9:00 AM – 10:00 AM'), findsOneWidget);
      await t.tap(find.text('Change time, only for me'));
      await t.pumpAndSettle();
      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(6));
      for (var i = 0; i < 3; i++) {
        await t.enterText(fields.at(i * 2), '10:00 AM');
        await t.enterText(fields.at(i * 2 + 1), '11:00 AM');
      }
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      expect(cal.state.slotOverrides.length, 3);
      expect(find.text('10:00–11:00'), findsNWidgets(3));
      expect(find.text('9:00–10:00'), findsNothing);
      await t.tap(find.text(_aaa).first);
      await t.pumpAndSettle();
      expect(find.text('YOUR TIME'), findsOneWidget);
      await t.tap(find.text('Reset to the published time'));
      await t.pumpAndSettle();
      expect(cal.state.slotOverrides, isEmpty);
      expect(find.text('9:00–10:00'), findsNWidgets(3));
    });

    testWidgets('Section switch moves every lecture to the other section', (
      t,
    ) async {
      final j = store.t!.toJson();
      final sec = (((j['courses'] as Map)[_aaa] as Map)['sec'] as List);
      sec.add({
        'ty': 'L',
        'no': 2,
        'prof': ['B Teacher'],
        'room': 'F202',
        'slots': [
          {'d': 2, 's': 660, 'e': 720},
          {'d': 4, 's': 660, 'e': 720},
        ],
      });
      store.t = Timetable.fromJson(j);
      await pump(t);
      await tab(t, 'Week');
      await t.tap(find.text(_aaa).first);
      await t.pumpAndSettle();
      // Only the lecture has a second section: one Section list, the tutorial is not offered.
      expect(find.text('Section'), findsOneWidget);
      await t.tap(find.textContaining('Lecture 2'));
      await t.pumpAndSettle();
      expect(cal.state.picks[_aaa], ['$_aaa|L2', '$_aaa|T1']);
      expect(find.text('9:00–10:00'), findsNothing); // no L1 left
      expect(
        find.text('11:00–12:00'),
        findsNWidgets(3),
      ); // L2 Tue and Thu, T1 Thu
    });

    testWidgets('a bad time says so and saves nothing', (t) async {
      await pump(t);
      await tab(t, 'Week');
      await t.tap(find.text(_aaa).first);
      await t.pumpAndSettle();
      await t.tap(find.text('Change time, only for me'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).at(1), '8:00 AM');
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      expect(find.text('End must be after start'), findsOneWidget);
      expect(cal.state.slotOverrides, isEmpty);
    });

    testWidgets('Repeat until sets the course\'s last date', (t) async {
      await pump(t);
      await tab(t, 'Week');
      await t.tap(find.text(_aaa).first);
      await t.pumpAndSettle();
      expect(find.textContaining('28 Nov'), findsOneWidget);
      await t.tap(find.text('Repeat until a different date'));
      await t.pumpAndSettle();
      await t.tap(find.text('2'));
      await t.tap(find.text('OK'));
      await t.pumpAndSettle();
      expect(cal.state.repeatUntil[_aaa], '2026-11-02');
    });

    testWidgets('Remove one day asks first, then hides only that day', (
      t,
    ) async {
      await pump(t);
      await tab(t, 'Week');
      await t.tap(find.text(_aaa).first);
      await t.pumpAndSettle();
      await t.tap(find.text('Remove this day only'));
      await t.pumpAndSettle();
      expect(find.text('Remove this day?'), findsOneWidget);
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(cal.state.removed, isEmpty);
      await t.tap(find.text(_aaa).first);
      await t.pumpAndSettle();
      await t.tap(find.text('Remove this day only'));
      await t.pumpAndSettle();
      await t.tap(find.text('Remove'));
      await t.pumpAndSettle();
      expect(cal.state.removed.single, '$_aaa|L1|1-540|2026-09-21');
      expect(find.text(_aaa), findsNWidgets(3));
      expect(cal.state.picks, isNotEmpty);
    });

    testWidgets('Remove the course clears it from every day', (t) async {
      await pump(t);
      await tab(t, 'Week');
      await t.tap(find.text(_aaa).first);
      await t.pumpAndSettle();
      await t.tap(find.text('Remove from my timetable'));
      await t.pumpAndSettle();
      await t.tap(find.text('Remove'));
      await t.pumpAndSettle();
      expect(cal.state.picks, isEmpty);
      expect(find.text(_aaa), findsNothing);
    });

    testWidgets('Add a course: search, pick, save, and it shows', (t) async {
      await pump(t);
      await tab(t, 'Week');
      await t.tap(find.text('Add'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'gadget');
      await t.pumpAndSettle();
      await t.tap(find.text('Gadget Design'));
      await t.pumpAndSettle();
      await t.tap(find.text('Add course'));
      await t.pumpAndSettle();
      expect(cal.state.picks.keys, contains('CCC F311'));
      expect(find.text('CCC F311'), findsOneWidget);
    });

    testWidgets('Add an event of my own with no course', (t) async {
      await pump(t);
      await tab(t, 'Day');
      await t.tap(find.text('Add'));
      await t.pumpAndSettle();
      await t.tap(find.text('My event'));
      await t.pumpAndSettle();
      await t.tap(find.text('Add event'));
      await t.pumpAndSettle();
      expect(find.text('Give it a name'), findsOneWidget);
      await t.enterText(find.byType(TextField).first, 'Study group');
      await t.tap(find.text('Add event'));
      await t.pumpAndSettle();
      expect(cal.state.custom.single.title, 'Study group');
      expect(find.text('Study group'), findsOneWidget);
    });

    testWidgets('the add sheet keeps its title field above the keyboard', (
      t,
    ) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      t.view.viewInsets = const FakeViewPadding(bottom: 320);
      addTearDown(t.view.resetViewInsets);
      await t.pumpWidget(
        MaterialApp(
          theme: AppPalette.light.materialTheme,
          home: Scaffold(
            body: AddSheet(
              timetable: fakeTimetable(),
              state: const CalendarState(),
              today: '2026-09-23',
            ),
          ),
        ),
      );
      await t.tap(find.text('My event'));
      await t.pumpAndSettle();
      await t.showKeyboard(find.byType(TextField).first);
      await t.pumpAndSettle();
      expect(
        t.getBottomLeft(find.byType(TextField).first).dy,
        lessThan(844 - 320),
      );
      expect(t.takeException(), isNull);
    });

    testWidgets(
      'Add offers this semester\'s courses before anything is typed',
      (t) async {
        t.view.physicalSize = const Size(390, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(
          MaterialApp(
            theme: AppPalette.light.materialTheme,
            home: Scaffold(
              body: AddSheet(
                timetable: fakeTimetable(),
                state: const CalendarState(),
                suggested: const {'CCC F311'},
              ),
            ),
          ),
        );
        expect(find.text('Gadget Design'), findsOneWidget);
        expect(find.text('Intro Widgets'), findsNothing);
      },
    );

    testWidgets('no broadcast yet: a Note, and Month and Week still work', (
      t,
    ) async {
      store.t = null;
      await pump(t);
      expect(find.text('Timetable not published yet.'), findsOneWidget);
      expect(find.text('Next up'), findsOneWidget);
      expect(find.text('Add'), findsNothing);
      await tab(t, 'Week');
      expect(find.text('MON'), findsOneWidget);
    });

    testWidgets('a failed load says so, and Try again loads it', (t) async {
      store
        ..t = fakeTimetable()
        ..peek = false
        ..fail = true;
      await pump(t);
      expect(find.text('No connection. Nothing was changed.'), findsOneWidget);
      store.fail = false;
      await t.tap(find.text('Try again'));
      await t.pumpAndSettle();
      expect(find.text('No connection. Nothing was changed.'), findsNothing);
      expect(find.text('Add'), findsOneWidget);
    });

    testWidgets(
      'offline with a saved timetable: no error, nothing to wait for',
      (t) async {
        store.fail = true;
        await pump(t);
        expect(find.byType(Notice), findsNothing);
        await tab(t, 'Week');
        expect(find.text(_aaa), findsNWidgets(4));
      },
    );

    testWidgets('a peeked timetable draws on the first frame, no spinner', (
      t,
    ) async {
      await pump(t, settle: false);
      await t.tap(find.text('Week'));
      await t.pump();
      expect(find.text(_aaa), findsNWidgets(4));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await t.pumpAndSettle();
    });

    testWidgets('no overflow at 320, 768, 1440 or 200% text in Week and Day', (
      t,
    ) async {
      for (final v in ['Week', 'Day']) {
        for (final s in const [
          Size(320, 640),
          Size(768, 1024),
          Size(1440, 900),
        ]) {
          await pump(t, size: s);
          await tab(t, v);
          expect(t.takeException(), isNull, reason: '$v $s');
        }
        await pump(t, size: const Size(320, 640), k: 2);
        await tab(t, v);
        final ex = t.takeException();
        if (ex != null) debugPrint(ex.toString());
        expect(ex, isNull, reason: '$v 200%');
      }
    });

    group('first load puts the courses in', () {
      late CalendarStore fresh;
      late MemBox prefs;
      const notice =
          'We added your courses from the timetable. You can add or remove '
          'courses, or switch sections.';

      setUp(() {
        fresh = CalendarStore(MemBox(), profile: 2);
        prefs = MemBox();
      });

      Course mine(
        String id,
        int grade,
        String elective, {
        String sem = '3 - 1',
      }) => Course(
        title: 'T $id',
        id: id,
        credits: 3,
        grade1: grade,
        grade2: -2,
        discipline: 'A7',
        sem: sem,
        elective: elective,
      );

      Future<void> have(WidgetTester t, List<Course> cs) =>
          t.runAsync(() => Hive.box<Course>(coursesBoxName).addAll(cs));

      Widget page() => CalendarPage(
        today: _now,
        timetables: store,
        campus: 'goa',
        calendar: fresh,
        prefs: prefs,
      );

      testWidgets(
        'ongoing courses of the term go in, first section of each type; others are skipped',
        (t) async {
          await have(t, [
            mine(_aaa, GradeCode.ongoing, Elective.open.tag),
            mine(
              'ZZZ F999',
              GradeCode.clr,
              Elective.cdc1.tag,
            ), // not in the timetable
            mine('CCC F311', 9, Elective.cdc1.tag), // graded: not taking
            mine(
              'OLD F101',
              GradeCode.ongoing,
              Elective.cdc1.tag,
              sem: '2 - 1',
            ), // last year
          ]);
          await pump(t, home: page());
          expect(fresh.state.picks, {
            _aaa: ['$_aaa|L1', '$_aaa|T1'],
          });
          expect(find.text(notice), findsOneWidget);
        },
      );

      testWidgets(
        'with nothing ongoing, the discipline\'s CDCs for the term go in',
        (t) async {
          await have(t, [
            mine(_aaa, 9, Elective.cdc1.tag),
            mine('CCC F311', 9, Elective.humanity.tag),
            mine('DDD F101', 9, Elective.cdc2.tag, sem: '2 - 1'),
          ]);
          await pump(t, home: page());
          expect(fresh.state.picks.keys, [_aaa]);
          expect(find.text(notice), findsOneWidget);
        },
      );

      testWidgets(
        'it does not run again once picks exist or were all removed',
        (t) async {
          await have(t, [mine(_aaa, GradeCode.ongoing, Elective.open.tag)]);
          await pump(t, home: page());
          expect(fresh.state.picks.keys, [_aaa]);
          await fresh.removeCourse(_aaa);
          await pump(t, home: page());
          expect(fresh.state.picks, isEmpty);
          // And a student who picked their own keeps exactly those.
          final own = CalendarStore(MemBox(), profile: 3);
          await own.adopt('goa', '2026-1');
          await own.addCourse(store.t!.courses['CCC F311']!, ['CCC F311|L1']);
          await pump(
            t,
            home: CalendarPage(
              today: _now,
              timetables: store,
              campus: 'goa',
              calendar: own,
              prefs: prefs,
            ),
          );
          expect(own.state.picks.keys, ['CCC F311']);
        },
      );

      testWidgets(
        'the note shows once, Got it closes it, and it never comes back',
        (t) async {
          await have(t, [mine(_aaa, GradeCode.ongoing, Elective.open.tag)]);
          await pump(t, home: page());
          expect(find.text(notice), findsOneWidget);
          expect(prefs.get('calendar_autofill_seen'), true);
          await t.tap(find.text('Got it'));
          await t.pumpAndSettle();
          expect(find.text(notice), findsNothing);
          // A new student on this device (another profile) is not told again.
          fresh = CalendarStore(MemBox(), profile: 4);
          await pump(t, home: KeyedSubtree(key: UniqueKey(), child: page()));
          expect(fresh.state.picks.keys, [_aaa]);
          expect(find.text(notice), findsNothing);
        },
      );

      testWidgets('nothing to add: no picks and no note', (t) async {
        await pump(t, home: page());
        expect(fresh.state.picks, isEmpty);
        expect(find.text(notice), findsNothing);
      });
    });
  });
}
