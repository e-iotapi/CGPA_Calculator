import 'package:cgpa_calculator/core/platform/browser.dart';
import 'package:cgpa_calculator/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('phones and tablets sign in by redirect; computers by popup', () {
    expect(redirectsOn(InstallDevice.android), isTrue);
    expect(redirectsOn(InstallDevice.ios), isTrue);
    expect(redirectsOn(InstallDevice.desktop), isFalse);
  });
}
