// Step 11, as registered in agent_instructions/deprecated/PREREGISTERED_10_11.md (S1–S14).
import 'dart:io';

import 'package:cgpa_calculator/admin/admin_home.dart';
import 'package:cgpa_calculator/admin/config_pages.dart';
import 'package:cgpa_calculator/admin/dept_resources.dart';
import 'package:cgpa_calculator/admin/grant_form.dart';
import 'package:cgpa_calculator/admin/maintain.dart';
import 'package:cgpa_calculator/admin/open_as.dart';
import 'package:cgpa_calculator/admin/people.dart';
import 'package:cgpa_calculator/admin/professors.dart';
import 'package:cgpa_calculator/admin/publish_page.dart';
import 'package:cgpa_calculator/admin/roster.dart';
import 'package:cgpa_calculator/admin/scheme_editor.dart';
import 'package:cgpa_calculator/admin/succession.dart';
import 'package:cgpa_calculator/admin/volunteers.dart';
import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/router.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/core/cache/cache_first.dart';
import 'package:cgpa_calculator/core/catalog/catalog.dart';
import 'package:cgpa_calculator/core/models/programmes.dart';
import 'package:cgpa_calculator/core/roles/contacts.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cgpa_calculator/core/roles/maintain_store.dart';
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
import 'package:cgpa_calculator/features/roles/role_switch_page.dart';
import 'package:cgpa_calculator/script.dart' as script;
import 'package:cgpa_calculator/shared/layout/responsive.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/app_nav.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/count_badge.dart';
import 'package:cgpa_calculator/shared/widgets/pill_button.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce/hive.dart';

import '../helpers/fake_data.dart';

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

