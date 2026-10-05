import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

void downloadBytes(List<int> bytes, String filename, String mime) {
  final blob = web.Blob(
    [Uint8List.fromList(bytes).toJS].toJS,
    web.BlobPropertyBag(type: mime),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = url;
  anchor.download = filename;
  anchor.style.display = 'none';
  web.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}

Future<String?> pickTextFile(String accept) {
  final input = web.document.createElement('input') as web.HTMLInputElement;
  input.type = 'file';
  input.accept = accept;
  final done = Completer<String?>();

  input.onchange =
      ((web.Event _) {
        final files = input.files;
        if (files == null || files.length == 0) {
          if (!done.isCompleted) done.complete(null);
          return;
        }
        final reader = web.FileReader();
        reader.onload =
            ((web.Event _) {
              if (done.isCompleted) return;
              final r = reader.result;
              done.complete(r.isA<JSString>() ? (r as JSString).toDart : null);
            }).toJS;
        reader.onerror =
            ((web.Event _) {
              if (!done.isCompleted) {
                done.completeError('Could not read the file');
              }
            }).toJS;
        reader.readAsText(files.item(0)!);
      }).toJS;

  // Fires when the picker is dismissed without choosing anything.
  input.addEventListener(
    'cancel',
    ((web.Event _) {
      if (!done.isCompleted) done.complete(null);
    }).toJS,
  );

  input.click();
  return done.future;
}

void reloadPage() => web.window.location.reload();

String userAgent() => web.window.navigator.userAgent;

void sendBeacon(String url, String body) {
  web.window.navigator.sendBeacon(url, body.toJS);
}

const _redirectKey = 'pointer.signInRedirect';

void markSignInRedirect() {
  try {
    web.window.sessionStorage.setItem(_redirectKey, '1');
  } on Object {
    // Storage blocked: the result still lands; only its error is unseen.
  }
}

bool takeSignInRedirect() {
  try {
    final s = web.window.sessionStorage;
    final was = s.getItem(_redirectKey) != null;
    s.removeItem(_redirectKey);
    return was;
  } on Object {
    return false;
  }
}

bool isStandalone() {
  // iOS has its own flag, and only iOS has it; trust it there over the media
  // query, which some WebKit builds answer for a Safari tab too.
  final ios =
      (web.window.navigator as JSObject)
          .getProperty<JSAny?>('standalone'.toJS)
          ?.dartify();
  if (ios is bool) return ios;
  return web.window.matchMedia('(display-mode: standalone)').matches;
}

bool hasTouch() => web.window.navigator.maxTouchPoints > 0;

/// Logical CPU cores, when the browser exposes it.
int? hardwareConcurrency() {
  final v =
      (web.window.navigator as JSObject)
          .getProperty<JSAny?>('hardwareConcurrency'.toJS)
          ?.dartify();
  // The WebAssembly build gets JS numbers back as doubles: `as int?` threw
  // there and blanked the app after its first frame.
  return v is num ? v.toInt() : null;
}

/// Approximate device RAM in GB (Chrome only; null elsewhere).
double? deviceMemory() {
  final v =
      (web.window.navigator as JSObject)
          .getProperty<JSAny?>('deviceMemory'.toJS)
          ?.dartify();
  return v is num ? v.toDouble() : null;
}

/// Calls window.promptInstall from index.html, which holds the deferred
/// beforeinstallprompt event.
bool promptInstall() {
  try {
    return globalContext.callMethod<JSAny?>('promptInstall'.toJS)?.dartify() ==
        true;
  } catch (_) {
    return false;
  }
}

/// Calls window.pickPdfText from index.html.
Future<String?> pickPdfText() async {
  final result =
      await globalContext
          .callMethod<JSPromise<JSString?>>('pickPdfText'.toJS)
          .toDart;
  return result?.toDart;
}

void onPageHidden(void Function() run) {
  web.document.addEventListener(
    'visibilitychange',
    ((web.Event _) {
      if (web.document.visibilityState == 'hidden') run();
    }).toJS,
  );
  web.window.addEventListener('pagehide', ((web.Event _) => run()).toJS);
}

void onDomPointerDown(void Function(double x, double y) run) {
  web.window.addEventListener(
    'pointerdown',
    ((web.PointerEvent e) => run(e.clientX.toDouble(), e.clientY.toDouble()))
        .toJS,
    web.AddEventListenerOptions(capture: true, passive: true),
  );
}

// IndexedDB runs requests in order, so Firebase's later open waits for this.
void forgetSavedSignIn() =>
    web.window.indexedDB.deleteDatabase('firebaseLocalStorageDb');

void openUrl(String url) {
  final app = RegExp(r'^(mailto|tel|sms):').hasMatch(url);
  web.window.open(
    url,
    app ? '_top' : '_blank',
    app ? '' : 'noopener,noreferrer',
  );
}
