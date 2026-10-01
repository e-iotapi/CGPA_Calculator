/// Reads and writes for people, owners, grants, the staff index, the audit log
/// and config (ARCHITECTURE.md §4). Every shared write goes out in one batch
/// with its audit entry; firestore.rules refuses it otherwise.
library;

import 'package:cgpa_calculator/core/cache/cache_first.dart';
import 'package:cgpa_calculator/core/heads/heads.dart';
import 'package:cgpa_calculator/core/perf/perf.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/timings.dart';
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

  /// Who acted, in what role, and a one-line description of the change.
  final String actorEmail, actorName, actorRole, summary, path, campus;

  /// The course the change concerns, if any.
  final String? course;

  /// The changed document's data before and after the write.
  final Object? before, after;

  /// When the entry was written.
  final DateTime? at;

  /// JSON-safe, for `cacheFirst`: [fromMap] reads it back.
  Map<String, dynamic> toMap() => {
    'actor': {'email': actorEmail, 'name': actorName, 'role': actorRole},
    'summary': summary,
    'path': path,
    'campus': campus,
    'course': course,
    'before': _safe(before),
    'after': _safe(after),
    'at': at?.millisecondsSinceEpoch,
  };

  /// Timestamps as millis, so the value caches as JSON.
  static Object? _safe(Object? v) => switch (v) {
    Timestamp t => t.millisecondsSinceEpoch,
    Map m => {for (final e in m.entries) '${e.key}': _safe(e.value)},
    List l => [for (final x in l) _safe(x)],
    _ => v,
  };

  /// Reads an audit document's data.
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

/// The terms used until `config/grantTerms` exists.
const defaultTerms = (crDays: 183, presidentDays: 365, adminDays: 730);

/// The grant length in days for role [r] under terms [t].
int termDays(GrantTerms t, GrantRole r) => switch (r) {
  GrantRole.admin => t.adminDays,
  GrantRole.dept => t.presidentDays,
  GrantRole.course => t.crDays,
};

/// `config/public` (§10.5).
typedef PublicContact =
    ({String name, String method, String target, bool enabled});

/// Reads and writes grants, owners, terms and the audit log as [me].
///
/// Every write goes in a batch with its audit entry.
class RoleStore {
  RoleStore(this.db, {required String me, required this.myName, this.actingAs})
    : me = me.toLowerCase();

  /// The Firestore instance written to.
  final FirebaseFirestore db;

  /// The acting person's lower-cased address and display name.
  final String me, myName;

  /// The role the audit entry names ("owner", "president"…), and, under Open
  /// as, what the owner was viewing as (§16.3 fix 1).
  /// Who the actor is acting as when an entry is written (Switch role, Open
  /// as).
  final ({String role, String? viewingAs}) Function()? actingAs;

  // ---- People --------------------------------------------------------------

