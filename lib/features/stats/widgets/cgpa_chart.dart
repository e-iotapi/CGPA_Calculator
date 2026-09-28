import 'dart:math' as math;
import 'dart:ui';

import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/features/stats/stats_controller.dart';
import 'package:flutter/material.dart';

/// Running CGPA by semester: actual, forecast and the target line.
class CgpaChart extends StatelessWidget {
  const CgpaChart({
    super.key,
    required this.actual,
    required this.forecast,
    required this.target,
  });

  final List<CgpaPoint> actual;

  /// Starts at the last actual point.
  final List<CgpaPoint> forecast;
  final double target;

  static Color forecastColor(AppPalette p) =>
      Color.lerp(p.accent, p.hero, 0.45)!;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    String f(double v) => v.toStringAsFixed(2);
    final label = [
      'CGPA by semester:',
      for (final a in actual) '${a.sem} ${f(a.cgpa)},',
      if (forecast.length > 1) 'forecast finish ${f(forecast.last.cgpa)},',
      'target ${f(target)}',
    ].join(' ');
    return Semantics(
      label: label,
      excludeSemantics: true,
      // Its own layer: the sliders below repaint on every drag.
      child: RepaintBoundary(
        child: SizedBox(
          height: 170,
          child: CustomPaint(
            size: Size.infinite,
            painter: _ChartPainter(
              actual: actual,
              forecast: forecast,
              target: target,
              line: p.text,
              forecastLine: forecastColor(p),
              targetLine: p.behind,
              grid: p.divider,
              label: p.textMuted,
              surface: p.surface,
            ),
          ),
        ),
      ),
    );
  }
}

/// The y axis: the whole numbers the [values] span, at least one apart,
/// within 0–10.
(double, double) yRange(Iterable<double> values) {
  final lo = math.max(0.0, values.reduce(math.min).floorToDouble());
  final hi = math.min(10.0, values.reduce(math.max).ceilToDouble());
  if (hi - lo >= 1) return (lo, hi);
  return hi < 10 ? (lo, lo + 1) : (hi - 1, hi);
}

