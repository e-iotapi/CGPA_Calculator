// B1 PrefsStore: device copy first, merge-set, quiet offline/no-doc. Storage
// is exercised in plain test() (memory: Hive writes stall under fake time).
import 'dart:io';

import 'package:cgpa_calculator/core/prefs/prefs_store.dart';
import 'package:cgpa_calculator/core/storage/cache_boxes.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  late Directory tmp;
  late FakeFirebaseFirestore db;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('prefs');
    Hive.init(tmp.path);
    await Hive.openBox(deviceBoxName);
    db = FakeFirebaseFirestore();
  });
  tearDown(() async {
    await Hive.close();
    tmp.deleteSync(recursive: true);
  });

  test(
    'defaults are false and the setters merge into users/{uid}.prefs',
    () async {
      await db.doc('users/u1').set({'rev': 3, 'data': '{}'});
      final s = PrefsStore(db, uid: 'u1');
      expect(s.offshootHidden, false);
      expect(s.tourSeen, false);
      await s.setOffshootHidden(true);
      await s.setTourSeen(true);
      expect(s.offshootHidden, true);
      expect(offshootHiddenNow.value, true);
      expect(Hive.box(deviceBoxName).get('pref.offshootHidden'), true);
      final d = (await db.doc('users/u1').get()).data()!;
      expect(d['prefs'], {'offshootHidden': true, 'tourSeen': true});
      expect(d['rev'], 3); // the rest of the doc is untouched
      await s.setOffshootHidden(false);
      expect((await db.doc('users/u1').get()).data()!['prefs'], {
        'offshootHidden': false,
        'tourSeen': true,
      });
    },
  );

  test('pulled turns true once the server answered, with or without prefs',
      () async {
    final s = PrefsStore(db, uid: 'u1');
    expect(s.pulled.value, false);
    await s.pull(); // no doc
    expect(s.pulled.value, true);
    final t = PrefsStore(db, uid: 'u2');
    await db.doc('users/u2').set({'rev': 1, 'prefs': {'tourSeen': true}});
    await t.pull();
    expect(t.pulled.value, true);
    expect(t.tourSeen, true);
  });

  test('pull takes the server flags into the device box', () async {
    await db.doc('users/u1').set({
      'rev': 1,
      'prefs': {'offshootHidden': true},
    });
    final s = PrefsStore(db, uid: 'u1');
    await s.pull();
    expect(s.offshootHidden, true);
    expect(s.tourSeen, false);
    expect(offshootHiddenNow.value, true);
  });

  test('pull with no doc or no prefs changes nothing', () async {
    final s = PrefsStore(db, uid: 'nobody');
    await Hive.box(deviceBoxName).put('pref.tourSeen', true);
    await s.pull();
    expect(s.tourSeen, true);
  });

  test('the constructor loads the device value for Home', () async {
    await Hive.box(deviceBoxName).put('pref.offshootHidden', true);
    PrefsStore(db, uid: 'u1');
    expect(offshootHiddenNow.value, true);
  });

  group('errors', () {
    test(
      'no user doc yet: the refusal is swallowed, the local value stands',
      () async {
        final s = _Failing(db, 'permission-denied', exists: false);
        await s.setOffshootHidden(true);
        expect(s.offshootHidden, true);
      },
    );

    test('unavailable and not-found are swallowed', () async {
      for (final code in ['unavailable', 'not-found']) {
        await _Failing(db, code, exists: true).setTourSeen(true);
      }
    });

    test('permission-denied on an existing doc is rethrown', () async {
      final s = _Failing(db, 'permission-denied', exists: true);
      await expectLater(
        s.setOffshootHidden(true),
        throwsA(isA<FirebaseException>()),
      );
      expect(s.offshootHidden, true); // box first
    });
  });
}

class _Failing extends PrefsStore {
  _Failing(super.db, this.code, {required this.exists}) : super(uid: 'u1');
  final String code;
  final bool exists;

  @override
  Future<void> merge(String k, bool v) =>
      Future.error(FirebaseException(plugin: 'cloud_firestore', code: code));

  @override
  Future<bool> docExists() async => exists;
}
