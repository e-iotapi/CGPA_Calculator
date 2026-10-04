/// Grants, the staff index and the addresses rules check (ARCHITECTURE.md
/// §4). The same functions as firestore.rules, so the screens and the rules
/// agree on who is a student and which department a course is in.
library;

import 'package:cgpa_calculator/core/models/programmes.dart';
import 'package:cgpa_calculator/core/roles/capabilities.dart';
import 'package:cgpa_calculator/core/roles/claim_store.dart' show CourseClaim;

final _student = RegExp(
  r'^[fhp][0-9]{4}[0-9]+@(goa|hyderabad|pilani|dubai)\.bits-pilani\.ac\.in$',
);
final _bits = RegExp(
  r'^[^@]+@(goa|pilani|dubai|hyderabad)\.bits-pilani\.ac\.in$',
);

/// A BITS student address; faculty and alumni addresses are not.
bool isStudentAddress(String email) => _student.hasMatch(email.toLowerCase());

/// Whether [email] is any BITS campus address, student or not.
bool isBitsAddress(String email) => _bits.hasMatch(email.toLowerCase());

/// "goa" from a campus address; null otherwise.
String? campusOfAddress(String email) =>
    _bits.firstMatch(email.toLowerCase())?.group(1);

/// The batch year from a student address: 2023 from f20230802@…
int? batchOfAddress(String email) =>
    isStudentAddress(email)
        ? int.parse(email.toLowerCase().substring(1, 5))
        : null;

/// A president's scope is a department key, derived from the course code:
/// electronics is one department, FIN sits under ECON. A prefix no department
/// owns belongs to [genDept], the electives department (B2); mirrors the
/// rules' `deptOf`.
String deptOf(String courseId) {
  final p = courseId.trim().split(' ').first.toUpperCase();
  if (const {'EEE', 'ECE', 'INSTR', 'ECOM'}.contains(p)) return 'ELEC';
  if (p == 'FIN') return 'ECON';
  return departments.containsKey(p) ? p : genDept;
}

/// The management-only electives department (shown as "Electives"). Never a
/// programme, a branch or a choice in setup.
const genDept = 'GEN';

/// Who manages [courseId]: its department, or the department that claimed a
/// GEN course (B2). [claims] maps course id to its claim; a
/// claim on a non-GEN course is ignored.
String managingDept(String courseId, Map<String, CourseClaim> claims) {
  final d = deptOf(courseId);
  return d == genDept ? claims[courseId]?.dept ?? d : d;
}

/// Display names by campus key, plus `all` for grants that span campuses.
const campusNames = {
  'goa': 'Goa',
  'hyderabad': 'Hyderabad',
  'pilani': 'Pilani',
  'dubai': 'Dubai',
  'all': 'Every campus',
};

/// The display name for campus [key], or [key] itself when unknown.
String campusName(String key) => campusNames[key] ?? key;

/// The kind of grant a maintainer holds.
enum GrantRole {
  admin('admin', 'Admin', 'ADMIN'),
  dept('dept', 'Department president', 'PRESIDENT'),
  course('course', 'Course manager', 'CR'),

  /// B7: campus-wide, no expiry (the sentinel 2100-01-01), until revoked.
  contributor('contributor', 'Contributor', 'CONTRIBUTOR');

  const GrantRole(this.key, this.label, this.tag);

  /// The stored key, the display label and the short badge tag.
  final String key, label, tag;

  /// Looks up the role stored under [key]; throws if there is none.
  static GrantRole of(String key) => values.firstWhere((r) => r.key == key);

  /// The capability-table [Role] this grant role maps to.
  Role get role => switch (this) {
    admin => Role.admin,
    dept => Role.president,
    course => Role.cr,
    contributor => Role.student,
  };
}

/// `grants/{role}|{campus}|{scope}|{email}`.
class Grant {
  const Grant({
    required this.role,
    required this.email,
    required this.name,
    required this.campus,
    required this.scope,
    required this.active,
    required this.expiresAt,
    this.programme,
    this.grantedByEmail = '',
    this.grantedByName = '',
    this.grantedAt,
    this.handedTo,
    this.expiresBefore,
    this.secretary = false,
    this.dept,
  });

  /// Contributor grants only: the department whose president approved it.
  final String? dept;

  /// The kind of grant.
  final GrantRole role;

  /// Dept grants only: a secretary holds every president right but handing
  /// over and appointing secretaries.
  final bool secretary;

  /// The holder's address and name, the campus key, and the scope (a
  /// department key or a course id).
  final String email, name, campus, scope;

  /// Dept grants only: the programme appointed for ("A3").
  final String? programme;

  /// Whether the grant has not been revoked.
  final bool active;

  /// When the grant lapses.
  final DateTime expiresAt;

  /// Who issued the grant.
  final String grantedByEmail, grantedByName;

  /// When the grant was issued, if recorded.
  final DateTime? grantedAt;

  /// A president's handover in progress (§13.4): the successor's address,
  /// and the expiry this grant had before, which a cancel restores.
  final String? handedTo;

