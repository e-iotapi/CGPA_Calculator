// Step 11, as registered in test/PREREGISTERED_10_11.md (S1–S14).
import 'dart:io';

import 'package:cgpa_calculator/admin/roster.dart';
import 'package:cgpa_calculator/admin/succession.dart';
import 'package:cgpa_calculator/admin/volunteers.dart';
import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/router.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/core/catalog/catalog.dart';
import 'package:cgpa_calculator/core/models/programmes.dart';
import 'package:cgpa_calculator/core/roles/contacts.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/core/roles/volunteer_message.dart';
import 'package:cgpa_calculator/core/storage/courses.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/marks/official.dart';
import 'package:cgpa_calculator/features/more/more_page.dart';
import 'package:cgpa_calculator/features/more/representatives_page.dart';
import 'package:cgpa_calculator/features/resources/resources_page.dart';
import 'package:cgpa_calculator/features/reviews/reviews_home.dart';
import 'package:cgpa_calculator/features/roles/rep_profile.dart';
import 'package:cgpa_calculator/script.dart' as script;
import 'package:cgpa_calculator/shared/layout/responsive.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/app_nav.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';

const pres = 'f20230802@goa.bits-pilani.ac.in';
const student = 'f20230456@goa.bits-pilani.ac.in';
const next = 'f20240001@goa.bits-pilani.ac.in';

final far = DateTime.now().add(const Duration(days: 100));

Grant presidency({DateTime? until}) => Grant(
  role: GrantRole.dept,
  email: pres,
  name: 'Meera Iyer',
  campus: 'goa',
  scope: 'ELEC',
  programme: 'A3',
  active: true,
  expiresAt: until ?? far,
);

