/// Switches to a named test account via `?as=<key>` before the app reads
/// `authStateChanges()` (PERF_TEST_PLAN.md T1). Callers must guard this with
/// `isTestEnv`, which is `const false` in production, so dart2js drops the
/// whole call site (and this file) from the prod build.
library;

import 'package:cgpa_calculator/core/env/app_env.dart';
import 'package:cgpa_calculator/core/env/test_accounts.g.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/rendering.dart';

/// Signs in the test account chosen for the E2E run, for non-production
/// builds only.
Future<User?> testSignIn() async {
  // The E2E tests (T6) find widgets by role/text, which needs a semantics
  // tree; production never turns it on. Staging had it on every load, which
  // slowed scrolling, the theme switch and start (owner, 2026-10-04: prod
  // felt far smoother), so only the emulator build (the E2E run) has it by
  // default. `?semantics=1` turns it on, `?semantics=0` off.
  final semantics = Uri.base.queryParameters['semantics'];
  if (semantics == '1' || (semantics != '0' && appEnv == AppEnv.emulator)) {
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
