/// `heads/{campus}`: one small document per campus that says what moved —
/// the catalogue version, the public contact, and a version per offering —
/// so an app open reads it (at most every [headMaxAge]) instead of polling
/// each of those (PERF_TEST_PLAN.md §A.1, §A.2).
///
/// Budget: ≤ 1 read per open older than [headMaxAge] per user; writers add
/// one merge-set to a batch they already commit (no extra read).
library;

import 'package:cgpa_calculator/core/cache/cache_first.dart';
import 'package:cgpa_calculator/core/models/programmes.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const headMaxAge = Duration(hours: 6);

class Head {
  const Head({
    this.catalog,
    this.catalogSchema,
    this.contact,
    this.offerings = const {},
  });

  /// The published catalogue's version and schema, when published since
  /// heads existed.
  final int? catalog, catalogSchema;

  /// The public contact as `config/public` holds it.
  final Map<String, Object?>? contact;

  /// `'<courseId>|<term>'` → a counter each scheme save moves.
  final Map<String, int> offerings;

  int? offering(String courseId, String term) =>
      offerings[offeringKey(courseId, term)];

  static Head fromMap(Map m) => Head(
    catalog: (m['catalog'] as num?)?.toInt(),
    catalogSchema: (m['catalogSchema'] as num?)?.toInt(),
    contact: (m['contact'] as Map?)?.cast<String, Object?>(),
    offerings: {
      for (final e in ((m['offerings'] as Map?) ?? const {}).entries)
        '${e.key}': (e.value as num).toInt(),
    },
  );

  Map<String, Object?> toMap() => {
    'catalog': catalog,
    'catalogSchema': catalogSchema,
    'contact': contact,
    'offerings': offerings,
  };
}

String offeringKey(String courseId, String term) => '$courseId|$term';

DocumentReference<Map<String, dynamic>> headRef(
  FirebaseFirestore db,
  String campus,
) => db.collection('heads').doc(campus);

/// [campus]'s head: cached, refreshed in the background past [headMaxAge].
/// Null when none is written yet or it cannot be read.
Future<Head?> headFor(String campus, {FirebaseFirestore? db}) async {
  try {
    return await cacheFirst<Head?>(
      key: 'head|$campus',
      maxAge: headMaxAge,
      fetch: () async {
        final m =
            (await headRef(db ?? FirebaseFirestore.instance, campus).get())
                .data();
        return m == null ? null : Head.fromMap(m);
      },
      encode: (h) => h?.toMap(),
      decode: (v) => v == null ? null : Head.fromMap(v as Map),
    );
  } on Object {
    return null;
  }
}

/// In a scheme-saving batch: moves each course's offering version on its
/// campus's head, so students re-read only what changed.
void bumpOfferings(
  WriteBatch b,
  FirebaseFirestore db,
  String campus,
  String term,
  Iterable<String> courseIds,
) => b.set(headRef(db, campus), {
  'offerings': {
    for (final c in courseIds) offeringKey(c, term): FieldValue.increment(1),
  },
}, SetOptions(merge: true));

/// Every campus head, for writes that concern all of them (a catalogue
/// publish, the public contact).
void setOnAllHeads(
  WriteBatch b,
  FirebaseFirestore db,
  Map<String, Object?> fields,
) {
  for (final c in Campus.values) {
    b.set(headRef(db, c.name), fields, SetOptions(merge: true));
  }
}
