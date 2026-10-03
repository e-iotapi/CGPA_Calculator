// U8: the tour is for students: never as a role, never while viewing as
// someone else, never on a role page, and not before the prefs are read.
import 'dart:io';

import 'package:cgpa_calculator/core/prefs/prefs_store.dart';
import 'package:cgpa_calculator/core/roles/capabilities.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/core/storage/cache_boxes.dart';
import 'package:cgpa_calculator/features/tour/tour.dart';
import 'package:cgpa_calculator/script.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import '../helpers/fake_seed.dart';

void main() {
  late Directory tmp;
  late FakeFirebaseFirestore db;
  late bool wasSelected;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('tour');
    Hive.init(tmp.path);
    await Hive.openBox(deviceBoxName);
    db = FakeFirebaseFirestore();
    wasSelected = degree_selected;
    workingAs.value = null;
    viewAs.value = null;
  });
  tearDown(() async {
    prefsStore = null;
    degree_selected = wasSelected;
    workingAs.value = null;
    viewAs.value = null;
    await Hive.close();
    tmp.deleteSync(recursive: true);
  });

  test('a student on Home may; anywhere else may not', () {
    expect(tourAllowedAt('/'), isTrue);
    for (final at in [
      '/settings',
      '/more',
      '/course/x',
      '/stats',
      '/calendar',
    ]) {
      expect(tourAllowedAt(at), isFalse, reason: at);
    }
  });

  test('never while working as a role', () {
    workingAs.value = presGrant;
    expect(tourAllowedAt('/'), isFalse);
    workingAs.value = crGrant;
    expect(tourAllowedAt('/'), isFalse);
  });

  test('never while viewing as someone else', () {
    viewAs.value = const ViewAs(Role.student);
    expect(tourAllowedAt('/'), isFalse);
  });

  test('never on /admin, /maintain or /roles', () {
    for (final at in [
      '/admin',
      '/admin/roster',
      '/maintain/goa/A3',
      '/roles',
    ]) {
      expect(tourAllowedAt(at), isFalse, reason: at);
    }
  });

  test(
    'the first-run tour needs prefs, an unseen flag and finished setup',
    () async {
      degree_selected = true;
      prefsStore = null;
      expect(firstTourDue(), isFalse, reason: 'prefs not created yet');

      final s = PrefsStore(db, uid: 'u1');
      prefsStore = s;
      expect(firstTourDue(), isTrue);

      degree_selected = false;
      expect(firstTourDue(), isFalse, reason: 'setup not finished');
      degree_selected = true;

      await s.setTourSeen(true);
      expect(firstTourDue(), isFalse, reason: 'already seen');
    },
  );

  test('prefs not read yet: the tour waits (pulled is false)', () async {
    await db.doc('users/u1').set({
      'rev': 1,
      'prefs': {'tourSeen': true},
    });
    final s = PrefsStore(db, uid: 'u1');
    expect(s.pulled.value, isFalse);
    expect(s.tourSeen, isFalse, reason: 'unset until the server answers');
    await s.pull();
    expect(s.pulled.value, isTrue);
    expect(s.tourSeen, isTrue);
  });
}
