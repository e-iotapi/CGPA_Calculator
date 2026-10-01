/// `heads/{campus}`: one small document per campus that says what moved —
/// the catalogue version, the public contact, and a version per offering —
/// so an app open reads it (at most every [headMaxAge]) instead of polling
/// each of those (PERF_TEST_PLAN.md §A.1, §A.2).
///
/// Budget: ≤ 1 read per open older than [headMaxAge] per user; writers add
/// one merge-set to a batch they already commit (no extra read).
library;

import 'package:cgpa_calculator/core/cache/cache_first.dart';
import 'package:cgpa_calculator/core/heads/heads_client.dart';
import 'package:cgpa_calculator/core/models/programmes.dart';
import 'package:cgpa_calculator/core/timings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// A campus's `heads/{campus}` document: small version counters that let
/// the app skip reads when nothing changed.
class Head {
  const Head({
    this.catalog,
    this.catalogSchema,
    this.contact,
    this.offerings = const {},
    this.v = const {},
  });

  /// The published catalogue's version and schema, when published since
  /// heads existed.
  final int? catalog, catalogSchema;

  /// The public contact as `config/public` holds it.
  final Map<String, Object?>? contact;

  /// `'<courseId>|<term>'` → a counter each scheme save moves.
  final Map<String, int> offerings;

  /// Marker path (see `Paths`) → a counter each write to that shared data
  /// moves.
  final Map<String, int> v;

  /// The marker of [path], or `null`.
  int? version(String path) => v[path];

  /// The counter of [courseId]'s scheme in [term], or `null`.
  int? offering(String courseId, String term) =>
      offerings[offeringKey(courseId, term)];

  /// Reads a head from its document data.
  static Head fromMap(Map m) => Head(
    catalog: (m['catalog'] as num?)?.toInt(),
    catalogSchema: (m['catalogSchema'] as num?)?.toInt(),
    contact: (m['contact'] as Map?)?.cast<String, Object?>(),
    offerings: {
      for (final e in ((m['offerings'] as Map?) ?? const {}).entries)
        '${e.key}': (e.value as num).toInt(),
    },
    v: {
      for (final e in ((m['v'] as Map?) ?? const {}).entries)
        '${e.key}': (e.value as num).toInt(),
    },
  );

  /// Serialises the head for the cache.
  Map<String, Object?> toMap() => {
    'catalog': catalog,
    'catalogSchema': catalogSchema,
    'contact': contact,
    'offerings': offerings,
    'v': v,
  };
}

/// The [Head.offerings] key for [courseId] in [term].
String offeringKey(String courseId, String term) => '$courseId|$term';

/// The head document of [campus].
DocumentReference<Map<String, dynamic>> headRef(
  FirebaseFirestore db,
  String campus,
) => db.collection('heads').doc(campus);

/// [campus]'s head: cached, refreshed in the background past [headMaxAge].
/// Null when none is written yet or it cannot be read.
///
/// [awaitStale]: wait for the refresh when the cache is old (the catalogue
/// check does, so a publish lands on the first open past [headMaxAge] rather
/// than the one after; same single read).
///
/// The fetch asks the Worker first when [headsUrl] is set ([worker] swaps it
/// out for tests), then Firestore if it has nothing or fails.
Future<Head?> headFor(
  String campus, {
  FirebaseFirestore? db,
  bool awaitStale = false,
  Future<Map<String, dynamic>?> Function(String campus) worker = workerHead,
}) async {
  try {
    return await cacheFirst<Head?>(
      key: 'head|$campus',
      maxAge: headMaxAge,
      awaitStale: awaitStale,
      fetch: () async {
        try {
          final w = await worker(campus);
          if (w != null && w.isNotEmpty) return Head.fromMap(w);
        } on Object {
          // fall through to Firestore
        }
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

/// In a write batch: moves [path]'s marker on [campus]'s head by one.
void bumpPath(WriteBatch b, FirebaseFirestore db, String campus, String path) =>
    b.set(headRef(db, campus), {
      'v': {path: FieldValue.increment(1)},
    }, SetOptions(merge: true));

/// The same on every campus head (owners, terms).
void bumpPathOnAllHeads(WriteBatch b, FirebaseFirestore db, String path) {
  for (final c in Campus.values) {
    bumpPath(b, db, c.name, path);
  }
}

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
