/// Switches to a named test account via `?as=<key>` before the app reads
/// `authStateChanges()` (PERF_TEST_PLAN.md T1). Callers must guard this with
/// `isTestEnv`, which is `const false` in production, so dart2js drops the
/// whole call site (and this file) from the prod build.
library;

import 'package:cgpa_calculator/core/env/test_accounts.g.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/rendering.dart';

/// Signs in the test account chosen for the E2E run, for non-production
/// builds only.
Future<User?> testSignIn() async {
  // The E2E tests (T6) find widgets by role/text, which needs a semantics
  // tree; production never turns this on. It costs frame time, so a
  // performance run can leave it off with `?semantics=0`.
  if (Uri.base.queryParameters['semantics'] != '0') {
    SemanticsBinding.instance.ensureSemantics();
  }
  final key = Uri.base.queryParameters['as'] ??
      const String.fromEnvironment('POINTER_TEST_AS');
  final auth = FirebaseAuth.instance;
  final email = testAccounts[key];
  if (email == null || auth.currentUser?.email == email) {
    return auth.currentUser;
  }
  if (auth.currentUser != null) await auth.signOut();
  const password = String.fromEnvironment(
    'POINTER_TEST_PASSWORD',
    defaultValue: 'pointer-test-only',
  );
  final credential = await auth.signInWithEmailAndPassword(
    email: email,
    password: password,
  );
  // Sync.init(uid) wipes local Hive data on a uid change, so the switch is
  // safe even mid-session.
  return credential.user;
}
