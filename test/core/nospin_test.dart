import 'dart:async';
import 'dart:io';

import 'package:cgpa_calculator/admin/dept_list.dart';
import 'package:cgpa_calculator/admin/duplicates.dart';
import 'package:cgpa_calculator/app/router.dart';
import 'package:cgpa_calculator/core/cache/cache_first.dart';
import 'package:cgpa_calculator/core/professors/professor.dart';
import 'package:cgpa_calculator/core/professors/professor_store.dart';
import 'package:flutter/material.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  test('peekResolved follows a merge to the survivor, from saved copies', () async {
    final dir = await Directory.systemTemp.createTemp('nospin');
    Hive.init(dir.path);
    await openSharedCache();
    final db = FakeFirebaseFirestore();
    await db.doc('professors/a').set({'name': 'A. Old', 'mergedInto': 'b'});
    await db.doc('professors/b').set({'name': 'A. Sharma'});
    final store = ProfessorStore(db);
    expect(store.peekResolved('a'), isNull);
    await store.get('a');
    expect(store.peekResolved('a')!.name, 'A. Sharma');
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('likelyPairs pairs the same surname', () {
    Professor p(String id, String n) =>
        Professor(id: id, name: n, campus: 'goa', department: 'CS');
    final pairs = likelyPairs([p('1', 'R. Menon'), p('2', 'Ravi Menon'), p('3', 'S. Rao')]);
    expect(pairs.map((x) => (x.a.id, x.b.id)), [('1', '2')]);
  });

  test('campusBranchesNow is the list campusBranches gives', () async {
    expect(campusBranchesNow('goa'), await campusBranches('goa'));
  });

  testWidgets('a loaded deferred page draws in the first frame', (t) async {
    final never = Completer<void>();
    await t.pumpWidget(MaterialApp(
      home: DeferredPage(load: never.future, loaded: true, page: () => const Text('page')),
    ));
    expect(find.text('page'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
