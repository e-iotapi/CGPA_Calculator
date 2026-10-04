// UI_OPT O8.1: the theme snapshot stays small enough for Safari's canvas cap.
import 'package:cgpa_calculator/app/theme/circle_reveal.dart';
import 'package:cgpa_calculator/core/perf/device_tier.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test("the screen's own ratio elsewhere, so the pictures stay sharp", () {
    expect(snapshotRatio(dpr: 3, tier: DeviceTier.normal, ios: false), 3);
    expect(snapshotRatio(dpr: 1.25, tier: DeviceTier.normal, ios: false), 1.25);
  });

  test('1 on a low tier device', () {
    expect(snapshotRatio(dpr: 3, tier: DeviceTier.low, ios: false), 1);
  });

  test('1 on iOS, whatever the tier', () {
    expect(snapshotRatio(dpr: 3, tier: DeviceTier.normal, ios: true), 1);
  });

  test('only past a 4K screen does the ratio drop', () {
    double r(double w, double h, double dpr) => snapshotRatio(
      dpr: dpr,
      tier: DeviceTier.normal,
      ios: false,
      size: Size(w, h),
    );
    expect(r(390, 844, 3), 3);
    expect(r(1920, 1080, 1), 1);
    expect(r(2560, 1440, 1.25), 1.25);
    expect(r(1920, 1080, 2), 2);
    final big = r(2560, 1440, 2);
    expect(2560 * 1440 * big * big, closeTo(maxSnapshotPixels, 1));
  });
}
