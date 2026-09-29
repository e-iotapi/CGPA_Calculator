// Sync's quota path (PERF_TEST_PLAN.md §A.4): after the first transaction
// push, a push is one plain update; the pull check brings back only a newer
// copy, and applies it.
import 'dart:io';

import 'package:cgpa_calculator/core/models/marks.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/sync.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  late Directory dir;
  late FakeFirebaseFirestore db;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('hive_sync');
    Hive.init(dir.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(CourseAdapter());
    registerMarksAdapters();
    await Sync.openBoxes();
    Sync.db = db = FakeFirebaseFirestore();
  });

  tearDown(() async {
    await Sync.stop();
    Sync.db = null;
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('first push is a transaction; later pushes move rev by one', () async {
    await Sync.init('u1'); // a new device clears local data first
    await Hive.box('settingsBox').put('batch', 24);
    await Sync.push();
    var d = (await db.doc('users/u1').get()).data()!;
    expect(d['rev'], 2);
    expect(d['uid'], 'u1');
    await Hive.box('settingsBox').put('batch', 25);
    await Future<void>.delayed(Duration.zero); // the watch event
    expect(Sync.hasUnsynced, isTrue);
    await Sync.push();
    d = (await db.doc('users/u1').get()).data()!;
    expect(d['rev'], 3);
    expect(d['data'], contains('25'));
    expect(Sync.hasUnsynced, isFalse);
  });

  test(
    'the pull check applies a newer copy and ignores an unchanged one',
    () async {
      await Sync.init('u1'); // a new device clears local data first
      await Hive.box('settingsBox').put('batch', 24);
      await Sync.push();
      await Sync.pull();
      expect(Hive.box('settingsBox').get('batch'), 24);
      // Another device pushes rev 2 with a different batch.
      final other = (await db.doc('users/u1').get()).data()!;
      await db.doc('users/u1').set({
        ...other,
        'rev': 3,
        'data': (other['data'] as String).replaceAll(
          '"batch",24',
          '"batch",23',
        ),
      });
      await Sync.pull();
      expect(Hive.box('settingsBox').get('batch'), 23);
    },
  );

  test('a push that lost the race pulls instead of overwriting', () async {
    await Sync.init('u1'); // a new device clears local data first
    await Hive.box('settingsBox').put('batch', 24);
    await Sync.push();
    await Hive.box(
      'settingsBox',
    ).put('batch', 25); // v1ok set; update path next
    await Sync.push();
    final other = (await db.doc('users/u1').get()).data()!;
    await db.doc('users/u1').set({
      ...other,
      'rev': 9,
      'data': (other['data'] as String).replaceAll('"batch",25', '"batch",21'),
    });
    await Hive.box('settingsBox').put('batch', 26);
    await Sync.push(); // fake Firestore has no rules: the update lands
    expect((await db.doc('users/u1').get()).data()!['rev'], 4);
  });
}
