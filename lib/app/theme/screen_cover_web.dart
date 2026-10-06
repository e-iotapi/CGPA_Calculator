import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;

import 'package:cgpa_calculator/app/theme/screen_cover.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/scheduler.dart';
import 'package:web/web.dart' as web;

Future<ScreenCover?> takeCover() async {
  try {
    final canvases = web.document
        .querySelector('flt-glass-pane')
        ?.shadowRoot
        ?.querySelectorAll('canvas');
    if (canvases == null || canvases.length != 1) return null;
    final src = canvases.item(0)! as web.HTMLCanvasElement;
    // A WebGL canvas is clear once its frame is shown, so the copy is taken
    // in a browser frame callback queued after Flutter's: same frame, drawn.
    final copied = Completer<web.ImageBitmap>();
    SchedulerBinding.instance.scheduleForcedFrame();
    web.window.requestAnimationFrame(
      ((JSNumber _) {
        web.window
            .createImageBitmap(src)
            .toDart
            .then(copied.complete, onError: copied.completeError);
      }).toJS,
    );
    final bitmap = await copied.future;
    final r = src.getBoundingClientRect();
    final cover =
        web.document.createElement('canvas') as web.HTMLCanvasElement
          ..width = bitmap.width
          ..height = bitmap.height;
    cover.style
      ..position = 'fixed'
      ..left = '${r.left}px'
      ..top = '${r.top}px'
      ..width = '${r.width}px'
      ..height = '${r.height}px'
      ..pointerEvents = 'none'
      ..zIndex = '2147483647';
    (cover.getContext('bitmaprenderer')! as web.ImageBitmapRenderingContext)
        .transferFromImageBitmap(bitmap);
    web.document.body!.append(cover);
    return _WebCover(cover, Size(r.width, r.height));
  } on Object {
    return null;
  }
}

class _WebCover extends ScreenCover {
  _WebCover(this._el, this._size);
  final web.HTMLCanvasElement _el;
  final Size _size;

  @override
  Future<void> reveal(
    Offset center, {
    required bool fade,
    required Duration duration,
  }) {
    final done = Completer<void>();
    final far = [
      Offset.zero,
      Offset(_size.width, 0),
      Offset(0, _size.height),
      Offset(_size.width, _size.height),
    ].map((c) => (c - center).distance).reduce(math.max);
    final curve = fade ? Curves.easeOut : Curves.easeInOutCubic;
    final ms = duration.inMilliseconds;
    double? start;
    late final JSFunction tick;
    tick =
        ((JSNumber now) {
          final t0 = start ??= now.toDartDouble;
          final t = ((now.toDartDouble - t0) / ms).clamp(0.0, 1.0);
          final v = curve.transform(t);
          final style = _el.style;
          if (fade) {
            style.opacity = '${1 - v}';
          } else {
            final mask =
                'radial-gradient(circle at ${center.dx}px ${center.dy}px, '
                'transparent ${far * v}px, #000 ${far * v + 0.5}px)';
            style
              ..setProperty('mask-image', mask)
              ..setProperty('-webkit-mask-image', mask);
          }
          if (t < 1) {
            web.window.requestAnimationFrame(tick);
          } else {
            remove();
            done.complete();
          }
        }).toJS;
    web.window.requestAnimationFrame(tick);
    return done.future;
  }

  @override
  void remove() => _el.remove();
}
