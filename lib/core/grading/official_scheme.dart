/// The one place a course's published scheme meets the student's own
/// (ARCHITECTURE.md §5): `override ?? published ?? custom ?? empty`, per
/// granule. Pure; core/storage/offerings.dart writes the result.
///
/// Published values are copied into the student's evaluatives so every
/// screen reads one list, and copied again whenever the offering changes —
/// except where the student has made a value theirs (a detached granule).
library;

import 'dart:convert';

import 'package:cgpa_calculator/core/models/marks.dart';
import 'package:cgpa_calculator/core/models/offering.dart';
import 'package:cgpa_calculator/core/storage/marks.dart' show defaultComponents;

/// Granules (§5). Each can be made the student's on its own.
String componentGranule(String id) => 'components.$id';
const courseAverageGranule = 'average.course';
String componentAverageGranule(String id) => 'average.component.$id';
String partAverageGranule(String id, int i) => 'average.part.$id.$i';

/// Every granule that belongs to component [id].
bool ofComponent(String granule, String id) =>
    granule == componentGranule(id) ||
    granule == componentAverageGranule(id) ||
    granule.startsWith('average.part.$id.');

/// A seeded placeholder nobody has edited: no scheme at all (§5). Older data
/// has no flag, so a Quiz 1 / Quiz 2 / Midsem / Compre at weight 0 with no
/// marks is one too.
bool isSeed(Evaluative e) =>
    e.sourceId == null &&
    e.weight == 0 &&
    defaultComponents.contains(e.name) &&
    e.parts.every((p) => p.marks == null);

bool _hasMarks(Evaluative e) => e.parts.any((p) => p.marks != null);

/// "Mid Semester", "Midsem" and "mid-sem exam" are one name.
String _key(String name) => name
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]'), '')
    .replaceAll('semester', 'sem')
    .replaceAll('comprehensive', 'compre')
    .replaceAll(RegExp(r'(examination|exam)$'), '');

/// What applying an offering changes. Keys are marksBox keys.
class SchemeUpdate {
  SchemeUpdate({
    required this.save,
    required this.add,
    required this.delete,
    required this.config,
    required this.detach,
  });

  /// Existing evaluatives, changed.
  final Map<String, Evaluative> save;

  /// Published components the student did not have yet.
  final List<Evaluative> add;
  final List<String> delete;

  /// The course config after the offering; null when unchanged.
  final CourseConfig? config;

  /// Granules made the student's on first sight, because their own values
  /// already differed from the published ones. `basedOn` 0, so the
  /// difference is shown until they choose.
  final Map<String, int> detach;

  bool get isEmpty =>
      save.isEmpty &&
      add.isEmpty &&
      delete.isEmpty &&
      config == null &&
      detach.isEmpty;
}

String _json(Object o) =>
    jsonEncode(o is Evaluative ? o.toJson() : (o as CourseConfig).toJson());

