import 'package:cgpa_calculator/core/cache/cache_first.dart';
import 'package:cgpa_calculator/core/heads/heads.dart';
import 'package:cgpa_calculator/core/heads/paths.dart';
import 'package:cgpa_calculator/core/live/live_heads.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/store_error.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Where a contributor request stands.
enum RequestStatus { pending, approved, declined, withdrawn }

/// `contributorRequests/<campus>|<dept>|<email>`.
class ContributorRequest {
  const ContributorRequest({
    required this.email,
    required this.name,
    required this.campus,
    required this.dept,
    required this.status,
    required this.createdAt,
    this.reason,
    this.decidedBy,
  });

  /// The applicant's address and name, their campus and department keys.
  final String email, name, campus, dept;

  /// Where the request stands.
  final RequestStatus status;

  /// When it was made (epoch ms).
  final int createdAt;

  /// The decline reason and who decided, when decided.
  final String? reason, decidedBy;

  /// The document id.
  String get id => '$campus|$dept|$email';

  /// JSON-safe, for the cache.
  Map<String, dynamic> toMap() => {
    'email': email,
    'name': name,
    'campus': campus,
    'dept': dept,
    'status': status.name,
    'createdAt': createdAt,
    'reason': reason,
    'decidedBy': decidedBy,
  };

  /// Reads a request document or [toMap].
  static ContributorRequest fromMap(Map m) => ContributorRequest(
    email: m['email'] as String,
    name: m['name'] as String? ?? '',
    campus: m['campus'] as String,
    dept: m['dept'] as String,
    status: RequestStatus.values.firstWhere(
      (s) => s.name == m['status'],
      orElse: () => RequestStatus.pending,
    ),
    createdAt: asDate(m['createdAt'])?.millisecondsSinceEpoch ?? 0,
    reason: m['reason'] as String?,
    decidedBy: m['decidedBy'] as String?,
  );
}

/// What the signed-in student is, as a contributor.
class MyContributor {
  const MyContributor({
    required this.isContributor,
    this.username,
    this.points = 0,
    this.request,
  });

  /// Whether a live contributor grant is held.
  final bool isContributor;

  /// The claimed username, if any, and the points earned.
  final String? username;
  final int points;

  /// The latest request, when it was loaded.
  final ContributorRequest? request;

  /// JSON-safe, for the cache.
  Map<String, dynamic> toMap() => {
    'c': isContributor,
    'u': username,
    'p': points,
  };

  /// Reads [toMap].
  static MyContributor fromMap(Object? o) {
    final m = o as Map;
    return MyContributor(
      isContributor: m['c'] as bool? ?? false,
      username: m['u'] as String?,
      points: (m['p'] as num?)?.toInt() ?? 0,
    );
  }
}

/// A contributor-store refusal ("exists": already pending or approved;
/// "badName": not a valid username).
class ContribError extends StoreError {
  const ContribError(super.code);
}

/// The username is already claimed on this campus.
class UsernameTaken extends StoreError {
  const UsernameTaken() : super('taken');
}

final _username = RegExp(r'^[a-z0-9_]{3,20}$');

/// Whether [s] (trimmed, lower-cased) is a valid username.
bool validUsername(String s) => _username.hasMatch(s.trim().toLowerCase());

/// The no-expiry sentinel stored on a contributor grant ("until revoked").
final contributorUntil = DateTime.utc(2100);

/// Contributor requests, grants and usernames (DATA_SYNC_PLAN 5.2).
class ContributorStore {
  ContributorStore(this.roles);

  /// The store whose identity and audit log the writes use.
  final RoleStore roles;

  FirebaseFirestore get _db => roles.db;

  DocumentReference<Map<String, dynamic>> _request(
    String campus,
    String dept,
    String email,
  ) => _db.collection('contributorRequests').doc('$campus|$dept|$email');

  static Object? _enc(ContributorRequest? r) => r?.toMap();
  static ContributorRequest? _dec(Object? o) =>
      o == null ? null : ContributorRequest.fromMap(o as Map);

