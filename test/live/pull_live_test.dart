// Sync.pullLive (LOADING_SERVER_PLAN D3): a pull the live socket asks for
// must never race or overwrite a push that is pending.
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
    dir = await Directory.systemTemp.createTemp('hive_pull_live');
    Hive.init(dir.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(CourseAdapter());
    registerMarksAdapters();
    await Sync.openBoxes();
    Sync.db = db = FakeFirebaseFirestore();
    await Sync.init('u1');
    await Hive.box('settingsBox').put('batch', 24);
    await Sync.push();
    await Sync.pull();
  });
  tearDown(() async {
    await Sync.stop();
    Sync.db = null;
    await Hive.close();
    await dir.delete(recursive: true);
  });

  Future<void> otherDevice(int batch, int rev) async {
    final d = (await db.doc('users/u1').get()).data()!;
    await db.doc('users/u1').set({
      ...d,
      'rev': rev,
      'data': (d['data'] as String).replaceAll('"batch",24', '"batch",$batch'),
    });
  }

  test('with nothing pending it pulls the newer copy', () async {
    final rev = (await db.doc('users/u1').get()).data()!['rev'] as int;
    await otherDevice(23, rev + 1);
    await Sync.pullLive();
    expect(Hive.box('settingsBox').get('batch'), 23);
  });

  test('a pending local change is pushed first, not pulled over', () async {
    await Hive.box('settingsBox').put('batch', 30);
    await Future<void>.delayed(Duration.zero); // the watch event
    expect(Sync.hasUnsynced, isTrue);
    await Sync.pullLive();
    expect(Hive.box('settingsBox').get('batch'), 30);
    expect(Sync.hasUnsynced, isFalse);
    expect(
      (await db.doc('users/u1').get()).data()!['data'] as String,
      contains('"batch",30'),
    );
  });

  test('a push in flight is waited for, and pushes are not doubled', () async {
    await Hive.box('settingsBox').put('batch', 31);
    await Future<void>.delayed(Duration.zero);
    final p = Sync.push();
    expect(identical(p, Sync.push()), isTrue); // joins, not a second write
    await Sync.pullLive();
    await p;
    expect(Hive.box('settingsBox').get('batch'), 31);
    expect(
      (await db.doc('users/u1').get()).data()!['data'] as String,
      contains('"batch",31'),
    );
  });
}
