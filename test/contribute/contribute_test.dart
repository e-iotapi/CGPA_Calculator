// U11: Contributors UI (state machine, Apply, Contribute, Leaderboard,
// Approvals, keyboard). Runs on the shared fake Firestore.
import 'package:cgpa_calculator/admin/approvals.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/core/contrib/contributor_store.dart';
import 'package:cgpa_calculator/core/resources/resource.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/features/contribute/add_page.dart';
import 'package:cgpa_calculator/features/contribute/apply_page.dart';
import 'package:cgpa_calculator/features/contribute/contribute_data.dart';
import 'package:cgpa_calculator/features/contribute/contribute_page.dart';
import 'package:cgpa_calculator/features/contribute/leaderboard_page.dart';
import 'package:cgpa_calculator/features/more/more_page.dart';
import 'package:cgpa_calculator/features/resources/resources_page.dart';
import 'package:cgpa_calculator/features/settings/settings_view.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show SetOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_data.dart';
import '../helpers/flaky_firestore.dart';

void main() {
  setUpAll(() async {
    await seedAll();
    // Hive writes stall inside a widget test once another has run: apply here.
    await ContributorStore(
      RoleStore(sharedDb, me: cr2Email, myName: 'Dev Patel'),
    ).apply('goa', 'CS');
  });

  Resource link({
    bool approved = false,
    bool removed = false,
    String reason = '',
  }) => Resource(
    id: 'x',
    title: 't',
    url: 'https://drive.google.com/x',
    campus: 'goa',
    department: 'CS',
    approved: approved,
    removed: removed,
    rejectedReason: reason,
  );

  test('state machine: none, applied, approved, declined', () {
    ContributorRequest req(RequestStatus s) => ContributorRequest(
      email: 'a@b.c',
      name: 'A',
      campus: 'goa',
      dept: 'CS',
      status: s,
      createdAt: 0,
    );
    MyContrib v(RequestStatus? s, {bool grant = false}) => (
      me: MyContributor(isContributor: grant),
      request: s == null ? null : req(s),
    );
    myRoles.value = MyRoles.none;
    expect(contribStateOf(null), ContribState.none);
    expect(contribStateOf(v(null)), ContribState.none);
    expect(contribStateOf(v(RequestStatus.pending)), ContribState.applied);
    expect(
      contribStateOf(v(RequestStatus.approved, grant: true)),
      ContribState.approved,
    );
    expect(contribStateOf(v(RequestStatus.declined)), ContribState.declined);
    myRoles.value = const MyRoles(email: 'a@b.c', contributor: true);
    expect(contribStateOf(null), ContribState.approved);
    myRoles.value = MyRoles.none;
  });

  test('link states: awaiting, approved, rejected, removed', () {
    final now = DateTime.now();
    expect(linkStateOf(link(), now), LinkState.awaiting);
    expect(linkStateOf(link(approved: true), now), LinkState.approved);
    expect(
      linkStateOf(link(removed: true, reason: 'Broken'), now),
      LinkState.rejected,
    );
    expect(linkStateOf(link(removed: true), now), isNull);
  });

  testWidgets('Settings row shows only when onContribute is given', (t) async {
    Widget view(VoidCallback? on) => MaterialApp(
      theme: AppPalette.light.materialTheme,
      home: SettingsView(
        name: 'S',
        email: 'f20220000@goa.bits-pilani.ac.in',
        discipline: 'B3A7',
        batch: 24,
        isDark: false,
        profiles: const ['a', 'b', 'c', 'd', 'e'],
        onClose: () {},
        onPickDiscipline: (_) {},
        onTheme: (_) {},
        onRenameProfile: (_) {},
        onExport: () {},
        onImportOld: () {},
        onReport: () {},
        onReset: () {},
        onSignOut: () {},
        onContribute: on,
      ),
    );
    await t.pumpWidget(view(() {}));
    expect(find.text('Become a contributor'), findsOneWidget);
    await t.pumpWidget(view(null));
    expect(find.text('Become a contributor'), findsNothing);
  });

  Future<void> open(WidgetTester t, As who, Widget page) async {
    roleStore = RoleStore(sharedDb, me: who.email, myName: who.name);
    myRoles.value = who.roles;
    myUid = 'u-test';
    contribState.value = ContribState.none;
    addTearDown(() {
      myRoles.value = MyRoles.none;
      roleStore = null;
    });
    await t.pumpWidget(
      MaterialApp(theme: AppPalette.light.materialTheme, home: page),
    );
    await settle(t);
  }

  testWidgets('Approvals: decline asks a reason; approve all', (t) async {
    await open(t, As.president2, const Approvals(campus: 'goa', dept: 'CS'));
    expect(find.text('Contributor approvals'), findsOneWidget);
    expect(find.text('Dev Patel'), findsOneWidget);
    await t.tap(
      find.descendant(
        of: find.ancestor(
          of: find.text('Dev Patel'),
          matching: find.byType(AppCard),
        ),
        matching: find.text('Decline'),
      ),
    );
    await settle(t);
    expect(find.text('Not a good fit'), findsOneWidget);
    expect(find.widgetWithText(PrimaryButton, 'Send'), findsOneWidget);
    await t.tap(find.text('Not a good fit'));
    await t.pump();
    await t.tap(find.widgetWithText(PrimaryButton, 'Send'));
    await settle(t);
    expect(find.text('Dev Patel'), findsNothing);
    final r = await t.runAsync(
      () => ContributorStore(
        RoleStore(sharedDb, me: cr2Email, myName: 'P'),
      ).myRequest('goa', 'CS'),
    );
    expect(r!.status, RequestStatus.declined);
    expect(r.reason, contains('Not a good fit'));
  });

  testWidgets('Apply: a taken username shows inline; a free one sends', (
    t,
  ) async {
    await t.runAsync(
      () => ContributorStore(
        RoleStore(sharedDb, me: 'f20210001@goa.bits-pilani.ac.in', myName: 'O'),
      ).claimUsername('goa', 'taken_name'),
    );
    await open(t, As.student, const ApplyPage());
    expect(find.text('Apply'), findsOneWidget);
    expect(find.textContaining('An approver confirms each link'), findsOneWidget);
    final field = find.byType(TextField);
    t.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(t.view.resetViewInsets);
    await t.pump();
    expect(t.getRect(field).bottom, lessThan(844 - 300 / 3));
    await t.enterText(field, 'taken_name');
    t.view.resetViewInsets();
    await t.pump();
    await t.tap(find.textContaining('I understand how approval'));
    await t.pump();
    await t.tap(find.text('Send application'));
    await settle(t);
    expect(find.textContaining('That username is taken'), findsOneWidget);
    await t.enterText(field, 'quiet_owl');
    await t.tap(find.text('Send application'));
    await settle(t);
    expect(find.text('Application sent'), findsOneWidget);
    expect(find.text('Waiting for approval'), findsOneWidget);
    expect(contribState.value, ContribState.applied);
  });

  testWidgets('Contribute: applied sees pending, approved sees filters', (
    t,
  ) async {
    await open(t, As.student, const ContributePage());
    expect(find.text('Application sent'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    myRoles.value = const MyRoles(email: studentEmail, contributor: true);
    await t.pumpWidget(
      MaterialApp(
        theme: AppPalette.light.materialTheme,
        home: const ContributePage(),
      ),
    );
    await settle(t);
    // No links yet: the card and its button, no filters.
    expect(find.text('Your links'), findsOneWidget);
    expect(find.text('Add your first link'), findsOneWidget);
    expect(find.text('Add a link'), findsOneWidget);
  });

  testWidgets('Contribute: staff publish directly, no states', (t) async {
    await open(t, As.president2, const ContributePage());
    expect(find.textContaining('publish at once'), findsOneWidget);
    expect(find.text('Waiting'), findsNothing);
    expect(find.byTooltip('Add a link'), findsOneWidget);
  });

  testWidgets('Add links: Department or a course, Another link', (t) async {
    await open(t, As.president2, const AddPage());
    expect(find.text('Another link'), findsOneWidget);
    expect(find.text('Publish 1 link'), findsOneWidget);
    t.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(t.view.resetViewInsets);
    await t.pump();
    await t.scrollUntilVisible(
      find.text('Another link'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await t.drag(find.byType(Scrollable).first, const Offset(0, -150));
    await t.pump();
    await t.tap(find.text('Another link'));
    await t.pump();
    expect(find.text('LINK 2'), findsOneWidget);
  });

  testWidgets('Leaderboard: empty, then ranked with my place', (t) async {
    // Hyderabad has no board.
    await open(t, As.admin, const LeaderboardPage());
    expect(find.text('Leaderboard'), findsOneWidget);
    expect(find.text('No one has points yet'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await t.runAsync(() async {
      await sharedDb.collection('leaderboard').doc('goa').set({
        'p': {'ann': 12, 'bob': 8, 'quiet_owl': 4},
      });
      await sharedDb.collection('contributors').doc(studentEmail).set({
        'username': 'quiet_owl',
      }, SetOptions(merge: true));
    });
    await open(t, As.student, const LeaderboardPage());
    expect(find.text('Leaderboard'), findsOneWidget);
    expect(find.textContaining('ann'), findsOneWidget);
    expect(find.textContaining('quiet_owl'), findsOneWidget);
  });

  testWidgets('More: Contribute card follows the state', (t) async {
    await open(t, As.student, const MorePage());
    contribState.value = ContribState.none;
    await t.pump();
    expect(find.text('Contributor Leaderboard'), findsOneWidget);
    expect(find.text('Contribute'), findsNothing);
    contribState.value = ContribState.applied;
    await t.pump();
    expect(find.text('Contribute'), findsOneWidget);
    contribState.value = ContribState.declined;
    await t.pump();
    expect(find.text('Contribute'), findsNothing);
  });

  testWidgets('Resources prompt shows once per session', (t) async {
    contributePromptShown = false;
    await open(t, As.student, const SizedBox());
    // Someone who has not applied.
    roleStore = RoleStore(
      sharedDb,
      me: 'f20250001@goa.bits-pilani.ac.in',
      myName: 'New',
    );
    myRoles.value = const MyRoles(email: 'f20250001@goa.bits-pilani.ac.in');
    await t.pumpWidget(
      MaterialApp(
        theme: AppPalette.light.materialTheme,
        home: const ResourcesPage(),
      ),
    );
    await settle(t);
    expect(find.text('Contribute to the Community Now'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
    await t.tap(find.text('Not now'));
    await settle(t);
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(
      MaterialApp(
        theme: AppPalette.light.materialTheme,
        home: const ResourcesPage(),
      ),
    );
    await settle(t);
    expect(find.text('Contribute to the Community Now'), findsNothing);
  });

  testWidgets('Approvals: a failed load says so, and Try again loads it', (
    t,
  ) async {
    final flaky = FlakyFirestore()..down = true;
    await open(t, As.president2, const SizedBox());
    roleStore = RoleStore(flaky, me: cr2Email, myName: 'Dev Patel');
    await t.pumpWidget(
      MaterialApp(
        theme: AppPalette.light.materialTheme,
        home: const Approvals(campus: 'goa', dept: 'ECE'),
      ),
    );
    await settle(t);
    expect(find.text('No connection. Nothing was changed.'), findsOneWidget);
    flaky.down = false;
    await t.tap(find.text('Try again'));
    await settle(t);
    expect(find.text('No connection. Nothing was changed.'), findsNothing);
  });
}
