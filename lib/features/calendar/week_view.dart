import 'dart:async';

import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/timetable/occurrences.dart';
import 'package:cgpa_calculator/features/calendar/calendar_time.dart';
import 'package:flutter/material.dart';

/// An all-day line: a holiday, an academic date, or an evaluative part from
/// Marks (which has a date but no time).
class AllDayItem {
  const AllDayItem(this.label, this.kind, {this.courseId});
  final String label;

  /// `holiday`, `event` or `eval`.
  final String kind;
  final String? courseId;
}

/// Where each of [spans] (sorted by start) sits when overlapping blocks
/// share a column: its lane and how many lanes its cluster has.
List<(int lane, int lanes)> layoutLanes(List<({int s, int e})> spans) {
  final out = List<(int, int)>.filled(spans.length, (0, 1));
  var from = 0, laneEnds = <int>[];
  void close(int to) {
    for (var i = from; i < to; i++) {
      out[i] = (out[i].$1, laneEnds.length);
    }
  }

  for (var i = 0; i < spans.length; i++) {
    final x = spans[i];
    if (laneEnds.isNotEmpty && laneEnds.every((e) => e <= x.s)) {
      close(i);
      from = i;
      laneEnds = [];
    }
    var lane = laneEnds.indexWhere((e) => e <= x.s);
    if (lane < 0) {
      lane = laneEnds.length;
      laneEnds.add(x.e);
    } else {
      laneEnds[lane] = x.e;
    }
    out[i] = (lane, 1);
  }
  close(spans.length);
  return out;
}

const hourHeight = 56.0;
const _axisWidth = 44.0;

/// The Week and Day views: a time axis, one column per date, an all-day
/// strip on top. Day is the same widget with one date.
class WeekView extends StatefulWidget {
  const WeekView({
    super.key,
    required this.dates,
    required this.occs,
    required this.allDay,
    required this.today,
    required this.now,
    required this.onBlock,
    required this.onAllDay,
  });

  final List<String> dates;

  /// Timed occurrences in [dates] (all-day events are in [allDay]).
  final List<Occurrence> occs;
  final Map<String, List<AllDayItem>> allDay;
  final String today;
  final DateTime Function() now;
  final void Function(Occurrence) onBlock;
  final void Function(String date) onAllDay;

  @override
  State<WeekView> createState() => _WeekViewState();
}

