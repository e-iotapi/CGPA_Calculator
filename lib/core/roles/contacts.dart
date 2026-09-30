/// Contact details (ARCHITECTURE.md §13.5, §16.3 fix 8) and CR volunteers
/// (fix 16). Two documents, two audiences: `staffContacts/{email}` is for
/// other privileged roles; `directory/{email}` is what a president or CR
/// chose to show the students of their campus.
library;

import 'package:cgpa_calculator/core/cache/cache_first.dart';
import 'package:cgpa_calculator/core/perf/perf.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/timings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// A phone or WhatsApp number as typed: digits, spaces, +, - and brackets.
final phonePattern = RegExp(r'^[+0-9 ()-]{7,20}$');

/// One role as the directory lists it, with the expiry it had when written.
typedef ListedRole =
    ({GrantRole role, String scope, DateTime until, bool secretary});

/// `directory/{email}`.
class DirectoryEntry {
  const DirectoryEntry({
    required this.email,
    required this.name,
    required this.campus,
    required this.roles,
    this.shownEmail,
    this.whatsapp,
    this.phone,
  });

  /// The person's address, name and campus key.
  final String email, name, campus;

  /// The roles listed for the person.
  final List<ListedRole> roles;

  /// The contact channels the person chose to show students.
  final String? shownEmail, whatsapp, phone;

  /// Roles still live at [now]; a lapsed one is never listed.
  Iterable<ListedRole> liveAt(DateTime now) =>
      roles.where((r) => now.isBefore(r.until));

  /// "Email, WhatsApp".
  String get summary => [
    if (shownEmail != null) 'Email',
    if (whatsapp != null) 'WhatsApp',
    if (phone != null) 'Phone',
  ].join(', ');

  /// Reads the directory document of [email].
  static DirectoryEntry fromMap(String email, Map<String, dynamic> m) =>
      DirectoryEntry(
        email: email,
        name: m['name'] as String? ?? '',
        campus: m['campus'] as String? ?? '',
        roles: [
          for (final r in m['roles'] as List? ?? const [])
            if (r is Map)
              (
                role: GrantRole.of(r['role'] as String),
                scope: r['scope'] as String,
                until: asDate(r['until']) ?? DateTime(1970),
                secretary: r['secretary'] == true,
              ),
        ],
        shownEmail: m['email'] as String?,
        whatsapp: m['whatsapp'] as String?,
        phone: m['phone'] as String?,
      );
}

/// The grants a president or CR lists in the directory: live ones, with
/// their expiry.
List<ListedRole> listedRoles(MyRoles r) => [
  for (final g in r.grants)
    if (g.role != GrantRole.admin)
      (
        role: g.role,
        scope: g.scope,
        until: g.expiresAt,
        secretary: g.secretary,
      ),
];

/// The departments whose officers a student sees: those of the courses
/// they take, and of their own degree programmes (codes like "A7", "B3").
List<String> myDepartments(
  Iterable<String> courses,
  Iterable<String> degrees,
) =>
    {
        // deptOf("BITS F412") is "BITS", the common-course prefix, not a
        // department — drop anything that isn't a real one (BUG-34).
        for (final c in courses)
          if (departments.containsKey(deptOf(c))) deptOf(c),
        for (final d in degrees)
          if (departmentOfProgramme(d) case final x?) x,
      }.toList()
      ..sort();

/// Whether RepProfile must be served first (fix 8): a privileged person
/// without staff contacts, or a president or CR whose directory entry lacks
/// a role they now hold (or holds it with another expiry, after a renewal).
bool needsProfile(
  MyRoles r, {
  required bool hasStaffContact,
  DirectoryEntry? directory,
}) {
  if (!r.privileged) return false;
  if (!hasStaffContact) return true;
  final want = listedRoles(r);
  if (want.isEmpty) return false;
  if (directory == null) return true;
  return want.any(
    (w) =>
        !directory.roles.any(
          (d) =>
              d.role == w.role &&
              d.scope == w.scope &&
              d.until.millisecondsSinceEpoch == w.until.millisecondsSinceEpoch,
        ),
  );
}

/// `volunteers/{campus}|{courseId}|{email}`.
class Volunteer {
  const Volunteer({
    required this.email,
    required this.name,
    required this.campus,
    required this.courseId,
    required this.term,
    required this.open,
    this.createdAt,
  });

