/// An on-screen frame readout for measuring scrolling on a phone, where the
/// console needs a Mac. Compiled in only with POINTER_FRAMES (the profile
/// preview); [FrameHud] is the child itself everywhere else.
library;

import 'package:cgpa_calculator/core/perf/frame_stats.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Shows, for the last scroll (a flick or a drag, start to end), the frame
/// rate, how many frames ran late, the longest gap between frames, and the
/// worst frame's build and draw time.
class FrameHud extends StatefulWidget {
  const FrameHud({super.key, required this.child});

  final Widget child;

  @override
  State<FrameHud> createState() => _FrameHudState();
}

class _FrameHudState extends State<FrameHud> {
  final _clock = Stopwatch()..start();
  final _text = ValueNotifier('flick a list');

  // One scroll, from its start to its end; the box's own redraws and the
  // pauses between scrolls never count.
  int _scrolls = 0, _first = 0, _last = 0, _frames = 0, _late = 0, _gap = 0;
  int _build = 0, _draw = 0;

  // The motion: when the finger went down and up, and where the content
  // was on each update (ms, px, still dragging).
  int _down = -1, _up = -1;
  final _moves = <(int, double, bool)>[];

  @override
  void initState() {
    super.initState();
    if (!framesOn) return;
    SchedulerBinding.instance.addPersistentFrameCallback((_) => _frame());
    SchedulerBinding.instance.addTimingsCallback(_timings);
  }

  bool _onScroll(ScrollNotification n) {
    if (n is ScrollStartNotification && _scrolls++ == 0) {
      _first = _last = _clock.elapsedMilliseconds;
      _frames = _late = _gap = _build = _draw = 0;
      _moves.clear();
    } else if (n is ScrollUpdateNotification && _scrolls > 0) {
      _moves.add((
        _clock.elapsedMilliseconds,
        n.metrics.pixels,
        n.dragDetails != null,
      ));
    } else if (n is ScrollEndNotification && _scrolls > 0 && --_scrolls == 0) {
      _show();
    }
    return false;
  }

  void _frame() {
    if (_scrolls == 0) return;
    final now = _clock.elapsedMilliseconds, gap = now - _last;
    _last = now;
    if (gap > 25) _late += (gap / 16.7).round() - 1;
    if (gap > _gap) _gap = gap;
    _frames++;
  }

  void _timings(List<FrameTiming> t) {
    if (_scrolls == 0) return;
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
        '${(1000 * _frames / ms).round()} fps · $_frames frames in $ms ms\n'
        'late $_late · gap $_gap ms · worst build $_build + draw $_draw ms'
        '\n${_motion()}';
  }

  /// Touch to first movement, lift to the fling's first step, and the
  /// biggest single step against the steps either side of it.
  String _motion() {
    if (_moves.length < 3) return '';
    final touch = _down < 0 ? '?' : '${_moves.first.$1 - _down}';
    final fling = _moves.indexWhere((m) => !m.$3);
    final lift =
        fling < 0 || _up < 0 || _up > _moves[fling].$1
            ? '-'
            : '${_moves[fling].$1 - _up}';
    var at = 1, big = 0.0, around = 0.0;
    for (var i = 1; i < _moves.length; i++) {
      final step = (_moves[i].$2 - _moves[i - 1].$2).abs();
      if (step <= big) continue;
      final prev = i > 1 ? (_moves[i - 1].$2 - _moves[i - 2].$2).abs() : 0;
      final next =
          i + 1 < _moves.length ? (_moves[i + 1].$2 - _moves[i].$2).abs() : 0;
      (at, big, around) = (i, step, (prev + next) / 2);
    }
    final where =
        _moves[at].$3 ? 'drag' : (fling < 0 ? 'fling' : 'fling+${at - fling}');
    final resample = GestureBinding.instance.resamplingEnabled ? 'on' : 'off';
    return 'touch→move $touch ms · lift→fling $lift ms · resample $resample\n'
        'jump ${big.round()} px ($where, around ${around.round()})';
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!framesOn) return widget.child;
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _down = _clock.elapsedMilliseconds,
          onPointerUp: (_) => _up = _clock.elapsedMilliseconds,
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: widget.child,
          ),
        ),
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
