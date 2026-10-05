import 'package:cgpa_calculator/core/diag/sign_in_log.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ua =
      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/128 Mobile';

  test('a Firebase failure keeps its code and message, never an address', () {
    final e = signInEntry(
      'failed',
      'popup',
      FirebaseAuthException(
        code: 'popup-closed-by-user',
        message: 'Closed for f20260001@goa.bits-pilani.ac.in.',
      ),
      attempt: 2,
      ms: 9000,
      ua: ua,
    );
    expect(e['code'], 'popup-closed-by-user');
    expect(e['message'], 'Closed for <email>');
    expect((e['device'], e['browser'], e['attempt']), ('android', 'chrome', 2));
  });

  test('a refusal keeps only its kind: its text names the account', () {
    final e = signInEntry(
      'failed',
      'refused-false',
      'Sign in with your BITS email. x@gmail.com is not…',
      attempt: 1,
      ms: 4000,
      ua: ua,
    );
    expect((e['code'], e['message']), ('refused', ''));
  });
}