  /// The volunteer's address and name, and the offer's campus, course and
  /// term.
  final String email, name, campus, courseId, term;

  /// Whether the offer still stands.
  final bool open;

  /// When the offer was made.
  final DateTime? createdAt;

  /// The document id, see [volunteerId].
  String get id => volunteerId(campus, courseId, email);

  /// Reads a volunteer document's data.
  static Volunteer fromMap(Map<String, dynamic> m) => Volunteer(
    email: m['email'] as String,
    name: m['name'] as String? ?? '',
    campus: m['campus'] as String,
    courseId: m['courseId'] as String,
    term: m['term'] as String? ?? '',
    open: m['open'] as bool? ?? false,
    createdAt: asDate(m['createdAt']),
  );

  /// JSON-safe, for `cacheFirst` (P1): `createdAt` as millis, not a Timestamp.
  Map<String, dynamic> toMap() => {
    'email': email,
    'name': name,
    'campus': campus,
    'courseId': courseId,
    'term': term,
    'open': open,
    'createdAt': createdAt?.millisecondsSinceEpoch,
  };
}

/// The volunteer document id: `campus|courseId|email`.
String volunteerId(String campus, String courseId, String email) =>
    '$campus|$courseId|$email';

/// Reads and writes contact details and volunteer offers as [RoleStore.me].
class ContactStore {
  ContactStore(this.roles);

  /// The store whose identity the reads and writes use.
  final RoleStore roles;

  /// The Firestore instance of [roles].
  FirebaseFirestore get db => roles.db;

  DocumentReference<Map<String, dynamic>> _staffContact(String email) =>
      db.collection('staffContacts').doc(email);
  DocumentReference<Map<String, dynamic>> _directory(String email) =>
      db.collection('directory').doc(email);

  /// The signed-in person's staff contact: name and phone.
  Future<({String name, String phone})?> myStaffContact() async {
    final m = (await _staffContact(roles.me).get()).data();
    return m == null
        ? null
        : (
          name: m['name'] as String? ?? '',
          phone: m['phone'] as String? ?? '',
        );
  }

  /// Reads the signed-in person's directory entry, or `null` if none.
  Future<DirectoryEntry?> myDirectory() async {
    final m = (await _directory(roles.me).get()).data();
    return m == null ? null : DirectoryEntry.fromMap(roles.me, m);
  }

  /// Whether RepProfile must come first for [r].
  Future<bool> profileDue(MyRoles r) async {
    if (!r.privileged) return false;
    return needsProfile(
      r,
      hasStaffContact: await myStaffContact() != null,
      directory: listedRoles(r).isEmpty ? null : await myDirectory(),
    );
  }

