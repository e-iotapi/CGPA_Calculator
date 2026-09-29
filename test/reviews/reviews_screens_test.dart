// Step 10, as registered in test/PREREGISTERED_10_11.md (R1–R12).
import 'dart:io';

import 'package:cgpa_calculator/admin/dept_reviews.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/core/catalog/catalog.dart';
import 'package:cgpa_calculator/core/models/offering.dart';
import 'package:cgpa_calculator/core/professors/professor.dart';
import 'package:cgpa_calculator/core/reviews/review.dart';
import 'package:cgpa_calculator/core/reviews/review_store.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/core/storage/courses.dart';
import 'package:cgpa_calculator/core/storage/offerings.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/marks/official.dart';
import 'package:cgpa_calculator/features/reviews/course_reviews.dart';
import 'package:cgpa_calculator/features/reviews/review_form.dart';
import 'package:cgpa_calculator/features/reviews/review_widgets.dart';
import 'package:cgpa_calculator/features/reviews/reviews_home.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show SetOptions;
import 'package:cgpa_calculator/shared/widgets/pill_button.dart';
import 'package:cgpa_calculator/shared/widgets/confirm_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

const me = 'f20230456@goa.bits-pilani.ac.in';
const course = 'CS F211';

class _Offerings implements OfferingSource {
  _Offerings(this.o);
  final Offering? o;
  @override
  Future<Offering?> get(String courseId, String campus, String term) async => o;
}