/// The chart semester of today's term for batch 24 (the taking-now filter
/// only lists courses charted for the running term).
String _semNow() {
  final t = currentTerm(DateTime.now()).split('-');
  return '${int.parse(t[0]) - 2024 + 1} - ${t[2] == '1' ? 1 : 2}';
}

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
              sem: _semNow(),
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
  }) async {
    final entry = {
      'name': name,
      'campus': 'goa',
      'roles': [
        for (final (role, scope, until) in roles)
          {'role': role, 'scope': scope, 'until': Timestamp.fromDate(until)},
      ],
      if (email_) 'email': email,
      if (whatsapp != null) 'whatsapp': whatsapp,
      if (phone != null) 'phone': phone,
    };
    await db.collection('directory').doc(email).set(entry);
    await db.collection('repIndex').doc('goa').set({
      'p': {email: entry},
    }, SetOptions(merge: true));
  }

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
    await seedGrant(presidency()); // the save re-reads roles
    await t.pumpWidget(pushed(const RepProfilePage()));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(button(t, 'Save'), isNull);
    await t.enterText(find.byType(TextField).at(1), '98765 43210');
    await t.pump();
    expect(button(t, 'Save'), isNull);
    await t.tap(find.byType(Switch).first);
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
    await seedGrant(presidency()); // the save re-reads roles
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
    await t.enterText(find.byType(TextField).at(1), '98765 43210');
    await t.tap(find.byType(Switch).first);
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

  testWidgets('Representatives: Resources last updated, per president and CR', (
    t,
  ) async {
    signIn(student, name: 'Rohan');
    await courses(t, ['EEE F211']);
    await listed('p1@x', 'Pres One', [('dept', 'ELEC', far)]);
    await listed('cr@x', 'Cr Person', [('course', 'EEE F211', far)]);
    await db.doc('activity/goa').set({
      'dept': {'ELEC': Timestamp.fromDate(DateTime(2026, 8, 20))},
      'course': {'EEE F211': Timestamp.fromDate(DateTime(2026, 9, 5))},
    });
    await forget('act|');
    await t.pumpWidget(app(const RepresentativesPage()));
    await t.pumpAndSettle();
    expect(find.text('Resources last updated Aug 2026'), findsOneWidget);
    expect(find.text('Resources last updated Sep 2026'), findsOneWidget);
  });

  testWidgets('Representatives: no activity, no text', (t) async {
    signIn(student, name: 'Rohan');
    await courses(t, ['EEE F211']);
    await listed('p1@x', 'Pres One', [('dept', 'ELEC', far)]);
    await forget('act|');
    await t.pumpWidget(app(const RepresentativesPage()));
    await t.pumpAndSettle();
    expect(find.text('Pres One'), findsOneWidget);
    expect(find.textContaining('last updated'), findsNothing);
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

  testWidgets('no president listed shows the public contact', (t) async {
    // Only the student's own branch reports a missing president (A3).
    script.selecteddiscipline = '--A3';
    addTearDown(() => script.selecteddiscipline = '----');
    signIn(student, name: 'Rohan');
    await courses(t, ['EEE F211']);
    await db.collection('config').doc('public').set({
      'contactName': 'Owner',
      'contactMethod': 'whatsapp',
      'contactTarget': '9000000001',
      'contactEnabled': true,
    });
    await t.pumpWidget(app(const RepresentativesPage()));
    await t.pumpAndSettle();
    expect(find.textContaining('No president listed'), findsOneWidget);
    expect(find.text('Message Owner'), findsOneWidget);
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
    await t.tap(find.byTooltip('Copy the election notice'));
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
      await t.enterText(find.byType(TextField).first, address);
      await t.pump(const Duration(milliseconds: 500));
      await t.pumpAndSettle();
    }

    await lookUp('f20240001@pilani.bits-pilani.ac.in');
    expect(find.text('A successor must be on Goa.'), findsOneWidget);
    await lookUp('f20249999@goa.bits-pilani.ac.in');
    expect(find.textContaining('Can not be found'), findsOneWidget);
    await lookUp(next);
    expect(find.text('WHAT HAPPENS'), findsOneWidget);
    expect(find.textContaining('✓ '), findsOneWidget);
    final ends = RoleStore.outgoingExpiry(presidency(), DateTime.now());
    expect(find.textContaining(shortDay(ends, year: true)), findsOneWidget);
  });

  testWidgets('S9b a next secretary is looked up the same way, optional', (
    t,
  ) async {
    await presidentOfElec();
    const sec = 'f20240002@goa.bits-pilani.ac.in';
    await db.collection('people').doc(sec).set({
      'name': 'Kiran Das',
      'campus': 'goa',
    });
    await t.pumpWidget(app(const Succession(campus: 'goa', dept: 'ELEC')));
    await t.pumpAndSettle();
    Future<void> type(int i, String a) async {
      await t.enterText(find.byType(TextField).at(i), a);
      await t.pump(const Duration(milliseconds: 500));
      await t.pumpAndSettle();
    }

    await type(0, next);
    expect(button(t, 'Review the handover'), isNotNull);
    await type(1, 'f20249999@goa.bits-pilani.ac.in');
    expect(button(t, 'Review the handover'), isNull);
    await type(1, sec);
    expect(find.textContaining('✓ Kiran Das'), findsOneWidget);
    expect(button(t, 'Review the handover'), isNotNull);
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
    expect(button(t, 'Hand ELEC to f20240001'), isNull);
    await t.enterText(find.byType(TextField), 'ELEC');
    await t.pump();
    expect(button(t, 'Hand ELEC to f20240001'), isNotNull);
    await t.tap(find.widgetWithText(PrimaryButton, 'Hand ELEC to f20240001'));
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

  // ---- T8.1 Controls -------------------------------------------------------

  Grant dept(String email, String scope) => Grant(
    role: GrantRole.dept,
    email: email,
    name: email.split('@').first,
    campus: 'goa',
    scope: scope,
    active: true,
    expiresAt: DateTime.now().add(const Duration(days: 90)),
  );

  testWidgets('Controls counts maintainers', (t) async {
    signIn(
      'owner@example.com',
      roles: const MyRoles(email: 'owner@example.com', owner: true),
    );
    await seedGrant(dept('p1@goa.bits-pilani.ac.in', 'ELEC'));
    await seedGrant(dept('p2@goa.bits-pilani.ac.in', 'CS'));
    await t.pumpWidget(app(const AdminHome()));
    await t.pumpAndSettle();
    expect(
      find.text('2 presidents · 0 course managers · 0 admins'),
      findsOneWidget,
    );
    expect(find.textContaining('Me — every campus'), findsOneWidget);
    expect(
      find.text('CR 1 semester · president 1 year · admin 2 years'),
      findsOneWidget,
    );
  });

  testWidgets('Controls offers staff a leaderboard username', (t) async {
    const me = 'f20200001@pilani.bits-pilani.ac.in';
    signIn(me, roles: const MyRoles(email: me, owner: true));
    await db.doc('contributors/$me').set({'campus': 'pilani', 'points': 8});
    await t.pumpWidget(app(const AdminHome()));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await t.pumpAndSettle();
    expect(find.text('Show up on the leaderboard'), findsOneWidget);
    expect(find.textContaining('8 so far'), findsOneWidget);
    await t.enterText(find.byType(TextField).first, 'boss_1');
    await t.runAsync(() async {
      await t.tap(find.text('Claim username'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await t.pumpAndSettle();
    expect(find.text('You are on the leaderboard as boss_1.'), findsOneWidget);
    expect((await db.doc('leaderboard/pilani').get()).data()!['p'], {'boss_1': 8});
  });

  testWidgets('Publish shows waiting changes in amber', (t) async {
    signIn(
      'owner@example.com',
      roles: const MyRoles(email: 'owner@example.com', owner: true),
    );
    for (final id in ['CS F111', 'CS F211']) {
      await db.collection('courses').doc(id).set({'id': id, 'draft': true});
    }
    await t.pumpWidget(app(const AdminHome()));
    await t.pumpAndSettle();
    expect(find.text('2 changes waiting'), findsOneWidget);
    final badge = t.widget<CountBadge>(find.byType(CountBadge).last);
    expect(badge.text, '2');
    expect(badge.tone, CountTone.waiting);
  });

  // ---- T8.2 Owners ---------------------------------------------------------

  testWidgets('Remove is 44 px', (t) async {
    signIn(
      'owner@example.com',
      roles: const MyRoles(email: 'owner@example.com', owner: true),
    );
    for (final e in ['owner@example.com', 'other@example.com']) {
      await db.collection('owners').doc(e).set({
        'email': e,
        'name': e.split('@').first,
        'active': true,
      });
    }
    await t.pumpWidget(app(const OwnersPage()));
    await t.pumpAndSettle();
    expect(find.text('Remove'), findsOneWidget);
    expect(find.text('You can\'t remove yourself'), findsOneWidget);
    final hit = find.ancestor(
      of: find.text('Remove'),
      matching: find.byType(InkWell),
    );
    expect(t.getSize(hit.first).height, greaterThanOrEqualTo(44));
  });

  // ---- T8.3 Publish --------------------------------------------------------

  testWidgets('publish waits for the credit-change checkbox', (t) async {
    signIn(
      'owner@example.com',
      roles: const MyRoles(email: 'owner@example.com', owner: true),
    );
    final now = catalog.master.firstWhere((m) => m.id == 'CS F211').credits;
    await db.collection('courses').doc('CS F211').set({
      'id': 'CS F211',
      'credits': now + 1,
      'draft': true,
    });
    await t.pumpWidget(app(const PublishPage()));
    await t.pumpAndSettle();
    VoidCallback? publish() =>
        t.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed;
    expect(find.text('MOVES CGPAs · 1'), findsOneWidget);
    expect(publish(), isNull);
    await t.tap(find.textContaining('I have read the 1 credit change'));
    await t.pump();
    expect(publish(), isNotNull);
  });

  // ---- T8.4 Open as --------------------------------------------------------

  testWidgets('President row opens the department picker', (t) async {
    signIn(
      'owner@example.com',
      roles: const MyRoles(email: 'owner@example.com', owner: true),
    );
    final router = GoRouter(
      initialLocation: Routes.openAs,
      routes: [
        GoRoute(path: Routes.openAs, builder: (_, _) => const OpenAsPage()),
        GoRoute(
          path: Routes.openAsDept,
          builder: (_, _) => const ViewAsDeptPage(),
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
    expect(find.text('Signed in as an owner'), findsOneWidget);
    await t.tap(find.text('Department president'));
    await t.pumpAndSettle();
    expect(find.text('Which department?'), findsOneWidget);
    // A row per ELEC programme, each with its own presidents.
    for (final branch in [
      'Electrical & Electronics',
      'Electronics and Instrumentation',
      'Electronics and Communication',
      'Electronics and Computer',
    ]) {
      expect(find.text(branch), findsOneWidget);
    }
    expect(find.textContaining('A3 · 0 presidents'), findsOneWidget);
  });

  test('last opened sits on top', () {
    expect(
      recentFirst(['BIO', 'CS', 'ELEC', 'MATH'], ['ELEC', 'GONE', 'BIO']),
      ['ELEC', 'BIO', 'CS', 'MATH'],
    );
    expect(recentFirst(['A', 'B'], const []), ['A', 'B']);
  });

  // ---- T8.5 Maintainers ----------------------------------------------------

  testWidgets('expiring grant is amber', (t) async {
    signIn(
      'owner@example.com',
      roles: const MyRoles(email: 'owner@example.com', owner: true),
    );
    final g = Grant(
      role: GrantRole.dept,
      email: 'p2@goa.bits-pilani.ac.in',
      name: 'Rohan Deshpande',
      campus: 'goa',
      scope: 'CS',
      active: true,
      // An hour of slack, so "4 days" survives the test's own clock.
      expiresAt: DateTime.now().add(const Duration(days: 4, hours: 1)),
    );
    await seedGrant(g);
    await t.pumpWidget(app(const AdminPeople()));
    await t.pumpAndSettle();
    expect(find.text('EXPIRES IN 4 DAYS'), findsOneWidget);
    expect(find.textContaining('Renewing is deliberate'), findsOneWidget);
    final block = t.widget<Container>(
      find
          .ancestor(
            of: find.text('Rohan Deshpande'),
            matching: find.byType(Container),
          )
          .last,
    );
    final ctx = t.element(find.byType(AdminPeople));
    expect(block.color, AppPalette.of(ctx).noticeTone.fill);
    final later = Grant(
      role: g.role,
      email: g.email,
      name: g.name,
      campus: g.campus,
      scope: g.scope,
      active: true,
      expiresAt: DateTime.now().add(const Duration(days: 9)),
    );
    expect(expiresSoon(later), isFalse);
  });

  // ---- T8.6 Appoint --------------------------------------------------------

  Future<void> appointForm(WidgetTester t, String address) async {
    signIn(
      'owner@example.com',
      roles: const MyRoles(email: 'owner@example.com', owner: true),
    );
    await db.collection('people').doc(pres).set({
      'name': 'Meera Iyer',
      'campus': 'goa',
    });
    await t.pumpWidget(app(const AdminGrant()));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).first, address);
    // Looked up once typing stops, with no button to press.
    await t.pump(const Duration(milliseconds: 450));
    await t.pumpAndSettle();
  }

  String grantButton(WidgetTester t) =>
      t.widget<PrimaryButton>(find.byType(PrimaryButton)).label;

  testWidgets('grant button names the grant', (t) async {
    await appointForm(t, 'f2023@goa.bits-pilani.ac.in');
    expect(grantButton(t), 'Grant');
    await appointForm(t, pres);
    expect(find.text('Meera Iyer uses Pointer'), findsOneWidget);
    await t.tap(find.text('President'));
    await t.pumpAndSettle();
    await t.tap(find.text('Choose a department'));
    await t.pumpAndSettle();
    // The shared list: ELEC shows as its branches, never as "ELEC".
    expect(find.textContaining('ELEC'), findsNothing);
    await t.tap(find.text('A3'));
    await t.pumpAndSettle();
    await t.tap(find.text('A3'));
    await t.pumpAndSettle();
    expect(grantButton(t), 'Grant — president, ELEC Goa');
    // A secretary names itself and is granted as a flagged dept grant.
    await t.tap(find.text('Secretary'));
    await t.pumpAndSettle();
    expect(grantButton(t), 'Grant — secretary, ELEC Goa');
    await t.tap(find.byType(PrimaryButton));
    await t.pumpAndSettle();
    final g =
        (await db.collection('grants').doc('dept|goa|ELEC|$pres').get())
            .data()!;
    expect(g['secretary'], isTrue);
    expect(g['programme'], 'A3');
    expect(
      grantLabel(GrantRole.course, 'CS F372', 'goa'),
      'Grant — course manager, CS F372 Goa',
    );
  });

  testWidgets('unknown address says Can not be found', (t) async {
    await appointForm(t, 'f20249999@goa.bits-pilani.ac.in');
    expect(find.text('Can not be found'), findsOneWidget);
    expect(grantButton(t), 'Grant');
  });

  testWidgets('a CR for a course not in the catalogue is refused', (t) async {
    await appointForm(t, pres);
    // No red box for a valid address.
    expect(find.textContaining('Refused'), findsNothing);
    await t.tap(find.text('CR'));
    await t.pumpAndSettle();
    final field = find.widgetWithText(TextField, 'EEE F211').first;
    // A code still being typed is not refused, nor granted.
    await t.enterText(field, 'EEE');
    await t.pumpAndSettle();
    expect(find.textContaining('not in the catalogue'), findsNothing);
    expect(
      t.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
      isNull,
    );
    await t.enterText(field, 'XYZ F999');
    await t.pumpAndSettle();
    expect(find.text('XYZ F999 is not in the catalogue.'), findsOneWidget);
    expect(
      t.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
      isNull,
    );
  });

  testWidgets('a course refusal shows under the course field', (t) async {
    signIn(pres, roles: MyRoles(email: pres, grants: [presidency()]));
    const cr = 'f20240001@goa.bits-pilani.ac.in';
    await db.collection('people').doc(cr).set({
      'name': 'Asha',
      'campus': 'goa',
    });
    await t.pumpWidget(
      app(
        const AdminGrant(
          prefill: (role: GrantRole.course, email: cr, scope: 'EEE F311'),
        ),
      ),
    );
    await t.pumpAndSettle();
    VoidCallback? grant() =>
        t.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed;
    expect(grant(), isNotNull);
    // An ELEC president can not appoint a CS CR; it says so by the field.
    final field = find.widgetWithText(TextField, 'EEE F311');
    await t.enterText(field, 'CS F111');
    await t.pumpAndSettle();
    expect(grant(), isNull);
    final refusal = find.textContaining('your own department');
    expect(refusal, findsOneWidget);
    expect(
      t.getTopLeft(refusal).dy,
      greaterThan(t.getTopLeft(find.byType(TextField).last).dy),
    );
  });

  testWidgets('a lapsed grant reads Expired, a revoked one Revoked', (t) async {
    signIn(
      'owner@example.com',
      roles: const MyRoles(email: 'owner@example.com', owner: true),
    );
    Grant g(String email, {required bool active}) => Grant(
      role: GrantRole.dept,
      email: email,
      name: email,
      campus: 'goa',
      scope: 'CS',
      active: active,
      expiresAt: DateTime.now().subtract(const Duration(days: 3)),
    );
    await seedGrant(g('lapsed@goa.bits-pilani.ac.in', active: true));
    await seedGrant(g('revoked@goa.bits-pilani.ac.in', active: false));
    await t.pumpWidget(app(const AdminPeople()));
    await t.pumpAndSettle();
    expect(find.text('EXPIRED'), findsOneWidget);
    expect(find.text('REVOKED'), findsOneWidget);
    expect(find.text('0 PEOPLE'), findsOneWidget);
  });

  // ---- T8.7 Grant terms ----------------------------------------------------

  Future<void> terms(WidgetTester t, MyRoles roles) async {
    signIn(roles.email, roles: roles);
    await db.collection('config').doc('grantTerms').set({
      'crDays': 183,
      'presidentDays': 365,
      'adminDays': 730,
    });
    await t.pumpWidget(app(const TermsPage()));
    await t.pumpAndSettle();
  }

  testWidgets('CR term shows semesters', (t) async {
    await terms(t, const MyRoles(email: 'owner@example.com', owner: true));
    expect(find.text('1'), findsNWidgets(2)); // 1 semester, 1 year
    expect(find.text('semester'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('years'), findsOneWidget);
    await t.tap(find.bySemanticsLabel('Longer').first);
    await t.pump();
    expect(find.text('semesters'), findsOneWidget);
  });

  testWidgets('admin cannot change the admin term', (t) async {
    const me = 'admin@example.com';
    await terms(
      t,
      MyRoles(
        email: me,
        grants: [
          Grant(
            role: GrantRole.admin,
            email: me,
            name: 'Ad Min',
            campus: 'all',
            scope: 'all',
            active: true,
            expiresAt: far,
          ),
        ],
      ),
    );
    // − and + on the CR and president rows only.
    expect(find.byType(PillButton), findsNWidgets(4));
    expect(find.text('2 years'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
  });

  // ---- T8.8 Public contact -------------------------------------------------

  testWidgets('preview names the contact', (t) async {
    signIn(
      'owner@example.com',
      name: 'Owner One',
      roles: const MyRoles(email: 'owner@example.com', owner: true),
    );
    await roleStore!.savePublicContact((
      name: 'Owner',
      method: 'whatsapp',
      target: '9000000001',
      enabled: true,
    ));
    await t.pumpWidget(app(const PublicContactPage()));
    await t.pumpAndSettle();
    expect(find.text('Message Owner'), findsOneWidget);
    expect(
      find.textContaining('Last changed by Owner One (owner)'),
      findsOneWidget,
    );
    await t.enterText(find.byType(TextField).first, 'Siddharth');
    await t.pump();
    expect(find.text('Message Siddharth'), findsOneWidget);
  });

  // ---- T8.9 Work as --------------------------------------------------------

  Grant elec() => Grant(
    role: GrantRole.dept,
    email: pres,
    name: 'Meera Iyer',
    campus: 'goa',
    scope: 'ELEC',
    programme: 'A3',
    active: true,
    expiresAt: DateTime(2027, 9, 27),
  );

  testWidgets('current role shows NOW chip', (t) async {
    final g = elec();
    signIn(pres, roles: MyRoles(email: pres, grants: [g]));
    workingAs.value = g;
    addTearDown(() => workingAs.value = null);
    await t.pumpWidget(app(const RoleSwitchPage()));
    await t.pumpAndSettle();
    expect(find.text('✓ NOW'), findsOneWidget);
    // The chip sits on the president row, a plain row, not an inverted card.
    final row =
        find
            .ancestor(of: find.text('✓ NOW'), matching: find.byType(InkWell))
            .first;
    expect(
      find.descendant(of: row, matching: find.text('Department president')),
      findsOneWidget,
    );
    expect(find.text('Your contact details'), findsOneWidget);
  });

  testWidgets('expiry reads 27 Sep 2027', (t) async {
    signIn(pres, roles: MyRoles(email: pres, grants: [elec()]));
    await t.pumpWidget(app(const RoleSwitchPage()));
    await t.pumpAndSettle();
    expect(find.textContaining('until 27 Sep 2027'), findsOneWidget);
  });

  // ---- T8.10 Audit log -----------------------------------------------------

  testWidgets('president sees their campus', (t) async {
    signIn(pres, roles: MyRoles(email: pres, grants: [presidency()]));
    final hourAgo = DateTime.now().subtract(const Duration(hours: 1));
    for (final (campus, what) in [
      ('goa', 'Changed the Midsem weight in EEE F211'),
      ('hyderabad', 'Added a link to CS F211'),
    ]) {
      await db.collection('audit').add({
        'actor': {'email': student, 'name': 'Arjun Rao', 'role': 'cr'},
        'summary': what,
        'campus': campus,
        'before': '30%',
        'after': '35%',
        'at': Timestamp.fromDate(hourAgo),
      });
    }
    await t.pumpWidget(app(const AuditLogPage()));
    await t.pumpAndSettle();
    expect(find.text('Changed the Midsem weight in EEE F211'), findsOneWidget);
    expect(find.text('Added a link to CS F211'), findsNothing);
    // An hour ago reads "1 hour ago", or "Yesterday, hh:mm" just after
    // midnight, and groups under TODAY or YESTERDAY to match.
    expect(
      find.text(
        hourAgo.day == DateTime.now().day ? '1 hour ago' : ago(hourAgo),
      ),
      findsOneWidget,
    );
    expect(find.text('30%'), findsOneWidget);
    final label = hourAgo.day == DateTime.now().day ? 'TODAY' : 'YESTERDAY';
    expect(find.text(label), findsOneWidget);
  });

  testWidgets('audit finds a course by name through the catalogue', (t) async {
    signIn(pres, roles: MyRoles(email: pres, grants: [presidency()]));
    await t.pumpWidget(app(const AuditLogPage()));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'electrical machines');
    await t.pump(const Duration(milliseconds: 200));
    await t.tap(find.text('Electrical Machines').first);
    await t.pumpAndSettle();
    expect(find.textContaining(' · Electrical Machines'), findsOneWidget);
  });

  // ---- T8.11 Roster --------------------------------------------------------

  testWidgets('volunteers tab counts offers', (t) async {
    signIn(pres, roles: MyRoles(email: pres, grants: [presidency()]));
    for (final e in [
      'f20240101@goa.bits-pilani.ac.in',
      'f20240102@goa.bits-pilani.ac.in',
    ]) {
      await db.collection('volunteers').doc('goa_EEE F212_$e').set({
        'name': e.substring(0, 9),
        'email': e,
        'campus': 'goa',
        'courseId': 'EEE F212',
        'dept': 'ELEC',
        'term': currentTerm(DateTime.now()),
        'open': true,
      });
    }
    await t.pumpWidget(
      app(RosterPage(volunteersTab: (c) => VolunteersTab(campus: c))),
    );
    await t.pumpAndSettle();
    expect(find.text('Volunteers · 2'), findsOneWidget);
    await t.tap(find.text('Volunteers · 2'));
    await t.pumpAndSettle();
    expect(find.text('Appoint as CR'), findsNWidgets(2));
  });

  testWidgets('merge names the survivor', (t) async {
    await t.runAsync(() => seedFirestore(db));
    signIn(pres, roles: MyRoles(email: pres, grants: [presidency()]));
    await t.pumpWidget(app(const ProfessorMerge(campus: 'goa', dept: 'CS')));
    await t.pumpAndSettle();
    expect(find.text('Pick the one to keep'), findsOneWidget);
    await t.tap(find.text('Ramesh Menon'));
    await t.pump();
    await t.tap(find.text('Dr. R. Menon'));
    await t.pump();
    expect(find.text('KEEP'), findsOneWidget);
    expect(find.text('Merge into Ramesh Menon'), findsOneWidget);
    expect(find.textContaining('Also known as Dr. R. Menon'), findsOneWidget);
  });

  testWidgets('merge suggests likely duplicates and picks both', (t) async {
    await t.runAsync(() => seedFirestore(db));
    signIn(pres, roles: MyRoles(email: pres, grants: [presidency()]));
    await t.pumpWidget(app(const ProfessorMerge(campus: 'goa', dept: 'CS')));
    await t.pumpAndSettle();
    expect(find.text('Possible duplicates'.toUpperCase()), findsOneWidget);
    await t.tap(find.textContaining('Tap to pick both').first);
    await t.pump();
    expect(find.text('KEEP'), findsOneWidget);
    expect(find.text('MERGE'), findsOneWidget);
  });

  testWidgets('reported tab counts reports', (t) async {
    await t.runAsync(() => seedFirestore(db));
    signIn(pres, roles: MyRoles(email: pres, grants: [presidency()]));
    // The Reported dot pulses for as long as the page is open, so this
    // pumps frames instead of settling (UI_OPT O6.1).
    Future<void> frames() async {
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
    }

    await t.pumpWidget(app(const DeptResources(campus: 'goa', dept: 'ELEC')));
    await frames();
    expect(find.text('Reported 1'), findsOneWidget);
    expect(find.text('Add a link'), findsOneWidget);
    await t.tap(find.text('Reported 1'));
    await frames();
    expect(find.text('Fix the link'), findsOneWidget);
    expect(find.text('It works · dismiss'), findsOneWidget);
    expect(find.text('Add a link'), findsNothing);
  });

  testWidgets('THIS WEEK counts CR edits', (t) async {
    final course = deptCourses('ELEC').first.id;
    final at = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(hours: 1)),
    );
    await t.runAsync(() async {
      for (final (who, role) in [
        (pres, 'dept'),
        ('f20220001@goa.bits-pilani.ac.in', 'dept'),
        ('f20240002@goa.bits-pilani.ac.in', 'course'),
        ('f20240003@goa.bits-pilani.ac.in', 'course'),
      ]) {
        await db.collection('audit').add({
          'actor': {'email': who, 'name': 'X', 'role': role},
          'summary': 'Changed a weight',
          'campus': 'goa',
          'course': course,
          'at': at,
        });
      }
    });
    signIn(pres, roles: MyRoles(email: pres, grants: [presidency()]));
    await t.pumpWidget(app(const DeptHome(campus: 'goa', dept: 'ELEC')));
    await t.pumpAndSettle();
    expect(
      find.text('1 by you · 1 by other presidents · 2 by CRs'),
      findsOneWidget,
    );
    expect(find.text('Appoint a CR'), findsNothing);
    expect(
      find.textContaining('with the A8, AA, AC presidents'),
      findsOneWidget,
    );
  });

  testWidgets('timeline names the end date', (t) async {
    await presidentOfElec();
    await t.pumpWidget(app(const Succession(campus: 'goa', dept: 'ELEC')));
    await t.pumpAndSettle();
    final ends = RoleStore.outgoingExpiry(presidency(), DateTime.now());
    expect(find.text('WHAT HAPPENS'), findsOneWidget);
    expect(find.textContaining(shortDay(ends, year: true)), findsOneWidget);
    expect(button(t, 'Review the handover'), isNull);
  });

  testWidgets('an owner previewing sees the president\'s handover', (t) async {
    await presidentOfElec();
    signIn(
      'owner@example.com',
      roles: const MyRoles(email: 'owner@example.com', owner: true),
    );
    await t.pumpWidget(app(const Succession(campus: 'goa', dept: 'ELEC')));
    await t.pumpAndSettle();
    expect(find.textContaining('Previewing as'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2)); // president, secretary
    expect(find.text('Review the handover'), findsOneWidget);
  });

  testWidgets('scheme shows averages', (t) async {
    await t.runAsync(() => seedFirestore(db));
    signIn(pres, roles: MyRoles(email: pres, grants: [presidency()]));
    await t.pumpWidget(app(const CrHome(campus: 'goa', courseId: 'CS F372')));
    await t.pumpAndSettle();
    expect(find.text('avg 12.4'), findsOneWidget);
    expect(find.text('no avg'), findsWidgets);
    expect(find.text('Pick from department resources'), findsOneWidget);
  });

  testWidgets('the scheme editor bounds the average by the scale', (t) async {
    signIn(pres, roles: MyRoles(email: pres, grants: [presidency()]));
    await t.pumpWidget(
      app(
        const SchemeEditorPage(
          courseId: 'CS F372',
          campus: 'goa',
          term: '2026-27-1',
        ),
      ),
    );
    await t.pumpAndSettle();
    Finder field(String label) => find.descendant(
      of:
          find
              .ancestor(
                of: find.text(label.toUpperCase()),
                matching: find.byType(Column),
              )
              .first,
      matching: find.byType(TextField),
    );
    expect(find.text('GRADED OUT OF'), findsOneWidget);
    expect(find.textContaining('they no longer set it'), findsOneWidget);
    expect(find.text('COURSE AVERAGE (OUT OF 100)'), findsOneWidget);
    await t.enterText(field('Graded out of'), '200');
    await t.pump();
    expect(find.text('COURSE AVERAGE (OUT OF 200)'), findsOneWidget);
    await t.enterText(field('Course average (out of 200)'), '250');
    await t.pump();
    await t.tap(find.text('Marks out of a total'));
    await t.pump();
    expect(find.text('GRADED OUT OF'), findsNothing);
    await t.enterText(field('Course out of'), '50');
    await t.pump();
    expect(find.text('COURSE AVERAGE (OUT OF 50)'), findsOneWidget);
  });

  testWidgets('a CR enters the course average', (t) async {
    await t.runAsync(() => seedFirestore(db));
    signIn(pres, roles: MyRoles(email: pres, grants: [presidency()]));
    await t.pumpWidget(app(const CrHome(campus: 'goa', courseId: 'CS F372')));
    await t.pumpAndSettle();
    VoidCallback? save() =>
        t.widget<PillButton>(find.widgetWithText(PillButton, 'Save')).onPressed;
    final field = find.widgetWithText(TextField, '63.5');
    expect(field, findsOneWidget);
    expect(save(), isNull);
    await t.enterText(field, '101');
    await t.pump();
    expect(find.text('Type a number from 0 to 100.'), findsOneWidget);
    expect(save(), isNull);
    await t.enterText(find.widgetWithText(TextField, '101'), '70');
    await t.pump();
    await t.tap(find.widgetWithText(PillButton, 'Save'));
    await t.pumpAndSettle();
    final o = await t.runAsync(
      () =>
          MaintainStore(roleStore!).offering('CS F372', 'goa', maintainedTerm),
    );
    expect(o!.courseAverage, 70);
  });
}