  /// RepProfile's Save: both documents in one batch. The directory entry is
  /// written only for a president or CR, and needs one field shown.
  Future<void> saveProfile(
    MyRoles r, {
    required String name,
    required String phone,
    bool showEmail = false,
    String? whatsapp,
    bool showPhone = false,
  }) async {
    final b =
        db.batch()..set(_staffContact(roles.me), {
          'name': name.trim(),
          'phone': phone.trim(),
          'email': roles.me,
          'updatedAt': FieldValue.serverTimestamp(),
        });
    final listed = listedRoles(r);
    if (listed.isNotEmpty) {
      final wa = whatsapp?.trim();
      final entry = {
        'name': name.trim(),
        'campus': campusOfAddress(roles.me),
        'roles': [
          for (final x in listed)
            {
              'role': x.role.key,
              'scope': x.scope,
              'until': Timestamp.fromDate(x.until),
              if (x.secretary) 'secretary': true,
            },
        ],
        if (showEmail) 'email': roles.me,
        if (wa != null && wa.isNotEmpty) 'whatsapp': wa,
        if (showPhone) 'phone': phone.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      final campus = campusOfAddress(roles.me) ?? '';
      b.set(_directory(roles.me), entry);
      await roles.putRepCopy(b, campus, roles.me, entry);
    }
    await b.commit();
    await sharedCacheBox?.delete('reps|${campusOfAddress(roles.me) ?? ''}');
  }

  /// Every staff phone number, by address: the roster shows them to other
  /// privileged roles (fix 8). Empty for anyone the rules keep out.
  Future<Map<String, String>> staffPhones() async {
    try {
      final q = await db.collection('staffContacts').get();
      return {
        for (final d in q.docs)
          if (d.data()['phone'] case final String p) d.id: p,
      };
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return const {};
      rethrow;
    }
  }

  DocumentReference<Map<String, dynamic>> _repIndex(String campus) =>
      db.collection('repIndex').doc(campus);

  /// Every president and CR listed on [campus], from one doc
  /// (`repIndex/{campus}`), cached 6 h; [fresh] reads it live.
  // ponytail: one doc per campus caps near 3,000 listed people.
  Future<List<DirectoryEntry>> directory(
    String campus, {
    bool fresh = false,
  }) async {
    Future<Map<String, dynamic>> fetch() async {
      final d = await Perf.time(
        'contacts.directory',
        () => _repIndex(campus).get(),
      );
      return {
        for (final e in ((d.data()?['p'] as Map?) ?? const {}).entries)
          '${e.key}': _jsonSafe(e.value),
      };
    }

    final m =
        fresh
            ? await fetch()
            : await cacheFirst<Map<String, dynamic>>(
              key: 'reps|$campus',
              maxAge: repsMaxAge,
              fetch: fetch,
              encode: (m) => m,
              decode: (o) => Map<String, dynamic>.from(o as Map),
            );
    return [
      for (final e in m.entries)
        DirectoryEntry.fromMap(e.key, Map<String, dynamic>.from(e.value)),
    ];
  }

  /// Timestamps as millis, so the entry caches as JSON.
  static Object? _jsonSafe(Object? v) => switch (v) {
    Timestamp t => t.millisecondsSinceEpoch,
    Map m => {for (final e in m.entries) '${e.key}': _jsonSafe(e.value)},
    List l => [for (final x in l) _jsonSafe(x)],
    _ => v,
  };

  // ---- Volunteers (fix 16) -------------------------------------------------

  DocumentReference<Map<String, dynamic>> _offer(String id) =>
      db.collection('volunteers').doc(id);

  // Budget: 1 read per course with no CR, per representatives_page.dart
  // visit, until P2b's helper (P0). 24 h cache (P2): `volunteer`/`withdraw`
  // invalidate their own campus.
  /// Reads the signed-in person's volunteer offer for [courseId] on
  /// [campus], or `null` if none.
  Future<Volunteer?> myOffer(String campus, String courseId) async {
    try {
      return await cacheFirst<Volunteer?>(
        key: 'offer|$campus|$courseId|${roles.me}',
        maxAge: offerMaxAge,
        fetch: () async {
          final m =
              (await Perf.time(
                'contacts.myOffer',
                () => _offer(volunteerId(campus, courseId, roles.me)).get(),
              )).data();
          return m == null ? null : Volunteer.fromMap(m);
        },
        encode: (v) => v?.toMap(),
        decode: (v) => v == null ? null : Volunteer.fromMap((v as Map).cast()),
      );
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return null;
      rethrow;
    }
  }

  /// A student offers to be CR for [courseId] this term.
  Future<void> volunteer(
    String campus,
    String courseId, {
    required String name,
    required String term,
  }) async {
    await _offer(volunteerId(campus, courseId, roles.me)).set({
      'name': name,
      'email': roles.me,
      'campus': campus,
      'courseId': courseId,
      'dept': deptOf(courseId),
      'term': term,
      'open': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await forget('offer|$campus|');
  }

  /// The student takes the offer back.
  Future<void> withdraw(Volunteer v) async {
    await _offer(v.id).update({'open': false});
    await forget('offer|${v.campus}|');
  }

  /// Open offers in [dept] on [campus] in [term], by course.
  Future<Map<String, List<Volunteer>>> offers(
    String campus,
    String dept, {
    required String term,
  }) async {
    final q =
        await db
            .collection('volunteers')
            .where('campus', isEqualTo: campus)
            .where('dept', isEqualTo: dept)
            .where('open', isEqualTo: true)
            .get();
    final out = <String, List<Volunteer>>{};
    for (final d in q.docs) {
      final v = Volunteer.fromMap(d.data());
      // Offers close when the term ends.
      if (v.term == term) (out[v.courseId] ??= []).add(v);
    }
    for (final l in out.values) {
      l.sort((a, b) => a.name.compareTo(b.name));
    }
    return out;
  }

  /// A president dismisses one offer.
  Future<void> dismiss(Volunteer v) => _offer(v.id).update({
    'open': false,
    'closedBy': {'email': roles.me, 'name': roles.myName},
  });
}