  /// The expiry to restore if the handover is cancelled.
  final DateTime? expiresBefore;

  /// The document id, see [grantId].
  String get id => grantId(role, campus, scope, email);

  /// Copies this grant with a new [active] flag or [expiresAt].
  Grant copyWith({bool? active, DateTime? expiresAt}) => Grant(
    role: role,
    email: email,
    name: name,
    campus: campus,
    scope: scope,
    programme: programme,
    active: active ?? this.active,
    expiresAt: expiresAt ?? this.expiresAt,
    secretary: secretary,
    dept: dept,
  );

  /// Whether the grant is active and unexpired at [now].
  bool liveAt(DateTime now) => active && now.isBefore(expiresAt);

  /// "A3", "CS F301", "Every campus": a president goes by their branch
  /// code, a CR by their course code.
  String get scopeLabel => switch (role) {
    GrantRole.admin => 'Every campus',
    GrantRole.dept => branchCode(scope, programme),
    GrantRole.course => scope,
    GrantRole.contributor => 'Every department',
  };

  /// Reads a grant document's data.
  static Grant fromMap(Map<String, dynamic> m) => Grant(
    role: GrantRole.of(m['role'] as String),
    email: m['email'] as String,
    name: m['name'] as String? ?? '',
    campus: m['campus'] as String,
    scope: m['scope'] as String,
    programme: m['programme'] as String?,
    active: m['active'] as bool? ?? false,
    expiresAt: asDate(m['expiresAt']) ?? DateTime(1970),
    grantedByEmail: (m['grantedBy'] as Map?)?['email'] as String? ?? '',
    grantedByName: (m['grantedBy'] as Map?)?['name'] as String? ?? '',
    grantedAt: asDate(m['grantedAt']),
    handedTo: m['handedTo'] as String?,
    expiresBefore: asDate(m['expiresBefore']),
    secretary: m['secretary'] as bool? ?? false,
    dept: m['dept'] as String?,
  );

  /// JSON-safe, for `cacheFirst`: [fromMap] reads it back (dates as millis).
  Map<String, dynamic> toMap() => {
    'role': role.key,
    'email': email,
    'name': name,
    'campus': campus,
    'scope': scope,
    'programme': programme,
    'active': active,
    'expiresAt': expiresAt.millisecondsSinceEpoch,
    'grantedBy': {'email': grantedByEmail, 'name': grantedByName},
    'grantedAt': grantedAt?.millisecondsSinceEpoch,
    'handedTo': handedTo,
    'expiresBefore': expiresBefore?.millisecondsSinceEpoch,
    'secretary': secretary,
    'dept': dept,
  };
}

/// The grant document id: `role|campus|scope|email`.
String grantId(GrantRole role, String campus, String scope, String email) =>
    '${role.key}|$campus|$scope|$email';

/// A Firestore Timestamp, a DateTime or epoch milliseconds.
DateTime? asDate(Object? v) => switch (v) {
  DateTime d => d,
  int ms => DateTime.fromMillisecondsSinceEpoch(ms),
  null => null,
  _ => (v as dynamic).toDate() as DateTime,
};

/// `staff/{email}`: one index document per maintainer, kept in step with
/// every grant change.
class StaffEntry {
  const StaffEntry({
    required this.email,
    this.name = '',
    this.campus = '',
    this.owner = false,
    this.admin = false,
    this.presidentOf = const [],
    this.courses = const [],
    this.expiresAt,
  });

  /// The maintainer's address, name and home campus key.
  final String email, name, campus;

  /// Whether the person is the owner, or holds a live admin grant.
  final bool owner, admin;

  /// Department keys presided over, and course ids managed.
  final List<String> presidentOf, courses;

  /// The latest expiry across live grants.
  final DateTime? expiresAt;

  /// Reads a staff document's data.
  static StaffEntry fromMap(Map<String, dynamic> m) => StaffEntry(
    email: m['email'] as String,
    name: m['name'] as String? ?? '',
    campus: m['campus'] as String? ?? '',
    owner: m['owner'] as bool? ?? false,
    admin: m['admin'] as bool? ?? false,
    presidentOf: [for (final d in m['presidentOf'] as List? ?? const []) '$d'],
    courses: [for (final c in m['courses'] as List? ?? const []) '$c'],
    expiresAt: asDate(m['expiresAt']),
  );

  /// This entry once [g] is written: its field moved by exactly its scope.
  Map<String, dynamic> after(Grant g) {
    List<String> move(List<String> l) =>
        g.active
            ? {...l, g.scope}.toList()
            : [
              for (final x in l)
                if (x != g.scope) x,
            ];
    final latest = [
      if (expiresAt != null) expiresAt!,
      if (g.active) g.expiresAt,
    ]..sort();
    return {
      'email': email,
      'name': name.isEmpty ? g.name : name,
      'campus': campus.isEmpty ? g.campus : campus,
      'owner': owner,
      'admin': g.role == GrantRole.admin ? g.active : admin,
      'presidentOf': g.role == GrantRole.dept ? move(presidentOf) : presidentOf,
      'courses': g.role == GrantRole.course ? move(courses) : courses,
      'expiresAt': latest.isEmpty ? g.expiresAt : latest.last,
      'lastGrant': g.id,
    };
  }
}

