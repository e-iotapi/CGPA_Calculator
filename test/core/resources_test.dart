import 'package:cgpa_calculator/core/resources/resource.dart';
import 'package:cgpa_calculator/core/resources/resource_store.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  test('any http(s) website, shown by its host', () {
    expect(hostOf('https://drive.google.com/x'), 'drive.google.com');
    expect(hostOf('https://www.youtube.com/watch?v=1'), 'youtube.com');
    expect(hostOf('https://en.wikipedia.org/wiki/X'), 'en.wikipedia.org');
    expect(hostOf('http://example.edu/notes.pdf'), 'example.edu');
    expect(hostOf('javascript:alert(1)'), isNull);
    expect(hostOf('ftp://files.example.com'), isNull);
    expect(hostOf('https://localhost/x'), isNull);
  });

  test('the same address under another spelling is one link', () {
    expect(
      normaliseUrl('https://www.Drive.google.com/folders/abc/?usp=sharing'),
      normaliseUrl('http://drive.google.com/folders/abc'),
    );
  });

  test('a course link rolls up unless the department has it', () {
    const dept = Resource(
      id: 'a',
      title: 'Past papers',
      url: 'https://drive.google.com/folders/abc',
      campus: 'goa',
      department: 'CS',
    );
    expect(
      shouldRollUp([dept], 'https://drive.google.com/folders/abc/'),
      false,
    );
    expect(shouldRollUp([dept], 'https://drive.google.com/folders/xyz'), true);
    final rolled = dept.copyWith();
    expect(rolled.onDepartment, true);
  });

  test('report ids are sha256 hex of uid + id', () {
    expect(reportId('u', 'r'), hasLength(64));
    expect(reportId('u', 'r'), isNot(reportId('u', 's')));
  });

  group('store', () {
    late FakeFirebaseFirestore db;
    late ResourceStore store;

    setUp(() async {
      Hive.init('.dart_tool/test_hive_resources');
      await openResources();
      await Hive.box(resourcesBoxName).clear();
      db = FakeFirebaseFirestore();
      store = ResourceStore(
        RoleStore(db, me: 'f20230802@goa.bits-pilani.ac.in', myName: 'P'),
        uid: 'uid1',
      );
    });

    tearDown(() => Hive.close());

    test('adding bumps the version, so the cached list is re-read', () async {
      expect(await store.department('goa', 'CS'), isEmpty);
      await store.add(
        const Resource(
          id: '',
          title: 'Notes',
          url: 'https://drive.google.com/n',
          campus: 'goa',
          department: 'CS',
        ),
      );
      expect((await db.doc('resourceVersions/goa').get()).data()!['v'], 1);
      final got = await store.department('goa', 'CS');
      expect(got.single.title, 'Notes');
      expect(got.single.addedByName, 'P');
      expect((await db.collection('audit').get()).docs, hasLength(1));
    });

    test('a report counts once per person and opens the flag', () async {
      const r = Resource(
        id: 'r1',
        title: 'Notes',
        url: 'https://drive.google.com/n',
        campus: 'goa',
        department: 'CS',
      );
      expect(await store.report(r, ReportReason.broken), true);
      final f = (await db.doc('resourceFlags/r1').get()).data()!;
      expect(f['count'], 1);
      expect(f['open'], true);
      expect(f['reasons'], {'broken': 1});
      final open = await store.flags('goa', 'CS');
      expect(open.single.top, ReportReason.broken);
      await store.dismiss(open.single, 'Notes');
      expect(await store.flags('goa', 'CS'), isEmpty);
    });
  });
}
