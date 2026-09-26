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
