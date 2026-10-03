import 'package:cgpa_calculator/admin/widgets.dart' show Note, problem;
import 'package:cgpa_calculator/app/router.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/models/course_names.dart';
import 'package:cgpa_calculator/core/storage/courses.dart';
import 'package:cgpa_calculator/core/storage/marks.dart';
import 'package:cgpa_calculator/core/timetable/auto_fill.dart';
import 'package:cgpa_calculator/core/timetable/calendar_store.dart';
import 'package:cgpa_calculator/core/timetable/occurrences.dart';
import 'package:cgpa_calculator/core/timetable/timetable.dart';
import 'package:cgpa_calculator/core/timetable/timetable_store.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/calendar/add_course_sheet.dart';
import 'package:cgpa_calculator/features/calendar/calendar_controller.dart';
import 'package:cgpa_calculator/features/calendar/calendar_data.dart';
import 'package:cgpa_calculator/features/calendar/calendar_time.dart';
import 'package:cgpa_calculator/features/calendar/class_sheet.dart';
import 'package:cgpa_calculator/features/calendar/timings_sheet.dart';
import 'package:cgpa_calculator/features/calendar/week_view.dart';
import 'package:cgpa_calculator/features/marks/marks_format.dart';
import 'package:cgpa_calculator/features/marks/marks_page.dart';
import 'package:cgpa_calculator/features/resources/resources_page.dart' show takingNow;
import 'package:cgpa_calculator/features/setup/campus_pick_page.dart' show viewCampus;
import 'package:cgpa_calculator/script.dart' show batch, selectedprofile;
import 'package:cgpa_calculator/shared/tour_key.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/card_row.dart';
import 'package:cgpa_calculator/shared/widgets/circle_icon_button.dart';
import 'package:cgpa_calculator/shared/widgets/confirm_dialog.dart';
import 'package:cgpa_calculator/shared/widgets/notice.dart';
import 'package:cgpa_calculator/shared/widgets/offline_strip.dart';
import 'package:cgpa_calculator/shared/widgets/outlined_pill.dart';
import 'package:cgpa_calculator/shared/widgets/segmented.dart';
import 'package:cgpa_calculator/sync.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';

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

enum _View { month, week, day }

/// Month, Week and Day over the published timetable, the student's own
/// changes and every dated part entered in Marks.
class CalendarPage extends StatefulWidget {
  const CalendarPage({
    super.key,
    this.today,
    this.timetables,
    this.campus,
    this.calendar,
    this.prefs,
  });

  /// Defaults to now; fixed in tests.
  final DateTime? today;

  /// The timetable source, the campus and the overrides; tests swap them.
  final TimetableStore? timetables;
  final String? campus;
  final CalendarStore? calendar;

  /// Where the "we added your courses" notice remembers it was shown (the
  /// settings box); tests swap it.
  final Box? prefs;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late final DateTime _today = widget.today ?? DateTime.now();
  late DateTime _month = DateTime(_today.year, _today.month);
  DateTime? _selected;

  _View _view = _View.month;

  /// The date Week and Day show (a Week shows the one that holds it).
  late String _focus = dayStr(_today);
  Timetable? _tt;
  CalendarStore? _cal;
  Object? _error;
  bool _loaded = false;

  /// The courses were just put in for the student and the note is still up.
  bool _added = false;

  TimetableStore? get _store => widget.timetables ?? timetableStore;
  String? get _campus => widget.campus ?? viewCampus();
  String get _todayStr => dayStr(_today);

  @override
  void initState() {
    super.initState();
    final campus = _campus;
    _cal = widget.calendar ?? peekCalendarStore(selectedprofile);
    _tt = campus == null ? null : _store?.peekCurrent(campus);
    _load();
  }

  Future<void> _load() async {
    final campus = _campus, store = _store;
    _error = null;
    try {
      _cal ??= await openCalendarStore(selectedprofile);
      if (campus != null && store != null) {
        _tt = await store.current(campus) ?? _tt;
        final t = _tt;
        if (t != null && _cal!.state.sem != t.sem) await _cal!.adopt(campus, t.sem);
        if (t != null) await _autoFill(t);
      }
    } on Object catch (e) {
      _error = e;
    }
    if (mounted) setState(() => _loaded = true);
  }

