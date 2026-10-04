/// Which published values a student has made theirs (ARCHITECTURE.md §5).
///
/// A sparse map per course, `{granule: basedOn}`, where `basedOn` is the
/// offering's `updatedAt` when it detached (§16.3 fix 9). It lives in
/// `settingsBox` under `overrides`, so it syncs with the rest of the user's
/// data in users/{uid} — the sparse diff the plan puts beside it, stored in
/// the one document the app already reads. `_seen` records that the course
/// has met a published offering.
library;

import 'package:hive_ce/hive.dart';

const _key = 'overrides';
/// The reserved granule key recording when the official version was seen.
const seenKey = '_seen';

Box get _settings => Hive.box('settingsBox');

Map<String, Map<String, int>> _all() {
  final raw = Hive.isBoxOpen('settingsBox') ? _settings.get(_key) : null;
  return {
    if (raw is Map)
      for (final e in raw.entries)
        '${e.key}': {
          if (e.value is Map)
            for (final g in (e.value as Map).entries)
              '${g.key}': (g.value as num).toInt(),
        },
  };
}

Future<void> _write(Map<String, Map<String, int>> all) => _settings.put(_key, {
  for (final e in all.entries)
    if (e.value.isNotEmpty) e.key: e.value,
});

/// [courseId]'s detached granules and their `basedOn`, without `_seen`.
Map<String, int> detachedFor(String courseId) =>
    {...?_all()[courseId]}..remove(seenKey);

/// Whether the student has seen [courseId]'s official scheme.
bool seenOfficial(String courseId) =>
    _all()[courseId]?.containsKey(seenKey) ?? false;

/// Records that [courseId]'s official scheme was seen at version [at].
Future<void> markSeen(String courseId, int at) async {
  final all = _all();
  (all[courseId] ??= {})[seenKey] = at;
  await _write(all);
}

/// Makes [granules] the student's, detached from the version at `basedOn`.
Future<void> detach(String courseId, Map<String, int> granules) async {
  if (granules.isEmpty) return;
  final all = _all();
  (all[courseId] ??= {}).addAll(granules);
  await _write(all);
}

/// "Use the official version": forgets every granule [which] accepts.
Future<void> reattach(String courseId, bool Function(String) which) async {
  final all = _all();
  all[courseId]?.removeWhere((g, _) => g != seenKey && which(g));
  await _write(all);
}

/// "Keep mine": the notice is answered for everything up to [at].
Future<void> keepMine(String courseId, int at) async {
  final all = _all();
  final m = all[courseId];
  if (m == null) return;
  for (final g in m.keys.toList()) {
    if (g != seenKey) m[g] = at;
  }
  await _write(all);
}
