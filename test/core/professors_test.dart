import 'package:cgpa_calculator/core/professors/professor.dart';
import 'package:cgpa_calculator/core/professors/professor_store.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('search matches partial names, titles ignored', () {
    expect(nameTokens('Dr. R. Menon'), containsAll(['r', 'men', 'menon']));
    expect(nameTokens('Dr. R. Menon'), isNot(contains('dr')));
    const p = Professor(
      id: 'p',
      name: 'Ramesh Menon',
      campus: 'goa',
      department: 'CS',
      aliases: ['Dr. R. Menon'],
    );
    expect(p.matches('men'), isTrue);
    expect(p.matches('ram men'), isTrue);
    expect(p.matches('iyer'), isFalse);
  });

  test('an exact-name duplicate is blocked, case- and space-insensitive', () {
    expect(sameName('Dr. QA Tester', 'dr. qa tester'), isTrue);
    expect(sameName('  Ramesh Menon ', 'Ramesh Menon'), isTrue);
    expect(sameName('Ramesh Menon', 'Dr. R. Menon'), isFalse);
  });

  test('a likely duplicate is caught before Add', () {
    expect(likelySame('Dr. R. Menon', 'Ramesh Menon'), isTrue);
    expect(likelySame('Menon', 'Ramesh Menon'), isTrue);
    expect(likelySame('S. Menon', 'Ramesh Menon'), isFalse);
    expect(likelySame('A. Iyer', 'Ramesh Menon'), isFalse);
  });

  test('merge by pointer: reads follow the survivor', () async {
    final db = FakeFirebaseFirestore();
    final store = ProfessorStore(
      db,
      roles: RoleStore(db, me: 'p@goa.bits-pilani.ac.in', myName: 'P'),
    );
    final keep = await store.add('Ramesh Menon', 'goa', 'CS');
    final gone = await store.add('Dr. R. Menon', 'goa', 'CS');
    await store.merge(keep, gone);

    expect((await store.get(gone.id))!.id, keep.id);
    final list = await store.department('goa', 'CS');
    expect(list.single.name, 'Ramesh Menon');
    expect(list.single.allIds, [keep.id, gone.id]);
    expect(list.single.aliases, ['Dr. R. Menon']);
    // One audit entry for the merge, one per add.
    expect((await db.collection('audit').get()).docs, hasLength(3));

    await store.rename(list.single, 'R. Menon');
    final renamed = (await store.department('goa', 'CS')).single;
    expect(renamed.id, keep.id);
    expect(renamed.aliases, containsAll(['Dr. R. Menon', 'Ramesh Menon']));
  });

  test(
    'Reviews search: by any word of a name, and the courses taught',
    () async {
      final db = FakeFirebaseFirestore();
      final store = ProfessorStore(
        db,
        roles: RoleStore(db, me: 'p@goa.bits-pilani.ac.in', myName: 'P'),
      );
      final keep = await store.add('Ramesh Menon', 'goa', 'CS');
      final gone = await store.add('Dr. R. Menon', 'goa', 'CS');
      await store.add('Anita Iyer', 'goa', 'EEE');
      await store.add('Ramesh Rao', 'pilani', 'CS');
      await store.merge(keep, gone);

      expect(
        [for (final p in await store.search('goa', 'men')) p.name],
        ['Ramesh Menon'],
      );
      expect(
        [for (final p in await store.search('goa', 'ram')) p.name],
        ['Ramesh Menon'],
      );
      expect(await store.search('goa', 'ramesh iyer'), isEmpty);
      expect(await store.search('goa', ''), isEmpty);

      Future<void> offer(String course, String term, List<String> profs) => db
          .collection('courses')
          .doc(course)
          .collection('offerings')
          .doc('goa_$term')
          .set({
            'courseId': course,
            'campus': 'goa',
            'term': term,
            'professors': profs,
          });
      await offer('CS F211', '2025-26-1', [keep.id]);
      await offer('CS F211', '2024-25-1', [gone.id]);
      await offer('CS F301', '2025-26-2', [gone.id, 'other']);
      await offer('CS F303', '2025-26-2', ['other']);

      final survivor = (await store.get(keep.id))!;
      final taught = await store.taught(survivor, 'goa');
      expect(taught.keys.toSet(), {'CS F211', 'CS F301'});
      expect(taught['CS F211'], ['2025-26-1', '2024-25-1']);
    },
  );
}
