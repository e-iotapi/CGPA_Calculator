// U13 / B2: Electives (GEN), the claim flow, Appoint and Work as.
import 'package:cgpa_calculator/admin/grant_form.dart';
import 'package:cgpa_calculator/admin/maintain.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/core/models/programmes.dart';
import 'package:cgpa_calculator/core/roles/claim_store.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/features/roles/role_switch_page.dart';
import 'package:cgpa_calculator/shared/widgets/confirm_dialog.dart';
import 'package:cgpa_calculator/shared/widgets/pill_button.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const pres = 'f20230802@goa.bits-pilani.ac.in';
const course = 'BITS F225'; // a core course of the electronics programme AA

Grant grant({
  String scope = 'ELEC',
  String? programme = 'AA',
  bool secretary = false,
  String email = pres,
}) => Grant(
  role: GrantRole.dept,
  email: email,
  name: 'Meera Iyer',
  campus: 'goa',
  scope: scope,
  programme: programme,
  active: true,
  expiresAt: DateTime.now().add(const Duration(days: 100)),
  secretary: secretary,
);

void main() {
  late FakeFirebaseFirestore db;

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
  });

  void signIn(String email, {MyRoles? roles}) {
    roleStore = RoleStore(db, me: email, myName: 'Meera Iyer');
    myRoles.value = roles ?? MyRoles(email: email);
  }

  Widget app(Widget home) =>
      MaterialApp(theme: AppPalette.light.materialTheme, home: home);

  group('GEN in the app', () {
    test('an unknown prefix is GEN; it is never a programme', () {
      expect(deptOf('BITS F225'), genDept);
      expect(deptOf('HSS F211'), genDept);
      expect(deptOf('CS F211'), 'CS');
      expect(deptOf('EEE F111'), 'ELEC');
      expect(departments.containsKey(genDept), isFalse);
      expect(departmentOfProgramme('GEN'), isNull);
      expect(departmentName(genDept), 'Electives');
      expect(branchCode(genDept), 'Electives');
    });

    test(
      'a claim moves a GEN course; a claim on a department course is ignored',
      () {
        final claim = CourseClaim(
          campus: 'goa',
          courseId: course,
          dept: 'ELEC',
          byName: 'M',
          byEmail: pres,
          at: 0,
        );
        expect(managingDept(course, {course: claim}), 'ELEC');
        expect(managingDept(course, const {}), genDept);
        expect(managingDept('CS F211', {'CS F211': claim}), 'CS');
      },
    );

    test('managedCourses: the claimant gains the course, GEN loses it', () {
      final claim = CourseClaim(
        campus: 'goa',
        courseId: course,
        dept: 'ELEC',
        byName: 'M',
        byEmail: pres,
        at: 0,
      );
      bool has(String d, Map<String, CourseClaim> c) =>
          managedCourses(d, c).any((m) => m.id == course);
      expect(has(genDept, const {}), isTrue);
      expect(has('ELEC', const {}), isFalse);
      expect(has('ELEC', {course: claim}), isTrue);
      expect(has(genDept, {course: claim}), isFalse);
      expect(
        claimableCourses('ELEC', const {}).any((m) => m.id == course),
        isTrue,
      );
      expect(
        claimableCourses('ELEC', {course: claim}).any((m) => m.id == course),
        isFalse,
      );
    });
  });

  group('ClaimStore', () {
    test('claim writes the doc, the audit entry and the marker', () async {
      signIn(pres);
      final store = ClaimStore(roleStore!);
      await store.claim('goa', course, 'ELEC');
      final d = await db.doc('courseClaims/goa|$course').get();
      expect(d.data()!['dept'], 'ELEC');
      expect(d.data()!['auditId'], isNotNull);
      final a = await db.collection('audit').doc(d.data()!['auditId']).get();
      expect(a.data()!['path'], 'courseClaims/goa|$course');
      expect((await store.claims('goa'))[course]?.dept, 'ELEC');
    });

    test('a second claim is refused as taken', () async {
      signIn(pres);
      final store = ClaimStore(roleStore!);
      await store.claim('goa', course, 'ELEC');
      expect(
        () => store.claim('goa', course, 'CS'),
        throwsA(isA<ClaimError>().having((e) => e.code, 'code', 'taken')),
      );
    });

    test('unclaim deletes the claim under a derived audit id', () async {
      signIn(pres);
      final store = ClaimStore(roleStore!);
      await db.doc('courseClaims/goa|$course').set({
        'campus': 'goa',
        'courseId': course,
        'dept': 'ELEC',
        'at': Timestamp.fromMillisecondsSinceEpoch(1000),
      });
      await store.unclaim('goa', course);
      expect((await db.doc('courseClaims/goa|$course').get()).exists, isFalse);
      final audit = await db.collection('audit').get();
      expect(audit.docs.single.id, 'del|goa|$course|1000');
    });
  });

  group('Electives screens', () {
    testWidgets('DeptHome calls it Electives and has no Hand over', (t) async {
      final g = grant(scope: genDept, programme: null);
      signIn(pres, roles: MyRoles(email: pres, grants: [g]));
      await t.pumpWidget(app(const DeptHome(campus: 'goa', dept: genDept)));
      await t.pumpAndSettle();
      expect(find.text('Electives'), findsWidgets);
      expect(find.text('Hand over to your successor'), findsNothing);
    });

    testWidgets('DeptHome of a department still hands over', (t) async {
      signIn(pres, roles: MyRoles(email: pres, grants: [grant()]));
      await t.pumpWidget(app(const DeptHome(campus: 'goa', dept: 'ELEC')));
      await t.pumpAndSettle();
      expect(find.text('Hand over to your successor'), findsOneWidget);
    });

    Future<void> openCourses(WidgetTester t, Grant g) async {
      signIn(pres, roles: MyRoles(email: pres, grants: [g]));
      await t.pumpWidget(app(DeptCourses(campus: 'goa', dept: g.scope)));
      await t.pumpAndSettle();
      // The claim list sits below the (lazy) course rows; search brings it up.
      await t.enterText(find.byType(TextField).first, course);
      await t.pumpAndSettle();
    }

    testWidgets('a president sees Claim on a GEN core course', (t) async {
      await openCourses(t, grant());
      expect(find.text('Claim'), findsWidgets);
      expect(find.textContaining('$course ·'), findsOneWidget);
    });

    testWidgets('a secretary does not', (t) async {
      await openCourses(t, grant(secretary: true));
      expect(find.text('Claim'), findsNothing);
    });

    testWidgets('Cancel keeps it, Claim moves the course under ELEC', (
      t,
    ) async {
      await openCourses(t, grant());
      final pill = find.widgetWithText(PillButton, 'Claim').first;
      await t.ensureVisible(pill);
      await t.tap(pill);
      await t.pumpAndSettle();
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(await db.collection('courseClaims').get().then((s) => s.size), 0);

      await t.tap(pill);
      await t.pumpAndSettle();
      await t.tap(
        find.descendant(
          of: find.byType(ConfirmDialog),
          matching: find.text('Claim'),
        ),
      );
      await t.pumpAndSettle();
      final claims = await db.collection('courseClaims').get();
      expect(claims.size, 1);
      expect(claims.docs.single.data()['dept'], 'ELEC');
    });

    testWidgets('a claimed course shows under its claimant', (t) async {
      await db.doc('courseClaims/goa|$course').set({
        'campus': 'goa',
        'courseId': course,
        'dept': 'ELEC',
        'at': Timestamp.fromMillisecondsSinceEpoch(1000),
      });
      await openCourses(t, grant());
      expect(find.textContaining('$course ·'), findsOneWidget);
      expect(find.text('Claimed from Electives'), findsOneWidget);
    });

    testWidgets('Work as lists GEN as Electives', (t) async {
      final g = grant(scope: genDept, programme: null);
      signIn(pres, roles: MyRoles(email: pres, grants: [g]));
      await t.pumpWidget(app(const RoleSwitchPage()));
      await t.pumpAndSettle();
      expect(find.text('Elective Contributor'), findsOneWidget);
      expect(find.textContaining('Electives · until'), findsOneWidget);
      expect(roleLabel(g), 'Electives');
    });

    testWidgets('Appoint offers Electives to an owner, not to a president', (
      t,
    ) async {
      signIn(
        'owner@example.com',
        roles: const MyRoles(email: 'owner@example.com', owner: true),
      );
      await t.pumpWidget(app(const AdminGrant()));
      await t.pumpAndSettle();
      expect(find.text('Electives'), findsOneWidget);
      await t.tap(find.text('Electives'));
      await t.pumpAndSettle();
      expect(find.textContaining('No branch, and no handover'), findsOneWidget);
      expect(find.text('Choose a department'), findsNothing);
      expect(
        grantLabel(GrantRole.dept, genDept, 'goa'),
        'Grant — electives Goa',
      );

      signIn(pres, roles: MyRoles(email: pres, grants: [grant()]));
      await t.pumpWidget(app(const SizedBox()));
      await t.pumpWidget(app(const AdminGrant()));
      await t.pumpAndSettle();
      expect(find.text('Electives'), findsNothing);
    });
  });
}
