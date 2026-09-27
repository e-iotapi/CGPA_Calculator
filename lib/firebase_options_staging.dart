// TODO(user): replace with the real output of
// `flutterfire configure --project=<staging-id> --platforms=web \
//   --out=lib/firebase_options_staging.dart`
// (PERF_TEST_PLAN.md T1/T5). This placeholder keeps the same API as
// lib/firebase_options.dart so app_env.dart compiles before that is run.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class StagingFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (!kIsWeb) {
      throw UnsupportedError('Staging only targets web (PERF_TEST_PLAN.md T1).');
    }
    return web;
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'TODO(user)',
    appId: 'TODO(user)',
    messagingSenderId: 'TODO(user)',
    projectId: 'pointer-staging',
    authDomain: 'TODO(user)',
    storageBucket: 'TODO(user)',
  );
}
