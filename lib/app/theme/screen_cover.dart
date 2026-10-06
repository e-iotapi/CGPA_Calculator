import 'package:cgpa_calculator/app/theme/screen_cover_stub.dart'
    if (dart.library.js_interop) 'package:cgpa_calculator/app/theme/screen_cover_web.dart'
    as impl;
import 'package:flutter/painting.dart';

/// A copy of the screen held above the app by the browser, outside Flutter:
/// the theme switch animates it where Flutter's own pictures are too slow
/// (Firefox reads WebGL pixels back for each, 1.5-3 s; owner, 2026-10-06).
abstract class ScreenCover {
  /// Copies the app's canvas in the frame Flutter draws it and lays the copy
  /// over the app; null where that can't be done (off the web, more than one
  /// canvas, an error).
  static Future<ScreenCover?> take() => impl.takeCover();

  /// Opens a circular hole from [center] (logical pixels) until the copy is
  /// gone, or with [fade] fades it out, eased, over [duration]; then removes
  /// it. Runs on the browser's frames: Flutter draws nothing meanwhile.
  Future<void> reveal(
    Offset center, {
    required bool fade,
    required Duration duration,
  });

  /// Takes the copy down at once.
  void remove();
}
