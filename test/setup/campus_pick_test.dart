import 'dart:io';

import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/core/storage/cache_boxes.dart';
import 'package:cgpa_calculator/features/setup/campus_pick_page.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import 'package:cgpa_calculator/core/roles/role_store.dart';

void main() {
  test(
    'an owner with no campus views the picked one; students keep theirs',
    () async {
      final dir = await Directory.systemTemp.createTemp('hive_campus');
      Hive.init(dir.path);
      await Hive.openBox(deviceBoxName);
      final db = FakeFirebaseFirestore();
      roleStore = RoleStore(db, me: 'owner@pointer.test', myName: 'O');
      expect(viewCampus(), isNull);
      await Hive.box(deviceBoxName).put('previewCampus', 'pilani');
      expect(viewCampus(), 'pilani');
      roleStore = RoleStore(
        db,
        me: 'f20239992@goa.bits-pilani.ac.in',
        myName: 'S',
      );
      expect(viewCampus(), 'goa');
      roleStore = null;
      await Hive.close();
    },
  );
}