  static const _seenKey = 'calendar_autofill_seen';

  /// A sem's first load: the student's courses go in, once; the note says so
  /// the first time only.
  Future<void> _autoFill(Timetable t) async {
    final c = _cal!;
    if (c.state.autoFilled) return;
    final fresh = c.state.picks.isEmpty;
    await c.autoFill(autoPicks(t, allCourses(), batch));
    final prefs = widget.prefs ?? (Hive.isBoxOpen('settingsBox') ? Hive.box('settingsBox') : null);
    if (!fresh || c.state.picks.isEmpty || prefs?.get(_seenKey) == true) return;
    _added = true;
    await prefs?.put(_seenKey, true);
  }

  CalendarState get _state => _cal?.state ?? const CalendarState();

  /// Runs a write on the overrides and redraws; a failure is said, not thrown.
  Future<void> _write(Future<void> Function(CalendarStore c) f) async {
    final c = _cal;
    if (c == null) return;
    try {
      await f(c);
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(problem(e))));
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _openCourse(String id) async {
    final c = allCourses().where((c) => c.id == id).firstOrNull;
    if (c == null) return;
    await openRoute(context, Routes.course(id), () => MarksPage(course: c));
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

    final top = <Widget>[
      _header(p),
      const SizedBox(height: 10),
      KeyedSubtree(
        key: tourKey('cal.views'),
        child: SegmentedTrack<_View>(
          tabs: const [
            (_View.month, 'Month'),
            (_View.week, 'Week'),
            (_View.day, 'Day'),
          ],
          value: _view,
          onChanged: (v) => setState(() => _view = v),
        ),
      ),
      const SizedBox(height: 10),
      _actions(p),
      ..._notices(p),
    ];

    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                Expanded(
                  child:
                      _view == _View.month
                          ? ListView(
                            padding: const EdgeInsets.fromLTRB(
                              18,
                              Space.lg,
                              18,
                              Space.lg,
                            ),
                            children: [
                              ...top,
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
                                      style: TypeScale.section.copyWith(
                                        color: p.text,
                                      ),
                                    ),
                                  ),
                                  if (_selected != null)
                                    TextButton(
                                      onPressed:
                                          () =>
                                              setState(() => _selected = null),
                                      child: Text(
                                        'Show all',
                                        style: TypeScale.button.copyWith(
                                          color: p.text,
                                        ),
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
                          )
                          : Padding(
                            padding: const EdgeInsets.fromLTRB(
                              18,
                              Space.lg,
                              18,
                              Space.sm,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ...top,
                                const SizedBox(height: Space.sm),
                                Expanded(child: _timeView(all)),
                              ],
                            ),
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

  /// Today and Add: Today only where a date is in view that can be left.
  Widget _actions(AppPalette p) => Wrap(
    spacing: Space.sm,
    runSpacing: Space.xs,
    children: [
      if (_view != _View.month)
        OutlinedPill(
          label: 'Today',
          onPressed: _focus == _todayStr ? null : () => setState(() => _focus = _todayStr),
        ),
      if (_tt != null && _cal != null)
        OutlinedPill(label: 'Add', onPressed: _add),
    ],
  );

  List<Widget> _notices(AppPalette p) {
    final published = _tt != null;
    return [
      if (_added) ...[
        const SizedBox(height: Space.sm),
        const Notice(
          text: TextSpan(
            text:
                'We added your courses from the timetable. You can add or '
                'remove courses, or switch sections.',
          ),
        ),
        const SizedBox(height: Space.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedPill(
            label: 'Got it',
            onPressed: () => setState(() => _added = false),
          ),
        ),
      ],
      if (!published && _error != null) ...[
        const SizedBox(height: Space.sm),
        Notice(text: TextSpan(text: problem(_error!)), warning: true),
        const SizedBox(height: Space.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedPill(
            label: 'Try again',
            onPressed: () {
              setState(() => _loaded = false);
              _load();
            },
          ),
        ),
      ] else if (!published && _loaded && _store != null && _campus != null)
        const Note('Timetable not published yet.'),
    ];
  }

  void _step(int dir) => setState(() {
    switch (_view) {
      case _View.month:
        _month = DateTime(_month.year, _month.month + dir);
        // The day label below would otherwise keep naming a date that's no
        // longer on screen (BUG-24).
        _selected = null;
      case _View.week:
        _focus = addDays(_focus, 7 * dir);
      case _View.day:
        _focus = addDays(_focus, dir);
    }
  });

  String get _unit => switch (_view) { _View.month => 'month', _View.week => 'week', _View.day => 'day' };

  String get _title {
    switch (_view) {
      case _View.month:
        return '${_months[_month.month - 1]} ${_month.year}';
      case _View.week:
        final a = parseDay(mondayOf(_focus)), b = a.add(const Duration(days: 6));
        final m = monthNames[b.month - 1].substring(0, 3);
        return a.month == b.month
            ? '${a.day} – ${b.day} $m ${b.year}'
            : '${a.day} ${monthNames[a.month - 1].substring(0, 3)} – ${b.day} $m ${b.year}';
      case _View.day:
        final d = parseDay(_focus);
        return '${dateLabel(_focus)} ${d.year}';
    }
  }

  /// Week (Mon-Sat, Sunday only when it has something) or Day.
  Widget _timeView(List<CalendarEntry> all) {
    final week = _view == _View.week;
    final from = week ? mondayOf(_focus) : _focus;
    final to = week ? addDays(from, 6) : _focus;
    final occs = expandOccurrences(_tt, _state, from: from, to: to);
    final academic = _cal == null || showAcademic(_cal!);
    final allDay = <String, List<AllDayItem>>{};
    void put(String d, AllDayItem i) => (allDay[d] ??= []).add(i);
    for (var d = from; d.compareTo(to) <= 0; d = addDays(d, 1)) {
      if (academic) {
        for (final e in eventsOn(_tt, d)) {
          if (e.kind == 'holiday') put(d, AllDayItem(e.title, 'holiday'));
        }
      }
      for (final e in all) {
        if (dayStr(e.date) == d) put(d, AllDayItem(e.label, 'eval', courseId: e.courseId));
      }
    }
    final timed = <Occurrence>[];
    for (final o in occs) {
      if (o.kind != OccKind.event) {
        timed.add(o);
      } else if (academic) {
        put(o.date, AllDayItem(o.title, 'event'));
      }
    }
    final dates = [
      if (week) ...[
        for (var i = 0; i < 6; i++) addDays(from, i),
        if (timed.any((o) => o.date == to) || (allDay[to] ?? const []).isNotEmpty) to,
      ] else
        from,
    ];
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v.abs() > 250) _step(v < 0 ? 1 : -1);
      },
      child: WeekView(
        key: ValueKey('$_view|$from'),
        dates: dates,
        occs: timed,
        allDay: allDay,
        today: _todayStr,
        now: () => widget.today ?? DateTime.now(),
        onBlock: _blockTap,
        onAllDay: (d) => _allDaySheet(d, allDay[d] ?? const []),
      ),
    );
  }

