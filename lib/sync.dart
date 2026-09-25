import 'dart:async';
import 'dart:convert';
import 'package:cgpa_calculator/course.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// Keeps the three Hive boxes mirrored into a single Firestore document.
///
/// The whole local state is pushed as one JSON snapshot, debounced 1.5s after
/// any box change, guarded by an optimistic `rev` counter. On conflict the
/// server wins and the un-pushed local snapshot is stashed in syncMeta['backup'].
class Sync {
  static const _boxes = ['settingsBox', 'coursesBox', 'offshootBox'];
  static late Box _meta; // uid, rev, last (last synced snapshot), backup
  static late DocumentReference<Map<String, dynamic>> _doc;
  static Timer? _debounce;
  static final List<StreamSubscription> _subs = [];

  static Box _box(String n) =>
      n == 'settingsBox' ? Hive.box(n) : Hive.box<Course>(n);

  static Future<void> openBoxes() async {
    _meta = await Hive.openBox('syncMeta');
    await Hive.openBox('settingsBox');
    await Hive.openBox<Course>('coursesBox');
    await Hive.openBox<Course>('offshootBox');
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
      await _meta.put('uid', uid);
    }
    _doc = FirebaseFirestore.instance.collection('users').doc(uid);
    await pull();
    for (final n in _boxes) {
      _subs.add(
        _box(n).watch().listen((_) {
          _debounce?.cancel();
          _debounce = Timer(const Duration(milliseconds: 1500), push);
        }),
      );
    }
  }

  static Future<void> stop() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    _debounce?.cancel();
  }

  static String snapshot() => jsonEncode({
    for (final n in _boxes)
      n: [
        for (final k in _box(n).keys) [k, _enc(_box(n).get(k))],
      ],
  });

  static dynamic _enc(dynamic v) =>
      v is Course
          ? {
            'title': v.title,
            'id': v.id,
            'credits': v.credits,
            'grade1': v.grade1,
            'grade2': v.grade2,
            'discipline': v.discipline,
            'sem': v.sem,
            'elective': v.elective,
          }
          : v;

  static Course _course(Map m) => Course(
    title: m['title'],
    id: m['id'],
    credits: (m['credits'] as num).toDouble(),
    grade1: (m['grade1'] as num).toInt(),
    grade2: (m['grade2'] as num).toInt(),
    discipline: m['discipline'],
    sem: m['sem'],
    elective: m['elective'] ?? 'CDC',
  );

  static Future<void> pull() async {
    try {
      final s = await _doc.get();
      final cur = snapshot();
      final String? last = _meta.get('last');
      if (!s.exists) return push(); // new user: seed from local
      final int rev = s.data()!['rev'];
      if (rev == _meta.get('rev', defaultValue: 0)) {
        if (cur != last) await push();
        return;
      }
      // server wins; stash anything local that was never pushed
      if (last != null && cur != last) await _meta.put('backup', cur);
      await apply(s.data()!['data'] as String);
      await _meta.putAll({'rev': rev, 'last': snapshot()});
    } catch (e) {
      debugPrint('pull failed: $e'); // offline: stay local
    }
  }

  static Future<void> push() async {
    try {
      final cur = snapshot();
      if (cur == _meta.get('last')) return;
      final int base = _meta.get('rev', defaultValue: 0);
      final newRev = await FirebaseFirestore.instance
          .runTransaction<int?>((tx) async {
            final s = await tx.get(_doc);
            final int serverRev = s.exists ? s.data()!['rev'] : 0;
            if (serverRev != base) return null; // conflict
            tx.set(_doc, {
              'rev': base + 1,
              'data': cur,
              'updatedAt': FieldValue.serverTimestamp(),
            });
            return base + 1;
          });
      if (newRev == null) {
        await pull();
        return;
      }
      await _meta.putAll({'rev': newRev, 'last': cur});
    } catch (e) {
      debugPrint('push failed: $e'); // retried on next change/launch
    }
  }

  /// Also used by the "Import from old site" dialog.
  static Future<void> apply(String json) async {
    final data = Map<String, dynamic>.from(jsonDecode(json));
    for (final n in _boxes) {
      final rows = (data[n] as List?) ?? const [];
      final box = _box(n);
      await box.clear();
      if (n == 'settingsBox') {
        await box.putAll({for (final r in rows) r[0]: r[1]});
      } else {
        await (box as Box<Course>).putAll({
          for (final r in rows) r[0]: _course(Map.from(r[1])),
        });
      }
    }
  }
}
