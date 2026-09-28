/// One course as taught on one campus in one term: the published evaluation
/// scheme, averages and professors (ARCHITECTURE.md §4, §8, §10.1).
///
/// Stored at `courses/{courseId}/offerings/{campus}_{term}`, written by the
/// course's CRs and the department's presidents, read live by students of
/// that campus and cached.
library;

/// The term a semester label falls in, for a student whose batch (two-digit
/// entry year) is [batch]: "2 - 1" for batch 24 is "2025-26-1". Summer terms
/// ("PS 1", "ST 1") end in "-S". Null for a label with no year.
String? termOf(int batch, String sem) {
  final summer = const {'PS 1': 2, 'ST 1': 3, 'ST 2': 4}[sem.trim()];
  final m = RegExp(r'^(\d)\s*-\s*(\d)$').firstMatch(sem.trim());
  if (summer == null && m == null) return null;
  final year = summer ?? int.parse(m!.group(1)!);
  final start = 2000 + batch + year - 1;
  final next = ((start + 1) % 100).toString().padLeft(2, '0');
  return '$start-$next-${summer != null ? 'S' : m!.group(2)}';
}

/// "2026-27 Sem 1", "2026-27 Summer".
String termLabel(String term) {
  final i = term.lastIndexOf('-');
  final k = term.substring(i + 1);
  return '${term.substring(0, i)} ${k == 'S' ? 'Summer' : 'Sem $k'}';
}

/// The document id of [campus]'s offering in [term].
String offeringId(String campus, String term) => '${campus}_$term';

/// A part of a published component; single-mark components have one, named
/// "".
class OfferedPart {
  const OfferedPart({
    required this.name,
    required this.outOf,
    this.date,
    this.average,
  });

  final String name;
  final double outOf;

  /// ISO-8601 date ("2026-09-08").
  final String? date;
  final double? average;

  Map<String, dynamic> toMap() => {
    'name': name,
    'outOf': outOf,
    if (date != null) 'date': date,
    if (average != null) 'average': average,
  };

  static OfferedPart fromMap(Map m) => OfferedPart(
    name: m['name'] as String? ?? '',
    outOf: (m['outOf'] as num).toDouble(),
    date: m['date'] as String?,
    average: (m['average'] as num?)?.toDouble(),
  );
}

/// A published component. [id] is stable across renames: a student's marks
/// pin to it (§5).
class OfferedComponent {
  const OfferedComponent({
    required this.id,
    required this.name,
    required this.weight,
    required this.parts,
    this.countBest = 0,
    this.average,
  });

  final String id;
  final String name;

  /// Percent when the course is weighted, else marks.
  final double weight;
  final List<OfferedPart> parts;

  /// 0 = every part counts, else the best N.
  final int countBest;
  final double? average;

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'weight': weight,
    'parts': [for (final p in parts) p.toMap()],
    'countBest': countBest,
    if (average != null) 'average': average,
  };

  static OfferedComponent fromMap(Map m) => OfferedComponent(
    id: m['id'] as String,
    name: m['name'] as String,
    weight: (m['weight'] as num).toDouble(),
    parts: [
      for (final p in m['parts'] as List? ?? const []) OfferedPart.fromMap(p),
    ],
    countBest: (m['countBest'] as num?)?.toInt() ?? 0,
    average: (m['average'] as num?)?.toDouble(),
  );
}

class Offering {
  const Offering({
    required this.courseId,
    required this.campus,
    required this.term,
    required this.components,
    required this.updatedAt,
    this.weighted = true,
    this.totalMarks = 100,
    this.courseAverage,
    this.outOf,
    this.professors = const [],
    this.updatedByName = '',
    this.updatedByEmail = '',
  });

  final String courseId, campus, term;
  final bool weighted;
  final double totalMarks;
  final List<OfferedComponent> components;
  final double? courseAverage;

  /// The scale a weighted course is graded out of (e.g. 200), set by whoever
  /// maintains it; students' "Shown out of" follows it (UI_REBUILD_HANDOFF
  /// §3.2). Null: the course's own units.
  final double? outOf;

  /// Professor ids (§10.1); a course can have two in one term.
  final List<String> professors;

  /// Milliseconds since the epoch. An override records the value it was
  /// detached from (`basedOn`, §16.3 fix 9).
  final int updatedAt;
  final String updatedByName, updatedByEmail;

  bool get hasScheme => components.isNotEmpty;

  /// This offering with [outOf] replaced (null clears it).
  Offering copyWith({required double? outOf}) => Offering(
    courseId: courseId,
    campus: campus,
    term: term,
    components: components,
    updatedAt: updatedAt,
    weighted: weighted,
    totalMarks: totalMarks,
    courseAverage: courseAverage,
    outOf: outOf,
    professors: professors,
    updatedByName: updatedByName,
    updatedByEmail: updatedByEmail,
  );

  OfferedComponent? component(String id) =>
      components.where((c) => c.id == id).firstOrNull;

  Map<String, dynamic> toMap() => {
    'courseId': courseId,
    'campus': campus,
    'term': term,
    'weighted': weighted,
    'totalMarks': totalMarks,
    'components': [for (final c in components) c.toMap()],
    if (courseAverage != null) 'courseAverage': courseAverage,
    if (outOf != null) 'outOf': outOf,
    'professors': professors,
    'updatedAt': updatedAt,
    'updatedBy': {'name': updatedByName, 'email': updatedByEmail},
  };

  static Offering fromMap(Map m) {
    final by = m['updatedBy'] as Map? ?? const {};
    final at = m['updatedAt'];
    return Offering(
      courseId: m['courseId'] as String,
      campus: m['campus'] as String,
      term: m['term'] as String,
      weighted: m['weighted'] as bool? ?? true,
      totalMarks: (m['totalMarks'] as num?)?.toDouble() ?? 100,
      components: [
        for (final c in m['components'] as List? ?? const [])
          OfferedComponent.fromMap(c),
      ],
      courseAverage: (m['courseAverage'] as num?)?.toDouble(),
      outOf: (m['outOf'] as num?)?.toDouble(),
      professors: [for (final p in m['professors'] as List? ?? const []) '$p'],
      // A Firestore Timestamp in the database, an int in the cache.
      updatedAt:
          at is int
              ? at
              : at is num
              ? at.toInt()
              : (at as dynamic)?.millisecondsSinceEpoch as int? ?? 0,
      updatedByName: by['name'] as String? ?? '',
      updatedByEmail: by['email'] as String? ?? '',
    );
  }
}
