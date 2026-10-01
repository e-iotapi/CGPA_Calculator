import 'package:cgpa_calculator/core/cache/cache_first.dart';
import 'package:cgpa_calculator/core/grading/eval_import.dart';
import 'package:cgpa_calculator/core/heads/heads.dart';
import 'package:cgpa_calculator/core/models/offering.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cgpa_calculator/core/timings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Writes to a course's offering (ARCHITECTURE.md §13.2, §13.3): presidents
/// in scope and the course's CRs. Every write is one batch with its audit
/// entry; the rules check the grant and tie the two together.
class MaintainStore {
  MaintainStore(this.roles);

  /// The store whose identity and audit log the writes use.
  final RoleStore roles;

  FirebaseFirestore get _db => roles.db;

  DocumentReference<Map<String, dynamic>> _ref(
    String courseId,
    String campus,
    String term,
  ) => _db
      .collection('courses')
      .doc(courseId)
      .collection('offerings')
      .doc(offeringId(campus, term));

  /// The document path of the offering of [courseId] on [campus] in [term].
  static String pathOf(String courseId, String campus, String term) =>
      'courses/$courseId/offerings/${offeringId(campus, term)}';

  /// Reads one offering, or `null` if it does not exist. With [fresh], the
  /// saved copy is skipped: Firestore is read and the result saved.
  Future<Offering?> offering(
    String courseId,
    String campus,
    String term, {
    bool fresh = false,
  }) async {
    final key = 'mo|$campus|$term|$courseId';
    if (fresh) await sharedCacheBox?.delete(key);
    return cacheFirst<Offering?>(
      key: key,
      maxAge: adminMaxAge,
      version: (await headFor(campus, db: _db))
          ?.offering(courseId, term)
          ?.toString(),
      fetch: () async {
        final m = (await _ref(courseId, campus, term).get()).data();
        return m == null ? null : Offering.fromMap(m);
      },
      encode: (o) => o?.toMap(),
      decode: _decodeOffering,
    );
  }

  static Offering? _decodeOffering(Object? o) =>
      o == null ? null : Offering.fromMap(o as Map);

  /// The saved [offering], read synchronously; null when none is saved (also
  /// when the course was saved as having no offering).
  Offering? peekOffering(String courseId, String campus, String term) =>
      peekCache<Offering?>('mo|$campus|$term|$courseId', _decodeOffering);

  /// Every offering on [campus] in [term] (Open as › course picker; the
  /// collection-group index on campus, term).
  Future<List<Offering>> campusOfferings(String campus, String term) =>
      cacheFirst<List<Offering>>(
        key: 'mco|$campus|$term',
        maxAge: adminMaxAge,
        fetch: () async {
          final q =
              await _db
                  .collectionGroup('offerings')
                  .where('campus', isEqualTo: campus)
                  .where('term', isEqualTo: term)
                  .get();
          return [for (final d in q.docs) Offering.fromMap(d.data())];
        },
        encode: (l) => [for (final o in l) o.toMap()],
        decode:
            (o) => [for (final m in o as List) Offering.fromMap(m as Map)],
      );

  /// The saved [campusOfferings], read synchronously; null when none is saved.
  List<Offering>? peekCampusOfferings(String campus, String term) => peekCache(
    'mco|$campus|$term',
    (o) => [for (final m in o as List) Offering.fromMap(m as Map)],
  );

  /// This term's offerings for [courseIds]; missing ones are absent.
  Future<Map<String, Offering>> offerings(
    Iterable<String> courseIds,
    String campus,
    String term,
  ) async {
    final got = await Future.wait([
      for (final id in courseIds) offering(id, campus, term),
    ]);
    return {
      for (final o in got)
        if (o != null) o.courseId: o,
    };
  }

  /// The saved [offerings], read synchronously; null if any course has no
  /// saved entry (a course saved as having none is simply absent).
  Map<String, Offering>? peekOfferings(
    Iterable<String> courseIds,
    String campus,
    String term,
  ) {
    final out = <String, Offering>{};
    for (final id in courseIds) {
      final raw = sharedCacheBox?.get('mo|$campus|$term|$id');
      if (raw == null) return null;
      if (peekOffering(id, campus, term) case final o?) out[id] = o;
    }
    return out;
  }

  Future<void> _forget(Iterable<String> campuses) async {
    for (final c in campuses) {
      await forget('mo|$c|');
      await forget('mco|$c|');
    }
    await forget('audit|');
  }

  void _put(WriteBatch b, Offering o, String summary, {String? uploadId}) {
    final path = pathOf(o.courseId, o.campus, o.term);
    final id = roles.logInto(
      b,
      path: path,
      summary: summary,
      campus: o.campus,
      course: o.courseId,
      after: {'scheme': schemeKey(o)},
      uploadId: uploadId,
    );
    b.set(_ref(o.courseId, o.campus, o.term), {
      ...o.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': {'email': roles.me, 'name': roles.myName},
      'auditId': id,
      if (uploadId != null) 'uploadId': uploadId,
    });
  }

  /// Saves [o] as the course's offering this term.
  Future<void> save(Offering o, String summary) async {
    final b = _db.batch();
    _put(b, o, summary);
    bumpOfferings(b, _db, o.campus, o.term, [o.courseId]);
    await b.commit();
    await _forget([o.campus]);
  }

  /// Writes [offerings] five courses a batch, all tagged with one upload id
  /// (§16.3 fix 11). A failed chunk stops the run; [onLanded] hears each
  /// course that was written, so the rest can be retried.
  Future<({String uploadId, Object? error})> upload(
    List<Offering> offerings, {
    void Function(List<String> courseIds)? onLanded,
  }) async {
    final uploadId = _db.collection('audit').doc().id;
    for (final chunk in chunked(offerings)) {
      final b = _db.batch();
      for (final o in chunk) {
        _put(
          b,
          o,
          'Uploaded the ${termLabel(o.term)} scheme for ${o.courseId}',
          uploadId: uploadId,
        );
      }
      for (final campus in {for (final o in chunk) o.campus}) {
        final here = chunk.where((o) => o.campus == campus);
        for (final term in {for (final o in here) o.term}) {
          bumpOfferings(b, _db, campus, term, [
            for (final o in here)
              if (o.term == term) o.courseId,
          ]);
        }
      }
      try {
        await b.commit();
      } catch (e) {
        return (uploadId: uploadId, error: e);
      }
      await _forget({for (final o in chunk) o.campus});
      onLanded?.call([for (final o in chunk) o.courseId]);
    }
    return (uploadId: uploadId, error: null);
  }
}
