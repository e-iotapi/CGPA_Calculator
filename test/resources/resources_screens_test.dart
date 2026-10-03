// T7.4: Resources, Report this link and the empty state (UI.md §8.11–§8.13).
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/core/cache/cache_first.dart';
import 'package:cgpa_calculator/core/models/programmes.dart';
import 'package:cgpa_calculator/core/resources/resource.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/features/resources/link_sheet.dart';
import 'package:cgpa_calculator/features/resources/resource_course_page.dart';
import 'package:cgpa_calculator/features/resources/resource_courses_page.dart';
import 'package:cgpa_calculator/features/resources/resources_page.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_data.dart';

void main() {
  late FakeFirebaseFirestore db;

  setUp(() {
    db = FakeFirebaseFirestore();
    roleStore = RoleStore(
      db,
      me: 'f20230001@goa.bits-pilani.ac.in',
      myName: 'S',
    );
  });
  tearDown(() => roleStore = null);

  Widget app(Widget home) => MaterialApp(
    theme: AppPalette.light.materialTheme,
    home: Scaffold(body: home),
  );

  test('eyebrow names only the parts that are known', () {
    expect(resourcesEyebrow('goa', dual: true), 'GOA · DUAL DEGREE');
    expect(resourcesEyebrow(null, dual: true), 'DUAL DEGREE');
    expect(resourcesEyebrow('goa', dual: false), 'GOA');
  });

  testWidgets('report needs a reason', (t) async {
    const r = Resource(
      id: 'r1',
      title: 'Past papers',
      url: 'https://drive.google.com/drive/folders/x',
      campus: 'goa',
      department: 'CS',
    );
    await t.pumpWidget(
      app(
        Builder(
          builder:
              (c) => TextButton(
                onPressed: () => reportLink(c, r),
                child: const Text('open'),
              ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    VoidCallback? send() =>
        t.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed;
    expect(find.text('Report this link'), findsOneWidget);
    expect(send(), isNull);
    await t.tap(find.text('Wrong course'));
    await t.pump();
    expect(send(), isNotNull);
  });

  testWidgets('empty department shows the contact', (t) async {
    await db.collection('config').doc('public').set({
      'contactName': 'Owner',
      'contactMethod': 'whatsapp',
      'contactTarget': '9000000001',
      'contactEnabled': true,
    });
    await t.pumpWidget(app(ResourcesEmpty(onRepresentatives: () {})));
    await t.pumpAndSettle();
    expect(find.text('No resources here yet'), findsOneWidget);
    expect(find.text('Find your representatives'), findsOneWidget);
    expect(find.text('Message Owner'), findsOneWidget);
    expect(find.text('On WhatsApp'), findsOneWidget);
    expect(find.textContaining('9000000001'), findsNothing);
  });

  testWidgets('a switched-off contact is hidden', (t) async {
    await db.collection('config').doc('public').set({
      'contactName': 'Owner',
      'contactMethod': 'whatsapp',
      'contactTarget': '9000000001',
      'contactEnabled': false,
    });
    await t.pumpWidget(app(const ResourcesEmpty()));
    await t.pumpAndSettle();
    expect(find.text('No resources here yet'), findsOneWidget);
    expect(find.text('Find your representatives'), findsNothing);
    expect(find.textContaining('Message'), findsNothing);
  });

  // The seeded Goa campus: a B3 A7 student taking CS F372, whose course has a
  // link and a CR (Arjun Rao, WhatsApp shown); Rohan is the CS president.
  group('by course', () {
    setUpAll(seedAll);

    Future<void> open(WidgetTester t, As who, Widget page) async {
      roleStore = RoleStore(sharedDb, me: who.email, myName: who.name);
      myRoles.value = who.roles;
      myUid = 'u-test';
      addTearDown(() => myRoles.value = MyRoles.none);
      await t.pumpWidget(
        MaterialApp(theme: AppPalette.light.materialTheme, home: page),
      );
      await settle(t);
    }

    testWidgets('hub: a card per degree, then Course resources', (t) async {
      await open(t, As.student, const ResourcesPage());
      expect(find.text('Resources'), findsOneWidget);
      expect(find.text('Course resources'), findsOneWidget);
      expect(find.text(programmeName('B3')), findsOneWidget);
      expect(find.text(programmeName('A7')), findsOneWidget);
      // The pills moved to Course resources.
      expect(find.text('This semester'), findsNothing);
      await t.tap(find.text(programmeName('A7')));
      await settle(t);
      // The old degree body: department section, this semester's course links.
      expect(find.textContaining('DEPARTMENT ·'), findsOneWidget);
      expect(find.text('OS lab sheets'), findsOneWidget);
    });

    testWidgets('courses: this semester by default, search covers all', (
      t,
    ) async {
      await open(t, As.student, const ResourceCoursesPage());
      expect(find.textContaining(takingId), findsOneWidget);
      expect(find.text('This semester'), findsOneWidget);
      await t.enterText(find.byType(TextField), 'zzzzzz');
      await t.pump();
      expect(
        find.textContaining('No course code or name matches'),
        findsOneWidget,
      );
      // Any degree: a course the student is not taking is found.
      await t.enterText(find.byType(TextField), 'CS F');
      await t.pump();
      expect(find.textContaining('CS F'), findsWidgets);
      await t.enterText(find.byType(TextField), takingTitle);
      await t.pump();
      await t.tap(find.textContaining(takingId).first);
      await settle(t);
      expect(find.text('OS lab sheets'), findsOneWidget);
    });

    testWidgets('course: links, CR contact, Add a link only for staff', (
      t,
    ) async {
      await open(t, As.student, const ResourceCoursePage(courseId: takingId));
      expect(find.text('OS lab sheets'), findsOneWidget);
      expect(find.text('CR · Arjun Rao'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('Add a link'), findsNothing);
      await open(
        t,
        As.president2,
        const ResourceCoursePage(courseId: takingId),
      );
      expect(find.text('Add a link'), findsOneWidget);
    });

    testWidgets('course: Last updated beside the CR', (t) async {
      // The seed's scheme save stamped the course (ActivityStore.touch).
      await open(t, As.student, const ResourceCoursePage(courseId: takingId));
      expect(find.textContaining('Last updated '), findsOneWidget);
    });

    testWidgets('a reopened course screen draws its last copy at once', (
      t,
    ) async {
      await open(t, As.student, const ResourceCoursePage(courseId: takingId));
      // The first visit warmed the stores; a second opens with no spinner.
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(
        MaterialApp(
          theme: AppPalette.light.materialTheme,
          home: const ResourceCoursePage(courseId: takingId),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('OS lab sheets'), findsOneWidget);
    });

    testWidgets('the link sheet stays above the keyboard and saves', (t) async {
      await open(
        t,
        As.president2,
        const ResourceCoursePage(courseId: takingId),
      );
      t.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(t.view.resetViewInsets);
      await t.tap(find.text('Add a link'));
      await settle(t);
      expect(find.byType(LinkSheet), findsOneWidget);
      final field = find.widgetWithText(TextField, 'Name');
      expect(field, findsOneWidget);
      expect(t.getRect(field).bottom, lessThan(844 - 300 / 3));
      // A bad link is refused in the sheet, not swallowed.
      await t.enterText(field, 'Slides');
      await t.enterText(find.widgetWithText(TextField, 'Link'), 'nope');
      await t.tap(find.text('Save'));
      await t.pump();
      expect(find.textContaining('Paste a web link'), findsOneWidget);
    });
  });
}