/// The x labels, most important first: the first semester, the current one
/// ([current], -1 with none), the last, and a landmark (Practice School).
List<int> xLabels(List<String> sems, int current) {
  final ps = sems.indexWhere((s) => s.trim().toUpperCase().startsWith('PS'));
  final out = <int>[];
  for (final i in [0, current, sems.length - 1, ps]) {
    if (i >= 0 && i < sems.length && !out.contains(i)) out.add(i);
  }
  return out;
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.actual,
    required this.forecast,
    required this.target,
    required this.line,
    required this.forecastLine,
    required this.targetLine,
    required this.grid,
    required this.label,
    required this.surface,
  });

  final List<CgpaPoint> actual;
  final List<CgpaPoint> forecast;
  final double target;
  final Color line, forecastLine, targetLine, grid, label, surface;

  /// 1 when the forecast starts on the last actual point.
  int get _lead => actual.isEmpty ? 0 : 1;

  @override
  void paint(Canvas canvas, Size size) {
    final sems = [
      ...actual.map((a) => a.sem),
      ...forecast.skip(_lead).map((a) => a.sem),
    ];
    if (sems.isEmpty) return;
    final values = [
      ...actual.map((a) => a.cgpa),
      ...forecast.map((a) => a.cgpa),
      target,
    ];
    final (lo, hi) = yRange(values);
    const left = 22.0, bottom = 16.0, top = 6.0, right = 6.0;
    final w = size.width - left - right, h = size.height - top - bottom;
    double x(int i) =>
        left + (sems.length == 1 ? w / 2 : w * i / (sems.length - 1));
    double y(double v) => top + h * (1 - (v - lo) / (hi - lo));

    TextPainter text(String s, [Color? c, double size = 9.5]) => TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontFamily: TypeScale.family,
          fontSize: size,
          fontWeight: c == null ? FontWeight.w500 : FontWeight.w700,
          color: c ?? label,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final gridPaint =
        Paint()
          ..color = grid
          ..strokeWidth = 1;
    final gridStep = hi - lo <= 3 ? 0.5 : 1.0;
    for (var v = lo; v <= hi + 0.001; v += gridStep) {
      canvas.drawLine(Offset(left, y(v)), Offset(left + w, y(v)), gridPaint);
      if ((v - v.roundToDouble()).abs() < 0.001) {
        final t = text(v.toStringAsFixed(1), null, 8);
        t.paint(canvas, Offset(0, y(v) - t.height / 2));
      }
    }
    // First, current, last and a landmark only; drop any that would overlap.
    final drawnLabels = <Rect>[];
    for (final i in xLabels(sems, actual.length - 1)) {
      final t = text(sems[i].replaceAll(' ', ''), null, 7.5);
      final dx =
          (x(i) - t.width / 2).clamp(left, size.width - t.width).toDouble();
      final dy = size.height - t.height;
      final rect = Rect.fromLTWH(dx, dy, t.width, t.height).inflate(3);
      if (drawnLabels.any((r) => r.overlaps(rect))) continue;
      drawnLabels.add(rect);
      t.paint(canvas, Offset(dx, dy));
    }

    // Target, dashed.
    final tp =
        Paint()
          ..color = targetLine
          ..strokeWidth = 2;
    for (var d = left; d < left + w; d += 9) {
      canvas.drawLine(
        Offset(d, y(target)),
        Offset(math.min(d + 5, left + w), y(target)),
        tp,
      );
    }

    void path(List<double> vs, int from, Color c, {bool dashed = false}) {
      if (vs.isEmpty) return;
      final pth = Path()..moveTo(x(from), y(vs.first));
      for (var i = 1; i < vs.length; i++) {
        pth.lineTo(x(from + i), y(vs[i]));
      }
      final paint =
          Paint()
            ..color = c
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.6
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round;
      if (!dashed) {
        canvas.drawPath(pth, paint);
      } else {
        for (final PathMetric m in pth.computeMetrics()) {
          for (var d = 0.0; d < m.length; d += 11) {
            canvas.drawPath(m.extractPath(d, d + 6), paint);
          }
        }
      }
      final dot = Paint()..color = c;
      final ring =
          Paint()
            ..color = c
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2;
      final fill = Paint()..color = surface;
      for (var i = 0; i < vs.length; i++) {
        final o = Offset(x(from + i), y(vs[i]));
        if (dashed) {
          // Board `Stats`: forecast points are hollow.
          if (i == 0 && _lead == 1) continue;
          canvas.drawCircle(o, 3.4, fill);
          canvas.drawCircle(o, 3.4, ring);
        } else {
          canvas.drawCircle(o, 2.8, dot);
        }
      }
    }

    path(
      forecast.map((f) => f.cgpa).toList(),
      actual.length - _lead,
      forecastLine,
      dashed: true,
    );
    path(actual.map((a) => a.cgpa).toList(), 0, line);

    /// A value beside a point, kept inside the chart. The target line is
    /// named by the legend, not labelled on the chart.
    void tag(double v, int i, Color c, {bool above = true}) {
      final t = text(v.toStringAsFixed(2), c);
      final dx =
          (x(i) - t.width / 2).clamp(left, size.width - t.width).toDouble();
      final dy = above ? y(v) - t.height - 6 : y(v) + 6;
      t.paint(
        canvas,
        Offset(dx, dy.clamp(0, size.height - bottom - t.height).toDouble()),
      );
    }

    // Today, ringed and labelled; the forecast's end, labelled.
    if (actual.isNotEmpty) {
      final now = Offset(x(actual.length - 1), y(actual.last.cgpa));
      canvas.drawCircle(now, 5 + 2.4, Paint()..color = surface);
      canvas.drawCircle(now, 5, Paint()..color = line);
      tag(actual.last.cgpa, actual.length - 1, line, above: false);
    }
    if (forecast.length > 1) {
      tag(forecast.last.cgpa, sems.length - 1, forecastLine);
    }
  }

  @override
  bool shouldRepaint(_ChartPainter o) =>
      o.actual != actual ||
      o.forecast != forecast ||
      o.target != target ||
      o.line != line;
}
