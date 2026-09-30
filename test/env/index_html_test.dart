import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// firebase_core_web's `supportedFirebaseJsSdkVersion`, read from its source:
/// the package is web-only, so a VM test can't import it.
String firebaseSdkVersion() {
  final config =
      jsonDecode(File('.dart_tool/package_config.json').readAsStringSync())
          as Map;
  final pkg = (config['packages'] as List).cast<Map>().firstWhere(
    (p) => p['name'] == 'firebase_core_web',
  );
  final root = Uri.parse('${pkg['rootUri']}/').resolve('lib/src/');
  final dir =
      root.isAbsolute
          ? root
          : Directory('.dart_tool').absolute.uri.resolveUri(root);
  final src =
      File.fromUri(dir.resolve('firebase_sdk_version.dart')).readAsStringSync();
  return RegExp(
    r"supportedFirebaseJsSdkVersion = '([\d.]+)'",
  ).firstMatch(src)!.group(1)!;
}

// web/index.html preloads the Firebase JS SDK that FlutterFire imports at
// startup. A preload of another version is a second, wasted download, so a
// firebase_core_web upgrade must update the links too.
void main() {
  test('index.html preloads the Firebase SDK version FlutterFire loads', () {
    final html = File('web/index.html').readAsStringSync();
    final versions =
        RegExp(
          r'gstatic\.com/firebasejs/([\d.]+)/',
        ).allMatches(html).map((m) => m.group(1)).toSet();
    expect(versions, {firebaseSdkVersion()});
  });

  test('analytics loads after the first frame, not with the page', () {
    final html = File('web/index.html').readAsStringSync();
    expect(
      html,
      isNot(contains('<script async src="https://www.googletagmanager')),
    );
    expect(html, contains("addEventListener('flutter-first-frame', loadGtag)"));
  });

  // web/flutter_bootstrap.js replaces Flutter's default loader call; it must
  // still register the service worker the default one did.
  test('the bootstrap template keeps the service worker', () {
    final js = File('web/flutter_bootstrap.js').readAsStringSync();
    expect(js, contains('{{flutter_js}}'));
    expect(js, contains('{{flutter_build_config}}'));
    expect(js, contains('serviceWorkerVersion: {{flutter_service_worker_version}}'));
  });
}
