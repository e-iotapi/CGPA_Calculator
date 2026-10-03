// U10: the compulsory-reviews gate on the student's screens and the staff row.
import 'dart:io';

import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/core/cache/cache_first.dart';
import 'package:cgpa_calculator/core/models/elective.dart';
import 'package:cgpa_calculator/core/models/offering.dart';
import 'package:cgpa_calculator/core/reviews/gate.dart';
import 'package:cgpa_calculator/core/reviews/gate_store.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/core/storage/courses.dart';
import 'package:cgpa_calculator/core/storage/offerings.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/marks/official.dart';
import 'package:cgpa_calculator/features/reviews/compulsory_pick.dart';
import 'package:cgpa_calculator/features/reviews/course_reviews.dart';
import 'package:cgpa_calculator/features/reviews/gate_ui.dart';
import 'package:cgpa_calculator/features/reviews/review_widgets.dart';
import 'package:cgpa_calculator/features/reviews/reviews_home.dart';
import 'package:cgpa_calculator/script.dart' as script;
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/search_box.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

const _me = 'f20230456@goa.bits-pilani.ac.in';

class _Offerings implements OfferingSource {
  @override
  Future<Offering?> get(String courseId, String campus, String term) async =>
      Offering(
        courseId: courseId,
        campus: campus,
        term: term,
        components: const [],
        updatedAt: 0,
      );
}

Course _c(String id, String tag, {String sem = '2 - 1'}) => Course(
  title: 'Title $id',
  id: id,
  credits: 3,
  grade1: 9,
  grade2: -2,
  discipline: 'A7',
  sem: sem,
  elective: tag,
);

void main() {
  late FakeFirebaseFirestore db;

  setUpAll(() async {
    Hive.init((await Directory.systemTemp.createTemp('gate_ui')).path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(CourseAdapter());
    await Hive.openBox<Course>(coursesBoxName);
    await openSharedCache();
    await Hive.openBox('settingsBox');
  });

  setUp(() async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(800, 2400);
    view.devicePixelRatio = 1;
    db = FakeFirebaseFirestore();
    roleStore = RoleStore(db, me: _me, myName: 'Student');
    myUid = 'u-me';
    offeringSource = _Offerings();
    script.currentsem = '2 - 2';
    script.selecteddiscipline = '----';
    await Hive.box<Course>(coursesBoxName).clear();
    await sharedCacheBox!.clear();
    await Hive.box('settingsBox').clear();
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
    roleStore = null;
    myUid = null;
    offeringSource = null;
  });

  Widget app(Widget home) =>
      MaterialApp(theme: AppPalette.light.materialTheme, home: home);

  /// Lets writes started under fake time finish on real time; a stuck one
  /// would block the box for every later test.
  Future<void> settle(WidgetTester t) async {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await t.pump();
  }

  /// Three electives taken, and the gate on and saved for goa.
  Future<void> locked(WidgetTester t, {bool on = true}) => t.runAsync(() async {
    await Hive.box<Course>(coursesBoxName).addAll([
      _c('HSS F101', Elective.humanity.tag),
      _c('BITS F201', Elective.open.tag),
      _c('CS F211', Elective.cdc1.tag), // a CDC never counts
    ]);
    await db.collection('reviewGate').doc('goa').set({'on': on});
    await GateStore(roleStore!).of('goa');
  });

  testWidgets('locked: no search, no rows, the way out', (t) async {
    await locked(t);
    await t.pumpWidget(app(const ReviewsHome()));
    await t.pump();
    expect(find.text('Review your electives'), findsOneWidget);
    expect(find.text('Course or professor'), findsNothing);
    expect(find.textContaining('Reviews are locked'), findsOneWidget);
    // No count anywhere on the banner.
    expect(find.textContaining('3'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await settle(t);
  });

  testWidgets('locked course page hides reviews, keeps resources', (t) async {
    await locked(t);
    await t.pumpWidget(app(const CourseReviewsPage(courseId: 'HSS F101')));
    await t.pump();
    expect(find.text('Review your electives'), findsOneWidget);
    expect(find.byTooltip('Course resources'), findsOneWidget);
    expect(find.text('Search reviews'), findsNothing);
    await settle(t);
  });

  testWidgets('gate never loaded, first year, or off: not locked', (t) async {
    // Never loaded: unlocked.
    await t.runAsync(
      () => Hive.box<Course>(coursesBoxName).add(_c('HSS F101', 'Humanity')),
    );
    expect(myGate('goa'), isNot(GateState.locked));
    // On, but first year; and on with the gate off.
    await locked(t);
    expect(myGate('goa'), GateState.locked);
    script.currentsem = '1 - 2';
    expect(myGate('goa'), GateState.exempt);
  });

  testWidgets('a tick with no stars keeps Post off; search adds a course', (
    t,
  ) async {
    await locked(t);
    await t.runAsync(
      () => Hive.box<Course>(coursesBoxName).add(_c('EEE F111', 'CDC')),
    );
    await t.pumpWidget(app(const CompulsoryPickPage()));
    await t.pumpAndSettle();
    final post = find.widgetWithText(PrimaryButton, 'Post 2 reviews');
    expect(t.widget<PrimaryButton>(post).onPressed, isNull);
    await t.enterText(
      find.descendant(
        of: find.byType(SearchBox),
        matching: find.byType(TextField),
      ),
      'EEE F111',
    );
    await t.pump();
    await t.tap(find.text('EEE F111 · Title EEE F111'));
    await t.pump();
    expect(find.text('Post 3 reviews'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await settle(t);
  });

  // Last: its saves leave the shared cache busy for any test after it.
  testWidgets('CompulsoryPick posts the ticked electives and unlocks', (
    t,
  ) async {
    await locked(t);
    await t.pumpWidget(
      app(
        Builder(
          builder:
              (c) => Scaffold(
                body: TextButton(
                  onPressed:
                      () => Navigator.of(c).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const CompulsoryPickPage(),
                        ),
                      ),
                  child: const Text('open'),
                ),
              ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    // Both electives share a semester, so both start ticked; no CDC.
    expect(find.text('HSS F101 · Title HSS F101'), findsOneWidget);
    expect(find.text('CS F211 · Title CS F211'), findsNothing);
    expect(find.text('Post 2 reviews'), findsOneWidget);
    for (final i in [0, 1]) {
      await t.tap(
        find
            .descendant(
              of: find.byType(Stars).at(i),
              matching: find.byType(Icon),
            )
            .at(3),
      );
      await t.tap(find.text('Yes').at(i));
    }
    await t.pump();
    await t.tap(find.text('Post 2 reviews'));
    // Saves finish on real time (Hive deletes under the cache).
    for (
      var i = 0;
      i < 10 && find.text('Reviews unlocked').evaluate().isEmpty;
      i++
    ) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await t.pump();
    }
    expect(find.text('Reviews unlocked'), findsOneWidget);
    await t.tap(find.text('Done'));
    await t.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    final mine = await t.runAsync(
      () => Future.wait([
        reviewStore!.mine('HSS F101'),
        reviewStore!.mine('BITS F201'),
      ]),
    );
    expect(mine!.every((r) => r != null && r.stars == 4), isTrue);
  });
}
