import 'package:cgpa_calculator/core/env/app_env.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults to prod, with test paths compiled out', () {
    expect(appEnv, AppEnv.prod);
    expect(isTestEnv, isFalse);
  });
}
