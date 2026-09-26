import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/models/course_names.dart';
import 'package:cgpa_calculator/core/storage/courses.dart';
import 'package:cgpa_calculator/core/storage/marks.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/calendar/calendar_controller.dart';
import 'package:cgpa_calculator/features/marks/marks_format.dart';
import 'package:cgpa_calculator/features/marks/marks_page.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/circle_icon_button.dart';
import 'package:cgpa_calculator/shared/widgets/offline_strip.dart';
import 'package:cgpa_calculator/sync.dart';
import 'package:flutter/material.dart';

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Month grid and agenda of every dated part entered in Marks.
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, this.today});

  /// Defaults to now; fixed in tests.
  final DateTime? today;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late final DateTime _today = widget.today ?? DateTime.now();
  late DateTime _month = DateTime(_today.year, _today.month);
  DateTime? _selected;

  Future<void> _openCourse(String id) async {
    final c = allCourses().where((c) => c.id == id).firstOrNull;
    if (c == null) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => MarksPage(course: c)));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final all = calendarEntries(allEvaluatives());
    final titles = <String, Course>{for (final c in allCourses()) c.id: c};
    final shown =
        _selected == null
            ? upcoming(all, _today)
            : all.where((e) => e.date == _selected).toList();

    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      18,
                      Space.lg,
                      18,
                      Space.lg,
                    ),
                    children: [
                      _header(p),
                      const SizedBox(height: 13),
                      _grid(p, all),
                      const SizedBox(height: 13),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selected == null
                                  ? 'Next up'
                                  : 'On ${_selected!.day} '
                                      '${_months[_selected!.month - 1]}',
                              style: TypeScale.section.copyWith(color: p.text),
                            ),
                          ),
                          if (_selected != null)
                            TextButton(
                              onPressed: () => setState(() => _selected = null),
                              child: Text(
                                'Show all',
                                style: TypeScale.button.copyWith(color: p.text),
                              ),
                            )
                          else
                            Text(
                              '${shown.length} remaining',
                              style: TypeScale.caption.copyWith(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: p.textMuted,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: Space.sm),
                      if (all.isEmpty)
                        Text(
                          'Dates you add to parts in Marks show up here.',
                          style: TypeScale.body.copyWith(
                            fontWeight: FontWeight.w500,
                            color: p.textMuted,
                          ),
                        ),
                      for (final (i, e) in shown.indexed) ...[
                        _entry(p, e, titles[e.courseId], first: i == 0),
                        const SizedBox(height: Space.sm),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, Space.md),
                  child: OfflineStrip(pending: () => Sync.hasUnsynced),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(AppPalette p) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What is coming',
              style: TypeScale.caption.copyWith(
                fontSize: 12,
                color: p.textMuted,
              ),
            ),
            Text(
              '${_months[_month.month - 1]} ${_month.year}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TypeScale.title.copyWith(fontSize: 24, color: p.text),
            ),
          ],
        ),
      ),
      CircleIconButton(
        icon: Icons.chevron_left_rounded,
        tooltip: 'Previous month',
        onPressed:
            () => setState(
              () => _month = DateTime(_month.year, _month.month - 1),
            ),
        size: 40,
      ),
      const SizedBox(width: 7),
      CircleIconButton(
        icon: Icons.chevron_right_rounded,
        tooltip: 'Next month',
        onPressed:
            () => setState(
              () => _month = DateTime(_month.year, _month.month + 1),
            ),
        size: 40,
      ),
      const SizedBox(width: 7),
      CircleIconButton(
        icon: Icons.arrow_back_rounded,
        tooltip: 'Back',
        onPressed: () => Navigator.of(context).maybePop(),
        size: 40,
      ),
    ],
  );

  Widget _grid(AppPalette p, List<CalendarEntry> all) {
    final dated = {for (final e in all) e.date};
    final first = _month;
    final days = DateTime(first.year, first.month + 1, 0).day;
    final lead = first.weekday - 1; // Monday first
    final today = DateTime(_today.year, _today.month, _today.day);
    final next = upcoming(all, _today).firstOrNull?.date;
    final label = TypeScale.label.copyWith(fontSize: 9.5, color: p.textMuted);

    Widget cell(int day) {
      final d = DateTime(first.year, first.month, day);
      final past = d.isBefore(today);
      final isToday = d == today;
      final marked = _selected == d || (_selected == null && next == d);
      final has = dated.contains(d);
      final fg =
          isToday
              ? p.onInverse
              : marked
              ? p.onHero
              : past
              ? p.textMuted
              : p.icon;
      return Semantics(
        button: true,
        selected: _selected == d,
        label:
            '$day ${_months[first.month - 1]}'
            '${has ? ', has dated work' : ''}${isToday ? ', today' : ''}',
        excludeSemantics: true,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => setState(() => _selected = _selected == d ? null : d),
          child: SizedBox(
            height: 38,
            child: Center(
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      isToday
                          ? p.inverse
                          : marked
                          ? p.hero
                          : null,
                ),
                // Scales down rather than overflowing at large text sizes.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$day',
                        style: TypeScale.body.copyWith(
                          fontSize: 12.5,
                          fontWeight:
                              isToday || marked || has
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                          color: fg,
                        ),
                      ),
                      if (has && !isToday && !marked)
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: past ? p.textMuted : p.text,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final cells = [
      for (var i = 0; i < lead; i++) const SizedBox.shrink(),
      for (var d = 1; d <= days; d++) cell(d),
    ];
    return AppCard(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
      child: Column(
        children: [
          Row(
            children: [
              for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                Expanded(
                  child: Text(d, textAlign: TextAlign.center, style: label),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (var r = 0; r < cells.length; r += 7)
            Row(
              children: [
                for (var c = r; c < r + 7; c++)
                  Expanded(
                    child: c < cells.length ? cells[c] : const SizedBox(),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _entry(
    AppPalette p,
    CalendarEntry e,
    Course? course, {
    required bool first,
  }) {
    final soon = soonLabel(e.date, _today);
    final tone = p.gradeTone('C');
    final sub =
        course == null
            ? e.courseId
            : '${displayTitle(course.id, course.title)} · ${course.id}';
    return AppCard(
      onTap: () => _openCourse(e.courseId),
      radius: Radii.row - 2,
      border: first ? BorderSide(color: p.border, width: 1.5) : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Column(
              children: [
                Text(
                  '${e.date.day}',
                  style: TypeScale.section.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: p.text,
                  ),
                ),
                Text(
                  _months[e.date.month - 1].substring(0, 3).toUpperCase(),
                  style: TypeScale.label.copyWith(
                    fontSize: 9,
                    color: p.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 30,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: p.divider,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TypeScale.body.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: p.text,
                  ),
                ),
                Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TypeScale.caption.copyWith(
                    fontSize: 10.5,
                    color: p.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Space.sm),
          if (soon != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: tone.fill,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                soon,
                style: TypeScale.label.copyWith(
                  fontSize: 9.5,
                  color: tone.text,
                ),
              ),
            )
          else
            Text(
              '${marks2(e.weight)}%',
              style: TypeScale.caption.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: p.textMuted,
              ),
            ),
        ],
      ),
    );
  }
}
