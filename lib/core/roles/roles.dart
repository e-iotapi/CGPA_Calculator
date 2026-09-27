/// Grants, the staff index and the addresses rules check (ARCHITECTURE.md
/// §4). The same functions as firestore.rules, so the screens and the rules
/// agree on who is a student and which department a course is in.
library;

import 'package:cgpa_calculator/core/roles/capabilities.dart';

final _student = RegExp(
  r'^[fhp][0-9]{4}[0-9]+@(goa|hyderabad|pilani|dubai)\.bits-pilani\.ac\.in$',
);
final _bits = RegExp(
  r'^[^@]+@(goa|pilani|dubai|hyderabad)\.bits-pilani\.ac\.in$',
);

/// A BITS student address; faculty and alumni addresses are not.
bool isStudentAddress(String email) => _student.hasMatch(email.toLowerCase());

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
/// electronics is one department, FIN sits under ECON.
String deptOf(String courseId) {
  final p = courseId.trim().split(' ').first.toUpperCase();
  if (const {'EEE', 'ECE', 'INSTR', 'ECOM'}.contains(p)) return 'ELEC';
  return p == 'FIN' ? 'ECON' : p;
}

const campusNames = {
  'goa': 'Goa',
  'hyderabad': 'Hyderabad',
  'pilani': 'Pilani',
  'dubai': 'Dubai',
  'all': 'Every campus',
};

String campusName(String key) => campusNames[key] ?? key;

enum GrantRole {
  admin('admin', 'Admin', 'ADMIN'),
  dept('dept', 'Department president', 'PRESIDENT'),
  course('course', 'Course manager', 'CR');

  const GrantRole(this.key, this.label, this.tag);
  final String key, label, tag;

  static GrantRole of(String key) => values.firstWhere((r) => r.key == key);

  Role get role => switch (this) {
    admin => Role.admin,
    dept => Role.president,
    course => Role.cr,
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
  });

  final GrantRole role;
  final String email, name, campus, scope;

  /// Dept grants only: the programme appointed for ("A3").
  final String? programme;
  final bool active;
  final DateTime expiresAt;
  final String grantedByEmail, grantedByName;
  final DateTime? grantedAt;

  /// A president's handover in progress (§13.4): the successor's address,
  /// and the expiry this grant had before, which a cancel restores.
  final String? handedTo;
  final DateTime? expiresBefore;

  String get id => grantId(role, campus, scope, email);

  bool liveAt(DateTime now) => active && now.isBefore(expiresAt);

  /// "ELEC · A3", "CS F301", "Every campus".
  String get scopeLabel => switch (role) {
    GrantRole.admin => 'Every campus',
    GrantRole.dept => programme == null ? scope : '$scope · $programme',
    GrantRole.course => scope,
  };

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
  );
}

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

  final String email, name, campus;
  final bool owner, admin;
  final List<String> presidentOf, courses;
  final DateTime? expiresAt;

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
  });

  static const none = MyRoles(email: '');

  final String email;
  final bool owner;

  /// Live grants only.
  final List<Grant> grants;

  bool get admin => grants.any((g) => g.role == GrantRole.admin);
  bool get privileged => owner || grants.isNotEmpty;
  bool get reachesAdmin => owner || admin;

  Iterable<Grant> get presidencies =>
      grants.where((g) => g.role == GrantRole.dept);
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

String departmentName(String key) => departments[key]?.name ?? key;

/// The department a programme belongs to: ELEC for A3.
String? departmentOfProgramme(String code) =>
    departments.entries
        .where((e) => e.value.programmes.contains(code))
        .firstOrNull
        ?.key;
