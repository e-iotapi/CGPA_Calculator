/// An on-screen frame readout for measuring scrolling on a phone, where the
/// console needs a Mac. Compiled in only with POINTER_FRAMES (the profile
/// preview); [FrameHud] is the child itself everywhere else.
library;

import 'dart:async';

import 'package:cgpa_calculator/core/perf/frame_stats.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Shows, for the last burst of frames (a flick, a drag), the frame rate,
/// how many frames ran late, the longest gap between frames, and the worst
/// frame's build and draw time.
class FrameHud extends StatefulWidget {
  const FrameHud({super.key, required this.child});

  final Widget child;

  @override
  State<FrameHud> createState() => _FrameHudState();
}

class _FrameHudState extends State<FrameHud> {
  final _clock = Stopwatch()..start();
  final _text = ValueNotifier('touch and flick');
  Timer? _tick;

  // The current burst: frames closer than 400 ms apart.
  int _first = 0, _last = -1 << 30, _frames = 0, _late = 0, _gap = 0;
  int _build = 0, _draw = 0;

  @override
  void initState() {
    super.initState();
    if (!framesOn) return;
    SchedulerBinding.instance.addPersistentFrameCallback((_) => _frame());
    SchedulerBinding.instance.addTimingsCallback(_timings);
    _tick = Timer.periodic(const Duration(milliseconds: 250), (_) => _show());
  }

  void _frame() {
    final now = _clock.elapsedMilliseconds, gap = now - _last;
    _last = now;
    if (gap > 400) {
      _first = now;
      _frames = _late = _gap = _build = _draw = 0;
    } else {
      if (gap > 25) _late += (gap / 16.7).round() - 1;
      if (gap > _gap) _gap = gap;
    }
    _frames++;
  }

  void _timings(List<FrameTiming> t) {
    for (final f in t) {
      final b = f.buildDuration.inMilliseconds;
      final r = f.rasterDuration.inMilliseconds;
      if (b + r > _build + _draw) {
        _build = b;
        _draw = r;
      }
    }
  }

  void _show() {
    final ms = _last - _first;
    if (_frames < 2 || ms <= 0) return;
    _text.value =
        '${(1000 * (_frames - 1) / ms).round()} fps · late $_late · '
        'gap $_gap ms\nworst build $_build + draw $_draw ms';
  }

  @override
  void dispose() {
    _tick?.cancel();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!framesOn) return widget.child;
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        widget.child,
        Positioned(
          left: 8,
          top: MediaQuery.paddingOf(context).top + 4,
          child: IgnorePointer(
            child: RepaintBoundary(
              child: ColoredBox(
                color: const Color(0xCC000000),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: ValueListenableBuilder(
                    valueListenable: _text,
                    builder:
                        (_, s, _) => Text(
                          s,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                            color: Color(0xFFFFFFFF),
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
