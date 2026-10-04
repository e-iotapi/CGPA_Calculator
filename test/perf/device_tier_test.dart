import 'package:cgpa_calculator/core/perf/device_tier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('low cores, low memory, or a slow median raster is low tier', () {
    expect(tierFrom(cores: 4), DeviceTier.low);
    expect(tierFrom(cores: 8, memory: 2), DeviceTier.low);
    expect(tierFrom(cores: 8, memory: 8, medianRasterMs: 14), DeviceTier.low);
  });

  test('otherwise normal', () {
    expect(tierFrom(cores: 8, memory: 8, medianRasterMs: 6), DeviceTier.normal);
  });
}