class _WeekViewState extends State<WeekView> {
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    // 8 AM at the top, or higher up when something starts earlier.
    final first = widget.occs.fold<int>(480, (m, o) => o.start < m ? o.start : m);
    _scroll = ScrollController(initialScrollOffset: first / 60 * hourHeight);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final dates = widget.dates;
    final strip = widget.allDay.values.fold<int>(0, (m, l) => l.length > m ? l.length : m);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: _axisWidth),
          child: Row(
            children: [
              for (final d in dates) Expanded(child: _dayHead(p, d)),
            ],
          ),
        ),
        if (strip > 0)
          Padding(
            padding: const EdgeInsets.only(left: _axisWidth, top: Space.xs),
            child: Row(
              children: [
                for (final d in dates)
                  Expanded(child: _strip(p, d, widget.allDay[d] ?? const [])),
              ],
            ),
          ),
        const SizedBox(height: Space.xs),
        Expanded(
          child: SingleChildScrollView(
            controller: _scroll,
            child: RepaintBoundary(
              child: SizedBox(
                height: 24 * hourHeight,
                child: LayoutBuilder(
                  builder: (context, box) {
                    final w = (box.maxWidth - _axisWidth) / dates.length;
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _Grid(p.divider, dates.length),
                          ),
                        ),
                        for (var h = 0; h < 24; h++)
                          Positioned(
                            left: 0,
                            top: h * hourHeight + 2,
                            width: _axisWidth - 6,
                            child: Text(
                              hourLabel(h),
                              textAlign: TextAlign.right,
                              style: TypeScale.caption.copyWith(
                                fontSize: 9.5,
                                color: p.textMuted,
                              ),
                            ),
                          ),
                        for (final (i, d) in dates.indexed) ..._column(p, i, d, w),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dayHead(AppPalette p, String d) {
    final isToday = d == widget.today;
    final dt = parseDay(d);
    return Semantics(
      header: true,
      label: '${dayNames[dt.weekday - 1]} ${dt.day}${isToday ? ', today' : ''}',
      excludeSemantics: true,
      child: Column(
        children: [
          Text(
            dayShort(dt.weekday).toUpperCase(),
            style: TypeScale.label.copyWith(fontSize: 9.5, color: p.textMuted),
          ),
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isToday ? p.inverse : null,
            ),
            child: Text(
              '${dt.day}',
              style: TypeScale.body.copyWith(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: isToday ? p.onInverse : p.text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _strip(AppPalette p, String d, List<AllDayItem> items) {
    final shown = items.take(2).toList();
    return Semantics(
      button: true,
      label: items.isEmpty
          ? 'No all-day items on ${dateLabel(d)}'
          : '${items.length} all-day on ${dateLabel(d)}: ${items.map((i) => i.label).join(', ')}',
      excludeSemantics: true,
      child: InkWell(
        onTap: items.isEmpty ? null : () => widget.onAllDay(d),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1.5, vertical: 1),
          child: Column(
            children: [
              for (final i in shown) _chip(p, i),
              if (items.length > shown.length)
                Text(
                  '+${items.length - shown.length}',
                  style: TypeScale.caption.copyWith(fontSize: 9.5, color: p.textMuted),
                ),
            ],
          ),
        ),
      ),
    );
  }

  GradeTone _tone(AppPalette p, String kind) => switch (kind) {
    'holiday' => p.gradeTone('D'),
    'eval' => p.gradeTone('B-'),
    _ => p.mutedTone,
  };

  Widget _chip(AppPalette p, AllDayItem i) {
    final t = _tone(p, i.kind);
    return Container(
      height: 18,
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 3),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(color: t.fill, borderRadius: BorderRadius.circular(5)),
      child: Text(
        i.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textScaler: TextScaler.noScaling,
        style: TypeScale.caption.copyWith(fontSize: 9, fontWeight: FontWeight.w700, color: t.text),
      ),
    );
  }

  Color _fill(AppPalette p, Occurrence o) => switch (o.kind) {
    OccKind.cls => p.gradeTone('A').fill,
    OccKind.midsem || OccKind.compre => p.gradeTone('C').fill,
    _ => p.gradeTone('B').fill,
  };

  Color _ink(AppPalette p, Occurrence o) => switch (o.kind) {
    OccKind.cls => p.gradeTone('A').text,
    OccKind.midsem || OccKind.compre => p.gradeTone('C').text,
    _ => p.gradeTone('B').text,
  };

  List<Widget> _column(AppPalette p, int i, String d, double w) {
    final day = widget.occs.where((o) => o.date == d && o.kind != OccKind.event).toList();
    final lanes = layoutLanes([for (final o in day) (s: o.start, e: o.end)]);
    final out = <Widget>[];
    for (final (k, o) in day.indexed) {
      final (lane, of) = lanes[k];
      final bw = w / of;
      final top = o.start / 60 * hourHeight;
      final height = ((o.end - o.start) / 60 * hourHeight).clamp(24.0, 24 * hourHeight);
      out.add(
        Positioned(
          left: _axisWidth + i * w + lane * bw + 1,
          top: top + 1,
          width: bw - 2,
          height: height - 2,
          child: _block(context, p, o, height),
        ),
      );
    }
    if (d == widget.today) {
      out.add(
        Positioned(
          left: _axisWidth + i * w,
          width: w,
          top: 0,
          height: 24 * hourHeight,
          child: _NowLine(now: widget.now, color: p.behind),
        ),
      );
    }
    return out;
  }

  Widget _block(BuildContext context, AppPalette p, Occurrence o, double height) {
    final ink = _ink(p, o);
    final code = o.courseId.isEmpty ? o.title : o.courseId;
    final lines = <String>[
      code,
      if (o.courseId.isNotEmpty) o.title,
      if (o.room != null && o.room!.isNotEmpty) o.room!,
      '${clockShort(o.start)}–${clockShort(o.end)}',
      if (o.edited) 'Your time',
    ];
    // Whole lines only: a block never overflows (the sheet has the rest).
    final fit = ((height - 6) / 11.5).floor().clamp(1, lines.length);
    return Semantics(
      button: true,
      label:
          '${o.title}${o.courseId.isEmpty ? '' : ', ${o.courseId}'}, '
          '${o.room == null ? '' : '${o.room}, '}${span(o.start, o.end)}'
          '${o.edited ? ', your time' : ''}',
      excludeSemantics: true,
      child: Material(
        color: _fill(p, o),
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => widget.onBlock(o),
          child: Container(
            decoration: o.edited
                ? BoxDecoration(border: Border(left: BorderSide(color: ink, width: 3)))
                : null,
            padding: const EdgeInsets.fromLTRB(4, 2, 3, 1),
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (n, t) in lines.take(fit).toList().indexed)
                    Text(
                      t,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TypeScale.caption.copyWith(
                        fontSize: 9.5,
                        height: 1.2,
                        fontWeight: n == 0 ? FontWeight.w800 : FontWeight.w600,
                        color: ink,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

DateTime parseDay(String d) => DateTime.utc(
  int.parse(d.substring(0, 4)),
  int.parse(d.substring(5, 7)),
  int.parse(d.substring(8, 10)),
);

class _Grid extends CustomPainter {
  _Grid(this.line, this.cols);
  final Color line;
  final int cols;

  @override
  void paint(Canvas c, Size s) {
    final paint = Paint()..color = line..strokeWidth = 1;
    for (var h = 0; h <= 24; h++) {
      c.drawLine(Offset(_axisWidth, h * hourHeight), Offset(s.width, h * hourHeight), paint);
    }
    final w = (s.width - _axisWidth) / cols;
    for (var i = 0; i < cols; i++) {
      c.drawLine(Offset(_axisWidth + i * w, 0), Offset(_axisWidth + i * w, s.height), paint);
    }
  }

  @override
  bool shouldRepaint(_Grid o) => o.line != line || o.cols != cols;
}

/// The red "now" line across today's column; ticks on its own timer so the
/// grid around it never rebuilds.
class _NowLine extends StatefulWidget {
  const _NowLine({required this.now, required this.color});
  final DateTime Function() now;
  final Color color;

  @override
  State<_NowLine> createState() => _NowLineState();
}

class _NowLineState extends State<_NowLine> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.now();
    final top = (n.hour * 60 + n.minute) / 60 * hourHeight;
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: top - 1,
          child: Semantics(
            label: 'Now, ${clock(n.hour * 60 + n.minute)}',
            child: Container(height: 2, color: widget.color),
          ),
        ),
      ],
    );
  }
}
