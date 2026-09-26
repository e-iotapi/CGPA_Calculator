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

/// Running as the installed app rather than in a browser tab.
bool isStandalone() => impl.isStandalone();

enum InstallDevice { ios, android, desktop }

enum InstallBrowser { safari, chrome, edge, firefox, samsung, opera, other }

/// Which home-screen steps apply: the device, and the browser on it.
typedef InstallTarget = ({InstallDevice device, InstallBrowser browser});

InstallTarget installTarget() =>
    parseInstallTarget(impl.userAgent(), touch: impl.hasTouch());

/// Reads [ua]. [touch] tells an iPad, which reports itself as a Mac, from a
/// Mac.
InstallTarget parseInstallTarget(String ua, {bool touch = false}) {
  ua = ua.toLowerCase();
  bool has(String s) => ua.contains(s);
  if (has('iphone') ||
      has('ipad') ||
      has('ipod') ||
      (has('macintosh') && touch)) {
    // Every iOS browser is WebKit; the UA names the app on top.
    final browser =
        has('crios')
            ? InstallBrowser.chrome
            : has('edgios')
            ? InstallBrowser.edge
            : has('fxios')
            ? InstallBrowser.firefox
            : has('safari') && !has('gsa/')
            ? InstallBrowser.safari
            : InstallBrowser.other;
    return (device: InstallDevice.ios, browser: browser);
  }
  final device = has('android') ? InstallDevice.android : InstallDevice.desktop;
  final browser =
      has('samsungbrowser')
          ? InstallBrowser.samsung
          : has('edg')
          ? InstallBrowser.edge
          : has('firefox')
          ? InstallBrowser.firefox
          : has('opr/') || has('opera')
          ? InstallBrowser.opera
          : has('chrome') || has('chromium')
          ? InstallBrowser.chrome
          : has('safari')
          ? InstallBrowser.safari
          : InstallBrowser.other;
  return (device: device, browser: browser);
}

/// Opens the browser's own install prompt. False when it has none to offer
/// (Safari, Firefox, or a prompt already used or dismissed).
bool promptInstall() => impl.promptInstall();