void main() {
  late Directory dir;
  late FakeFirebaseFirestore db;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('hive_reviews');
    Hive.init(dir.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(CourseAdapter());
    await Hive.openBox<Course>(coursesBoxName);
  });

  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  setUp(() {
    // Tall enough that every list is built whole.
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(800, 2400);
    view.devicePixelRatio = 1;
    db = FakeFirebaseFirestore();
    roleStore = RoleStore(db, me: me, myName: 'Student');
    myUid = 'u-me';
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

  /// [page] pushed above a launcher, so it can pop.
  Widget pushed(Widget page) => app(
    Builder(
      builder:
          (c) => Scaffold(
            body: TextButton(
              onPressed:
                  () => Navigator.of(
                    c,
                  ).push(MaterialPageRoute<void>(builder: (_) => page)),
              child: const Text('open'),
            ),
          ),
    ),
  );

  ReviewStore as(String uid) => ReviewStore(db, uid: uid, roles: roleStore);

  Future<void> review(
    String uid, {
    String id = course,
    String? prof,
    int stars = 4,
    bool take = true,
    String? text,
  }) => as(uid).save(
    courseId: id,
    campus: 'goa',
    term: '2024-25-1',
    professorId: prof,
    stars: stars,
    recommend: take,
    text: text,
  );

  Future<void> professor(String id, String name, String campus) =>
      db.collection('professors').doc(id).set({
        'name': name,
        'campus': campus,
        'department': 'CS',
        'aliases': <String>[],
        'mergedIds': <String>[],
        'active': true,
        'nameTokens': nameTokens(name).toList(),
      });

  Future<void> courses(WidgetTester t, List<Course> list) =>
      t.runAsync(() async {
        final box = Hive.box<Course>(coursesBoxName);
        await box.clear();
        await box.addAll(list);
      });

  Course taking(String id, {String sem = '2 - 1', int grade = -8}) => Course(
    title: id,
    sem: sem,
    id: id,
    grade1: grade,
    grade2: -2,
    discipline: 'A7',
    credits: 3,
    elective: 'CDC',
  );

  Finder tileOf(String text) =>
      find.ancestor(of: find.text(text), matching: find.byType(ReviewTile));

  String titleOf(String id) =>
      catalog.master.firstWhere((m) => m.id == id).title;

  testWidgets('R1 signed out, ReviewsHome asks to sign in', (t) async {
    roleStore = null;
    await t.pumpWidget(app(const ReviewsHome()));
    await t.pumpAndSettle();
    expect(
      find.text('Sign in with your BITS account to read reviews.'),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('Your reviews tab counts mine', (t) async {
    await review('u-me');
    await review('u-me', id: 'EEE F211', stars: 3, take: false);
    // Opened here only: other tests save reviews, and an open settings box
    // would make those saves real Hive writes outside runAsync.
    await t.runAsync(() async {
      final s = await Hive.openBox('settingsBox');
      await s.put('myReviews', [course, 'EEE F211']);
    });
    addTearDown(
      () => t.runAsync(() => Hive.box('settingsBox').deleteFromDisk()),
    );
    await t.pumpWidget(app(const ReviewsHome()));
    await t.pumpAndSettle();
    expect(find.text('Your reviews · 2'), findsOneWidget);
    await t.tap(find.text('Your reviews · 2'));
    await t.pumpAndSettle();
    expect(find.text('Search your reviews'), findsOneWidget);
    expect(find.text('EEE F211'), findsOneWidget);
  });

  testWidgets('R2 most reviewed on the campus, by count', (t) async {
    await courses(t, []);
    Future<void> stat(String id, int count) =>
        db.collection('reviewIndex').doc('goa').set({
          'c': {
            id: {
              'count': count,
              'starSum': count * 4,
              'recommendCount': count ~/ 2,
            },
          },
        }, SetOptions(merge: true));
    await stat('MATH F111', 5);
    await stat('CS F211', 12);
    await stat('BITS F111', 2);
    await t.pumpWidget(app(const ReviewsHome()));
    await t.pumpAndSettle();
    expect(find.text('MOST REVIEWED AT GOA'), findsOneWidget);
    final ys = [
      for (final id in ['CS F211', 'MATH F111', 'BITS F111'])
        t.getTopLeft(find.text('$id · ${titleOf(id)}')).dy,
    ];
    expect(ys, orderedEquals([...ys]..sort()));
    expect(find.text('50% take it · 12 reviews'), findsOneWidget);
    expect(find.text('50% take it · 2 reviews'), findsOneWidget);
  });

  testWidgets('R3 a professor by any word of their name, on my campus', (
    t,
  ) async {
    await courses(t, []);
    await professor('pr-goa', 'Ramesh Menon', 'goa');
    await professor('pr-pil', 'Ramesh Menon', 'pilani');
    await t.pumpWidget(app(const ReviewsHome()));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'men');
    await t.pump(const Duration(milliseconds: 400));
    await t.pumpAndSettle();
    expect(find.text('PROFESSORS'), findsOneWidget);
    expect(find.text('Ramesh Menon'), findsOneWidget);
  });

  testWidgets('R4 a course by code', (t) async {
    await courses(t, []);
    await t.pumpWidget(app(const ReviewsHome()));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'CS F21');
    await t.pump(const Duration(milliseconds: 400));
    await t.pumpAndSettle();
    expect(find.text('COURSES'), findsOneWidget);
    expect(find.text('CS F211 · ${titleOf('CS F211')}'), findsOneWidget);
  });

  testWidgets('R5 a professor page lists every course they taught', (t) async {
    await courses(t, []);
    await professor('pr-goa', 'Ramesh Menon', 'goa');
    Future<void> offer(String id, String term) => db
        .collection('courses')
        .doc(id)
        .collection('offerings')
        .doc('goa_$term')
        .set({
          'courseId': id,
          'campus': 'goa',
          'term': term,
          'professors': ['pr-goa'],
          'components': <Object>[],
        });
    await offer('CS F211', '2024-25-1');
    await offer('CS F212', '2025-26-2');
    await review('u1', prof: 'pr-goa');
    await t.pumpWidget(app(const ReviewsHome()));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'menon');
    await t.pump(const Duration(milliseconds: 400));
    await t.pumpAndSettle();
    expect(
      find.text('No course code or name matches “menon”.'),
      findsOneWidget,
    );
    expect(find.textContaining('One box for both.'), findsOneWidget);
    await t.tap(find.text('Ramesh Menon'));
    await t.pumpAndSettle();
    expect(find.text('COURSES TAUGHT'), findsOneWidget);
    expect(find.text('CS F211 · ${titleOf('CS F211')}'), findsOneWidget);
    expect(find.text('CS F212 · ${titleOf('CS F212')}'), findsOneWidget);
    expect(find.textContaining('· 1 review'), findsOneWidget);
    expect(find.textContaining('· 0 reviews'), findsOneWidget);
  });

  Future<void> threeReviews() async {
    await professor('pr-a', 'Asha Rao', 'goa');
    await professor('pr-b', 'Bala Iyer', 'goa');
    await review('u1', prof: 'pr-a', stars: 4, text: 'first');
    await review('u2', prof: 'pr-b', stars: 2, text: 'second');
    await review('u3', prof: 'pr-a', stars: 5, text: 'hidden one');
    final hidden = (await as('u3').mine(course))!;
    await as('u-me').hide(hidden, 'Names a person');
  }

  testWidgets('R6 hidden reviews stay out; the card shows the average', (
    t,
  ) async {
    await courses(t, []);
    await threeReviews();
    await t.pumpWidget(app(const CourseReviewsPage(courseId: course)));
    await t.pumpAndSettle();
    expect(find.text('first'), findsOneWidget);
    expect(find.text('second'), findsOneWidget);
    expect(find.text('hidden one'), findsNothing);
    await t.tap(find.text('All'));
    await t.pumpAndSettle();
    expect(find.text('3.0'), findsOneWidget);
  });

  testWidgets('R7 a Taught by pill filters to that professor', (t) async {
    await courses(t, []);
    await threeReviews();
    await t.pumpWidget(app(const CourseReviewsPage(courseId: course)));
    await t.pumpAndSettle();
    await t.tap(find.text('Asha Rao'));
    await t.pumpAndSettle();
    expect(find.text('first'), findsOneWidget);
    expect(find.text('second'), findsNothing);
  });

  testWidgets('R8 Helpful counts once in the database; not on my own', (
    t,
  ) async {
    await courses(t, []);
    await professor('pr-a', 'Asha Rao', 'goa');
    await review('u1', prof: 'pr-a', text: 'first');
    await review('u-me', prof: 'pr-a', text: 'mine');
    await t.pumpWidget(app(const CourseReviewsPage(courseId: course)));
    await t.pumpAndSettle();
    await t.tap(
      find.descendant(
        of: tileOf('first'),
        matching: find.textContaining('Helpful'),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Marked helpful.'), findsOneWidget);
    final other = hashedId('u1', course);
    final doc =
        await db
            .collection('reviews')
            .doc(course)
            .collection('entries')
            .doc(other)
            .get();
    expect(doc.data()!['helpful'], 1);
    expect(
      find.descendant(
        of: tileOf('mine'),
        matching: find.textContaining('Helpful'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: tileOf('mine'), matching: find.text('Report')),
      findsNothing,
    );
  });

  testWidgets('R9 editing: no Delete; counters move by the difference', (
    t,
  ) async {
    await courses(t, []);
    await professor('pr-a', 'Asha Rao', 'goa');
    await review('u1', prof: 'pr-a', stars: 3);
    await review('u-me', prof: 'pr-a', stars: 4, text: 'mine');
    final before = await as('u-me').stats(course, 'goa');
    final mine = (await as('u-me').mine(course))!;
    await t.pumpWidget(
      pushed(ReviewFormPage(courseId: course, existing: mine)),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.text('Delete'), findsNothing);
    final stars = find.descendant(
      of: find.byType(StarPicker),
      matching: find.byType(InkWell),
    );
    await t.tap(stars.at(1));
    await t.pump();
    await t.tap(find.text('Save changes'));
    await t.pumpAndSettle();
    expect((await as('u-me').mine(course))!.stars, 2);
    final after = await as('u-me').stats(course, 'goa');
    expect(after.count, before.count);
    expect(after.starSum, before.starSum - 2);
  });

  testWidgets('R10 Post waits for stars and an answer, and 600 characters', (
    t,
  ) async {
    await courses(t, [taking(course, grade: 9)]);
    await professor('pr-a', 'Asha Rao', 'goa');
    offeringSource = _Offerings(
      const Offering(
        courseId: course,
        campus: 'goa',
        term: '2024-25-1',
        components: [],
        updatedAt: 0,
        professors: ['pr-a'],
      ),
    );
    await t.pumpWidget(pushed(const ReviewFormPage(courseId: course)));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    VoidCallback? post() =>
        t.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed;
    expect(post(), isNull);
    final stars = find.descendant(
      of: find.byType(StarPicker),
      matching: find.byType(InkWell),
    );
    await t.tap(stars.at(3));
    await t.pump();
    expect(post(), isNull);
    await t.tap(find.text('Yes'));
    await t.pump();
    expect(post(), isNotNull);
    await t.enterText(find.byType(TextField), 'x' * 601);
    await t.pump();
    expect(post(), isNull);
  });

  Future<Review> reported() async {
    await professor('pr-a', 'Asha Rao', 'goa');
    await review('u1', prof: 'pr-a', text: 'reported one');
    final r = (await as('u1').mine(course))!;
    await as('u2').report(r);
    return r;
  }

  Future<ReviewStats> courseStats() => as('u-me').stats(course, 'goa');

  testWidgets('R11 hide with a reason, logged; unhide puts it back', (t) async {
    await courses(t, []);
    final r = await reported();
    await t.pumpWidget(app(const DeptReviews(campus: 'goa', dept: 'CS')));
    await t.pumpAndSettle();
    expect(find.text('reported one'), findsOneWidget);
    expect(find.text('Reported 1'), findsOneWidget);
    expect(find.text('1 REPORT'), findsOneWidget);
    await t.tap(find.widgetWithText(PillButton, 'Hide'));
    await t.pumpAndSettle();
    await t.enterText(
      find.descendant(
        of: find.byType(AppDialog),
        matching: find.byType(TextField),
      ),
      'Names a person',
    );
    await t.tap(
      find.descendant(of: find.byType(AppDialog), matching: find.text('Hide')),
    );
    await t.pumpAndSettle();
    final entry = db
        .collection('reviews')
        .doc(course)
        .collection('entries')
        .doc(r.id);
    expect((await entry.get()).data()!['hidden'], isTrue);
    expect((await courseStats()).count, 0);
    expect((await db.collection('audit').get()).docs, hasLength(1));

    await t.tap(find.text('Hidden 1'));
    await t.pumpAndSettle();
    expect(find.text('reported one'), findsOneWidget);
    await t.tap(find.text('Unhide'));
    await t.pumpAndSettle();
    expect((await entry.get()).data()!['hidden'], isFalse);
    expect((await courseStats()).count, 1);
  });

  testWidgets('R12 an empty reason hides nothing', (t) async {
    await courses(t, []);
    final r = await reported();
    await t.pumpWidget(app(const DeptReviews(campus: 'goa', dept: 'CS')));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(PillButton, 'Hide'));
    await t.pumpAndSettle();
    await t.tap(
      find.descendant(of: find.byType(AppDialog), matching: find.text('Hide')),
    );
    await t.pumpAndSettle();
    final entry =
        await db
            .collection('reviews')
            .doc(course)
            .collection('entries')
            .doc(r.id)
            .get();
    expect(entry.data()!['hidden'], isFalse);
    expect((await courseStats()).count, 1);
    expect((await db.collection('audit').get()).docs, isEmpty);
  });
}
