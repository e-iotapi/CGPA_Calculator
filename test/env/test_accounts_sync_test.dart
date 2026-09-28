import 'dart:convert';
import 'dart:io';

import 'package:cgpa_calculator/core/env/test_accounts.g.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('test_accounts.g.dart matches test_env/accounts.json', () {
    final config =
        jsonDecode(File('test_env/accounts.json').readAsStringSync())
            as Map<String, dynamic>;
    final accounts = config['accounts'] as List<dynamic>;
    final expected = {
      for (final a in accounts)
        (a as Map<String, dynamic>)['key'] as String: a['email'] as String,
    };
    expect(
      testAccounts,
      expected,
      reason:
          'Run `node tools/test_env/gen_accounts.mjs` after editing test_env/accounts.json.',
    );
    expect(testAccountPassword, config['password']);
  });
}
