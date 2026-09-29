import 'dart:async';
import 'dart:convert';
import 'package:cgpa_calculator/core/models/marks.dart';
import 'package:cgpa_calculator/core/perf/perf.dart';
import 'package:cgpa_calculator/core/platform/browser.dart';
import 'package:cgpa_calculator/core/storage/cache_boxes.dart';
import 'package:cgpa_calculator/core/storage/course_link.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// Keeps the three Hive boxes mirrored into a single Firestore document.
///
/// The whole local state is pushed as one JSON snapshot, debounced 30 s after
/// any box change and flushed when the page is hidden, guarded by an
/// optimistic `rev` counter that the rules enforce. On conflict the server
/// wins and the un-pushed local snapshot is stashed in syncMeta['backup'].
///
/// Budget (PERF_TEST_PLAN.md §A.4): a push is 1 write and 0 reads; the pull
/// check runs at most once a day (plus on a conflict) and returns nothing,
/// billed as 1 read, when the server copy has not moved.
class Sync {
  static const _boxes = [
    'settingsBox',
    'coursesBox',
    'offshootBox',
    'marksBox',
  ];

  /// The boxes mirrored into users/{uid}. Caches of shared data never
  /// belong here (core/storage/cache_boxes.dart).
  @visibleForTesting
  static List<String> get syncedBoxes => _boxes;

  static late Box _meta; // uid, rev, last (last synced snapshot), backup
  static late DocumentReference<Map<String, dynamic>> _doc;
  static Timer? _debounce;

  /// How long after the last change a push waits; a hidden page pushes now.
  static const debounce = Duration(seconds: 30);

  /// The pull check runs at most this often on a device that has synced.
  static const pullEvery = Duration(hours: 24);

  /// Tests point Sync at a fake Firestore.
  @visibleForTesting
  static FirebaseFirestore? db;
  static FirebaseFirestore get _db => db ?? FirebaseFirestore.instance;
  static final List<StreamSubscription> _subs = [];

  static Box _box(String n) =>
      n == 'settingsBox' || n == 'marksBox' ? Hive.box(n) : Hive.box<Course>(n);

  static Future<void> openBoxes() async {
    _meta = await Hive.openBox('syncMeta');
    await Hive.openBox('settingsBox');
    await Hive.openBox<Course>('coursesBox');
    await Hive.openBox<Course>('offshootBox');
    await Hive.openBox('marksBox');
  }

  static Future<void> clearLocal() async {
    for (final n in _boxes) {
      await _box(n).clear();
    }
    await _meta.clear();
  }

  /// Call after openBoxes(), before basicStartup().
  static Future<void> init(String uid) async {
    if (_meta.get('uid') != uid) {
      await clearLocal();
      await clearAccountCaches();
      await _meta.put('uid', uid);
    }
    _doc = _db.collection('users').doc(uid);
    final at = _meta.get('pulledAt') as int?;
    if (at == null ||
        DateTime.now().millisecondsSinceEpoch - at >=
            pullEvery.inMilliseconds) {
      await pull();
    }
    _dirty = snapshot() != _meta.get('last');
    for (final n in _boxes) {
      _subs.add(
        _box(n).watch().listen((_) {
          _dirty = true;
          _debounce?.cancel();
          _debounce = Timer(debounce, push);
        }),
      );
    }
    if (!_hooked) {
      _hooked = true;
      onPageHidden(() {
        if (_debounce?.isActive ?? false) {
          _debounce!.cancel();
          unawaited(push());
        }
      });
    }
  }

  static bool _hooked = false;

  /// Local changes not yet pushed: set by any write to a synced box,
  /// cleared once the server holds this snapshot. No encoding per call (the
  /// offline strip asks on every rebuild). False before sync has started.
  static bool get hasUnsynced {
    // Encodes only while flagged: a pull's own writes flag it too, and
    // this clears them.
    if (_dirty) {
      try {
        _dirty = snapshot() != _meta.get('last');
      } catch (_) {
        return false;
      }
    }
    return _dirty;
  }

  static bool _dirty = false;

