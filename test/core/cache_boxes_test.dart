import 'package:cgpa_calculator/core/storage/cache_boxes.dart';
import 'package:cgpa_calculator/sync.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
