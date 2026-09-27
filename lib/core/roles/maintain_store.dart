import 'package:cgpa_calculator/core/grading/eval_import.dart';
import 'package:cgpa_calculator/core/models/offering.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Writes to a course's offering (ARCHITECTURE.md §13.2, §13.3): presidents
/// in scope and the course's CRs. Every write is one batch with its audit
/// entry; the rules check the grant and tie the two together.
class MaintainStore {
  MaintainStore(this.roles);
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

  static String pathOf(String courseId, String campus, String term) =>
      'courses/$courseId/offerings/${offeringId(campus, term)}';

  Future<Offering?> offering(
    String courseId,
    String campus,
    String term,
  ) async {
    final m = (await _ref(courseId, campus, term).get()).data();
    return m == null ? null : Offering.fromMap(m);
  }

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
    await b.commit();
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
      try {
        await b.commit();
      } catch (e) {
        return (uploadId: uploadId, error: e);
      }
      onLanded?.call([for (final o in chunk) o.courseId]);
    }
    return (uploadId: uploadId, error: null);
  }
}
