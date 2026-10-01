import 'dart:convert';
import 'dart:io';

import 'package:cgpa_calculator/core/analytics/analytics_store.dart';
import 'package:cgpa_calculator/core/cache/cache_first.dart';
import 'package:cgpa_calculator/core/heads/paths.dart';
import 'package:cgpa_calculator/core/models/offering.dart';
import 'package:cgpa_calculator/core/professors/professor_store.dart';
import 'package:cgpa_calculator/core/roles/maintain_store.dart';
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

  test('a write forgets the saved roster', () async {
    await db.doc('people/p@goa.bits-pilani.ac.in').set({'name': 'Pat'});
    expect(await roles.roster(), isEmpty);
    expect(roles.peekRoster(), isEmpty);
    expect(roles.peekRoster(campus: 'goa'), isNull);
    expect(await roles.owners(), isEmpty);
    expect(roles.peekOwners(), isEmpty);
    expect((await roles.terms()).crDays, defaultTerms.crDays);
    expect(roles.peekTerms()!.crDays, defaultTerms.crDays);
    expect(await roles.audit(campus: 'goa'), isEmpty);
    expect(roles.peekAudit(campus: 'goa'), isEmpty);
    expect(roles.peekAudit(campus: 'goa', limit: 5), isNull);
    final ok = await roles.appoint(
      role: GrantRole.dept,
      email: 'p@goa.bits-pilani.ac.in',
      campus: 'goa',
      scope: 'CS',
      expiresAt: DateTime(2099),
    );
    expect(ok, isTrue);
    expect(roles.peekRoster(), isNull);
    final g = (await roles.roster()).single;
    expect(roles.peekRoster()!.single.expiresAt, g.expiresAt);
    expect(roles.peekRoster()!.single.id, g.id);
    await roles.addOwner('o@goa.bits-pilani.ac.in', 'O');
    expect(roles.peekOwners(), isNull);
    expect((await roles.owners()).single['name'], 'O');
    expect(roles.peekOwners()!.single['name'], 'O');
    await roles.saveTerms((crDays: 1, presidentDays: 2, adminDays: 3));
    expect(roles.peekTerms(), isNull);
  });

  test('professor reads are saved and a write forgets them', () async {
    await db.doc('professors/p1').set({
      'name': 'Dr A',
      'campus': 'goa',
      'department': 'CS',
    });
    final ps = ProfessorStore(db, roles: roles);
    final rows = await ps.department('goa', 'CS');
    expect(ps.peekDepartment('goa', 'CS')!.single.name, 'Dr A');
    expect(ps.peekDepartment('goa', 'EEE'), isNull);
    expect(await ps.taught(rows.single, 'goa'), isEmpty);
    expect(ps.peekTaught(rows.single, 'goa'), isEmpty);
    expect((await ps.get('p1'))!.name, 'Dr A');
    expect(ps.peekGet('p1')!.name, 'Dr A');
    await ps.add('Dr B', 'goa', 'CS');
    expect(ps.peekDepartment('goa', 'CS'), isNull);
    expect(ps.peekTaught(rows.single, 'goa'), isNull);
    expect(ps.peekGet('p1'), isNull);
  });

  test('offerings are saved and a save forgets them', () async {
    final ms = MaintainStore(roles);
    const o = Offering(
      courseId: 'CS F111',
      campus: 'goa',
      term: 'T1',
      components: [],
      updatedAt: 1,
    );
    expect(await ms.offering('CS F111', 'goa', 'T1'), isNull);
    expect(ms.peekOffering('CS F111', 'goa', 'T1'), isNull);
    await ms.save(o, 'Saved');
    final got = await ms.offerings(['CS F111', 'CS F112'], 'goa', 'T1');
    expect(got.keys, ['CS F111']);
    expect(ms.peekOfferings(['CS F111'], 'goa', 'T1')!.keys, ['CS F111']);
    expect(ms.peekOfferings(['CS F111', 'CS F113'], 'goa', 'T1'), isNull);
    expect((await ms.campusOfferings('goa', 'T1')).single.courseId, 'CS F111');
    expect(ms.peekCampusOfferings('goa', 'T1')!.single.courseId, 'CS F111');
    await ms.save(o, 'Again');
    expect(ms.peekOffering('CS F111', 'goa', 'T1'), isNull);
    expect(ms.peekCampusOfferings('goa', 'T1'), isNull);
  });

  test('a fresh offering read skips the saved copy and saves the result', () async {
    final ms = MaintainStore(roles);
    const o = Offering(
      courseId: 'CS F111',
      campus: 'goa',
      term: 'T1',
      components: [],
      updatedAt: 1,
    );
    await ms.save(o, 'Saved');
    expect(await ms.offering('CS F111', 'goa', 'T1'), isNotNull);
    // Changed behind this device's back; the saved copy is still current.
    await db.doc(MaintainStore.pathOf('CS F111', 'goa', 'T1')).delete();
    expect(await ms.offering('CS F111', 'goa', 'T1'), isNotNull);
    expect(await ms.offering('CS F111', 'goa', 'T1', fresh: true), isNull);
    expect(ms.peekOffering('CS F111', 'goa', 'T1'), isNull);
    expect(await ms.offering('CS F111', 'goa', 'T1'), isNull);
  });

  test('analytics reads are saved', () async {
    await db.doc('analytics/2026-10-02').set({
      'sample': 20,
      'goa': {'dau': 2},
    });
    final a = AnalyticsStore(db);
    final t = DateTime.utc(2026, 10, 2, 6);
    expect((await a.days(1, campus: 'goa', now: t)).single.dau, 40);
    expect(a.peekDays(1, campus: 'goa')!.single.dau, 40);
    expect(a.peekDays(1), isNull);
    final c = await a.counts(campus: 'goa', now: t);
    expect(a.peekCounts(campus: 'goa')!.users, c.users);
    expect(a.peekCounts(), isNull);
  });

  group('markers', () {
    Future<Object?> marker(String campus, String path) async =>
        ((await db.doc('heads/$campus').get()).data()?['v'] as Map?)?[path];

    Future<void> setMarker(String campus, String path, int n) =>
        db.doc('heads/$campus').set({
          'v': {path: n},
        }, SetOptions(merge: true));

    // The device's head copy is good for headMaxAge; this is a refresh.
    Future<void> headRefresh() => forget('head|');

    // Makes the saved copy older than any maxAge.
    Future<void> age(String key) async {
      final b = sharedCacheBox!;
      final m = jsonDecode(b.get(key) as String) as Map;
      await b.put(key, jsonEncode({...m, 'at': 0}));
    }

    Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 50));

    test('every shared write moves its path on its campus head', () async {
      await roles.addOwner('o@goa.bits-pilani.ac.in', 'O');
      for (final c in ['goa', 'hyderabad', 'pilani', 'dubai']) {
        expect(await marker(c, Paths.owners), 1, reason: c);
      }
      await roles.saveTerms((crDays: 1, presidentDays: 2, adminDays: 3));
      expect(await marker('dubai', Paths.terms), 1);
      await roles.setOwnerActive('o@goa.bits-pilani.ac.in', false);
      expect(await marker('goa', Paths.owners), 2);

      await db.doc('people/p@goa.bits-pilani.ac.in').set({'name': 'Pat'});
      await roles.appoint(
        role: GrantRole.dept,
        email: 'p@goa.bits-pilani.ac.in',
        campus: 'goa',
        scope: 'CS',
        expiresAt: DateTime(2099),
      );
      expect(await marker('goa', Paths.grants), 1);
      expect(await marker('hyderabad', Paths.grants), isNull);

      await ProfessorStore(db, roles: roles).add('Dr B', 'goa', 'CS');
      expect(await marker('goa', Paths.professors('CS')), 1);

      await ReviewStore(db, uid: 'u1', roles: roles).save(
        courseId: 'CS F111',
        campus: 'goa',
        term: 'T1',
        professorId: null,
        stars: 4,
        recommend: true,
      );
      expect(await marker('goa', Paths.reviews), 1);
      expect(await marker('goa', Paths.reviewsOf('CS F111')), 1);

      await ResourceStore(roles).add(
        const Resource(
          id: '',
          title: 'More',
          url: 'https://drive.google.com/m',
          campus: 'goa',
          department: 'CS',
        ),
      );
      expect(await marker('goa', Paths.resources), 1);

      final contacts = ContactStore(roles);
      await contacts.volunteer('goa', 'CS F111', name: 'P', term: 'T1');
      expect(await marker('goa', Paths.volunteers('CS')), 1);
      await contacts.dismiss(
        (await contacts.offers('goa', 'CS', term: 'T1'))['CS F111']!.single,
      );
      expect(await marker('goa', Paths.volunteers('CS')), 2);

      await contacts.saveProfile(MyRoles.none, name: 'Q', phone: '+911234567');
      expect(await marker('goa', Paths.staff), 1);
    });

    test('a non-student BITS address counts its contact on goa', () async {
      // The rules: isBits() ? campusOf(me) : 'goa', isBits being the student regex.
      final fac = RoleStore(db, me: 'rmenon@pilani.bits-pilani.ac.in', myName: 'R');
      final contacts = ContactStore(fac);
      await contacts.saveProfile(MyRoles.none, name: 'R', phone: '+911234567');
      expect(await marker('goa', Paths.staff), 1);
      expect(await marker('pilani', Paths.staff), isNull);
      await setMarker('goa', Paths.staff, 5);
      await headRefresh();
      await contacts.myStaffContact();
      final saved = sharedCacheBox!.get('staffme|${fac.me}') as String;
      expect(jsonDecode(saved)['ver'], '5');
    });

    test('a listed profile also moves reps', () async {
      final r = MyRoles(
        email: _me,
        grants: [
          Grant(
            role: GrantRole.course,
            email: _me,
            name: 'P',
            campus: 'goa',
            scope: 'CS F111',
            active: true,
            expiresAt: DateTime(2099),
          ),
        ],
      );
      await ContactStore(roles).saveProfile(
        r,
        name: 'P',
        phone: '+911234567',
        showEmail: true,
      );
      expect(await marker('goa', Paths.reps), 1);
      expect(await marker('goa', Paths.staff), 1);
    });

    test('an unmoved marker skips the refetch, a moved one refetches', () async {
      await db.doc('repIndex/goa').set({
        'p': {
          'a@goa.bits-pilani.ac.in': {'name': 'A', 'campus': 'goa', 'roles': []},
        },
      });
      await setMarker('goa', Paths.reps, 1);
      final contacts = ContactStore(roles);
      expect((await contacts.directory('goa')).single.name, 'A');
      await db.doc('repIndex/goa').set({
        'p': {
          'a@goa.bits-pilani.ac.in': {'name': 'B', 'campus': 'goa', 'roles': []},
        },
      });
      // Old by the clock, current by the marker: no read.
      await age('reps|goa');
      await headRefresh();
      expect((await contacts.directory('goa')).single.name, 'A');
      await settle();
      expect((await contacts.directory('goa')).single.name, 'A');
      // The marker moves: the copy is stale, refreshed behind the read.
      await setMarker('goa', Paths.reps, 2);
      await headRefresh();
      expect((await contacts.directory('goa')).single.name, 'A');
      await settle();
      expect((await contacts.directory('goa')).single.name, 'B');
      expect(contacts.peekDirectory('goa')!.single.name, 'B');
    });

    test('with no marker the age decides', () async {
      await db.doc('repIndex/goa').set({
        'p': {
          'a@goa.bits-pilani.ac.in': {'name': 'A', 'campus': 'goa', 'roles': []},
        },
      });
      final contacts = ContactStore(roles);
      await contacts.directory('goa');
      await db.doc('repIndex/goa').set({
        'p': {
          'a@goa.bits-pilani.ac.in': {'name': 'B', 'campus': 'goa', 'roles': []},
        },
      });
      expect((await contacts.directory('goa')).single.name, 'A');
      await settle();
      expect((await contacts.directory('goa')).single.name, 'A');
      await age('reps|goa');
      await contacts.directory('goa');
      await settle();
      expect((await contacts.directory('goa')).single.name, 'B');
    });

    test('professors and resources read by marker too', () async {
      await db.doc('professors/p1').set({
        'name': 'Dr A',
        'campus': 'goa',
        'department': 'CS',
      });
      await setMarker('goa', Paths.professors('CS'), 1);
      await setMarker('goa', Paths.resources, 1);
      await seedLink();
      final ps = ProfessorStore(db, roles: roles);
      final rs = ResourceStore(roles);
      expect((await ps.department('goa', 'CS')).single.name, 'Dr A');
      expect((await rs.department('goa', 'CS')).single.title, 'Notes');
      await db.doc('professors/p1').update({'name': 'Dr Z'});
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
      await age('prof|goa|CS');
      await headRefresh();
      expect((await ps.department('goa', 'CS')).single.name, 'Dr A');
      expect((await rs.department('goa', 'CS')).single.title, 'Notes');
      await settle();
      expect((await ps.department('goa', 'CS')).single.name, 'Dr A');
      expect((await rs.department('goa', 'CS')).single.title, 'Notes');
      await setMarker('goa', Paths.professors('CS'), 2);
      await setMarker('goa', Paths.resources, 2);
      await headRefresh();
      await ps.department('goa', 'CS');
      await rs.department('goa', 'CS');
      await settle();
      expect((await ps.department('goa', 'CS')).single.name, 'Dr Z');
      expect((await rs.department('goa', 'CS')).single.title, 'New');
    });
  });
}