void main() {
  late Directory dir;
  late FakeFirebaseFirestore db;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('hive_step11');
    Hive.init(dir.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(CourseAdapter());
    await Hive.openBox<Course>(coursesBoxName);
  });

  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(800, 2400);
    view.devicePixelRatio = 1;
    db = FakeFirebaseFirestore();
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
    roleStore = null;
    myRoles.value = MyRoles.none;
    profileDue.value = false;
    myContactSummary.value = null;
  });

  void signIn(String email, {String name = 'Me', MyRoles? roles}) {
    roleStore = RoleStore(db, me: email, myName: name);
    myRoles.value = roles ?? MyRoles(email: email);
  }

  Widget app(Widget home) =>
      MaterialApp(theme: AppPalette.light.materialTheme, home: home);

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

  Future<void> courses(WidgetTester t, List<String> ids) =>
      t.runAsync(() async {
        final box = Hive.box<Course>(coursesBoxName);
        await box.clear();
        await box.addAll([
          for (final id in ids)
            Course(
              title: id,
              sem: '2 - 1',
              id: id,
              grade1: -8,
              grade2: -2,
              discipline: 'A3',
              credits: 3,
              elective: 'CDC',
            ),
        ]);
      });

  Future<void> seedGrant(Grant g, {Map<String, Object?> extra = const {}}) =>
      db.collection('grants').doc(g.id).set({
        'role': g.role.key,
        'email': g.email,
        'name': g.name,
        'campus': g.campus,
        'scope': g.scope,
        if (g.programme != null) 'programme': g.programme,
        'active': g.active,
        'expiresAt': Timestamp.fromDate(g.expiresAt),
        ...extra,
      });

  Future<void> listed(
    String email,
    String name,
    List<(String, String, DateTime)> roles, {
    bool email_ = false,
    String? whatsapp,
    String? phone,
  }) => db.collection('directory').doc(email).set({
    'name': name,
    'campus': 'goa',
    'roles': [
      for (final (role, scope, until) in roles)
        {'role': role, 'scope': scope, 'until': Timestamp.fromDate(until)},
    ],
    if (email_) 'email': email,
    if (whatsapp != null) 'whatsapp': whatsapp,
    if (phone != null) 'phone': phone,
  });

  VoidCallback? button(WidgetTester t, String label) =>
      t
          .widget<PrimaryButton>(find.widgetWithText(PrimaryButton, label))
          .onPressed;

  // ---- Contacts ------------------------------------------------------------

  testWidgets('S1 RepProfile: a phone and one field for students', (t) async {
    signIn(
      pres,
      name: 'Meera Iyer',
      roles: MyRoles(email: pres, grants: [presidency()]),
    );
    await t.pumpWidget(pushed(const RepProfilePage()));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(button(t, 'Save'), isNull);
    await t.enterText(find.widgetWithText(TextField, 'Phone'), '98765 43210');
    await t.pump();
    expect(button(t, 'Save'), isNull);
    await t.tap(find.widgetWithText(SwitchListTile, 'Email'));
    await t.pump();
    expect(button(t, 'Save'), isNotNull);
    await t.tap(find.widgetWithText(PrimaryButton, 'Save'));
    await t.pumpAndSettle();
    final staff = await db.collection('staffContacts').doc(pres).get();
    expect(staff.data()!['phone'], '98765 43210');
    final dir = await db.collection('directory').doc(pres).get();
    expect(dir.data()!['email'], pres);
  });

  testWidgets('S2 RepProfile forced: Before you start, then Switch role', (
    t,
  ) async {
    signIn(
      pres,
      name: 'Meera Iyer',
      roles: MyRoles(email: pres, grants: [presidency()]),
    );
    profileDue.value = true;
    final router = GoRouter(
      initialLocation: '/welcome',
      routes: [
        GoRoute(
          path: '/welcome',
          builder: (_, _) => RepProfilePage(onSignOut: () {}),
        ),
        GoRoute(path: '/roles', builder: (_, _) => const Text('ROLES PAGE')),
      ],
    );
    await t.pumpWidget(
      MaterialApp.router(
        theme: AppPalette.light.materialTheme,
        routerConfig: router,
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Before you start'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    await t.enterText(find.widgetWithText(TextField, 'Phone'), '98765 43210');
    await t.tap(find.widgetWithText(SwitchListTile, 'Email'));
    await t.pump();
    await t.tap(find.widgetWithText(PrimaryButton, 'Save and continue'));
    await t.pumpAndSettle();
    expect(profileDue.value, isFalse);
    expect(find.text('ROLES PAGE'), findsOneWidget);
  });

  test('S3 checkProfile sets and clears profileDue', () async {
    signIn(
      pres,
      name: 'Meera Iyer',
      roles: MyRoles(email: pres, grants: [presidency()]),
    );
    await checkProfile();
    expect(profileDue.value, isTrue);
    await ContactStore(roleStore!).saveProfile(
      myRoles.value,
      name: 'Meera Iyer',
      phone: '98765 43210',
      showEmail: true,
    );
    await checkProfile();
    expect(profileDue.value, isFalse);
  });

  test('S4 the router sends everything to welcome while it is due', () {
    profileDue.value = true;
    expect(profileGate('/reviews'), '/welcome');
    expect(profileGate('/'), '/welcome');
    expect(profileGate('/welcome'), isNull);
    profileDue.value = false;
    expect(profileGate('/reviews'), isNull);
  });

  // ---- Representatives and volunteers --------------------------------------

  testWidgets('S5 Representatives: live roles, chosen fields, a handover', (
    t,
  ) async {
    signIn(student, name: 'Rohan');
    await courses(t, ['EEE F211']);
    final now = DateTime.now();
    await listed('p1@x', 'Pres One', [
      ('dept', 'ELEC', now.add(const Duration(days: 300))),
    ], email_: true);
    await listed('p2@x', 'Pres Two', [
      ('dept', 'ELEC', now.add(const Duration(days: 10))),
    ], whatsapp: '98765 43210');
    await listed('cr@x', 'Cr Person', [
      ('course', 'EEE F211', now.add(const Duration(days: 100))),
    ], phone: '90000 00001');
    await listed('old@x', 'Old CR', [
      ('course', 'EEE F211', now.subtract(const Duration(days: 1))),
    ], email_: true);
    await t.pumpWidget(app(const RepresentativesPage()));
    await t.pumpAndSettle();
    Finder card(String name) =>
        find.ancestor(of: find.text(name), matching: find.byType(AppCard));
    // One card for the president in office; the successor is named on it.
    expect(find.text('Pres Two'), findsOneWidget);
    expect(find.text('Pres One is taking over'), findsOneWidget);
    expect(find.textContaining('HANDOVER IN'), findsOneWidget);
    expect(find.text('Cr Person'), findsNothing);
    expect(find.text('Cr Person · phone'), findsOneWidget);
    expect(find.textContaining('Old CR'), findsNothing);
    expect(
      find.descendant(of: card('Pres Two'), matching: find.text('WhatsApp')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card('Pres Two'), matching: find.text('Email')),
      findsNothing,
    );
    // The CR's phone is a round button, masked in its tooltip.
    expect(find.byTooltip('90xxx 00xxx'), findsOneWidget);
    expect(find.text('90000 00001'), findsNothing);
    expect(find.text('Volunteer'), findsNothing);
  });

  testWidgets('president card shows shared channels', (t) async {
    signIn(student, name: 'Rohan');
    await courses(t, ['EEE F211']);
    await listed(
      'p1@x',
      'Pres One',
      [('dept', 'ELEC', far)],
      email_: true,
      whatsapp: '98765 43210',
    );
    await t.pumpWidget(app(const RepresentativesPage()));
    await t.pumpAndSettle();
    expect(
      find.text('Department president · email and WhatsApp'),
      findsOneWidget,
    );
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.textContaining('HANDOVER'), findsNothing);
  });

  testWidgets('no CR shows Volunteer', (t) async {
    signIn(student, name: 'Rohan');
    await courses(t, ['CS F211']);
    await t.pumpWidget(app(const RepresentativesPage()));
    await t.pumpAndSettle();
    expect(find.text('No CR appointed yet'), findsOneWidget);
    expect(find.text('Volunteer'), findsOneWidget);
    expect(find.textContaining('You are a CR'), findsNothing);
  });

  testWidgets('S6 no CR: Volunteer, then Withdraw', (t) async {
    signIn(student, name: 'Rohan');
    await courses(t, ['EEE F211', 'CS F211']);
    await listed('cr@x', 'Cr Person', [
      ('course', 'EEE F211', far),
    ], phone: '90000 00001');
    await t.pumpWidget(app(const RepresentativesPage()));
    await t.pumpAndSettle();
    expect(find.text('Volunteer'), findsOneWidget);
    await t.tap(find.text('Volunteer'));
    await t.pumpAndSettle();
    final ref = db
        .collection('volunteers')
        .doc(volunteerId('goa', 'CS F211', student));
    expect((await ref.get()).data()!['open'], isTrue);
    expect(find.text('Withdraw'), findsOneWidget);
    await t.tap(find.text('Withdraw'));
    await t.pumpAndSettle();
    expect((await ref.get()).data()!['open'], isFalse);
  });

  testWidgets('S7 Roster › Volunteers: by course, copy, dismiss', (t) async {
    signIn(
      pres,
      name: 'Meera Iyer',
      roles: MyRoles(email: pres, grants: [presidency()]),
    );
    final term = currentTerm(DateTime.now());
    for (final (email, name) in [
      (student, 'Rohan Shetty'),
      (next, 'Asha Rao'),
    ]) {
      await ContactStore(
        RoleStore(db, me: email, myName: name),
      ).volunteer('goa', 'EEE F211', name: name, term: term);
    }
    String? copied;
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await t.pumpWidget(
      app(
        Scaffold(
          body: ListView(children: const [VolunteersTab(campus: 'goa')]),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('EEE F211 · 2 offers'), findsOneWidget);
    await t.tap(find.byTooltip('Copy the message for WhatsApp'));
    await t.pumpAndSettle();
    expect(
      copied,
      volunteerMessage(
        courseCode: 'EEE F211',
        courseTitle: catalog.master.firstWhere((m) => m.id == 'EEE F211').title,
        volunteers: ['Asha Rao', 'Rohan Shetty'],
        deadline: deadlineText(defaultDeadline(DateTime.now())),
        presidentName: 'Meera Iyer',
        departmentName: 'Electronics',
        deptKey: 'ELEC',
        campusName: 'Goa',
      ),
    );
    expect(
      copied,
      contains('The Class Representative will be chosen by election.'),
    );
    await t.tap(find.text('Dismiss').first);
    await t.pumpAndSettle();
    final open =
        await db.collection('volunteers').where('open', isEqualTo: true).get();
    expect(open.docs, hasLength(1));
  });

  test('S8 appointing a CR closes the course offers in its batch', () async {
    final term = currentTerm(DateTime.now());
    for (final email in [student, next]) {
      await ContactStore(
        RoleStore(db, me: email, myName: 'X'),
      ).volunteer('goa', 'EEE F211', name: 'X', term: term);
    }
    await db.collection('people').doc(student).set({
      'name': 'Rohan',
      'campus': 'goa',
    });
    final roles = RoleStore(db, me: pres, myName: 'Meera Iyer');
    final ok = await roles.appoint(
      role: GrantRole.course,
      email: student,
      campus: 'goa',
      scope: 'EEE F211',
      expiresAt: far,
      closeOffers: [
        volunteerId('goa', 'EEE F211', student),
        volunteerId('goa', 'EEE F211', next),
      ],
    );
    expect(ok, isTrue);
    final g =
        await db
            .collection('grants')
            .doc(grantId(GrantRole.course, 'goa', 'EEE F211', student))
            .get();
    expect(g.data()!['active'], isTrue);
    final open =
        await db.collection('volunteers').where('open', isEqualTo: true).get();
    expect(open.docs, isEmpty);
  });

  // ---- Succession ----------------------------------------------------------

  Future<void> presidentOfElec() async {
    signIn(
      pres,
      name: 'Meera Iyer',
      roles: MyRoles(email: pres, grants: [presidency()]),
    );
    await seedGrant(presidency());
    await db.collection('people').doc(next).set({
      'name': 'Asha Rao',
      'campus': 'goa',
    });
    await db.collection('config').doc('grantTerms').set({
      'crDays': 183,
      'presidentDays': 365,
      'adminDays': 730,
    });
  }

  testWidgets('S9 Succession: campus, unknown, then what happens', (t) async {
    await presidentOfElec();
    await t.pumpWidget(app(const Succession(campus: 'goa', dept: 'ELEC')));
    await t.pumpAndSettle();
    Future<void> lookUp(String address) async {
      await t.enterText(find.byType(TextField), address);
      await t.pump();
      await t.tap(find.text('Look up'));
      await t.pumpAndSettle();
    }

    await lookUp('f20240001@pilani.bits-pilani.ac.in');
    expect(find.text('A successor must be on Goa.'), findsOneWidget);
    await lookUp('f20249999@goa.bits-pilani.ac.in');
    expect(find.textContaining('Can not be found'), findsOneWidget);
    await lookUp(next);
    expect(find.text('2 · WHAT HAPPENS'), findsOneWidget);
    final ends = RoleStore.outgoingExpiry(presidency(), DateTime.now());
    expect(find.textContaining(shortDay(ends, year: true)), findsOneWidget);
  });

  testWidgets('S10 SuccessionConfirm: the code is typed, then it happens', (
    t,
  ) async {
    await presidentOfElec();
    final router = GoRouter(
      initialLocation: '/confirm',
      routes: [
        GoRoute(
          path: '/confirm',
          builder:
              (_, _) => const SuccessionConfirm(
                campus: 'goa',
                dept: 'ELEC',
                to: next,
              ),
        ),
        GoRoute(
          path: '/maintain/goa/ELEC',
          builder: (_, _) => const Text('DEPT HOME'),
        ),
      ],
    );
    await t.pumpWidget(
      MaterialApp.router(
        theme: AppPalette.light.materialTheme,
        routerConfig: router,
      ),
    );
    await t.pumpAndSettle();
    expect(button(t, 'Hand over'), isNull);
    await t.enterText(find.byType(TextField), 'ELEC');
    await t.pump();
    expect(button(t, 'Hand over'), isNotNull);
    await t.tap(find.widgetWithText(PrimaryButton, 'Hand over'));
    await t.pumpAndSettle();
    final mine = Grant.fromMap(
      (await db.collection('grants').doc(presidency().id).get()).data()!,
    );
    expect(mine.handedTo, next);
    final theirs = Grant.fromMap(
      (await db
              .collection('grants')
              .doc(grantId(GrantRole.dept, 'goa', 'ELEC', next))
              .get())
          .data()!,
    );
    expect(theirs.liveAt(DateTime.now()), isTrue);
    expect(find.text('DEPT HOME'), findsOneWidget);
  });

  testWidgets('S11 a running handover can be cancelled', (t) async {
    await presidentOfElec();
    final ends = DateTime.now().add(const Duration(days: 19));
    await seedGrant(
      presidency(until: ends),
      extra: {'handedTo': next, 'expiresBefore': Timestamp.fromDate(far)},
    );
    await seedGrant(
      Grant(
        role: GrantRole.dept,
        email: next,
        name: 'Asha Rao',
        campus: 'goa',
        scope: 'ELEC',
        programme: 'A3',
        active: true,
        expiresAt: far,
      ),
    );
    await t.pumpWidget(app(const Succession(campus: 'goa', dept: 'ELEC')));
    await t.pumpAndSettle();
    expect(find.text('Handing over to $next'), findsOneWidget);
    await t.tap(find.widgetWithText(PrimaryButton, 'Cancel the handover'));
    await t.pumpAndSettle();
    final mine = Grant.fromMap(
      (await db.collection('grants').doc(presidency().id).get()).data()!,
    );
    expect(mine.handedTo, isNull);
    expect(mine.expiresAt.millisecondsSinceEpoch, far.millisecondsSinceEpoch);
    final theirs =
        await db
            .collection('grants')
            .doc(grantId(GrantRole.dept, 'goa', 'ELEC', next))
            .get();
    expect(theirs.data()!['active'], isFalse);
  });

  // ---- More, the bar, the roster -------------------------------------------

  testWidgets('S12 More opens each of its three pages', (t) async {
    signIn(student, name: 'Rohan');
    await courses(t, []);
    script.campus = Campus.goa;
    await t.pumpWidget(app(const MorePage()));
    await t.pumpAndSettle();
    expect(find.textContaining('GOA ·'), findsOneWidget);
    for (final (label, page) in [
      ('Representatives', RepresentativesPage),
      ('Course reviews', ReviewsHome),
      ('Resources', ResourcesPage),
    ]) {
      await t.tap(find.text(label));
      await t.pumpAndSettle();
      expect(find.byType(page), findsOneWidget, reason: label);
      Navigator.of(t.element(find.byType(page))).pop();
      await t.pumpAndSettle();
    }
  });

  testWidgets('S13 five bar items, each at least 50 px', (t) async {
    final view = t.view;
    view.physicalSize = const Size(390, 844);
    view.devicePixelRatio = 1;
    await t.pumpWidget(
      app(
        ResponsiveScaffold(
          selectedIndex: 0,
          onSelected: (_) {},
          destinations: const [
            NavDestination(icon: Icons.home_outlined, label: 'Actual'),
            NavDestination(icon: Icons.bar_chart_rounded, label: 'Expected'),
            NavDestination(
              icon: Icons.compare_arrows_rounded,
              label: 'Compare',
            ),
            NavDestination(
              icon: Icons.workspace_premium_outlined,
              label: 'Offshoot',
            ),
            NavDestination(icon: Icons.more_horiz_rounded, label: 'More'),
          ],
          body: const SizedBox(),
        ),
      ),
    );
    await t.pumpAndSettle();
    final items = find.descendant(
      of: find.byType(AppNav),
      matching: find.byType(InkWell),
    );
    expect(items, findsNWidgets(5));
    for (var i = 0; i < 5; i++) {
      final s = t.getSize(items.at(i));
      expect(s.height, greaterThanOrEqualTo(50), reason: 'item $i height');
      expect(s.width, greaterThanOrEqualTo(50), reason: 'item $i width');
    }
  });

  testWidgets('S14 Roster: a phone, or No phone yet', (t) async {
    signIn(
      'owner@gmail.com',
      name: 'Owner',
      roles: const MyRoles(email: 'owner@gmail.com', owner: true),
    );
    await seedGrant(presidency());
    await seedGrant(
      Grant(
        role: GrantRole.course,
        email: student,
        name: 'Rohan Shetty',
        campus: 'goa',
        scope: 'EEE F211',
        active: true,
        expiresAt: far,
      ),
    );
    await db.collection('staffContacts').doc(pres).set({
      'name': 'Meera Iyer',
      'phone': '+91 90000 00203',
      'email': pres,
    });
    await t.pumpWidget(app(const RosterPage()));
    await t.pumpAndSettle();
    expect(find.text('+91 90000 00203'), findsOneWidget);
    expect(find.text('No phone yet'), findsOneWidget);
  });
}
