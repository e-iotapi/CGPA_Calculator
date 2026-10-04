import 'package:cgpa_calculator/core/perf/frame_stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('with framesOn false, start/stop add no timings callback', () {
    expect(framesOn, isFalse);
    FrameStats.start('theme');
    expect(FrameStats.hasListener, isFalse);
    FrameStats.stop();
    expect(FrameStats.hasListener, isFalse);
  });
}
