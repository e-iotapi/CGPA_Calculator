import 'package:cgpa_calculator/core/contrib/contributor_store.dart';
import 'package:cgpa_calculator/core/contrib/leaderboard_store.dart';
import 'package:cgpa_calculator/core/resources/resource.dart';
import 'package:cgpa_calculator/core/resources/resource_store.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

const _stu = 'f20230456@goa.bits-pilani.ac.in';
const _pres = 'f20230802@goa.bits-pilani.ac.in';

Resource _link(String title, {String url = 'https://drive.google.com/x'}) =>
    Resource(
      id: '',
      title: title,
      url: url,
      campus: 'goa',
      department: 'ELEC',
    );

void main() {
  test('usernames: 3 to 20 of a-z 0-9 _, after trim and lower-casing', () {
    expect(validUsername('  Cee_9 '), isTrue);
    expect(validUsername('ab'), isFalse);
    expect(validUsername('a' * 21), isFalse);
    expect(validUsername('has space'), isFalse);
    expect(validUsername('dot.dot'), isFalse);
  });

  group('requests, grant, username', () {
    late FakeFirebaseFirestore db;
    late ContributorStore student, president;

    setUp(() {
      db = FakeFirebaseFirestore();
      student = ContributorStore(RoleStore(db, me: _stu, myName: 'Stu'));
      president = ContributorStore(RoleStore(db, me: _pres, myName: 'Pres'));
    });

    test('apply, once; withdraw; apply again', () async {
      await student.apply('goa', 'ELEC');
      final r = (await student.myRequest('goa', 'ELEC'))!;
      expect(r.status, RequestStatus.pending);
      expect(r.id, 'goa|ELEC|$_stu');
      expect(
        () => student.apply('goa', 'ELEC'),
        throwsA(isA<ContribError>().having((e) => e.code, 'code', 'exists')),
      );
      await student.withdraw(r);
      expect((await student.myRequest('goa', 'ELEC'))!.status,
          RequestStatus.withdrawn);
      await student.apply('goa', 'ELEC');
      final head = (await db.doc('heads/goa').get()).data()!['v'] as Map;
      expect(head['contributorRequests/ELEC'], 3);
    });

    test('approve writes the request, an unexpiring grant and two audits',
        () async {
      await db.doc('people/$_stu').set({'name': 'Stu'});
      await student.apply('goa', 'ELEC');
      final pending = await president.requests('goa', 'ELEC');
      expect(pending.single.email, _stu);
      await president.approve(pending.single);
      final g = (await db.doc('grants/contributor|goa|goa|$_stu').get()).data()!;
      expect(g['active'], true);
      expect(g['scope'], 'goa');
      expect(g['dept'], 'ELEC');
      expect((g['expiresAt'] as Timestamp).toDate().toUtc().year, 2100);
      expect(
        (await db.doc('contributorRequests/goa|ELEC|$_stu').get()).data()!['status'],
        'approved',
      );
      expect((await db.collection('audit').get()).docs, hasLength(2));
      expect(await president.requests('goa', 'ELEC'), isEmpty);
      expect((await student.me('goa')).isContributor, isTrue);
      // Staff entries would make the contributor privileged: none written.
      expect((await db.doc('staff/$_stu').get()).exists, isFalse);
    });

    test('decline keeps the reason; revoke deactivates the grant', () async {
      await student.apply('goa', 'ELEC');
      final r = (await president.requests('goa', 'ELEC')).single;
      await president.decline(r, reason: 'not yet');
      final d = (await db.doc('contributorRequests/${r.id}').get()).data()!;
      expect(d['status'], 'declined');
      expect(d['reason'], 'not yet');
      expect(d['decidedBy'], _pres);

      await db.doc('grants/contributor|goa|goa|$_stu').set({
        'role': 'contributor',
        'email': _stu,
        'name': 'Stu',
        'campus': 'goa',
        'scope': 'goa',
        'active': true,
        'expiresAt': Timestamp.fromDate(contributorUntil),
      });
      final g = Grant.fromMap(
        (await db.doc('grants/contributor|goa|goa|$_stu').get()).data()!,
      );
      expect(g.role, GrantRole.contributor);
      await president.revoke(g);
      expect(
        (await db.doc('grants/${g.id}').get()).data()!['active'],
        false,
      );
    });

    test('claim a username: bad, free, then taken', () async {
      expect(
        () => student.claimUsername('goa', 'no'),
        throwsA(isA<ContribError>()),
      );
      await student.claimUsername('goa', ' Cee_9 ');
      expect((await db.doc('usernames/goa|cee_9').get()).data()!['email'], _stu);
      expect((await db.doc('contributors/$_stu').get()).data(), {
        'username': 'cee_9',
        'campus': 'goa',
        'points': 0,
      });
      expect(
        () => president.claimUsername('goa', 'cee_9'),
        throwsA(isA<UsernameTaken>()),
      );
    });

    test('a username claimed after earning points keeps the points', () async {
      await db.doc('contributors/$_stu').set({'campus': 'goa', 'points': 8});
      await student.claimUsername('goa', 'later');
      final c = (await db.doc('contributors/$_stu').get()).data()!;
      expect(c['username'], 'later');
      expect(c['points'], 8);
    });
  });

  group('links', () {
    late FakeFirebaseFirestore db;
    late ResourceStore contributor, approver;

    setUp(() async {
      Hive.init('.dart_tool/test_hive_contrib');
      await openResources();
      await Hive.box(resourcesBoxName).clear();
      db = FakeFirebaseFirestore();
      contributor = ResourceStore(
        RoleStore(db, me: _stu, myName: 'Stu'),
        uid: 'u1',
      );
      approver = ResourceStore(
        RoleStore(db, me: _pres, myName: 'Pres'),
        uid: 'u2',
      );
    });

    tearDown(() => Hive.close());

    test('submit: unapproved, in the mirror and pending, markers moved',
        () async {
      await db.doc('contributors/$_stu').set({
        'username': 'cee',
        'campus': 'goa',
        'points': 0,
      });
      final id = await contributor.addAsContributor(_link('Notes'));
      final r = (await db.doc('resources/$id').get()).data()!;
      expect(r['approved'], false);
      expect(r['publishedAt'], isNotNull);
      expect(r['batchId'], isNotEmpty);
      final v = (await db.doc('resourceVersions/goa').get()).data()!;
      expect(v['v'], 1);
      expect((v['links'] as Map)[id]['approved'], false);
      final p = (await db.doc('pending/goa|ELEC').get()).data()!;
      final b = (p['batches'] as Map)[r['batchId']] as Map;
      expect(b['username'], 'cee');
      expect((b['links'] as Map).keys, [id]);
      final marks = (await db.doc('heads/goa').get()).data()!['v'] as Map;
      expect(marks['resources'], 1);
      expect(marks['pending/ELEC'], 1);
      expect((await db.collection('audit').get()).docs, hasLength(1));
      expect(
        (await contributor.mine('goa')).single.approved,
        false,
      );
    });

    test('a batch shares one id; the queue is one entry', () async {
      final bid = await contributor.addBatchAsContributor([
        _link('One', url: 'https://a.example.com/1'),
        _link('Two', url: 'https://a.example.com/2'),
      ]);
      final q = await approver.pending('goa', 'ELEC');
      expect(q.single.id, bid);
      expect(q.single.links.map((l) => l.title), unorderedEquals(['One', 'Two']));
      final marks = (await db.doc('heads/goa').get()).data()!['v'] as Map;
      expect(marks['resources'], 2);
    });

    test('approve: +4 each, board mirrors points, pending shrinks', () async {
      await db.doc('contributors/$_stu').set({
        'username': 'cee',
        'campus': 'goa',
        'points': 0,
      });
      await contributor.addBatchAsContributor([
        _link('One', url: 'https://a.example.com/1'),
        _link('Two', url: 'https://a.example.com/2'),
      ]);
      final b = (await approver.pending('goa', 'ELEC')).single;
      await approver.approve(b, linkIds: [b.links.first.id]);
      expect((await db.doc('contributors/$_stu').get()).data()!['points'], 4);
      expect((await db.doc('leaderboard/goa').get()).data()!['p'], {'cee': 4});
      var left = (await approver.pending('goa', 'ELEC')).single;
      expect(left.links, hasLength(1));
      final done = (await db.doc('resources/${b.links.first.id}').get()).data()!;
      expect(done['approved'], true);
      final mirror = (await db.doc('resourceVersions/goa').get()).data()!;
      expect((mirror['links'] as Map)[b.links.first.id]['approved'], true);

      await approver.approve(left);
      expect((await db.doc('contributors/$_stu').get()).data()!['points'], 8);
      expect((await db.doc('leaderboard/goa').get()).data()!['p'], {'cee': 8});
      expect(await approver.pending('goa', 'ELEC'), isEmpty);
      expect((await LeaderboardStore(db).of('goa')).single.points, 8);
    });

    test('approve without a username creates contributors; no board', () async {
      await contributor.addAsContributor(_link('Notes'));
      await approver.approve((await approver.pending('goa', 'ELEC')).single);
      final c = (await db.doc('contributors/$_stu').get()).data()!;
      expect(c['points'], 4);
      expect(c['campus'], 'goa');
      expect((await db.doc('leaderboard/goa').get()).exists, isFalse);
    });

    test('reject: removed with a reason, off the mirror, no points', () async {
      final id = await contributor.addAsContributor(_link('Notes'));
      await approver.reject(
        (await approver.pending('goa', 'ELEC')).single,
        reason: 'duplicate',
      );
      final r = (await db.doc('resources/$id').get()).data()!;
      expect(r['removed'], true);
      expect(r['rejectedReason'], 'duplicate');
      expect(
        ((await db.doc('resourceVersions/goa').get()).data()!['links'] as Map)
            .containsKey(id),
        false,
      );
      expect(await approver.pending('goa', 'ELEC'), isEmpty);
      expect((await db.doc('contributors/$_stu').get()).exists, isFalse);
    });

    test('an edit keeps approval and publishedAt, and bumps the version',
        () async {
      final id = await contributor.addAsContributor(_link('Notes'));
      final before = (await db.doc('resources/$id').get()).data()!;
      final mine = (await contributor.mine('goa')).single;
      await contributor.updateOwn(mine.copyWith(title: 'Better notes'));
      final after = (await db.doc('resources/$id').get()).data()!;
      expect(after['title'], 'Better notes');
      expect(after['approved'], false);
      expect(after['publishedAt'], before['publishedAt']);
      final v = (await db.doc('resourceVersions/goa').get()).data()!;
      expect(v['v'], 2);
      expect((v['links'] as Map)[id]['approved'], false);
      expect((v['links'] as Map)[id]['title'], 'Better notes');
    });

    test('readers hide an unapproved link after 15 days, not before', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      Map<String, dynamic> row(int ago) => {
        'title': 'T',
        'url': 'https://a.example.com/x',
        'department': 'ELEC',
        'scope': 'department',
        'courseIds': <String>[],
        'pinnedToDepartment': false,
        'approved': false,
        'publishedAt': Timestamp.fromMillisecondsSinceEpoch(
          now - ago * 86400000,
        ),
      };
      await db.doc('resourceVersions/goa').set({
        'v': 1,
        'links': {'fresh': row(14), 'stale': row(16)},
      });
      final got = await contributor.department('goa', 'ELEC');
      expect(got.map((r) => r.id), ['fresh']);
    });
  });
}
