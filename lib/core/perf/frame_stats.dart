/// Frame timings for the performance work (UI_OPT.md §3). Compiled in only
/// with --dart-define=POINTER_FRAMES=1; release builds never carry it.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Whether the build collects frame timings.
const framesOn =bool.fromEnvironment('POINTER_FRAMES');

/// Collects build and raster frame times under a label.
abstract final class FrameStats {
  static final _build = <int>[], _raster = <int>[];
  static String? _label;

  /// Whether collection has started.
  @visibleForTesting
  static bool get hasListener => _label != null;

  /// Starts collecting under [label] ("theme", "push", "profile").
  static void start(String label) {
    if (!framesOn) return;
    _label = label;
    _build.clear();
    _raster.clear();
    SchedulerBinding.instance.addTimingsCallback(_on);
  }

  /// Stops and prints: frames, over-budget frames, worst build and raster.
  static void stop() {
    if (!framesOn || _label == null) return;
    SchedulerBinding.instance.removeTimingsCallback(_on);
    int over(List<int> l) => l.where((u) => u > 16700).length;
    int worst(List<int> l) => l.isEmpty ? 0 : l.reduce((a, b) => a > b ? a : b);
    debugPrint(
      '[Pointer frames] $_label: ${_build.length} frames, '
      'build over ${over(_build)} (worst ${worst(_build) ~/ 1000} ms), '
      'raster over ${over(_raster)} (worst ${worst(_raster) ~/ 1000} ms)',
    );
    _label = null;
  }

  static void _on(List<FrameTiming> t) {
    for (final f in t) {
      _build.add(f.buildDuration.inMicroseconds);
      _raster.add(f.rasterDuration.inMicroseconds);
    }
  }
}
