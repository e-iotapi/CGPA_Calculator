/// Published offerings: read live, cached in `offeringsBox`, and applied to
/// the student's marks (ARCHITECTURE.md §1 "two cadences", §5).
library;

import 'package:cgpa_calculator/core/grading/official_scheme.dart';
import 'package:cgpa_calculator/core/models/offering.dart';
import 'package:cgpa_calculator/core/perf/perf.dart';
import 'package:cgpa_calculator/core/storage/marks.dart';
import 'package:cgpa_calculator/core/storage/overrides.dart';
import 'package:cgpa_calculator/core/timings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';

const offeringsBoxName = 'offeringsBox';

abstract interface class OfferingSource {
  /// The offering, or null when none is published.
  Future<Offering?> get(String courseId, String campus, String term);
}

class FirestoreOfferingSource implements OfferingSource {
  FirestoreOfferingSource([FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  @override
  Future<Offering?> get(String courseId, String campus, String term) async {
    final d = await Perf.time(
      'offerings.get',
      () =>
          _db
              .collection('courses')
              .doc(courseId)
              .collection('offerings')
              .doc(offeringId(campus, term))
              .get(),
    );
    final m = d.data();
    return m == null ? null : Offering.fromMap(m);
  }
}

Box? get _cache =>
    Hive.isBoxOpen(offeringsBoxName) ? Hive.box(offeringsBoxName) : null;

String _cacheKey(String courseId, String campus, String term) =>
    '$courseId|${offeringId(campus, term)}';

Future<void> openOfferings() => Hive.openBox(offeringsBoxName);

/// The cached offering, or null when none is cached or none is published.
Offering? cachedOffering(String courseId, String campus, String term) {
  final v = _cache?.get(_cacheKey(courseId, campus, term));
  if (v is! Map || v['data'] is! Map) return null;
  return Offering.fromMap(v['data'] as Map);
}

/// Reads the offering when [version] (from the campus head) moved since the
/// cached copy, or — with no version — when the copy is older than [maxAge];
/// caches it (a missing one too, so it is not asked for again at once) and
/// applies it. Returns the offering in use. Offline, the cached one.
/// Budget: 0 reads while the head's version is unchanged (re-checked weekly).
Future<Offering?> refreshOffering(
  OfferingSource source,
  String courseId,
  String campus,
  String term, {
  Duration maxAge = offeringMaxAge,
  int? version,
  DateTime? now,
}) async {
  final box = _cache ?? await Hive.openBox(offeringsBoxName);
  final key = _cacheKey(courseId, campus, term);
  final at = (now ?? DateTime.now()).millisecondsSinceEpoch;
  final cached = box.get(key);
  if (cached is Map) {
    final age = at - (cached['at'] as int);
    final same = version != null && cached['ver'] == version;
    if (same && age < offeringVersionRecheck.inMilliseconds ||
        version == null && age < maxAge.inMilliseconds) {
      return cachedOffering(courseId, campus, term);
    }
  }
  try {
    final off = await source.get(courseId, campus, term);
    await box.put(key, {'at': at, 'data': off?.toMap(), 'ver': version});
    if (off != null) await applyOfficial(courseId, off);
    return off;
  } on Object catch (e) {
    debugPrint('[Pointer offering] $courseId: $e');
    return cachedOffering(courseId, campus, term);
  }
}

/// Writes [off] into [courseId]'s marks through the resolver.
Future<void> applyOfficial(String courseId, Offering off) async {
  final u = applyOffering(
    courseId: courseId,
    mine: evaluativesFor(courseId),
    config: configFor(courseId),
    off: off,
    detached: detachedFor(courseId),
    seen: seenOfficial(courseId),
  );
  for (final k in u.delete) {
    await deleteEvaluative(k);
  }
  for (final e in u.save.entries) {
    await saveEvaluative(e.value, key: e.key);
  }
  final base = DateTime.now().microsecondsSinceEpoch;
  for (final (i, e) in u.add.indexed) {
    await saveEvaluative(e, key: 'eval:$courseId:${base + i}');
  }
  if (u.config case final c?) await saveConfig(c);
  await detach(courseId, u.detach);
  if (!seenOfficial(courseId)) await markSeen(courseId, off.updatedAt);
}
