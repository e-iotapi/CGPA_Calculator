import 'package:cgpa_calculator/app/router.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_seed.dart';

void main() {
  test('a student page drops the role; a role page keeps it', () {
    addTearDown(() => workingAs.value = null);
    workingAs.value = presGrant;
    for (final at in [
      '/admin',
      '/admin/x',
      '/maintain/goa/A3',
      '/maintain/goa/A3/professors/add',
      '/roles',
    ]) {
      leaveRoleOutside(at);
      expect(workingAs.value, presGrant, reason: at);
    }
    for (final at in [
      '/',
      '/reviews',
      '/settings',
      '/administrator',
      '/resources',
      '/resources/courses',
    ]) {
      workingAs.value = presGrant;
      leaveRoleOutside(at);
      expect(workingAs.value, isNull, reason: at);
    }
  });
}