  /// Makes sure `people/{me}` exists, so the person can be appointed
  /// (§16.3 fix 12), and moves `lastSeen` (site analytics). [known]: this
  /// device already recorded them, so only `lastSeen` is written, unread.
  Future<void> recordSignIn({
    required String name,
    required String campus,
    bool known = false,
  }) async {
    final ref = db.collection('people').doc(me);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (known) {
      try {
        await ref.update({'lastSeen': now});
        return;
      } on FirebaseException catch (e) {
        if (e.code != 'not-found') rethrow;
      }
    }
    final d = await ref.get();
    if (d.exists) {
      await ref.update({'lastSeen': now});
      return;
    }
    await ref.set({
      'name': name.isEmpty ? me.split('@').first : name,
      'campus': campus,
      'firstSignIn': now,
      'lastSeen': now,
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

  // Budget: 2 reads per refresh (P0) — every 6h or on demand (P3.4), not
  // per app open.
  /// Loads the roles [me] holds, dropping expired grants.
  Future<MyRoles> loadMine({DateTime? now}) async {
    var owner = false;
    try {
      final o = await Perf.time(
        'roles.owner',
        () => db.collection('owners').doc(me).get(),
      );
      owner = o.data()?['active'] == true;
    } on FirebaseException {
      owner = false;
    }
    final q = await Perf.time(
      'roles.grants',
      () => db.collection('grants').where('email', isEqualTo: me).get(),
    );
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
  /// document's `auditId`. Every shared write goes through here (§4).
  String logInto(
    WriteBatch b, {
    required String path,
    required String summary,
    required String campus,
    String? course,
    Object? before,
    Object? after,
    String? uploadId,
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
      if (uploadId != null) 'uploadId': uploadId,
      'at': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Reads the newest [limit] audit entries, optionally for one [campus],
  /// [actor] or [course].
  ///
  /// Costs up to [limit] reads.
  Future<List<AuditEntry>> audit({
    String? campus,
    String? actor,
    String? course,
    int limit = 50,
  }) => cacheFirst<List<AuditEntry>>(
    key: _auditKey(campus, actor, course, limit),
    maxAge: adminMaxAge,
    fetch: () async {
      Query<Map<String, dynamic>> q = db.collection('audit');
      if (campus != null) q = q.where('campus', whereIn: [campus, 'all']);
      if (actor != null) q = q.where('actor.email', isEqualTo: actor);
      if (course != null) q = q.where('course', isEqualTo: course);
      final r = await q.orderBy('at', descending: true).limit(limit).get();
      return [for (final d in r.docs) AuditEntry.fromMap(d.data())];
    },
    encode: (l) => [for (final e in l) e.toMap()],
    decode: _decodeAudit,
  );

  static String _auditKey(String? campus, String? actor, String? course, int n) =>
      'audit|${campus ?? '*'}|${actor ?? '*'}|${course ?? '*'}|$n';

  static List<AuditEntry> _decodeAudit(Object? o) => [
    for (final m in o as List) AuditEntry.fromMap((m as Map).cast()),
  ];

  /// The saved [audit], read synchronously; null when none is saved.
  List<AuditEntry>? peekAudit({
    String? campus,
    String? actor,
    String? course,
    int limit = 50,
  }) => peekCache(_auditKey(campus, actor, course, limit), _decodeAudit);

  // ---- Grants --------------------------------------------------------------

  /// Reads the grant terms, or [defaultTerms] when unset.
  Future<GrantTerms> terms() => cacheFirst<GrantTerms>(
    key: 'terms',
    maxAge: adminMaxAge,
    fetch: () async {
      final m = (await db.collection('config').doc('grantTerms').get()).data();
      return m == null ? defaultTerms : _decodeTerms(m);
    },
    encode: _termsMap,
    decode: _decodeTerms,
  );

  static GrantTerms _decodeTerms(Object? o) {
    final m = o as Map;
    return (
      crDays: m['crDays'] as int,
      presidentDays: m['presidentDays'] as int,
      adminDays: m['adminDays'] as int,
    );
  }

  /// The saved [terms], read synchronously; null when none is saved.
  GrantTerms? peekTerms() => peekCache('terms', _decodeTerms);

  /// Writes the grant terms [t] with an audit entry.
  Future<void> saveTerms(GrantTerms t) async {
    final b = db.batch();
    final before = await terms();
    final id = logInto(
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
    await forget('terms');
    await forget('audit|');
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
  /// entry, in one batch. [also] adds to that batch: Appoint as CR closes
  /// the course's volunteer offers in it (§16.3 fix 16).
  Future<void> _writeGrant(
    Grant g,
    String summary, {
    Grant? before,
    void Function(WriteBatch b)? also,
  }) async {
    final staff = await _staff(g.email);
    final b = db.batch();
    _grantInto(b, g, staff, summary, before: before);
    also?.call(b);
    await b.commit();
    await forget('roster|');
    await forget('audit|');
  }

  void _grantInto(
    WriteBatch b,
    Grant g,
    StaffEntry staff,
    String summary, {
    Grant? before,
  }) {
    final id = logInto(
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
        if (g.secretary) 'secretary': true,
        'grantedBy': {'email': me, 'name': myName},
        'grantedAt': FieldValue.serverTimestamp(),
      });
    } else {
      b.update(ref, {
        ...data,
        if (g.programme != null) 'programme': g.programme,
      });
    }
    _staffInto(b, staff, g);
  }

  void _staffInto(WriteBatch b, StaffEntry staff, Grant g) {
    final s = staff.after(g);
    b.set(db.collection('staff').doc(g.email), {
      ...s,
      if (s['expiresAt'] case final DateTime e)
        'expiresAt': Timestamp.fromDate(e),
    });
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
    bool secretary = false,
    List<String> closeOffers = const [],
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
      secretary: secretary,
    );
    final what = switch (role) {
      GrantRole.admin => 'admin',
      GrantRole.dept when secretary =>
        'secretary of ${branchCode(scope, programme)}',
      GrantRole.dept => 'president of ${branchCode(scope, programme)}',
      GrantRole.course => 'CR for $scope',
    };
    final data = existing.data();
    await _writeGrant(
      g,
      '${data == null ? 'Appointed' : 'Renewed'} $name $what',
      before: data == null ? null : Grant.fromMap(data),
      also: (b) {
        for (final o in closeOffers) {
          b.update(db.collection('volunteers').doc(o), {
            'open': false,
            'closedBy': {'email': me, 'name': myName},
          });
        }
      },
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

  // ---- Succession (§13.4) ---------------------------------------------------

  /// How long both presidents hold the department.
  static const overlap = Duration(days: 20);

  /// The outgoing expiry: never later than the one already held, so a
  /// handover cannot extend a term. [clockSlack] short, for clock drift.
  static DateTime outgoingExpiry(Grant mine, DateTime now) {
    final end = now.add(overlap - clockSlack);
    return end.isBefore(mine.expiresAt) ? end : mine.expiresAt;
  }

  /// Why [email] cannot succeed [mine], or null when they can.
  static String? successorProblem(Grant mine, String email) {
    final a = email.trim().toLowerCase();
    if (mine.handedTo != null) {
      return 'A handover to ${mine.handedTo} is already running.';
    }
    if (!isStudentAddress(a)) return 'Enter a BITS student address.';
    if (a == mine.email) return 'That is you.';
    if (campusOfAddress(a) != mine.campus) {
      return 'A successor must be on ${campusName(mine.campus)}.';
    }
    return null;
  }

  /// Hands [mine] (a presidency) to [email]: their grant starts now, mine
  /// ends at [outgoingExpiry]. Both grants, both staff entries and both
  /// audit entries in one batch. False when nobody by that address has
  /// signed in.
  ///
  /// [secretary] names the next secretary too: their grant ends with the new
  /// president's, and the outgoing secretary's with mine.
  Future<bool> handOver(
    Grant mine,
    String email, {
    String? secretary,
    DateTime? now,
  }) async {
    final address = email.trim().toLowerCase();
    final problem = successorProblem(mine, address);
    if (problem != null) throw StateError(problem);
    final sec = secretary?.trim().toLowerCase();
    if (sec != null) {
      if (successorProblem(mine, sec) case final p?) throw StateError(p);
      if (sec == address) {
        throw StateError('The next secretary cannot be the next president.');
      }
    }
    final name = await personName(address);
    if (name == null) return false;
    final secName = sec == null ? null : await personName(sec);
    if (sec != null && secName == null) return false;
    final at = now ?? DateTime.now();
    final t = await terms();
    final next = Grant(
      role: GrantRole.dept,
      email: address,
      name: name,
      campus: mine.campus,
      scope: mine.scope,
      programme: mine.programme,
      active: true,
      expiresAt: at.add(Duration(days: t.presidentDays)),
    );
    final ends = outgoingExpiry(mine, at);
    final shortened = Grant(
      role: mine.role,
      email: mine.email,
      name: mine.name,
      campus: mine.campus,
      scope: mine.scope,
      programme: mine.programme,
      active: true,
      expiresAt: ends,
    );
    final theirs = await _staff(address);
    final ours = await _staff(mine.email);
    final b = db.batch();
    _grantInto(b, next, theirs, 'Handed ${mine.scope} to $name');
    final id = logInto(
      b,
      path: 'grants/${mine.id}',
      summary: 'Handing over ${mine.scope} to $name; access ends ${_day(ends)}',
      campus: mine.campus,
      before: _grantSummary(mine),
      after: _grantSummary(shortened),
    );
    b.update(db.collection('grants').doc(mine.id), {
      'expiresAt': Timestamp.fromDate(ends),
      'handedTo': address,
      'expiresBefore': Timestamp.fromDate(mine.expiresAt),
      'auditId': id,
    });
    _staffInto(b, ours, shortened);
    await _relist(b, shortened);
    if (sec != null) {
      for (final old in await _secretaries(mine)) {
        if (!old.expiresAt.isAfter(ends)) continue;
        _grantInto(
          b,
          old.copyWith(expiresAt: ends),
          await _staff(old.email),
          'Secretary term of ${old.name} ends with the handover',
          before: old,
        );
      }
      _grantInto(
        b,
        Grant(
          role: GrantRole.dept,
          email: sec,
          name: secName!,
          campus: mine.campus,
          scope: mine.scope,
          programme: mine.programme,
          active: true,
          expiresAt: next.expiresAt,
          secretary: true,
        ),
        await _staff(sec),
        'Appointed $secName secretary of ${mine.scopeLabel}',
      );
    }
    await b.commit();
    await forget('roster|');
    await forget('audit|');
    return true;
  }

  /// Live secretaries of [mine]'s department.
  Future<List<Grant>> _secretaries(Grant mine) async {
    final q =
        await db
            .collection('grants')
            .where('role', isEqualTo: 'dept')
            .where('campus', isEqualTo: mine.campus)
            .where('scope', isEqualTo: mine.scope)
            .where('secretary', isEqualTo: true)
            .where('active', isEqualTo: true)
            .get();
    return [for (final d in q.docs) Grant.fromMap(d.data())];
  }

  /// Cancels a running handover: the successor's grant is revoked and mine
  /// gets its old expiry back.
  Future<void> cancelHandover(Grant mine) async {
    final to = mine.handedTo!;
    final before = mine.expiresBefore!;
    final d =
        await db
            .collection('grants')
            .doc(grantId(GrantRole.dept, mine.campus, mine.scope, to))
            .get();
    final next = Grant.fromMap(d.data()!);
    final revoked = Grant(
      role: next.role,
      email: next.email,
      name: next.name,
      campus: next.campus,
      scope: next.scope,
      programme: next.programme,
      active: false,
      expiresAt: next.expiresAt,
    );
    final restored = Grant(
      role: mine.role,
      email: mine.email,
      name: mine.name,
      campus: mine.campus,
      scope: mine.scope,
      programme: mine.programme,
      active: true,
      expiresAt: before,
    );
    final theirs = await _staff(to);
    final ours = await _staff(mine.email);
    final b = db.batch();
    _grantInto(
      b,
      revoked,
      theirs,
      'Cancelled the handover of ${mine.scope} to ${next.name}',
      before: next,
    );
    final id = logInto(
      b,
      path: 'grants/${mine.id}',
      summary: 'Kept ${mine.scope}; the handover was cancelled',
      campus: mine.campus,
      before: _grantSummary(mine),
      after: _grantSummary(restored),
    );
    b.update(db.collection('grants').doc(mine.id), {
      'expiresAt': Timestamp.fromDate(before),
      'handedTo': FieldValue.delete(),
      'expiresBefore': FieldValue.delete(),
      'auditId': id,
    });
    _staffInto(b, ours, restored);
    await _relist(b, restored);
    // ponytail: told apart by expiry — the new secretary ends with the new
    // president, the outgoing one with my shortened term.
    for (final g in await _secretaries(mine)) {
      if (g.expiresAt == next.expiresAt) {
        _grantInto(
          b,
          g.copyWith(active: false),
          await _staff(g.email),
          'Cancelled ${g.name} as secretary with the handover',
          before: g,
        );
      } else if (g.expiresAt == mine.expiresAt) {
        _grantInto(
          b,
          g.copyWith(expiresAt: before),
          await _staff(g.email),
          'Restored ${g.name}\'s secretary term',
          before: g,
        );
      }
    }
    await b.commit();
    await forget('roster|');
    await forget('audit|');
  }

  /// Keeps the directory's copy of [g]'s expiry in step, so Representatives
  /// shows the handover (§13.5).
  Future<void> _relist(WriteBatch b, Grant g) async {
    final ref = db.collection('directory').doc(g.email);
    final m = (await ref.get()).data();
    if (m == null) return;
    final next = {
      ...m,
      'roles': [
        for (final r in m['roles'] as List? ?? const [])
          if (r is Map && r['role'] == g.role.key && r['scope'] == g.scope)
            {...r, 'until': Timestamp.fromDate(g.expiresAt)}
          else
            r,
      ],
      'updatedAt': FieldValue.serverTimestamp(),
    };
    b.set(ref, next);
    await putRepCopy(b, m['campus'] as String? ?? g.campus, g.email, next);
  }

  /// Puts [entry] as [email]'s whole listing in `repIndex/{campus}`. Not
  /// `set(merge)`, which keeps fields the entry dropped (the rules want an
  /// exact copy), nor `mergeFields`, which FlutterFire web splits at the
  /// dots in an email.
  Future<void> putRepCopy(
    WriteBatch b,
    String campus,
    String email,
    Map<String, dynamic> entry,
  ) async {
    final ref = db.collection('repIndex').doc(campus);
    var exists = true;
    try {
      exists = (await ref.get()).exists;
    } on FirebaseException {
      // Unreadable (another campus): it exists if anyone is listed there.
    }
    if (exists) {
      b.update(ref, {
        'k': email,
        FieldPath(['p', email]): entry,
      });
    } else {
      b.set(ref, {
        'k': email,
        'p': {email: entry},
      });
    }
  }

  static String _day(DateTime d) => '${d.day}/${d.month}/${d.year}';

  /// Every grant the reader may see: all of them for owners and admins,
  /// [campus] plus the every-campus ones for a president.
  Future<List<Grant>> roster({String? campus}) => cacheFirst<List<Grant>>(
    key: 'roster|${campus ?? '*'}',
    maxAge: adminMaxAge,
    fetch: () async {
      Query<Map<String, dynamic>> q = db.collection('grants');
      if (campus != null) q = q.where('campus', whereIn: [campus, 'all']);
      final r = await q.get();
      return [for (final d in r.docs) Grant.fromMap(d.data())];
    },
    encode: (l) => [for (final g in l) g.toMap()],
    decode: _decodeRoster,
  );

  static List<Grant> _decodeRoster(Object? o) => [
    for (final m in o as List) Grant.fromMap((m as Map).cast()),
  ];

  /// The saved [roster], read synchronously; null when none is saved.
  List<Grant>? peekRoster({String? campus}) =>
      peekCache('roster|${campus ?? '*'}', _decodeRoster);

  // ---- Owners --------------------------------------------------------------

  /// Reads every `owners/` document.
  Future<List<Map<String, dynamic>>> owners() =>
      cacheFirst<List<Map<String, dynamic>>>(
        key: 'owners',
        maxAge: adminMaxAge,
        fetch: () async {
          final r = await db.collection('owners').get();
          return [for (final d in r.docs) d.data()];
        },
        encode: (l) => [for (final m in l) AuditEntry._safe(m)],
        decode: _decodeOwners,
      );

  static List<Map<String, dynamic>> _decodeOwners(Object? o) => [
    for (final m in o as List) Map<String, dynamic>.from(m as Map),
  ];

  /// The saved [owners], read synchronously; null when none is saved.
  List<Map<String, dynamic>>? peekOwners() => peekCache('owners', _decodeOwners);

  /// Adds [email] as an owner, with an audit entry.
  Future<void> addOwner(String email, String name) async {
    final address = email.trim().toLowerCase();
    final b = db.batch();
    final id = logInto(
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
    await forget('owners');
    await forget('audit|');
  }

  /// Never for oneself; the rules refuse that too.
  Future<void> setOwnerActive(String email, bool active) async {
    if (email == me && !active) {
      throw StateError('An owner cannot remove themselves.');
    }
    final b = db.batch();
    final id = logInto(
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
    await forget('owners');
    await forget('audit|');
  }

  // ---- Public contact ------------------------------------------------------

  /// The public contact. Students get it from their campus head (no read of
  /// its own) or a 7-day cache; [fresh] reads it live, as its editor does.
  /// Budget: ~0 reads/user/day.
  Future<PublicContact?> publicContact({bool fresh = false}) async {
    Map<String, dynamic>? m;
    if (!fresh) {
      final campus = campusOfAddress(me);
      final head = campus == null ? null : await headFor(campus, db: db);
      m = head?.contact?.cast<String, dynamic>();
      m ??= await cacheFirst<Map<String, dynamic>?>(
        key: 'contact|public',
        maxAge: publicContactMaxAge,
        fetch:
            () async =>
                (await Perf.time(
                  'roles.publicContact',
                  () => db.collection('config').doc('public').get(),
                )).data(),
        encode:
            (v) =>
                v == null
                    ? null
                    : {
                      for (final e in v.entries)
                        if (e.key.startsWith('contact')) e.key: e.value,
                    },
        decode: (v) => (v as Map?)?.cast<String, dynamic>(),
      );
    } else {
      m = (await db.collection('config').doc('public').get()).data();
    }
    if (m == null) return null;
    return (
      name: m['contactName'] as String? ?? '',
      method: m['contactMethod'] as String? ?? 'whatsapp',
      target: m['contactTarget'] as String? ?? '',
      enabled: m['contactEnabled'] as bool? ?? false,
    );
  }

  /// Who last changed the public contact, with their role from the audit
  /// entry the save wrote; null when it was never set. Read live (T8.8).
  Future<({String name, String? role, DateTime? at})?>
  publicContactChange() async {
    final m = (await db.collection('config').doc('public').get()).data();
    final by = m?['updatedBy'] as Map?;
    if (m == null || by == null) return null;
    String? role;
    if (m['auditId'] case final String id) {
      final e = (await db.collection('audit').doc(id).get()).data();
      role = (e?['actor'] as Map?)?['role'] as String?;
    }
    return (
      name: by['name'] as String? ?? '',
      role: role,
      at: (m['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// One grant document, read fresh (a handover in progress lives only on
  /// it); null when absent.
  Future<Grant?> grant(String id) async {
    final m = (await db.collection('grants').doc(id).get()).data();
    return m == null ? null : Grant.fromMap(m);
  }

  /// Writes the public contact [c] to `config/public` with an audit entry.
  Future<void> savePublicContact(PublicContact c) async {
    final b = db.batch();
    final id = logInto(
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
    setOnAllHeads(b, db, {
      'contact': {
        'contactName': c.name,
        'contactMethod': c.method,
        'contactTarget': c.target,
        'contactEnabled': c.enabled,
      },
    });
    await b.commit();
    await forget('contact|');
    await forget('head|');
    await forget('audit|');
  }
}
