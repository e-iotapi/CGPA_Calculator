// Departments per campus (UI_REBUILD_HANDOFF.md §3.9): from the programme
// list, and branches not run on a campus are left out.
import 'package:cgpa_calculator/admin/dept_list.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('each campus runs the departments of its programmes', () {
    final goa = departmentsAt('goa'), hyd = departmentsAt('hyderabad');
    expect(goa, containsAll(['CS', 'ELEC', 'ECON', 'SNS']));
    expect(goa, isNot(contains('CE')));
    expect(goa, isNot(contains('PHA')));
    expect(hyd, containsAll(['CE', 'PHA', 'ELEC']));
    expect(goa, isNot(contains('BIOT')));
  });

  test('ELEC branches follow the campus', () async {
    final goa = await campusBranches('goa');
    final hyd = await campusBranches('hyderabad');
    String? ac(List<Branch> bs) =>
        bs.where((b) => b.programme == 'AC').firstOrNull?.programme;
    expect(ac(goa), 'AC');
    expect(ac(hyd), isNull);
    expect(hyd.where((b) => b.dept == 'ELEC'), hasLength(3));
  });
}
