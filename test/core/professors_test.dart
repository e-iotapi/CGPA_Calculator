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
}
