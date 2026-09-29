import 'package:cgpa_calculator/core/models/programmes.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';

/// One row of every department list: a department, or one branch of a
/// department that has several (ELEC's A3, A8, AA, AC), since each has its
/// own presidents. [programme] is null for a one-branch department.
typedef Branch = ({String dept, String? programme});

/// Every branch, in [order] (department keys; all of [departments] by
/// default), each multi-branch department spread out. The one list Open as,
/// Merge duplicates and Appoint all show.
List<Branch> deptBranches([Iterable<String>? order]) => [
  for (final k in order ?? departments.keys)
    if (departments[k] case final d?)
      for (final prog in d.programmes.length > 1 ? d.programmes : const [null])
        (dept: k, programme: prog),
];

/// A branch goes by its own name ("Electrical & Electronics"); a
/// one-branch department by the department's.
String branchName(Branch b) =>
    b.programme == null
        ? departmentName(b.dept)
        : programmeName(b.programme!).replaceFirst('B.E. ', '');

/// Branch codes only, never the department's course code: "A3", or
/// "A7" for Computer Science.
String branchCodes(Branch b) =>
    b.programme ?? (departments[b.dept]?.programmes.join(' · ') ?? b.dept);

/// Whether [b] matches a search, by name, code or department.
bool branchMatches(Branch b, String query) {
  final q = query.trim().toLowerCase();
  return q.isEmpty ||
      b.dept.toLowerCase().contains(q) ||
      departmentName(b.dept).toLowerCase().contains(q) ||
      branchName(b).toLowerCase().contains(q) ||
      branchCodes(b).toLowerCase().contains(q);
}

/// Where every department picker gets the departments a campus runs (a UI
/// seam, UI_REBUILD_HANDOFF.md §3). The logic branch points
/// [departmentSource] at its campus-wise list; until then every campus runs
/// every department in [departments].
abstract interface class DepartmentSource {
  /// Department keys on [campus], in the order to show them.
  Future<List<String>> at(String campus);
}

class AllDepartments implements DepartmentSource {
  const AllDepartments();

  @override
  Future<List<String>> at(String campus) async => departments.keys.toList();
}

/// The departments a campus runs, from the programme list (no Firestore).
class CampusDepartments implements DepartmentSource {
  const CampusDepartments();

  @override
  Future<List<String>> at(String campus) async => departmentsAt(campus);
}

DepartmentSource departmentSource = const CampusDepartments();

/// The branches on [campus] (every department when it is not known yet,
/// e.g. before an address is typed), in [departmentSource]'s order.
/// A branch not run on [campus] (AC on Hyderabad) is left out.
Future<List<Branch>> campusBranches(String? campus) async {
  if (campus == null) return deptBranches();
  final here = {for (final p in programmesAt(Campus.named(campus))) p.code};
  return [
    for (final b in deptBranches(await departmentSource.at(campus)))
      if (b.programme == null || here.contains(b.programme)) b,
  ];
}
