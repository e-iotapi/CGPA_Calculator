import 'dart:io';

import 'package:cgpa_calculator/app/prefetch_levels.dart';
import 'package:cgpa_calculator/core/roles/activity_store.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/core/models/marks.dart';
import 'package:cgpa_calculator/core/timetable/timetable_store.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/sync.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import '../helpers/fake_timetable.dart';

void main() {
  late Directory dir;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('hive_pl');
    Hive.init(dir.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(CourseAdapter());
    registerMarksAdapters();
    await Sync.openBoxes();
    TimetableStore.resetMemo();
  });
  tearDown(() async {
    roleStore = null;
    myRoles.value = MyRoles.none;
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  test(
    'level 2 loads the broadcast timetable, so the Calendar opens warm',
    () async {
      final db = FakeFirebaseFirestore();
      final t = fakeTimetable();
      final m = t.toJson();
      final courses = m.remove('courses')! as Map<String, Object?>;
      await db.doc('timetable/goa|current').set({'sem': '2026-1'});
      await db.doc('timetable/goa|2026-1').set({...m, 'chunks': 1});
      await db.doc('timetable/goa|2026-1|0').set({'courses': courses});
      startRoles(db, email: 'f20230802@goa.bits-pilani.ac.in', name: 'S');

      final levels = prefetchLevels();
      expect(levels.length, greaterThanOrEqualTo(3));
      for (final job in levels.first) {
        try {
          await job();
        } on Object {
          // Other jobs read data this test did not seed; they are dropped too.
        }
      }
      final box = await Hive.openBox('timetable');
      expect(box.get('tt|goa'), isNotNull);
      expect(
        TimetableStore(db, box: box).peekCurrent('goa')!.courses.keys,
        contains('AAA F111'),
      );
    },
  );

  test('level 2 loads Last updated (activity), saved for a peek', () async {
    final db = FakeFirebaseFirestore();
    await db.doc('activity/goa').set({
      'dept': {'CS': Timestamp.fromDate(DateTime(2026, 8, 20))},
    });
    startRoles(db, email: 'f20230802@goa.bits-pilani.ac.in', name: 'S');
    for (final job in prefetchLevels().first) {
      try {
        await job();
      } on Object {
        // Other jobs read data this test did not seed; they are dropped too.
      }
    }
    expect(ActivityStore(db).peekOf('goa')?.ofDept('CS'), isNotNull);
  });
}
