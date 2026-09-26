import 'package:cgpa_calculator/core/platform/browser_stub.dart'
    if (dart.library.js_interop) 'package:cgpa_calculator/core/platform/browser_web.dart'
    as impl;

/// Browser-only actions, kept here so the rest of lib/ compiles and tests on
/// the VM.

/// Triggers a download of [bytes] as [filename].
void downloadBytes(List<int> bytes, String filename, String mime) =>
    impl.downloadBytes(bytes, filename, mime);

/// Opens a file picker and returns the chosen file's text, or null if the
/// user cancelled.
Future<String?> pickTextFile(String accept) => impl.pickTextFile(accept);

void reloadPage() => impl.reloadPage();

/// The browser's user agent, for bug reports.
String userAgent() => impl.userAgent();

/// Which home-screen steps apply to this browser.
enum InstallPlatform { ios, android, desktop }

/// Running as the installed app rather than in a browser tab.
bool isStandalone() => impl.isStandalone();

InstallPlatform installPlatform() => switch (impl.platformName()) {
  'ios' => InstallPlatform.ios,
  'android' => InstallPlatform.android,
  _ => InstallPlatform.desktop,
};

/// Opens the browser's own install prompt. False when it has none to offer
/// (Safari, Firefox, or a prompt already used or dismissed).
bool promptInstall() => impl.promptInstall();