  /// My request in [dept], or null.
  Future<ContributorRequest?> myRequest(String campus, String dept) async =>
      cacheFirst<ContributorRequest?>(
        key: 'cr|${roles.me}',
        maxAge: const Duration(minutes: 5),
        version: await markerOf(_db, campus, Paths.contribRequests(dept)),
        fetch: () async {
          final d = await _request(campus, dept, roles.me).get();
          return d.data() == null ? null : ContributorRequest.fromMap(d.data()!);
        },
        encode: _enc,
        decode: _dec,
      );

  /// The saved [myRequest], read synchronously.
  ContributorRequest? peekMyRequest(String email) =>
      peekCache<ContributorRequest?>('cr|$email', _dec);

  /// Applies for [dept] (the student's branch department). Throws
  /// `ContribError('exists')` while a request is pending or approved.
  Future<void> apply(String campus, String dept) async {
    final ref = _request(campus, dept, roles.me);
    final old = (await ref.get()).data()?['status'];
    if (old == 'pending' || old == 'approved') throw const ContribError('exists');
    final b = _db.batch();
    b.set(ref, {
      'name': roles.myName,
      'email': roles.me,
      'campus': campus,
      'dept': dept,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    bumpPath(b, _db, campus, Paths.contribRequests(dept));
    await b.commit();
    await _changed(dept);
  }

  /// Withdraws my pending request.
  Future<void> withdraw(ContributorRequest r) async {
    final b = _db.batch();
    b.update(_request(r.campus, r.dept, r.email), {'status': 'withdrawn'});
    bumpPath(b, _db, r.campus, Paths.contribRequests(r.dept));
    await b.commit();
    await _changed(r.dept);
  }

  /// Pending requests for [dept] (approvers only).
  Future<List<ContributorRequest>> requests(String campus, String dept) async =>
      cacheFirst<List<ContributorRequest>>(
        key: 'crq|$campus|$dept',
        maxAge: const Duration(minutes: 5),
        version: await markerOf(_db, campus, Paths.contribRequests(dept)),
        fetch: () async {
          final q =
              await _db
                  .collection('contributorRequests')
                  .where('campus', isEqualTo: campus)
                  .where('dept', isEqualTo: dept)
                  .where('status', isEqualTo: 'pending')
                  .get();
          return [for (final d in q.docs) ContributorRequest.fromMap(d.data())]
            ..sort((a, b) => a.createdAt - b.createdAt);
        },
        encode: (l) => [for (final r in l) r.toMap()],
        decode: _decodeAll,
      );

  static List<ContributorRequest> _decodeAll(Object? o) => [
    for (final m in o as List) ContributorRequest.fromMap(m as Map),
  ];

  /// The saved [requests], read synchronously.
  List<ContributorRequest>? peekRequests(String campus, String dept) =>
      peekCache('crq|$campus|$dept', _decodeAll);

  Future<void> _changed(String dept) async {
    LiveHeads.poke(Paths.contribRequests(dept));
    await forget('cr|');
    await forget('crq|');
  }

  /// Approves [r]: the request and the grant (campus-wide, until revoked),
  /// with their audit entries, in one batch.
  Future<void> approve(ContributorRequest r) async {
    final name = await roles.personName(r.email) ?? r.name;
    final b = _db.batch();
    final audit = roles.logInto(
      b,
      path: 'contributorRequests/${r.id}',
      summary: 'Approved $name as contributor',
      campus: r.campus,
    );
    b.update(_request(r.campus, r.dept, r.email), {
      'status': 'approved',
      'decidedBy': roles.me,
      'decidedAt': FieldValue.serverTimestamp(),
      'auditId': audit,
    });
    final id = grantId(GrantRole.contributor, r.campus, r.campus, r.email);
    final gAudit = roles.logInto(
      b,
      path: 'grants/$id',
      summary: 'Appointed $name contributor',
      campus: r.campus,
      after: {'active': true},
    );
    b.set(_db.collection('grants').doc(id), {
      'role': GrantRole.contributor.key,
      'email': r.email,
      'name': name,
      'campus': r.campus,
      'scope': r.campus,
      'dept': r.dept,
      'active': true,
      'expiresAt': Timestamp.fromDate(contributorUntil),
      'grantedBy': {'email': roles.me, 'name': roles.myName},
      'grantedAt': FieldValue.serverTimestamp(),
      'auditId': gAudit,
    });
    bumpPath(b, _db, r.campus, Paths.contribRequests(r.dept));
    bumpPath(b, _db, r.campus, Paths.grants);
    await b.commit();
    LiveHeads.poke(Paths.grants);
    await _changed(r.dept);
    await forget('roster|');
  }

  /// Declines [r], with an optional [reason] (200 characters at most).
  Future<void> decline(ContributorRequest r, {String? reason}) async {
    final b = _db.batch();
    final audit = roles.logInto(
      b,
      path: 'contributorRequests/${r.id}',
      summary: 'Declined ${r.name} as contributor',
      campus: r.campus,
    );
    b.update(_request(r.campus, r.dept, r.email), {
      'status': 'declined',
      'decidedBy': roles.me,
      'decidedAt': FieldValue.serverTimestamp(),
      'auditId': audit,
      if (reason != null && reason.trim().isNotEmpty)
        'reason': reason.trim().length > 200 ? reason.trim().substring(0, 200) : reason.trim(),
    });
    bumpPath(b, _db, r.campus, Paths.contribRequests(r.dept));
    await b.commit();
    await _changed(r.dept);
  }

  /// Revokes contributor grant [g]. (No staff entry: it would make the
  /// contributor `privileged()` in the rules.)
  Future<void> revoke(Grant g) async {
    final b = _db.batch();
    final audit = roles.logInto(
      b,
      path: 'grants/${g.id}',
      summary: 'Revoked ${g.name} as contributor',
      campus: g.campus,
      before: {'active': true},
      after: {'active': false},
    );
    b.update(_db.collection('grants').doc(g.id), {
      'active': false,
      'auditId': audit,
    });
    bumpPath(b, _db, g.campus, Paths.grants);
    await b.commit();
    LiveHeads.poke(Paths.grants);
    await forget('roster|');
    await forget('me-ct|');
  }

  /// Whether I hold a grant, my username and points.
  Future<MyContributor> me(String campus) => cacheFirst<MyContributor>(
    key: 'me-ct|${roles.me}',
    maxAge: const Duration(minutes: 10),
    fetch: () async {
      final g =
          (await _db
                  .collection('grants')
                  .doc(grantId(GrantRole.contributor, campus, campus, roles.me))
                  .get())
              .data();
      final c = (await _db.collection('contributors').doc(roles.me).get()).data();
      return MyContributor(
        isContributor: g != null && Grant.fromMap(g).liveAt(DateTime.now()),
        username: c?['username'] as String?,
        points: (c?['points'] as num?)?.toInt() ?? 0,
      );
    },
    encode: (m) => m.toMap(),
    decode: MyContributor.fromMap,
  );

  /// The saved [me], read synchronously.
  MyContributor? peekMe(String email) =>
      peekCache('me-ct|$email', MyContributor.fromMap);

  /// Claims [name] on [campus]. Throws `ContribError('badName')` or
  /// [UsernameTaken].
  Future<void> claimUsername(String campus, String name) async {
    final n = name.trim().toLowerCase();
    if (!validUsername(n)) throw const ContribError('badName');
    final taken = _db.collection('usernames').doc('$campus|$n');
    try {
      if ((await taken.get()).exists) throw const UsernameTaken();
    } on FirebaseException catch (e) {
      // A claimed name is unreadable to anyone but its owner and the staff.
      if (e.code == 'permission-denied') throw const UsernameTaken();
      rethrow;
    }
    final mine = _db.collection('contributors').doc(roles.me);
    final has = (await mine.get()).exists;
    final b = _db.batch();
    b.set(taken, {
      'email': roles.me,
      'claimedAt': FieldValue.serverTimestamp(),
    });
    if (has) {
      b.update(mine, {'username': n});
    } else {
      b.set(mine, {'username': n, 'campus': campus, 'points': 0});
    }
    try {
      await b.commit();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') throw const UsernameTaken();
      rethrow;
    }
    await forget('me-ct|');
  }
}
