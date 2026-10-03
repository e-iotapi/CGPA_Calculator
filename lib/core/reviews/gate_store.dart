import 'package:cgpa_calculator/core/cache/cache_first.dart';
import 'package:cgpa_calculator/core/heads/heads.dart';
import 'package:cgpa_calculator/core/heads/paths.dart';
import 'package:cgpa_calculator/core/live/live_heads.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// `reviewGate/<campus>`: the switch for the review gate. Missing doc is off.
/// The unlock count is enforced in the app only (ruling R-A).
class GateStore {
  GateStore(this.roles);

  /// The signed-in person's role store (database, identity, audit).
  final RoleStore roles;

  FirebaseFirestore get _db => roles.db;

  /// Whether the gate is on for [campus]. One doc, cached under the marker.
  Future<bool> of(String campus) async => cacheFirst<bool>(
    key: 'gate|$campus',
    maxAge: const Duration(hours: 1),
    version: await markerOf(_db, campus, Paths.reviewGate),
    fetch:
        () async =>
            (await _db.collection('reviewGate').doc(campus).get()).data()?['on']
                as bool? ??
            false,
    encode: (v) => v,
    decode: (v) => v as bool? ?? false,
  );

  /// The saved value, read synchronously; null when none is saved.
  bool? peekOf(String campus) =>
      peekCache<bool>('gate|$campus', (v) => v as bool? ?? false);

  /// Turns the gate on or off for [campus]. Throws `permission-denied` for
  /// anyone who may not. A president or secretary passes the [dept] they
  /// hold; owners and admins need none.
  Future<void> set(String campus, bool on, {String? dept}) async {
    final b = _db.batch();
    final id = roles.logInto(
      b,
      path: 'reviewGate/$campus',
      summary: on ? 'Turned the review gate on' : 'Turned the review gate off',
      campus: campus,
    );
    b.set(_db.collection('reviewGate').doc(campus), {
      'on': on,
      'by': {'email': roles.me, 'name': roles.myName},
      'at': FieldValue.serverTimestamp(),
      'auditId': id,
      if (dept != null) 'dept': dept,
    });
    bumpPath(b, _db, campus, Paths.reviewGate);
    await b.commit();
    LiveHeads.poke(Paths.reviewGate);
    await forget('gate|$campus');
    await forget('audit|');
  }
}
