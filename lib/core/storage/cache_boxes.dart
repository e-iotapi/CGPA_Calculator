/// Hive boxes that cache shared data read from Firestore — the catalogue
/// bundle (ARCHITECTURE.md §3), and later reviews, resources, reports and the
/// directory. Each is opened with Hive alone and never registered in `Sync`,
/// which would push it into users/{uid} and its 500 KB cap (§16.3 fix 13).
/// Name every new cache box here; test/core/cache_boxes_test.dart holds the
/// line.
const cacheBoxes = <String>{'catalogBox'};
