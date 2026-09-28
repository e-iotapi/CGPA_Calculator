import 'package:cgpa_calculator/core/platform/browser.dart' as browser;
import 'package:cgpa_calculator/core/storage/cache_boxes.dart';
import 'package:flutter/scheduler.dart';
import 'package:hive/hive.dart';

enum DeviceTier { low, normal }

/// Measured once per device: a low tier gets cheaper snapshots and clip
/// edges (UI_OPT.md O1.3, O2.2). Stored in deviceBox under 'tier'.
DeviceTier deviceTier = DeviceTier.normal;

/// Pure classification: any of low cores, low RAM, or a slow median raster
/// (first 60 frames after first paint) puts a device in [DeviceTier.low].
DeviceTier tierFrom({int? cores, double? memory, double? medianRasterMs}) {
  if (cores != null && cores <= 4) return DeviceTier.low;
  if (memory != null && memory <= 3) return DeviceTier.low;
  if (medianRasterMs != null && medianRasterMs > 12) return DeviceTier.low;
  return DeviceTier.normal;
}

/// Call after the first frame: two seconds of frame timings, plus the
/// browser's hints where it has them. Reads the stored tier first, so the
/// first theme switch this run is already right, then remeasures.
Future<void> measureDeviceTier() async {
  final box = Hive.isBoxOpen(deviceBoxName) ? Hive.box(deviceBoxName) : null;
  final saved = box?.get('tier') as String?;
  if (saved != null) {
    deviceTier = saved == 'low' ? DeviceTier.low : DeviceTier.normal;
  }

  final rasters = <int>[];
  void onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      rasters.add(t.rasterDuration.inMicroseconds);
    }
  }

  SchedulerBinding.instance.addTimingsCallback(onTimings);
  await Future<void>.delayed(const Duration(seconds: 2));
  SchedulerBinding.instance.removeTimingsCallback(onTimings);

  double? medianMs;
  if (rasters.length >= 10) {
    final sorted = [...rasters]..sort();
    medianMs = sorted[sorted.length ~/ 2] / 1000;
  }
  deviceTier = tierFrom(
    cores: browser.hardwareConcurrency(),
    memory: browser.deviceMemory(),
    medianRasterMs: medianMs,
  );
  await box?.put('tier', deviceTier == DeviceTier.low ? 'low' : 'normal');
}
