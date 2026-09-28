import 'dart:io';

import 'package:cgpa_calculator/core/cache/cache_first.dart';
import 'package:cgpa_calculator/core/roles/contacts.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/volunteer_message.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

const pres = 'f20230802@goa.bits-pilani.ac.in';
final until = DateTime(2027, 1, 1);

Grant grant(GrantRole role, String scope, {DateTime? ends}) => Grant(
  role: role,
  email: pres,
  name: 'P',
  campus: 'goa',
  scope: scope,
  programme: role == GrantRole.dept ? 'A3' : null,
  active: true,
  expiresAt: ends ?? until,
);

void main() {
  test('RepProfile is due until both documents cover every role', () {
    final r = MyRoles(email: pres, grants: [grant(GrantRole.dept, 'ELEC')]);
    expect(needsProfile(r, hasStaffContact: false), isTrue);
    expect(needsProfile(r, hasStaffContact: true), isTrue);
    final listed = DirectoryEntry(
      email: pres,
      name: 'P',
      campus: 'goa',
      roles: listedRoles(r),
      shownEmail: pres,
    );
    expect(needsProfile(r, hasStaffContact: true, directory: listed), isFalse);
    // A new CR role, or a renewal, brings it back.
    final more = MyRoles(
      email: pres,
      grants: [
        grant(GrantRole.dept, 'ELEC'),
        grant(GrantRole.course, 'EEE F211'),
      ],
    );
    expect(
      needsProfile(more, hasStaffContact: true, directory: listed),
      isTrue,
    );
    final renewed = MyRoles(
      email: pres,
      grants: [grant(GrantRole.dept, 'ELEC', ends: DateTime(2027, 6, 1))],
    );
    expect(
      needsProfile(renewed, hasStaffContact: true, directory: listed),
      isTrue,
    );
    // Owners and admins: staff contacts only.
    const owner = MyRoles(email: 'o@gmail.com', owner: true);
    expect(needsProfile(owner, hasStaffContact: true), isFalse);
    expect(
      needsProfile(const MyRoles(email: 's'), hasStaffContact: false),
      isFalse,
    );
  });

  test(
    'saving writes staff contacts, and the directory for a president',
    () async {
      final db = FakeFirebaseFirestore();
      final store = ContactStore(RoleStore(db, me: pres, myName: 'P'));
      final r = MyRoles(email: pres, grants: [grant(GrantRole.dept, 'ELEC')]);
      await store.saveProfile(
        r,
        name: ' P ',
        phone: '+91 98765 43210',
        whatsapp: '98765 43210',
      );
      expect((await store.myStaffContact())!.phone, '+91 98765 43210');
      final d = (await store.myDirectory())!;
      expect(d.summary, 'WhatsApp');
      expect(d.name, 'P');
      expect(await store.profileDue(r), isFalse);
    expect(await store.staffPhones(), {pres: '+91 98765 43210'});
      expect(
        (await store.directory('goa')).single.liveAt(DateTime(2026)),
        hasLength(1),
      );
      expect(d.liveAt(DateTime(2027, 2)), isEmpty);
    },
  );

  test('succession never extends a term', () {
    final now = DateTime(2026, 9, 27);
    final long = grant(GrantRole.dept, 'ELEC');
    expect(RoleStore.outgoingExpiry(long, now).difference(now).inDays, 19);
    final soon = grant(GrantRole.dept, 'ELEC', ends: DateTime(2026, 10, 2));
    expect(RoleStore.outgoingExpiry(soon, now), soon.expiresAt);
    expect(RoleStore.successorProblem(long, pres), 'That is you.');
    expect(
      RoleStore.successorProblem(long, 'f20240001@pilani.bits-pilani.ac.in'),
      contains('Goa'),
    );
    expect(
      RoleStore.successorProblem(long, 'f20240001@goa.bits-pilani.ac.in'),
      isNull,
    );
  });

  test('handover and cancel, in the data', () async {
    final db = FakeFirebaseFirestore();
    final roles = RoleStore(db, me: pres, myName: 'P');
    const next = 'f20240001@goa.bits-pilani.ac.in';
    await db.collection('people').doc(next).set({'name': 'N', 'campus': 'goa'});
    await db.collection('config').doc('grantTerms').set({
      'crDays': 183,
      'presidentDays': 365,
      'adminDays': 730,
    });
    final mine = grant(GrantRole.dept, 'ELEC');
    await db.collection('grants').doc(mine.id).set({
      'role': 'dept',
      'email': pres,
      'name': 'P',
      'campus': 'goa',
      'scope': 'ELEC',
      'programme': 'A3',
      'active': true,
      'expiresAt': until,
    });
    final now = DateTime(2026, 9, 27);
    expect(await roles.handOver(mine, next, now: now), isTrue);
    final after = Grant.fromMap(
      (await db.collection('grants').doc(mine.id).get()).data()!,
    );
    expect(after.handedTo, next);
    expect(after.expiresBefore, until);
    final theirs = Grant.fromMap(
      (await db
              .collection('grants')
              .doc(grantId(GrantRole.dept, 'goa', 'ELEC', next))
              .get())
          .data()!,
    );
    expect(theirs.active, isTrue);
    expect(theirs.programme, 'A3');

    await roles.cancelHandover(after);
    final back = Grant.fromMap(
      (await db.collection('grants').doc(mine.id).get()).data()!,
    );
    expect(back.handedTo, isNull);
    expect(back.expiresAt, until);
    final gone = (await db.collection('staff').doc(next).get()).data()!;
    expect(gone['presidentOf'], isEmpty);
  });

  test('volunteer offers: this term, by course', () async {
    final db = FakeFirebaseFirestore();
    const s = 'f20230456@goa.bits-pilani.ac.in';
    final store = ContactStore(RoleStore(db, me: s, myName: 'S'));
    await store.volunteer('goa', 'EEE F211', name: 'S', term: '2026-27-1');
    final pres = ContactStore(RoleStore(db, me: 'p', myName: 'P'));
    expect(
      (await pres.offers('goa', 'ELEC', term: '2026-27-1'))['EEE F211'],
      hasLength(1),
    );
    expect(await pres.offers('goa', 'ELEC', term: '2026-27-2'), isEmpty);
    final v = (await store.myOffer('goa', 'EEE F211'))!;
    await store.withdraw(v);
    expect(await pres.offers('goa', 'ELEC', term: '2026-27-1'), isEmpty);
  });

  test('myOffer caches for 24h; volunteer/withdraw invalidate it', () async {
    final dir = await Directory.systemTemp.createTemp('contacts_cache');
    Hive.init(dir.path);
    await openSharedCache();
    addTearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });

    final db = FakeFirebaseFirestore();
    const s = 'f20230456@goa.bits-pilani.ac.in';
    final store = ContactStore(RoleStore(db, me: s, myName: 'S'));

    await store.volunteer('goa', 'EEE F211', name: 'S', term: '2026-27-1');
    final v1 = await store.myOffer('goa', 'EEE F211');
    expect(v1!.open, isTrue);

    // A second call within 24h is served from cache: it doesn't see a write
    // made directly against Firestore, bypassing the store.
    await db
        .collection('volunteers')
        .doc(v1.id)
        .update({'open': false});
    final v2 = await store.myOffer('goa', 'EEE F211');
    expect(v2!.open, isTrue);

    // withdraw() invalidates the cache, so the next read is live.
    await store.withdraw(v1);
    final v3 = await store.myOffer('goa', 'EEE F211');
    expect(v3!.open, isFalse);
  });

  test('the WhatsApp messages, verbatim', () {
    expect(
      deadlineText(defaultDeadline(DateTime(2026, 9, 27, 11))),
      '6:00 PM on Wednesday, 30 September 2026',
    );
    String msg(List<String> v) => volunteerMessage(
      courseCode: 'EEE F211',
      courseTitle: 'Electrical Machines',
      volunteers: v,
      deadline: '6:00 PM on Wednesday, 30 September 2026',
      presidentName: 'P',
      departmentName: 'Electronics',
      deptKey: 'ELEC',
      campusName: 'Goa',
    );
    expect(
      msg(['A']),
      'Dear students of EEE F211 Electrical Machines,\n\n'
      'The course does not have a Class Representative at present. A has '
      'volunteered for the role.\n\n'
      'Unless an objection is received by 6:00 PM on Wednesday, 30 September '
      '2026, A will be appointed as the Class Representative for EEE F211. '
      'Should you have an objection, please write to me directly before that '
      'time.\n\n'
      'Regards,\nP\nDepartment President, Electronics (ELEC), Goa',
    );
    final many = msg(['A', 'B']);
    expect(many, contains('volunteered for the role:\n\n1. A\n2. B\n\n'));
    expect(many, contains('The result will be announced in this group.'));
  });
}
