// heads/{campus} (PERF_TEST_PLAN.md §A): scheme saves move a course's
// version; a publish and the contact land on every campus.
import 'dart:io';

import 'package:cgpa_calculator/core/cache/cache_first.dart';
import 'package:cgpa_calculator/core/heads/heads.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory dir;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('hive_heads');
    Hive.init(dir.path);
    await openSharedCache();
  });
  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test(
    'a scheme save moves only its course; publishes reach every campus',
    () async {
      final db = FakeFirebaseFirestore();
      var b = db.batch();
      bumpOfferings(b, db, 'goa', '2026-27-1', ['CS F372', 'EEE F211']);
      setOnAllHeads(b, db, {'catalog': 7, 'catalogSchema': 1});
      await b.commit();
      b = db.batch();
      bumpOfferings(b, db, 'goa', '2026-27-1', ['CS F372']);
      await b.commit();
      final goa = (await headFor('goa', db: db))!;
      expect(goa.offering('CS F372', '2026-27-1'), 2);
      expect(goa.offering('EEE F211', '2026-27-1'), 1);
      expect(goa.offering('CS F372', '2025-26-2'), isNull);
      expect(goa.catalog, 7);
      expect((await headFor('hyderabad', db: db))!.catalog, 7);
      expect((await headFor('hyderabad', db: db))!.offerings, isEmpty);
    },
  );

  test('a head is read once, then served from the cache', () async {
    final db = FakeFirebaseFirestore();
    await db.doc('heads/goa').set({'catalog': 3});
    expect((await headFor('goa', db: db))!.catalog, 3);
    await db.doc('heads/goa').set({'catalog': 4});
    expect((await headFor('goa', db: db))!.catalog, 3);
  });
}
