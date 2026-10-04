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

const hourHeight = 50.0;
const _axisWidth = 30.0;

/// 9:00 -> "9", 11:30 -> "11:30", 13:00 -> "1": the board's block times.
String _hm(int m) {
  final h = (m ~/ 60) % 12 == 0 ? 12 : (m ~/ 60) % 12;
  return m % 60 == 0 ? '$h' : '$h:${(m % 60).toString().padLeft(2, '0')}';
}

/// The Week and Day views: a time axis, one column per date, the all-day
/// strips on top. Day is the same widget with one date.
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
    final items = [
      for (final d in dates)
        for (final i in widget.allDay[d] ?? const <AllDayItem>[]) (d, i),
    ];
    return Column(
      children: [
        for (final (d, i) in items.take(3)) _strip(p, d, i),
        if (items.length > 3)
          Semantics(
            button: true,
            child: InkWell(
              onTap: () => widget.onAllDay(items[3].$1),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  '+${items.length - 3} more all-day',
                  style: TypeScale.caption.copyWith(fontSize: 10.5, color: p.textMuted),
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(left: _axisWidth, top: 4, bottom: 4),
          child: Row(
            children: [
              for (final d in dates) Expanded(child: _dayHead(p, d)),
            ],
          ),
        ),
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
                          child: CustomPaint(painter: _Grid(p.divider)),
                        ),
                        for (var h = 0; h < 24; h++)
                          Positioned(
                            left: 0,
                            top: h == 0 ? 0 : h * hourHeight - 6,
                            child: Text(
                              hourLabel(h),
                              style: TypeScale.caption.copyWith(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w600,
                                color: p.faint,
                              ),
                            ),
                          ),
                        for (final (i, d) in dates.indexed) ..._column(p, i, d, w),
                        if (dates.contains(widget.today))
                          Positioned.fill(child: _NowLine(now: widget.now, p: p)),
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
            dayShort(dt.weekday),
            style: TypeScale.caption.copyWith(
              fontSize: 9.5,
              height: 1.2,
              fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
              color: isToday ? p.text : p.textMuted,
            ),
          ),
          Text(
            '${dt.day}',
            style: TypeScale.body.copyWith(
              fontSize: 13,
              height: 1.25,
              fontWeight: FontWeight.w800,
              color: p.text,
            ),
          ),
        ],
      ),
    );
  }

  /// One all-day line: ALL DAY, then the item and its date.
  Widget _strip(AppPalette p, String d, AllDayItem i) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
    child: Semantics(
      button: true,
      label: 'All day on ${dateLabel(d)}: ${i.label}',
      excludeSemantics: true,
      child: Material(
        color: p.hero,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => widget.onAllDay(d),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Text(
                  'ALL DAY',
                  style: TypeScale.label.copyWith(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: p.onHero,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${i.label} · ${dateLabel(d)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TypeScale.caption.copyWith(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: p.onHero,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

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
          child: _block(context, p, o, height, bw < 46),
        ),
      );
    }
    return out;
  }

  /// A class on a white card (an exam on the amber one); a time of the
  /// student's own gets an ink outline and a YOUR TIME chip.
  Widget _block(BuildContext context, AppPalette p, Occurrence o, double height, bool narrow) {
    final exam = o.kind == OccKind.midsem || o.kind == OccKind.compre;
    Widget line(String t, double size, FontWeight w, Color c, {bool fit = false}) {
      final text = Text(
        t,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TypeScale.caption.copyWith(fontSize: size, height: 1.2, fontWeight: w, color: c),
      );
      return Padding(
        padding: const EdgeInsets.only(bottom: 1),
        // Seven columns at 320 are ~38 wide: the code shrinks, never "CS F2…".
        child: fit ? FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: text) : text,
      );
    }

    final lines = <(Widget, double)>[
      (line(o.courseId.isEmpty ? o.title : o.courseId, 8.5, FontWeight.w800, p.text, fit: narrow), 11.2),
      if (o.courseId.isNotEmpty) (line(o.title, 7, FontWeight.w600, p.textMuted), 9.4),
      if (o.room != null && o.room!.isNotEmpty) (line(o.room!, 7, FontWeight.w700, p.text), 9.4),
      (line('${_hm(o.start)}–${_hm(o.end)}', 7, FontWeight.w600, p.textMuted), 9.4),
      if (o.edited)
        (
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(color: p.hero, borderRadius: BorderRadius.circular(4)),
              child: Text(
                'YOUR TIME',
                style: TypeScale.label.copyWith(
                  fontSize: 6.5,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  color: p.onHero,
                ),
              ),
            ),
          ),
          10,
        ),
    ];
    // Whole lines only: a block never overflows (the sheet has the rest).
    final room = height - 2 - 5 - (o.edited ? 3 : 0);
    var used = 0.0;
    final shown = <Widget>[];
    for (final (w, h) in lines) {
      if (shown.isNotEmpty && used + h > room) break;
      used += h;
      shown.add(w);
    }
    return Semantics(
      button: true,
      label:
          '${o.title}${o.courseId.isEmpty ? '' : ', ${o.courseId}'}, '
          '${o.room == null ? '' : '${o.room}, '}${span(o.start, o.end)}'
          '${o.edited ? ', your time' : ''}',
      excludeSemantics: true,
      child: Material(
        color: exam ? p.noticeTone.fill : p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9),
          side: o.edited ? BorderSide(color: p.text, width: 1.5) : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => widget.onBlock(o),
          child: Padding(
            padding: EdgeInsets.fromLTRB(narrow ? 2 : 4, 3, narrow ? 2 : 4, 2),
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: shown),
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
  _Grid(this.line);
  final Color line;

  @override
  void paint(Canvas c, Size s) {
    final paint = Paint()..color = line..strokeWidth = 1;
    for (var h = 0; h <= 24; h++) {
      c.drawLine(Offset(_axisWidth, h * hourHeight), Offset(s.width, h * hourHeight), paint);
    }
  }

  @override
  bool shouldRepaint(_Grid o) => o.line != line;
}

/// The "now" line across the grid, a dot on the axis and NOW beside it; ticks
/// on its own timer so the grid around it never rebuilds.
class _NowLine extends StatefulWidget {
  const _NowLine({required this.now, required this.p});
  final DateTime Function() now;
  final AppPalette p;

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
    final n = widget.now(), p = widget.p;
    final top = (n.hour * 60 + n.minute) / 60 * hourHeight;
    return Stack(
      children: [
        Positioned(
          left: _axisWidth,
          right: 0,
          top: top - 1,
          child: Semantics(
            label: 'Now, ${clock(n.hour * 60 + n.minute)}',
            child: Container(height: 2, color: p.nowLine),
          ),
        ),
        Positioned(
          left: _axisWidth - 4,
          top: top - 5,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: p.nowLine, shape: BoxShape.circle),
          ),
        ),
        Positioned(
          left: 2,
          top: top - 6,
          child: Container(
            color: p.background,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              'NOW',
              style: TypeScale.label.copyWith(
                fontSize: 8,
                height: 1.2,
                fontWeight: FontWeight.w800,
                color: p.nowLine,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
