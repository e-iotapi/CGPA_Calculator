import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The site-wide `frame-ancestors 'none'` once blocked Firebase's sign-in
/// helper, and no signed-out person could sign in on prod. Keep the
/// exemption.
void main() {
  test('the auth helper may be framed; everything else may not', () {
    final h = File('landing/_headers').readAsStringSync();
    expect(h, contains("Content-Security-Policy: frame-ancestors 'none'"));
    expect(
      RegExp(r'^/__/auth/\*\n  ! Content-Security-Policy$', multiLine: true)
          .hasMatch(h),
      isTrue,
    );
  });
}
