/// Reads and writes for people, owners, grants, the staff index, the audit log
/// and config (ARCHITECTURE.md §4). Every shared write goes out in one batch
/// with its audit entry; firestore.rules refuses it otherwise.
library;

import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// One line of `audit/`.
class AuditEntry {
  const AuditEntry({
    required this.actorEmail,
    required this.actorName,
    required this.actorRole,
    required this.summary,
    required this.path,
    required this.campus,
    this.course,
    this.before,
    this.after,
    this.at,
  });

  final String actorEmail, actorName, actorRole, summary, path, campus;
  final String? course;
  final Object? before, after;
  final DateTime? at;

  static AuditEntry fromMap(Map<String, dynamic> m) {
    final a = m['actor'] as Map? ?? const {};
    return AuditEntry(
      actorEmail: a['email'] as String? ?? '',
      actorName: a['name'] as String? ?? '',
      actorRole: a['role'] as String? ?? '',
      summary: m['summary'] as String? ?? m['action'] as String? ?? '',
      path: m['path'] as String? ?? '',
      campus: m['campus'] as String? ?? '',
      course: m['course'] as String?,
      before: m['before'],
      after: m['after'],
      at: asDate(m['at']),
    );
  }
}

/// `config/grantTerms`, in days (§4).
typedef GrantTerms = ({int crDays, int presidentDays, int adminDays});

const defaultTerms = (crDays: 183, presidentDays: 365, adminDays: 730);

int termDays(GrantTerms t, GrantRole r) => switch (r) {
  GrantRole.admin => t.adminDays,
  GrantRole.dept => t.presidentDays,
  GrantRole.course => t.crDays,
};

/// `config/public` (§10.5).
typedef PublicContact =
    ({String name, String method, String target, bool enabled});

class RoleStore {
  RoleStore(this.db, {required String me, required this.myName, this.actingAs})
    : me = me.toLowerCase();

  final FirebaseFirestore db;
  final String me, myName;

  /// The role the audit entry names ("owner", "president"…), and, under Open
  /// as, what the owner was viewing as (§16.3 fix 1).
  /// Who the actor is acting as when an entry is written (Switch role, Open
  /// as).
  final ({String role, String? viewingAs}) Function()? actingAs;

  // ---- People --------------------------------------------------------------

