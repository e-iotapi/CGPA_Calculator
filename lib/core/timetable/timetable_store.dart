/// Reads the broadcast timetable (B8b): the Worker's merged JSON first, the
/// Firestore chunks as the fallback, cached in Hive box `timetable` under the
/// `timetable` marker so a republish is picked up and nothing else re-reads.
library;

import 'dart:async';
import 'dart:convert';

import 'package:cgpa_calculator/core/cache/cache_first.dart';
import 'package:cgpa_calculator/core/heads/heads_client_stub.dart'
    if (dart.library.js_interop) 'package:cgpa_calculator/core/heads/heads_client_web.dart'
    as impl;
import 'package:cgpa_calculator/core/heads/paths.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cgpa_calculator/core/timetable/timetable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_ce/hive.dart';

const timetableBoxName = 'timetable';
const timetableMaxAge = Duration(hours: 12);

class TimetableStore {
  /// [workerBase] is the Worker's URL (POINTER_HEADS_URL); null or empty reads
  /// Firestore only. [get] and [box] are for tests.
  TimetableStore(
    this.db, {
    this.workerBase,
    Future<({int status, String body})> Function(String url) get = impl.httpGet,
    this.box,
  }) : _get = get;

  final FirebaseFirestore db;
  final String? workerBase;
  final Box? box;
  final Future<({int status, String body})> Function(String url) _get;

  /// Parsed once per (campus, marker), for the life of the app.
  static final _memo = <String, Timetable>{};

  /// Forgets what was parsed (tests).
  static void resetMemo() => _memo.clear();

  static String _key(String campus) => 'tt|$campus';

  Future<Box> _box() async =>
      box ??
      (Hive.isBoxOpen(timetableBoxName)
          ? Hive.box(timetableBoxName)
          : await Hive.openBox(timetableBoxName));

  /// The published timetable, or null when none is published yet.
  Future<Timetable?> current(String campus) async {
    final version = await markerOf(db, campus, Paths.timetable);
    final memo = _memo[campus];
    if (memo != null && version != null && '${memo.marker}' == version) {
      return memo;
    }
    final t = await cacheFirst<Timetable?>(
      key: _key(campus),
      box: await _box(),
      maxAge: timetableMaxAge,
      version: version,
      fetch: () => _fetch(campus),
      encode: (t) => t?.toJson(),
      decode: (o) => o == null ? null : Timetable.fromJson(o as Map),
    );
    // Never another campus's data, whatever the cache held.
    if (t == null || t.campus != campus) return null;
    return _memo[campus] = t;
  }

  /// The saved timetable, read synchronously; null when none is saved or the
  /// box is not open yet.
  Timetable? peekCurrent(String campus) {
    final b = box ?? (Hive.isBoxOpen(timetableBoxName) ? Hive.box(timetableBoxName) : null);
    if (b == null) return _memo[campus];
    final t = peekCache<Timetable?>(
      _key(campus),
      (o) => o == null ? null : Timetable.fromJson(o as Map),
      box: b,
    );
    return t != null && t.campus == campus ? (_memo[campus] ??= t) : null;
  }

  Future<Timetable?> _fetch(String campus) async {
    final base = workerBase;
    if (base != null && base.isNotEmpty) {
      try {
        final root = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
        final r = await _get('$root/timetable/$campus.json')
            .timeout(const Duration(seconds: 10));
        if (r.status == 200) return Timetable.fromJson(jsonDecode(r.body) as Map);
        if (r.status == 404 && r.body.contains('not published')) return null;
      } on Object catch (e) {
        // A newer schema is the same in Firestore: do not mask it.
        if (e is FormatException && e.message.contains('update the app')) rethrow;
        // Worker down or not deployed: fall back to Firestore.
      }
    }
    try {
      return await _fromFirestore(campus);
    } on FirebaseException {
      rethrow;
    } on Object catch (e) {
      throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable', message: '$e');
    }
  }

  Future<Timetable?> _fromFirestore(String campus) async {
    final col = db.collection('timetable');
    final cur = await col.doc('$campus|current').get();
    final sem = cur.data()?['sem'] as String?;
    if (sem == null) return null;
    final meta = await col.doc('$campus|$sem').get();
    final m = meta.data();
    if (m == null) return null;
    final n = (m['chunks'] as num).toInt();
    final chunks = await Future.wait([
      for (var i = 0; i < n; i++) col.doc('$campus|$sem|$i').get(),
    ]);
    final at = m['publishedAt'];
    return Timetable.fromJson({
      ...m,
      'campus': campus,
      'publishedAt': at is Timestamp ? at.millisecondsSinceEpoch : at,
      'courses': {
        for (final c in chunks)
          ...((c.data()?['courses'] as Map?)?.cast<String, Object?>() ?? const {}),
      },
    });
  }
}
