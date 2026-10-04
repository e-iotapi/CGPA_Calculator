import 'dart:io';

import 'package:cgpa_calculator/core/env/app_env.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults to prod, with test paths compiled out', () {
    expect(appEnv, AppEnv.prod);
    expect(isTestEnv, isFalse);
  });

  test('the ?as= sign-in is only ever called behind isTestEnv (BUG-38)', () {
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.contains('core/env/test_')) continue;
      for (final l in f.readAsLinesSync().where(
        (l) => l.contains('testSignIn('),
      )) {
        expect(l, contains('isTestEnv'), reason: f.path);
      }
    }
  });
}