/// What the signed-in person holds: owner status and every live grant.
class MyRoles {
  const MyRoles({
    required this.email,
    this.owner = false,
    this.grants = const [],
    this.contributor = false,
  });

  /// Nobody signed in, or a plain student.
  static const none = MyRoles(email: '');

  /// The signed-in address.
  final String email;

  /// Whether the person is the owner.
  final bool owner;

  /// Live grants only (contributor grants are not among them, see
  /// [contributor]).
  final List<Grant> grants;

  /// Whether a live contributor grant is held (B7).
  final bool contributor;

  /// Whether a live admin grant is held.
  bool get admin => grants.any((g) => g.role == GrantRole.admin);

  /// Whether the person is the owner or holds any live grant.
  bool get privileged => owner || grants.isNotEmpty;

  /// Owner, admin or president: publishes links at once and is never offered
  /// to contribute. A CR alone is not staff.
  bool get staff => owner || grants.any((g) => g.role != GrantRole.course);

  /// Whether the person may open the admin screens.
  bool get reachesAdmin => owner || admin;

  /// The live department grants.
  Iterable<Grant> get presidencies =>
      grants.where((g) => g.role == GrantRole.dept);

  /// The live course grants.
  Iterable<Grant> get courses =>
      grants.where((g) => g.role == GrantRole.course);

  /// The strongest role, for the capability table.
  Role get top =>
      owner
          ? Role.owner
          : admin
          ? Role.admin
          : presidencies.isNotEmpty
          ? Role.president
          : courses.isNotEmpty
          ? Role.cr
          : Role.student;

  /// Whether this person may do [action] on [campus]/[scope] ([scope] is a
  /// department key or a course id), through any role they hold.
  bool may(Capability action, {String? campus, String? scope}) {
    if (owner && can(Role.owner, action)) return true;
    if (admin && can(Role.admin, action)) return true;
    for (final g in presidencies) {
      final inScope =
          (campus == null || campus == g.campus) &&
          (scope == null || scope == g.scope || deptOf(scope) == g.scope);
      if (can(Role.president, action, inScope: inScope)) return true;
    }
    for (final g in courses) {
      final inScope =
          (campus == null || campus == g.campus) &&
          (scope == null || scope == g.scope);
      if (can(Role.cr, action, inScope: inScope)) return true;
    }
    return false;
  }
}

/// Department keys, their names and the programmes a president is appointed
/// for (§4). The key is the course prefix, save ELEC and ECON.
const departments = <String, ({String name, List<String> programmes})>{
  'BIO': (name: 'Biological Sciences', programmes: ['B1']),
  'BIOT': (name: 'Biotechnology', programmes: ['A9']),
  'CE': (name: 'Civil', programmes: ['A2']),
  'CHE': (name: 'Chemical', programmes: ['A1']),
  'CHEM': (name: 'Chemistry', programmes: ['B2']),
  'CS': (name: 'Computer Science', programmes: ['A7']),
  'ECON': (name: 'Economics', programmes: ['B3']),
  'ELEC': (name: 'Electronics', programmes: ['A3', 'A8', 'AA', 'AC']),
  'ENVS': (name: 'Environmental and Sustainability', programmes: ['AJ']),
  'MAC': (name: 'Mathematics and Computing', programmes: ['AD']),
  'MATH': (name: 'Mathematics', programmes: ['B4']),
  'ME': (name: 'Mechanical', programmes: ['A4']),
  'MF': (name: 'Manufacturing', programmes: ['AB']),
  'PHA': (name: 'Pharmacy', programmes: ['A5']),
  'PHY': (name: 'Physics', programmes: ['B5']),
  'SNS': (name: 'Semiconductor and Nanoscience', programmes: ['B7']),
};

/// The display name for department [key], or [key] itself when unknown.
String departmentName(String key) =>
    key == genDept ? 'Electives' : departments[key]?.name ?? key;

/// Department keys a campus runs, in [departments] order: those with a
/// programme offered there (`programmesAt`, DISCIPLINES_GOA_HYD.md).
List<String> departmentsAt(String campus) {
  final here = {for (final p in programmesAt(Campus.named(campus))) p.code};
  return [
    for (final e in departments.entries)
      if (e.value.programmes.any(here.contains)) e.key,
  ];
}

/// What a president of [dept] goes by: the branch they were appointed for
/// ("A3"), else the department's one branch ("A7" for CS), else [dept].
String branchCode(String dept, [String? programme]) =>
    programme ??
    (dept == genDept ? 'Electives' : null) ??
    switch (departments[dept]?.programmes) {
      [final only] => only,
      _ => dept,
    };

/// The department a programme belongs to: ELEC for A3.
String? departmentOfProgramme(String code) =>
    departments.entries
        .where((e) => e.value.programmes.contains(code))
        .firstOrNull
        ?.key;
