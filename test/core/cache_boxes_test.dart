import 'package:cgpa_calculator/core/storage/cache_boxes.dart';
import 'package:cgpa_calculator/sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

import 'package:hive/hive.dart';

void main() {
  test('no cache box is synced into the user document', () {
    expect(cacheBoxes, isNotEmpty);
    expect(Sync.syncedBoxes.toSet().intersection(cacheBoxes), isEmpty);
  });

  test('only the user\'s own data is synced', () {
    expect(Sync.syncedBoxes, [
      'settingsBox',
      'coursesBox',
      'offshootBox',
      'marksBox',
    ]);
  });

  test('signing out clears every cache but the catalogue', () async {
    Hive.init(Directory.systemTemp.createTempSync('hive').path);
    for (final n in cacheBoxes) {
      await (await Hive.openBox(n)).put('k', 'v');
    }
    await clearAccountCaches();
    for (final n in cacheBoxes) {
      expect(Hive.box(n).get('k'), n == 'catalogBox' ? 'v' : isNull, reason: n);
    }
    await Hive.close();
  });
}