  static Future<void> stop() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    _debounce?.cancel();
  }

  static String snapshot() => jsonEncode({
    // 2: catalogue courses stored by id (course_link.dart).
    'format': 2,
    for (final n in _boxes)
      n: [
        for (final k in _box(n).keys) [k, _enc(_box(n).get(k))],
      ],
  });

  // Catalogue courses are stored by id; title and credits come from the
  // catalogue (core/storage/course_link.dart, ARCHITECTURE.md §2).
  static dynamic _enc(dynamic v) =>
      v is Course
          ? encodeCourse(v)
          : v is Evaluative
          ? v.toJson()
          : v is CourseConfig
          ? v.toJson()
          : v;

  static Course _course(Map m) => decodeCourse(m);

  /// Checks the server copy and applies it when newer. A device that has
  /// synced asks only for a copy with a higher rev, so an unchanged server
  /// sends nothing back (1 read, no 500 KB download); [full] reads it whole.
  static Future<void> pull({bool full = false}) async {
    try {
      final int local = _meta.get('rev', defaultValue: 0);
      DocumentSnapshot<Map<String, dynamic>>? found;
      // A doc last pushed by an older app version has no uid field, so the
      // check cannot see its changes: read it whole at least once a week.
      final fullAt = _meta.get('fullAt') as int?;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (fullAt == null ||
          now - fullAt > const Duration(days: 7).inMilliseconds) {
        full = true;
      }
      if (!full && local > 0) {
        final q = await Perf.time(
          'sync.pull',
          () =>
              _db
                  .collection('users')
                  .where('uid', isEqualTo: _doc.id)
                  .where('rev', isGreaterThan: local)
                  .get(),
        );
        await _meta.put('pulledAt', DateTime.now().millisecondsSinceEpoch);
        if (q.docs.isEmpty) {
          if (snapshot() != _meta.get('last')) await push();
          return;
        }
        found = q.docs.first;
      }
      final DocumentSnapshot<Map<String, dynamic>> s;
      if (found != null) {
        s = found;
      } else {
        s = await Perf.time('sync.pull', () => _doc.get());
        await _meta.put('fullAt', DateTime.now().millisecondsSinceEpoch);
      }
      await _meta.put('pulledAt', DateTime.now().millisecondsSinceEpoch);
      final cur = snapshot();
      final String? last = _meta.get('last');
      if (!s.exists) {
        await push(); // new user: seed from local
        return;
      }
      final int rev = s.data()!['rev'];
      if (rev == _meta.get('rev', defaultValue: 0)) {
        if (cur != last) await push();
        return;
      }
      // server wins; stash anything local that was never pushed
      if (last != null && cur != last) await _meta.put('backup', cur);
      await apply(s.data()!['data'] as String);
      await _meta.putAll({'rev': rev, 'last': snapshot()});
      _dirty = false;
    } catch (e) {
      debugPrint('pull failed: $e'); // offline: stay local
    }
  }

  static Future<void> push() async {
    try {
      final cur = snapshot();
      if (cur == _meta.get('last')) {
        _dirty = false;
        return;
      }
      final int base = _meta.get('rev', defaultValue: 0);
      // After one transaction push on this device (which keeps the one-time
      // v1 copy), a push is a plain update the rules accept only as rev + 1:
      // 1 write, no read. A refusal means another device moved on first.
      if (base > 0 && _meta.get('v1ok') == true) {
        try {
          await Perf.time(
            'sync.push.write',
            () => _doc.update({
              'rev': base + 1,
              'uid': _doc.id,
              'data': cur,
              'updatedAt': FieldValue.serverTimestamp(),
            }),
          );
          Perf.markWrite('sync.push.write');
          await _meta.putAll({'rev': base + 1, 'last': cur});
          _dirty = false;
        } on FirebaseException catch (e) {
          if (e.code != 'permission-denied' && e.code != 'not-found') rethrow;
          await pull(full: true);
        }
        return;
      }
      final newRev = await _db.runTransaction<int?>((tx) async {
        final s = await tx.get(_doc);
        Perf.mark('sync.push.read');
        final int serverRev = s.exists ? s.data()!['rev'] : 0;
        if (serverRev != base) return null; // conflict
        // The last whole-course snapshot is kept once, so the move to
        // courses stored by id can be undone (ARCHITECTURE.md §9 step 3).
        final String? old = s.data()?['data'];
        final v1 =
            s.data()?['v1'] ??
            (old != null && !old.contains('"format":2') ? old : null);
        tx.set(_doc, {
          'rev': base + 1,
          'uid': _doc.id,
          'data': cur,
          if (v1 != null) 'v1': v1,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        Perf.markWrite('sync.push.write');
        return base + 1;
      });
      if (newRev == null) {
        await pull(full: true);
        return;
      }
      await _meta.putAll({'rev': newRev, 'last': cur, 'v1ok': true});
      _dirty = false;
    } catch (e) {
      debugPrint('push failed: $e'); // retried on next change/launch
    }
  }

  /// Parses a snapshot and checks it actually looks like one, so a stray file
  /// can't silently wipe every box. Returns {boxName: rowCount} for confirmation.
  static Map<String, int> validate(String json) {
    final decoded = jsonDecode(json);
    if (decoded is! Map) {
      throw const FormatException('File is not a JSON object');
    }
    final counts = <String, int>{
      for (final n in _boxes)
        if (decoded[n] is List) n: (decoded[n] as List).length,
    };
    if (counts.isEmpty) {
      throw const FormatException(
        'No settingsBox, coursesBox or offshootBox found in this file',
      );
    }
    return counts;
  }

  /// Also used by the "Import" dialogs. Boxes absent from [json] are left
  /// untouched rather than cleared.
  static Future<void> apply(String json) async {
    validate(json);
    final data = Map<String, dynamic>.from(jsonDecode(json));
    for (final n in _boxes) {
      if (data[n] is! List) continue;
      final rows = data[n] as List;
      final box = _box(n);
      await box.clear();
      if (n == 'settingsBox') {
        await box.putAll({for (final r in rows) r[0]: r[1]});
      } else if (n == 'marksBox') {
        await box.putAll({
          for (final r in rows) r[0]: marksFromJson(Map.from(r[1])),
        });
      } else {
        await (box as Box<Course>).putAll({
          for (final r in rows) r[0]: _course(Map.from(r[1])),
        });
      }
    }
  }
}
