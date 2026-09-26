import 'dart:async';
import 'dart:js_interop';
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