  Future<void> _allDaySheet(String date, List<AllDayItem> items) async {
    final id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder:
          (_) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, Space.md, 20, Space.lg),
              children: [
                Text(
                  dateLabel(date),
                  style: TypeScale.sheetTitle.copyWith(
                    color: AppPalette.of(context).text,
                  ),
                ),
                const SizedBox(height: Space.sm),
                for (final i in items)
                  CardRow(
                    title: i.label,
                    subtitle: switch (i.kind) {
                      'holiday' => 'Holiday',
                      'eval' => 'From Marks',
                      _ => 'Academic calendar',
                    },
                    onTap:
                        i.courseId == null
                            ? null
                            : () => Navigator.pop(context, i.courseId),
                  ),
              ],
            ),
          ),
    );
    if (id != null && mounted) await _openCourse(id);
  }

  Future<void> _add() async {
    final t = _tt;
    if (t == null) return;
    final r = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      builder:
          (_) => AddSheet(
            timetable: t,
            state: _state,
            suggested: takingNow(),
            today: _focus,
          ),
    );
    if (r is CoursePick) {
      await _write((c) => c.addCourse(r.course, r.keys));
      if (mounted && _view == _View.month) setState(() => _view = _View.week);
    } else if (r is CalendarCustom) {
      await _write((c) => c.addCustom(r));
    }
  }

  Future<void> _blockTap(Occurrence o) async {
    final act = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      builder:
          (_) => ClassSheet(
            occ: o,
            timetable: _tt,
            state: _state,
            canOpenCourse: allCourses().any((c) => c.id == o.courseId),
          ),
    );
    if (act == null || !mounted) return;
    final sk = o.sectionKey;
    if (act is String) {
      if (sk != null) await _write((c) => c.setSection(o.courseId, sk, act));
      return;
    }
    switch (act as ClassAct) {
      case ClassAct.open:
        await _openCourse(o.courseId);
      case ClassAct.changeTime:
        final sec = sectionOf(_tt, o);
        if (sec == null || sk == null) return;
        final r = await showModalBottomSheet<TimingsResult>(
          context: context,
          isScrollControlled: true,
          builder: (_) => TimingsSheet(sectionKey: sk, section: sec, state: _state),
        );
        if (r == null) return;
        await _write((c) async {
          if (r.set.isNotEmpty) await c.setSlotOverrides(r.set);
          for (final k in r.reset) {
            await c.resetSlot(k);
          }
        });
      case ClassAct.reset:
        await _write((c) async {
          for (final k in _state.slotOverrides.keys.toList()) {
            if (k.startsWith('$sk|')) await c.resetSlot(k);
          }
        });
      case ClassAct.repeat:
        final t = _tt;
        final cur = _state.repeatUntil[o.courseId] ?? t?.lastClassworkDay() ?? o.date;
        final d = await showDatePicker(
          context: context,
          initialDate: parseDate(cur),
          firstDate: parseDate(o.date),
          lastDate: parseDate(o.date).add(const Duration(days: 730)),
        );
        if (d != null) await _write((c) => c.setRepeatUntil(o.courseId, dayStr(d)));
      case ClassAct.removeOne:
        if (await confirmDialog(
          context,
          title: 'Remove this day?',
          body: '${o.courseId} on ${dateLabel(o.date)} leaves your calendar. '
              'Your marks and grades stay.',
          action: 'Remove',
          danger: true,
        )) {
          await _write((c) => c.removeOccurrence(slotOf(o), o.date));
        }
      case ClassAct.removeCourse:
        if (await confirmDialog(
          context,
          title: 'Remove ${o.courseId}?',
          body: 'Its classes and exams leave your calendar. Your marks and '
              'grades stay.',
          action: 'Remove',
          danger: true,
        )) {
          await _write((c) => c.removeCourse(o.courseId));
        }
      case ClassAct.hideExams:
        await _write((c) => c.setExamsShown(o.courseId, false));
      case ClassAct.removeCustom:
        if (await confirmDialog(
          context,
          title: 'Remove this event?',
          body: '${o.title} leaves your calendar.',
          action: 'Remove',
          danger: true,
        )) {
          await _write((c) => c.removeCustom(o.id.split('|')[1]));
        }
    }
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
            // Scales down rather than cutting "September 2026" at 320
            // (T9.1).
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                _title,
                maxLines: 1,
                style: TypeScale.title.copyWith(fontSize: 24, color: p.text),
              ),
            ),
          ],
        ),
      ),
      CircleIconButton(
        icon: Icons.chevron_left_rounded,
        tooltip: 'Previous $_unit',
        onPressed: () => _step(-1),
        size: 40,
      ),
      const SizedBox(width: 7),
      CircleIconButton(
        icon: Icons.chevron_right_rounded,
        tooltip: 'Next $_unit',
        onPressed: () => _step(1),
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
              // Board `Calendar`: days gone by fade back.
              : past
              ? p.navIcon
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
                            color: past ? p.navIcon : p.text,
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
