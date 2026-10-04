import 'package:cgpa_calculator/core/cache/cache_first.dart';
import 'package:cgpa_calculator/core/heads/heads.dart';
import 'package:cgpa_calculator/core/heads/paths.dart';
import 'package:cgpa_calculator/core/live/live_heads.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/store_error.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// `courseClaims/<campus>|<course>` (B2): a department took over a GEN-prefix
/// course; [at] is epoch ms.
class CourseClaim {
  const CourseClaim({
    required this.campus,
    required this.courseId,
    required this.dept,
    required this.byName,
    required this.byEmail,
    required this.at,
  });

  final String campus, courseId, dept, byName, byEmail;
  final int at;

  static int _ms(Object? v) => switch (v) {
    Timestamp t => t.millisecondsSinceEpoch,
    num n => n.toInt(),
    _ => 0,
  };

  factory CourseClaim.fromMap(Map m) {
    final by = (m['by'] as Map?) ?? const {};
    return CourseClaim(
      campus: '${m['campus']}',
      courseId: '${m['courseId']}',
      dept: '${m['dept']}',
      byName: '${by['name'] ?? ''}',
      byEmail: '${by['email'] ?? ''}',
      at: _ms(m['at']),
    );
  }

  Map<String, dynamic> toMap() => {
    'campus': campus,
    'courseId': courseId,
    'dept': dept,
    'by': {'email': byEmail, 'name': byName},
    'at': at,
  };
}

/// The course is already claimed (code `taken`).
class ClaimError extends StoreError {
  const ClaimError(super.code);
}

/// Claims and unclaims of GEN courses; presidents and secretaries of the
/// claiming department, owners and admins write (rules).
class ClaimStore {
  ClaimStore(this.roles);

  final RoleStore roles;

  FirebaseFirestore get _db => roles.db;

  String _id(String campus, String courseId) => '$campus|$courseId';

  CourseClaim _dec1(Object? j) =>
      CourseClaim.fromMap((j as Map).cast<String, Object?>());

  Map<String, CourseClaim> _dec(Object? j) => {
    for (final e in (j as Map).entries) '${e.key}': _dec1(e.value),
  };

  /// Course id to its claim on [campus].
  Future<Map<String, CourseClaim>> claims(String campus) async =>
      cacheFirst<Map<String, CourseClaim>>(
        key: 'cl|$campus',
        maxAge: const Duration(hours: 1),
        version: await markerOf(_db, campus, Paths.courseClaims),
        fetch: () async {
          final q =
              await _db
                  .collection('courseClaims')
                  .where('campus', isEqualTo: campus)
                  .get();
          return {
            for (final d in q.docs)
              if (d.data()['courseId'] case final String c)
                c: CourseClaim.fromMap(d.data()),
          };
        },
        encode: (m) => {for (final e in m.entries) e.key: e.value.toMap()},
        decode: _dec,
      );

  /// The saved [claims], read synchronously.
  Map<String, CourseClaim>? peekClaims(String campus) =>
      peekCache<Map<String, CourseClaim>>('cl|$campus', _dec);

  /// [dept] takes over [courseId]. Throws `ClaimError('taken')` if one exists.
  Future<void> claim(String campus, String courseId, String dept) async {
    final ref = _db.collection('courseClaims').doc(_id(campus, courseId));
    if ((await ref.get()).exists) throw const ClaimError('taken');
    final b = _db.batch();
    final audit = roles.logInto(
      b,
      path: 'courseClaims/${ref.id}',
      summary: 'Claimed $courseId for ${departmentName(dept)}',
      campus: campus,
      course: courseId,
      after: dept,
    );
    b.set(ref, {
      'campus': campus,
      'courseId': courseId,
      'dept': dept,
      'by': {'email': roles.me, 'name': roles.myName},
      'at': FieldValue.serverTimestamp(),
      'auditId': audit,
    });
    bumpPath(b, _db, campus, Paths.courseClaims);
    await b.commit();
    await _changed();
  }

  /// Hands [courseId] back to GEN. The claim is deleted, so its audit entry
  /// takes an id the rules can derive (`del|<id>|<claimed at>`).
  Future<void> unclaim(String campus, String courseId) async {
    final ref = _db.collection('courseClaims').doc(_id(campus, courseId));
    final snap = await ref.get();
    final c = snap.data();
    if (c == null) return;
    final b = _db.batch();
    roles.logInto(
      b,
      path: 'courseClaims/${ref.id}',
      summary: 'Unclaimed $courseId from ${departmentName('${c['dept']}')}',
      campus: campus,
      course: courseId,
      before: c['dept'],
      auditId: 'del|${ref.id}|${CourseClaim._ms(c['at'])}',
    );
    b.delete(ref);
    bumpPath(b, _db, campus, Paths.courseClaims);
    await b.commit();
    await _changed();
  }

  Future<void> _changed() async {
    LiveHeads.poke(Paths.courseClaims);
    await forget('cl|');
    await forget('audit|');
  }
}
