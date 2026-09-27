import 'package:cgpa_calculator/core/roles/capabilities.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;
  late RoleStore owner;
  final until = DateTime(2027, 6, 1);

  setUp(() async {
    db = FakeFirebaseFirestore();
    owner = RoleStore(
      db,
      me: 'Owner@goa.bits-pilani.ac.in',
      myName: 'Owner',
      actingAs: () => (role: 'owner', viewingAs: null),
    );
    await db.collection('people').doc('f20240001@goa.bits-pilani.ac.in').set({
      'name': 'Asha Rao',
      'campus': 'goa',
    });
  });

  test('an address nobody signed in with can not be appointed', () async {
    final ok = await owner.appoint(
      role: GrantRole.dept,
      email: 'nobody@goa.bits-pilani.ac.in',
      campus: 'goa',
      scope: 'CS',
      expiresAt: until,
    );
    expect(ok, isFalse);
    expect((await db.collection('grants').get()).docs, isEmpty);
  });

  test(
    'appoint writes the grant, the staff index and one audit entry',
    () async {
      final ok = await owner.appoint(
        role: GrantRole.dept,
        email: ' F20240001@goa.bits-pilani.ac.in ',
        campus: 'goa',
        scope: 'ELEC',
        programme: 'A3',
        expiresAt: until,
      );
      expect(ok, isTrue);
      const email = 'f20240001@goa.bits-pilani.ac.in';
      final id = grantId(GrantRole.dept, 'goa', 'ELEC', email);
      final g = await db.collection('grants').doc(id).get();
      expect(g.data()!['name'], 'Asha Rao');
      expect(g.data()!['active'], isTrue);
      expect((await db.collection('staff').doc(email).get()).exists, isTrue);
      final audit = (await db.collection('audit').get()).docs;
      expect(audit, hasLength(1));
      expect(audit.single.data()['summary'], contains('Appointed Asha Rao'));
      expect(
        audit.single.data()['actor']['email'],
        'owner@goa.bits-pilani.ac.in',
      );

      // The appointee sees it; revoking takes it away and is logged too.
      final mine = RoleStore(db, me: email, myName: 'Asha Rao');
      final roles = await mine.loadMine(now: DateTime(2026, 10));
      expect(roles.presidencies.single.scopeLabel, 'ELEC · A3');
      await owner.revoke(roles.grants.single);
      expect((await mine.loadMine(now: DateTime(2026, 10))).grants, isEmpty);
      final log = (await db.collection('audit').get()).docs;
      expect(log, hasLength(2));
    },
  );

  test('a lapsed grant is not live', () async {
    await owner.appoint(
      role: GrantRole.course,
      email: 'f20240001@goa.bits-pilani.ac.in',
      campus: 'goa',
      scope: 'CS F301',
      expiresAt: DateTime(2026, 1, 1),
    );
    final mine = RoleStore(
      db,
      me: 'f20240001@goa.bits-pilani.ac.in',
      myName: 'Asha Rao',
    );
    expect((await mine.loadMine(now: DateTime(2026, 10))).grants, isEmpty);
  });

  group('MyRoles.may', () {
    Grant grant(GrantRole r, String scope) => Grant(
      role: r,
      email: 'x@goa.bits-pilani.ac.in',
      name: 'X',
      campus: 'goa',
      scope: scope,
      active: true,
      expiresAt: until,
    );

    test('a president works in their department and campus only', () {
      final r = MyRoles(
        email: 'x@goa.bits-pilani.ac.in',
        grants: [grant(GrantRole.dept, 'ELEC')],
      );
      expect(
        r.may(Capability.courseStructures, campus: 'goa', scope: 'EEE F111'),
        isTrue,
      );
      expect(
        r.may(Capability.courseStructures, campus: 'goa', scope: 'CS F301'),
        isFalse,
      );
      expect(
        r.may(Capability.courseStructures, campus: 'pilani', scope: 'EEE F111'),
        isFalse,
      );
      expect(r.may(Capability.publish), isFalse);
    });

    test('a CR works on their own course only', () {
      final r = MyRoles(
        email: 'x@goa.bits-pilani.ac.in',
        grants: [grant(GrantRole.course, 'CS F301')],
      );
      expect(
        r.may(Capability.courseResources, campus: 'goa', scope: 'CS F301'),
        isTrue,
      );
      expect(
        r.may(Capability.courseResources, campus: 'goa', scope: 'CS F211'),
        isFalse,
      );
      expect(r.may(Capability.appointCrs), isFalse);
    });

    test('an owner may publish; nobody else may', () {
      expect(
        const MyRoles(email: 'o', owner: true).may(Capability.publish),
        isTrue,
      );
      expect(MyRoles.none.may(Capability.publish), isFalse);
    });
  });
}