  /// Every sign-in makes sure `people/{me}` exists, so the person can be
  /// appointed (§16.3 fix 12). Written once.
  Future<void> recordSignIn({
    required String name,
    required String campus,
  }) async {
    final ref = db.collection('people').doc(me);
    final d = await ref.get();
    if (d.exists) return;
    await ref.set({
      'name': name.isEmpty ? me.split('@').first : name,
      'campus': campus,
      'firstSignIn': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// The name of someone who has signed in, or null: "Can not be found".
  Future<String?> personName(String email) async {
    try {
      final d = await db.collection('people').doc(email.toLowerCase()).get();
      return d.data()?['name'] as String?;
    } on FirebaseException {
      return null;
    }
  }

  // ---- Who I am ------------------------------------------------------------

  Future<MyRoles> loadMine({DateTime? now}) async {
    var owner = false;
    try {
      final o = await db.collection('owners').doc(me).get();
      owner = o.data()?['active'] == true;
    } on FirebaseException {
      owner = false;
    }
    final q = await db.collection('grants').where('email', isEqualTo: me).get();
    final at = now ?? DateTime.now();
    return MyRoles(
      email: me,
      owner: owner,
      grants: [
        for (final d in q.docs)
          if (Grant.fromMap(d.data()) case final g when g.liveAt(at)) g,
      ],
    );
  }

  // ---- Audit ---------------------------------------------------------------

  /// Adds the audit entry for [path] to [b]; returns its id for the shared
  /// document's `auditId`.
  String _audit(
    WriteBatch b, {
    required String path,
    required String summary,
    required String campus,
    String? course,
    Object? before,
    Object? after,
  }) {
    final ref = db.collection('audit').doc();
    final acting = actingAs?.call();
    b.set(ref, {
      'actor': {'email': me, 'name': myName, 'role': acting?.role ?? 'owner'},
      if (acting?.viewingAs case final v?) 'viewingAs': v,
      'action': summary,
      'summary': summary,
      'path': path,
      'campus': campus,
      if (course != null) 'course': course,
      'before': before,
      'after': after,
      'at': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<List<AuditEntry>> audit({
    String? campus,
    String? actor,
    String? course,
    int limit = 50,
  }) async {
    Query<Map<String, dynamic>> q = db.collection('audit');
    if (campus != null) q = q.where('campus', whereIn: [campus, 'all']);
    if (actor != null) q = q.where('actor.email', isEqualTo: actor);
    if (course != null) q = q.where('course', isEqualTo: course);
    final r = await q.orderBy('at', descending: true).limit(limit).get();
    return [for (final d in r.docs) AuditEntry.fromMap(d.data())];
  }

  // ---- Grants --------------------------------------------------------------

  Future<GrantTerms> terms() async {
    final d = await db.collection('config').doc('grantTerms').get();
    final m = d.data();
    if (m == null) return defaultTerms;
    return (
      crDays: m['crDays'] as int,
      presidentDays: m['presidentDays'] as int,
      adminDays: m['adminDays'] as int,
    );
  }

  Future<void> saveTerms(GrantTerms t) async {
    final b = db.batch();
    final before = await terms();
    final id = _audit(
      b,
      path: 'config/grantTerms',
      summary:
          'Set grant terms: CR ${t.crDays} days, president '
          '${t.presidentDays}, admin ${t.adminDays}',
      campus: 'all',
      before: _termsMap(before),
      after: _termsMap(t),
    );
    b.set(db.collection('config').doc('grantTerms'), {
      ..._termsMap(t),
      'auditId': id,
    });
    await b.commit();
  }

  static Map<String, int> _termsMap(GrantTerms t) => {
    'crDays': t.crDays,
    'presidentDays': t.presidentDays,
    'adminDays': t.adminDays,
  };

  Future<StaffEntry> _staff(String email) async {
    final d = await db.collection('staff').doc(email).get();
    final m = d.data();
    return m == null ? StaffEntry(email: email) : StaffEntry.fromMap(m);
  }

  /// Writes [g] (new, renewed or revoked) with the staff index and the audit
  /// entry, in one batch.
  Future<void> _writeGrant(Grant g, String summary, {Grant? before}) async {
    final staff = await _staff(g.email);
    final b = db.batch();
    final id = _audit(
      b,
      path: 'grants/${g.id}',
      summary: summary,
      campus: g.campus,
      course: g.role == GrantRole.course ? g.scope : null,
      before: before == null ? null : _grantSummary(before),
      after: _grantSummary(g),
    );
    final ref = db.collection('grants').doc(g.id);
    final data = <String, dynamic>{
      'active': g.active,
      'expiresAt': Timestamp.fromDate(g.expiresAt),
      'auditId': id,
    };
    if (before == null) {
      b.set(ref, {
        ...data,
        'role': g.role.key,
        'email': g.email,
        'name': g.name,
        'campus': g.campus,
        'scope': g.scope,
        if (g.programme != null) 'programme': g.programme,
        'grantedBy': {'email': me, 'name': myName},
        'grantedAt': FieldValue.serverTimestamp(),
      });
    } else {
      b.update(ref, data);
    }
    final s = staff.after(g);
    b.set(db.collection('staff').doc(g.email), {
      ...s,
      if (s['expiresAt'] case final DateTime e)
        'expiresAt': Timestamp.fromDate(e),
    });
    await b.commit();
  }

  static Map<String, Object?> _grantSummary(Grant g) => {
    'active': g.active,
    'expiresAt': g.expiresAt.toIso8601String(),
  };

  /// Appoints [email] (who must have signed in) for [role] on [campus] /
  /// [scope]. Returns false when there is nobody by that address.
  Future<bool> appoint({
    required GrantRole role,
    required String email,
    required String campus,
    required String scope,
    required DateTime expiresAt,
    String? programme,
  }) async {
    final address = email.trim().toLowerCase();
    final name = await personName(address);
    if (name == null) return false;
    final existing =
        await db
            .collection('grants')
            .doc(grantId(role, campus, scope, address))
            .get();
    final g = Grant(
      role: role,
      email: address,
      name: name,
      campus: campus,
      scope: scope,
      programme: programme,
      active: true,
      expiresAt: expiresAt,
    );
    final what = switch (role) {
      GrantRole.admin => 'admin',
      GrantRole.dept =>
        'president of $scope${programme == null ? '' : ' for $programme'}',
      GrantRole.course => 'CR for $scope',
    };
    final data = existing.data();
    await _writeGrant(
      g,
      '${data == null ? 'Appointed' : 'Renewed'} $name $what',
      before: data == null ? null : Grant.fromMap(data),
    );
    return true;
  }

  /// Revoking deactivates; nothing is deleted (§4).
  Future<void> revoke(Grant g) => _writeGrant(
    Grant(
      role: g.role,
      email: g.email,
      name: g.name,
      campus: g.campus,
      scope: g.scope,
      programme: g.programme,
      active: false,
      expiresAt: g.expiresAt,
    ),
    'Revoked ${g.name} as ${g.role.label.toLowerCase()} (${g.scopeLabel})',
    before: g,
  );

  /// Every grant the reader may see: all of them for owners and admins,
  /// [campus] plus the every-campus ones for a president.
  Future<List<Grant>> roster({String? campus}) async {
    Query<Map<String, dynamic>> q = db.collection('grants');
    if (campus != null) q = q.where('campus', whereIn: [campus, 'all']);
    final r = await q.get();
    return [for (final d in r.docs) Grant.fromMap(d.data())];
  }

  // ---- Owners --------------------------------------------------------------

  Future<List<Map<String, dynamic>>> owners() async {
    final r = await db.collection('owners').get();
    return [for (final d in r.docs) d.data()];
  }

  Future<void> addOwner(String email, String name) async {
    final address = email.trim().toLowerCase();
    final b = db.batch();
    final id = _audit(
      b,
      path: 'owners/$address',
      summary: 'Added $address as an owner',
      campus: 'all',
      after: {'active': true},
    );
    b.set(db.collection('owners').doc(address), {
      'email': address,
      'name': name,
      'active': true,
      'addedBy': {'email': me, 'name': myName},
      'addedAt': FieldValue.serverTimestamp(),
      'auditId': id,
    });
    await b.commit();
  }

  /// Never for oneself; the rules refuse that too.
  Future<void> setOwnerActive(String email, bool active) async {
    if (email == me && !active) {
      throw StateError('An owner cannot remove themselves.');
    }
    final b = db.batch();
    final id = _audit(
      b,
      path: 'owners/$email',
      summary: '${active ? 'Restored' : 'Removed'} $email as an owner',
      campus: 'all',
      before: {'active': !active},
      after: {'active': active},
    );
    b.update(db.collection('owners').doc(email), {
      'active': active,
      'auditId': id,
    });
    await b.commit();
  }

  // ---- Public contact ------------------------------------------------------

  Future<PublicContact?> publicContact() async {
    final d = await db.collection('config').doc('public').get();
    final m = d.data();
    if (m == null) return null;
    return (
      name: m['contactName'] as String? ?? '',
      method: m['contactMethod'] as String? ?? 'whatsapp',
      target: m['contactTarget'] as String? ?? '',
      enabled: m['contactEnabled'] as bool? ?? false,
    );
  }

  Future<void> savePublicContact(PublicContact c) async {
    final b = db.batch();
    final id = _audit(
      b,
      path: 'config/public',
      summary:
          c.enabled
              ? 'Set the public contact to ${c.name} (${c.method})'
              : 'Turned the public contact off',
      campus: 'all',
    );
    b.set(db.collection('config').doc('public'), {
      'contactName': c.name,
      'contactMethod': c.method,
      'contactTarget': c.target,
      'contactEnabled': c.enabled,
      'updatedBy': {'email': me, 'name': myName},
      'updatedAt': FieldValue.serverTimestamp(),
      'auditId': id,
    });
    await b.commit();
  }
}
