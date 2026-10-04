import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Grant g(GrantRole role) => Grant(
    role: role,
    email: 'f20220001@goa.bits-pilani.ac.in',
    name: 'A',
    campus: 'goa',
    scope: role == GrantRole.course ? 'EEE F111' : 'EEE',
    active: true,
    expiresAt: DateTime(2100),
  );
  const email = 'f20220001@goa.bits-pilani.ac.in';

  test('a CR alone is not staff, so is still offered to contribute', () {
    final cr = MyRoles(email: email, grants: [g(GrantRole.course)]);
    expect(cr.privileged, isTrue);
    expect(cr.staff, isFalse);
    expect(MyRoles(email: email, grants: [g(GrantRole.dept)]).staff, isTrue);
    expect(const MyRoles(email: email).staff, isFalse);
  });
}
