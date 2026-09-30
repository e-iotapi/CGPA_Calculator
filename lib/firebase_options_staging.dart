// The pointer-staging web app, from `firebase apps:sdkconfig WEB
// 1:8768962364:web:339acd421cd0b1d990a839 --project pointer-staging`
// (PERF_TEST_PLAN.md T1/T5). Same API as lib/firebase_options.dart.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Firebase options for the staging project.
class StagingFirebaseOptions {
  /// The options for this platform; throws off the web.
  static FirebaseOptions get currentPlatform {
    if (!kIsWeb) {
      throw UnsupportedError('Staging only targets web (PERF_TEST_PLAN.md T1).');
    }
    return web;
  }

  /// The staging web app's options.
  static const FirebaseOptions web =FirebaseOptions(
    apiKey: 'AIzaSyD5aVnFDmzOQKjnuumyArZxFornqqrKHww',
    appId: '1:8768962364:web:339acd421cd0b1d990a839',
    messagingSenderId: '8768962364',
    projectId: 'pointer-staging',
    authDomain: 'pointer-staging.firebaseapp.com',
    storageBucket: 'pointer-staging.firebasestorage.app',
  );
}
