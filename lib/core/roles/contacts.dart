/// Contact details (ARCHITECTURE.md §13.5, §16.3 fix 8) and CR volunteers
/// (fix 16). Two documents, two audiences: `staffContacts/{email}` is for
/// other privileged roles; `directory/{email}` is what a president or CR
/// chose to show the students of their campus.
library;

import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// A phone or WhatsApp number as typed: digits, spaces, +, - and brackets.
final phonePattern = RegExp(r'^[+0-9 ()-]{7,20}$');

/// One role as the directory lists it, with the expiry it had when written.
typedef ListedRole = ({GrantRole role, String scope, DateTime until});

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

  final String email, name, campus;
  final List<ListedRole> roles;
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
      (role: g.role, scope: g.scope, until: g.expiresAt),
];

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

  final String email, name, campus, courseId, term;
  final bool open;
  final DateTime? createdAt;

  String get id => volunteerId(campus, courseId, email);

  static Volunteer fromMap(Map<String, dynamic> m) => Volunteer(
    email: m['email'] as String,
    name: m['name'] as String? ?? '',
    campus: m['campus'] as String,
    courseId: m['courseId'] as String,
    term: m['term'] as String? ?? '',
    open: m['open'] as bool? ?? false,
    createdAt: asDate(m['createdAt']),
  );
}

String volunteerId(String campus, String courseId, String email) =>
    '$campus|$courseId|$email';

/// Reads and writes contact details and volunteer offers as [roles.me].
class ContactStore {
  ContactStore(this.roles);

  final RoleStore roles;
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
      b.set(_directory(roles.me), {
        'name': name.trim(),
        'campus': campusOfAddress(roles.me),
        'roles': [
          for (final x in listed)
            {
              'role': x.role.key,
              'scope': x.scope,
              'until': Timestamp.fromDate(x.until),
            },
        ],
        if (showEmail) 'email': roles.me,
        if (wa != null && wa.isNotEmpty) 'whatsapp': wa,
        if (showPhone) 'phone': phone.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await b.commit();
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

  /// Every president and CR listed on [campus].
  Future<List<DirectoryEntry>> directory(String campus) async {
    final q =
        await db
            .collection('directory')
            .where('campus', isEqualTo: campus)
            .get();
    return [for (final d in q.docs) DirectoryEntry.fromMap(d.id, d.data())];
  }

  // ---- Volunteers (fix 16) -------------------------------------------------

  DocumentReference<Map<String, dynamic>> _offer(String id) =>
      db.collection('volunteers').doc(id);

  Future<Volunteer?> myOffer(String campus, String courseId) async {
    try {
      final m =
          (await _offer(volunteerId(campus, courseId, roles.me)).get()).data();
      return m == null ? null : Volunteer.fromMap(m);
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
  }) => _offer(volunteerId(campus, courseId, roles.me)).set({
    'name': name,
    'email': roles.me,
    'campus': campus,
    'courseId': courseId,
    'dept': deptOf(courseId),
    'term': term,
    'open': true,
    'createdAt': FieldValue.serverTimestamp(),
  });

  /// The student takes the offer back.
  Future<void> withdraw(Volunteer v) => _offer(v.id).update({'open': false});

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