/// Applies [off] to [courseId]'s evaluatives [mine] and [config], leaving
/// alone every granule in [detached]. [seen] is false the first time this
/// course meets a published offering.
SchemeUpdate applyOffering({
  required String courseId,
  required List<(String, Evaluative)> mine,
  required CourseConfig? config,
  required Offering off,
  required Map<String, int> detached,
  required bool seen,
}) {
  final save = <String, Evaluative>{};
  final add = <Evaluative>[];
  final delete = <String>[];
  final detach = <String, int>{};
  bool isDetached(String g) => detached.containsKey(g) || detach.containsKey(g);

  final published = {for (final c in off.components) c.id};
  final claimed = <String>{};

  if (off.hasScheme) {
    for (final (k, e) in mine) {
      if (isSeed(e)) delete.add(k);
    }
  }

  for (final c in off.components) {
    var match = mine.where((m) => m.$2.sourceId == c.id).firstOrNull;
    var adopted = false;
    if (match == null) {
      // The student's own component under the same name: link it once.
      match =
          mine
              .where(
                (m) =>
                    m.$2.sourceId == null &&
                    !delete.contains(m.$1) &&
                    !claimed.contains(m.$1) &&
                    _key(m.$2.name) == _key(c.name),
              )
              .firstOrNull;
      adopted = match != null;
    }
    if (match == null) {
      // Removed by the student after making it theirs: stays removed.
      if (!isDetached(componentGranule(c.id))) {
        add.add(_fromPublished(courseId, c));
      }
      continue;
    }
    final (key, e) = match;
    claimed.add(key);
    final before = _json(e);
    final next = Evaluative.fromJson(e.toJson());
    if (adopted) {
      next.sourceId = c.id;
      if (!_sameStructure(e, c)) detach[componentGranule(c.id)] = 0;
      if (e.average != null && c.average != null && e.average != c.average) {
        detach[componentAverageGranule(c.id)] = 0;
      }
    }
    if (!isDetached(componentGranule(c.id))) _copyStructure(next, c);
    if (c.average != null && !isDetached(componentAverageGranule(c.id))) {
      next.average = c.average;
    }
    for (final (i, p) in c.parts.indexed) {
      if (i >= next.parts.length || p.average == null) continue;
      if (!isDetached(partAverageGranule(c.id, i))) {
        next.parts[i].average = p.average;
      }
    }
    if (_json(next) != before) save[key] = next;
  }

  // A component that left the official scheme goes, unless the student holds
  // marks in it or made it theirs; then it stays, marked, until they clear it.
  for (final (k, e) in mine) {
    final id = e.sourceId;
    if (id == null || published.contains(id)) continue;
    if (!_hasMarks(e) && !detached.keys.any((g) => ofComponent(g, id))) {
      delete.add(k);
    }
  }

  final was = config ?? CourseConfig(courseId: courseId);
  final cfg = CourseConfig.fromJson(was.toJson());
  if (off.hasScheme) {
    cfg
      ..weighted = off.weighted
      ..courseTotal = off.weighted ? 100 : off.totalMarks;
  }
  final avg = off.courseAverage;
  if (avg != null) {
    if (!seen && was.classAverage != null && was.classAverage != avg) {
      detach[courseAverageGranule] = 0;
    } else if (!isDetached(courseAverageGranule)) {
      cfg.classAverage = avg;
    }
  }
  final changed = config == null ? off.hasScheme || avg != null : false;
  return SchemeUpdate(
    save: save,
    add: add,
    delete: delete,
    config: changed || _json(cfg) != _json(was) ? cfg : null,
    detach: detach,
  );
}

Evaluative _fromPublished(String courseId, OfferedComponent c) => Evaluative(
  courseId: courseId,
  name: c.name,
  weight: c.weight,
  countBest: c.countBest,
  average: c.average,
  sourceId: c.id,
  parts: [
    for (final p in c.parts)
      EvalPart(name: p.name, outOf: p.outOf, date: p.date, average: p.average),
  ],
);

bool _sameStructure(Evaluative e, OfferedComponent c) =>
    e.weight == c.weight &&
    e.countBest == c.countBest &&
    e.parts.length == c.parts.length &&
    [
      for (final (i, p) in c.parts.indexed)
        e.parts[i].outOf == p.outOf &&
            (e.parts[i].date == null || e.parts[i].date == p.date),
    ].every((same) => same);

/// Name, weight, rule and each part's name, out of and date from [c]. Marks
/// stay; a part beyond the published ones stays only if it holds marks.
void _copyStructure(Evaluative e, OfferedComponent c) {
  e
    ..name = c.name
    ..weight = c.weight
    ..countBest = c.countBest;
  final parts = <EvalPart>[
    for (final (i, p) in c.parts.indexed)
      EvalPart(
        name: p.name,
        marks: i < e.parts.length ? e.parts[i].marks : null,
        outOf: p.outOf,
        date: p.date,
        average: i < e.parts.length ? e.parts[i].average : null,
      ),
    for (final extra in e.parts.skip(c.parts.length))
      if (extra.marks != null) extra,
  ];
  e.parts = parts;
}

/// The granules of a course that detached from an older official version
/// than [off]: the "official changed" notice (§16.3 fix 9).
List<String> staleGranules(Map<String, int> detached, Offering off) => [
  for (final e in detached.entries)
    if (e.value < off.updatedAt) e.key,
];

/// What an edit of a published component touches, in words, or null when it
/// touches nothing published. [before] is the stored component, [after] the
/// edit.
String? structuralChange(Evaluative before, Evaluative after, bool weighted) {
  String n(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  final unit = weighted ? '%' : ' marks';
  if (before.weight != after.weight) {
    return 'Weight ${n(before.weight)}$unit → ${n(after.weight)}$unit';
  }
  if (before.name != after.name) return 'Name ${before.name} → ${after.name}';
  if (before.countBest != after.countBest) return 'Which parts count';
  if (before.parts.length != after.parts.length) return 'Its parts';
  for (final (i, p) in before.parts.indexed) {
    final q = after.parts[i];
    if (p.outOf != q.outOf) return 'Out of ${n(p.outOf)} → ${n(q.outOf)}';
    if (p.date != q.date) return 'The date';
    if (p.name != q.name) return 'Its parts';
  }
  return null;
}
