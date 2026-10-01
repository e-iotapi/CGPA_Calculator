import 'dart:io';

import 'package:cgpa_calculator/core/cache/cache_first.dart';
import 'package:cgpa_calculator/core/resources/resource.dart';
import 'package:cgpa_calculator/core/resources/resource_store.dart';
import 'package:cgpa_calculator/core/reviews/review_store.dart';
import 'package:cgpa_calculator/core/roles/contacts.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/storage/cache_boxes.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

/// A Firestore that is unreachable.
class _Down implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw FirebaseException(plugin: 'firestore', code: 'unavailable');
}

const _me = 'f20230802@goa.bits-pilani.ac.in';

void main() {
  late Directory dir;
  late FakeFirebaseFirestore db;
  late RoleStore roles;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('store_cache');
    Hive.init(dir.path);
    await openSharedCache();
    await openResources();
    db = FakeFirebaseFirestore();
    roles = RoleStore(db, me: _me, myName: 'P');
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  Future<void> seedLink() => db.doc('resourceVersions/goa').set({
    'v': 1,
    'links': {
      'r1': {
        'title': 'Notes',
        'url': 'https://drive.google.com/n',
        'department': 'CS',
      },
    },
  });

  test('offline: a saved department is returned and peeked', () async {
    await seedLink();
    final rows = await ResourceStore(roles).department('goa', 'CS');
    expect(rows.single.title, 'Notes');
    final down = ResourceStore(RoleStore(_Down(), me: _me, myName: 'P'));
    expect((await down.department('goa', 'CS')).single.title, 'Notes');
    expect(down.peekDepartment('goa', 'CS')!.single.title, 'Notes');
    expect(down.peekDepartment('goa', 'EEE'), isNull);
  });

  test(
    'a saved department shows at once; a new version shows next open',
    () async {
      await seedLink();
      final store = ResourceStore(roles);
      await store.department('goa', 'CS');
      await db.doc('resourceVersions/goa').set({
        'v': 2,
        'links': {
          'r1': {
            'title': 'New',
            'url': 'https://drive.google.com/n',
            'department': 'CS',
          },
        },
      });
      expect((await store.department('goa', 'CS')).single.title, 'Notes');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect((await store.department('goa', 'CS')).single.title, 'New');
    },
  );

  test('a write forgets the saved department', () async {
    await seedLink();
    final store = ResourceStore(roles);
    await store.department('goa', 'CS');
    await store.add(
      const Resource(
        id: '',
        title: 'More',
        url: 'https://drive.google.com/m',
        campus: 'goa',
        department: 'CS',
      ),
    );
    expect(store.peekDepartment('goa', 'CS'), isNull);
  });

  test('sign-out clears every saved copy', () async {
    await db.doc('repIndex/goa').set({
      'p': {
        'a@goa.bits-pilani.ac.in': {'name': 'A', 'campus': 'goa', 'roles': []},
      },
    });
    final contacts = ContactStore(roles);
    expect((await contacts.directory('goa')).single.name, 'A');
    expect(contacts.peekDirectory('goa')!.single.name, 'A');
    await ResourceStore(roles).department('goa', 'CS');
    await clearAccountCaches();
    expect(contacts.peekDirectory('goa'), isNull);
    expect(ResourceStore(roles).peekDepartment('goa', 'CS'), isNull);
  });

  test('keys are per campus', () async {
    await db.doc('repIndex/goa').set({'p': <String, dynamic>{}});
    final contacts = ContactStore(roles);
    await contacts.directory('goa');
    expect(contacts.peekDirectory('goa'), isEmpty);
    expect(contacts.peekDirectory('hyderabad'), isNull);
  });

  test(
    'own staff contact and directory entry are saved and forgotten',
    () async {
      final contacts = ContactStore(roles);
      await db.doc('staffContacts/$_me').set({
        'name': 'P',
        'phone': '+911234567',
      });
      await db.doc('directory/$_me').set({
        'name': 'P',
        'campus': 'goa',
        'roles': [
          {
            'role': 'dept',
            'scope': 'CS',
            'until': Timestamp.fromDate(DateTime(2099)),
          },
        ],
        'whatsapp': '+911234567',
      });
      expect((await contacts.myStaffContact())!.phone, '+911234567');
      final d = (await contacts.myDirectory())!;
      expect(contacts.peekMyStaffContact()!.name, 'P');
      final p = contacts.peekMyDirectory()!;
      expect(p.roles.single.until, d.roles.single.until);
      expect(p.whatsapp, '+911234567');
      await contacts.saveProfile(MyRoles.none, name: 'Q', phone: '+911234567');
      expect(contacts.peekMyStaffContact(), isNull);
      expect(contacts.peekMyDirectory(), isNull);
    },
  );

  test(
    'offers are saved per term and a volunteer offer forgets them',
    () async {
      final contacts = ContactStore(roles);
      expect(await contacts.offers('goa', 'CS', term: 'T1'), isEmpty);
      expect(contacts.peekOffers('goa', 'CS', term: 'T1'), isEmpty);
      expect(contacts.peekOffers('goa', 'CS', term: 'T2'), isNull);
      await contacts.volunteer('goa', 'CS F111', name: 'P', term: 'T1');
      expect(contacts.peekOffers('goa', 'CS', term: 'T1'), isNull);
      final got = await contacts.offers('goa', 'CS', term: 'T1');
      expect(got['CS F111']!.single.name, 'P');
      expect(
        contacts.peekOffers('goa', 'CS', term: 'T1')!['CS F111'],
        hasLength(1),
      );
    },
  );

  test('review reads are saved and a review forgets them', () async {
    final rs = ReviewStore(db, uid: 'u1', roles: roles);
    expect(await rs.mine('CS F111'), isNull);
    expect(await rs.byProfessor('CS F111', 'goa'), isEmpty);
    expect((await rs.stats('CS F111', 'goa', professorIds: ['p1'])).count, 0);
    expect(rs.peekByProfessor('CS F111', 'goa'), isEmpty);
    expect(rs.peekStats('CS F111', 'goa', professorIds: ['p1']), isNotNull);
    await rs.save(
      courseId: 'CS F111',
      campus: 'goa',
      term: 'T1',
      professorId: 'p1',
      stars: 4,
      recommend: true,
    );
    expect(rs.peekByProfessor('CS F111', 'goa'), isNull);
    expect(rs.peekStats('CS F111', 'goa', professorIds: ['p1']), isNull);
    expect((await rs.mine('CS F111'))!.stars, 4);
    expect(rs.peekMine('CS F111')!.stars, 4);
    expect((await rs.stats('CS F111', 'goa')).count, 1);
    expect(rs.peekStats('CS F111', 'goa')!.count, 1);
    expect(rs.peekMostReviewed('goa')!.single.courseId, 'CS F111');
    expect((await rs.page('CS F111', 'goa')).reviews, hasLength(1));
    expect(rs.peekPage('CS F111', 'goa')!.reviews, hasLength(1));
  });
}
