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

/// Reloads the page.
void reloadPage() => impl.reloadPage();

/// Whether the page is cross-origin isolated (COOP + COEP headers), which
/// runs the wasm renderer on its own thread but cuts Google's sign-in popup
/// off from the page.
bool crossOriginIsolated() => impl.crossOriginIsolated();

/// Replaces the page with [path], resolved against the app's base URL
/// (`''` is the app itself).
void replacePage(String path) => impl.replacePage(path);

/// Runs [run] when the page is hidden or closed (tab switch, app switch,
/// closing the tab): the last moment to flush pending writes.
void onPageHidden(void Function() run) => impl.onPageHidden(run);

/// Runs [run] with every pointer-down's page position, seen by the page
/// before Flutter: with the semantics tree on, a tap on a button reaches
/// Flutter as a tap action with no position.
void onDomPointerDown(void Function(double x, double y) run) =>
    impl.onDomPointerDown(run);

/// Opens [url] in a new tab; mail, phone and SMS links in place, where the
/// browser hands them to the right app.
void openUrl(String url) => impl.openUrl(url);

/// Deletes Firebase Auth's saved sign-in on this origin.
void forgetSavedSignIn() => impl.forgetSavedSignIn();

/// The browser's user agent, for bug reports.
String userAgent() => impl.userAgent();

/// Running as the installed app rather than in a browser tab.
bool isStandalone() => impl.isStandalone();

/// The kind of device that installs the app to its home screen.
enum InstallDevice { ios, android, desktop }

/// The browser the person installs from.
enum InstallBrowser { safari, chrome, edge, firefox, samsung, opera, other }

/// Which home-screen steps apply: the device, and the browser on it.
typedef InstallTarget = ({InstallDevice device, InstallBrowser browser});

/// The device and browser this page runs in.
InstallTarget installTarget() =>
    parseInstallTarget(impl.userAgent(), touch: impl.hasTouch());

/// Logical CPU cores, when the browser exposes it (UI_OPT O0.2).
int? hardwareConcurrency() => impl.hardwareConcurrency();

/// Approximate device RAM in GB, Chrome only (UI_OPT O0.2).
double? deviceMemory() => impl.deviceMemory();

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

/// Opens a PDF picker and returns the chosen file's text with positions (see
/// window.pickPdfText in index.html), or null if nothing was picked. Throws
/// a String when the file cannot be read.
Future<String?> pickPdfText() => impl.pickPdfText();
