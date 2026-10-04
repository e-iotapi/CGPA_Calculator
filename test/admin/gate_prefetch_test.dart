// U10: the gate's place in prefetch. Its own file: the switch tests' saves
// under fake time leave the shared cache busy for any test after them.
import 'dart:io';

import 'package:cgpa_calculator/app/prefetch_levels.dart';
import 'package:cgpa_calculator/core/cache/cache_first.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/core/storage/courses.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/reviews/gate_ui.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  test('prefetch level 2 loads the gate', () async {
    Hive.init((await Directory.systemTemp.createTemp('gate_prefetch')).path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(CourseAdapter());
    await Hive.openBox<Course>(coursesBoxName);
    await openSharedCache();
    await Hive.openBox('settingsBox');
    final db = FakeFirebaseFirestore();
    roleStore = RoleStore(
      db,
      me: 'f20230456@goa.bits-pilani.ac.in',
      myName: 'Student',
    );
    myUid = 'u-me';
    addTearDown(() {
      roleStore = null;
      myUid = null;
    });
    await db.collection('reviewGate').doc('goa').set({'on': true});
    expect(gateStore!.peekOf('goa'), isNull);
    await prefetchLevels().first.first(); // the gate job leads level 2
    expect(gateStore!.peekOf('goa'), isTrue);
  });
}
