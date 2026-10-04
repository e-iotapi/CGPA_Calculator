/// Which backend the app talks to: real production, the staging project, or
/// local emulators (PERF_TEST_PLAN.md Phase T1). Test-only paths gated on
/// [isTestEnv] must be `const`-foldable so dart2js tree-shakes them out of
/// the production build.
library;

import 'package:cgpa_calculator/core/platform/browser.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// The backend a build talks to.
enum AppEnv { prod, staging, emulator }

const _envName = String.fromEnvironment('POINTER_ENV', defaultValue: 'prod');

/// The environment chosen with `--dart-define=POINTER_ENV`; production by
/// default.
const appEnv =
    _envName == 'staging'
        ? AppEnv.staging
        : _envName == 'emulator'
        ? AppEnv.emulator
        : AppEnv.prod;

/// A LAN IP lets a phone on the same network reach a laptop's emulators.
const emulatorHost = String.fromEnvironment(
  'POINTER_EMULATOR_HOST',
  defaultValue: 'localhost',
);

/// Whether the build is anything but production.
const bool isTestEnv = appEnv != AppEnv.prod;

/// Call before `Firebase.initializeApp`. On the web that call also starts
/// Auth, which checks a saved user with the real servers; the emulator can
/// then no longer be set (FlutterFire swallows the error) and every later
/// request goes to production. The test sign-in runs on every load anyway.
void beforeFirebase() {
  if (appEnv == AppEnv.emulator) forgetSavedSignIn();
}

/// Points Firebase at the emulators when running under [AppEnv.emulator],
/// and sets the Firestore transport. Call once, right after
/// `Firebase.initializeApp`.
void configureEnv() {
  // iOS Safari (every iPhone browser) can hold a streamed Firestore reply
  // until its ~30 s timeout: 3 of ~10 iPhone cold loads spent 31 s in
  // sync.pull (TM-4). Long polling answers each request as it completes.
  if (kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    FirebaseFirestore.instance.settings = const Settings(
      webExperimentalForceLongPolling: true,
    );
  }
  if (appEnv == AppEnv.emulator) {
    FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8085);
  }
}
