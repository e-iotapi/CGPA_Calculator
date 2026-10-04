// UI_OPT O8.1: the theme snapshot stays small enough for Safari's canvas cap.
import 'package:cgpa_calculator/app/theme/circle_reveal.dart';
import 'package:cgpa_calculator/core/perf/device_tier.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('capped at 1.5 elsewhere', () {
    expect(snapshotRatio(dpr: 3, tier: DeviceTier.normal, ios: false), 1.5);
    expect(snapshotRatio(dpr: 1.25, tier: DeviceTier.normal, ios: false), 1.25);
  });

  test('1 on a low tier device', () {
    expect(snapshotRatio(dpr: 3, tier: DeviceTier.low, ios: false), 1);
  });

  test('1 on iOS, whatever the tier', () {
    expect(snapshotRatio(dpr: 3, tier: DeviceTier.normal, ios: true), 1);
  });

  test('a big window is captured at about 1080p worth of pixels', () {
    double r(double w, double h, double dpr) => snapshotRatio(
      dpr: dpr,
      tier: DeviceTier.normal,
      ios: false,
      size: Size(w, h),
    );
    expect(r(390, 844, 3), 1.5);
    expect(r(1920, 1080, 1), 1);
    expect(r(2560, 1440, 1.25), closeTo(0.75, 1e-9));
    final big = r(3840, 2160, 2);
    expect(3840 * 2160 * big * big, closeTo(maxSnapshotPixels, 1));
  });
}
