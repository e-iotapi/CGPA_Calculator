import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/timetable/calendar_store.dart';
import 'package:cgpa_calculator/core/timetable/timetable.dart';
import 'package:cgpa_calculator/features/calendar/cal_sheet.dart';
import 'package:cgpa_calculator/features/calendar/calendar_time.dart';
import 'package:cgpa_calculator/shared/widgets/tag_badge.dart';
import 'package:flutter/material.dart';

/// What the timings sheet asks for: rows to set and rows put back to the
/// published time (both keyed `<sectionKey>|<slotId>`).
typedef TimingsResult = ({Map<String, SlotEdit> set, List<String> reset});

/// Change the times of one section for this student only: one row per
/// published slot, saved together. [TimingsSheet.own] is the same sheet for a
/// course the timetable lacks: the student types each weekly time (pops a
/// `List<OwnTime>`).
class TimingsSheet extends StatefulWidget {
  const TimingsSheet({super.key, required String this.sectionKey, required TtSection this.section, required CalendarState this.state})
    : course = null,
      existing = const [];

  const TimingsSheet.own({super.key, required String this.course, this.existing = const []})
    : sectionKey = null,
      section = null,
      state = null;

  final String? sectionKey, course;
  final TtSection? section;
  final CalendarState? state;

  /// [TimingsSheet.own]: the times saved before, to edit.
  final List<CalendarCustom> existing;

  @override
  State<TimingsSheet> createState() => _TimingsSheetState();
}

class _Row {
  _Row(TtSlot this.slot, this.key, SlotEdit? e)
    : day = e?.d ?? slot.d,
      start = TextEditingController(text: clock(e?.s ?? slot.s)),
      end = TextEditingController(text: clock(e?.e ?? slot.e)),
      room = TextEditingController(),
      edited = e != null;

  /// A time the student types: no published slot behind it.
  _Row.own({this.day = 1, int s = 540, int e = 600, String room = ''})
    : slot = null,
      key = '',
      start = TextEditingController(text: clock(s)),
      end = TextEditingController(text: clock(e)),
      room = TextEditingController(text: room),
      edited = false;
  final TtSlot? slot;
  final String key;
  final bool edited;
  int day;
  final TextEditingController start, end, room;
}

class _TimingsSheetState extends State<TimingsSheet> {
  bool get _own => widget.course != null;

  late final List<_Row> _rows = _own
      ? [
          for (final c in widget.existing) _Row.own(day: c.d, s: c.s, e: c.e, room: c.room),
          if (widget.existing.isEmpty) _Row.own(),
        ]
      : [
          for (final sl in widget.section!.slots)
            _Row(sl, '${widget.sectionKey}|${sl.id}', widget.state!.slotOverrides['${widget.sectionKey}|${sl.id}']),
        ];
  final _errors = <String, String>{};

  /// Edits whose published slot is gone: only "Reset" applies to them.
  late final _gone = [
    for (final k in widget.state?.slotOverrides.keys ?? const <String>[])
      if (k.startsWith('${widget.sectionKey}|') && !_rows.any((r) => r.key == k)) k,
  ];

  @override
  void dispose() {
    for (final r in _rows) {
      r.start.dispose();
      r.end.dispose();
      r.room.dispose();
    }
    super.dispose();
  }

  void _saveOwn() {
    final out = <OwnTime>[];
    _errors.clear();
    for (final (i, r) in _rows.indexed) {
      final s = parseClock(r.start.text), e = parseClock(r.end.text);
      if (s == null || e == null) {
        _errors['$i'] = 'Use a time like 9:00 AM';
      } else if (e <= s) {
        _errors['$i'] = 'End must be after start';
      } else {
        out.add((d: r.day, s: s, e: e, room: r.room.text.trim()));
      }
    }
    if (_errors.isNotEmpty) return setState(() {});
    Navigator.pop<List<OwnTime>>(context, out);
  }

  void _save() {
    final set = <String, SlotEdit>{};
    final reset = <String>[];
    _errors.clear();
    for (final r in _rows) {
      final s = parseClock(r.start.text), e = parseClock(r.end.text);
      if (s == null || e == null) {
        _errors[r.key] = 'Use a time like 9:00 AM';
      } else if (e <= s) {
        _errors[r.key] = 'End must be after start';
      } else if (r.day == r.slot!.d && s == r.slot!.s && e == r.slot!.e) {
        if (r.edited) reset.add(r.key);
      } else {
        set[r.key] = (d: r.day, s: s, e: e);
      }
    }
    if (_errors.isNotEmpty) return setState(() {});
    Navigator.pop<TimingsResult>(context, (set: set, reset: reset));
  }

  void _restore() => Navigator.pop<TimingsResult>(context, (
    set: const {},
    reset: [for (final r in _rows) if (r.edited) r.key, ..._gone],
  ));

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final course = widget.course ?? widget.sectionKey!.split('|').first;
    return CalSheet(
      title: _own ? 'Class times' : 'Change time',
      subtitle: '$course · only for you',
      footer: SheetButton('Save', onPressed: _own ? _saveOwn : _save),
      children: [
        for (final (i, r) in _rows.indexed) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _own
                        ? 'Time ${i + 1}'
                        : 'Published ${dayShort(r.slot!.d)} ${span(r.slot!.s, r.slot!.e)}',
                    style: TypeScale.caption.copyWith(color: p.textMuted),
                  ),
                ),
                if (r.edited) const TagBadge('Your time', tone: TagTone.yours),
                if (_own && _rows.length > 1)
                  Semantics(
                    button: true,
                    label: 'Remove time ${i + 1}',
                    child: InkWell(
                      onTap: () => setState(() => _rows.removeAt(i).room.dispose()),
                      child: SizedBox.square(
                        dimension: Sizes.minTouch,
                        child: Icon(Icons.close_rounded, size: 17, color: p.icon),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _field(
            p,
            'Day',
            DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: r.day,
                isExpanded: true,
                isDense: true,
                icon: _chevron(p),
                dropdownColor: p.surface,
                style: _ink(p),
                items: [
                  for (var d = 1; d <= 7; d++)
                    DropdownMenuItem(value: d, child: Text(dayNames[d - 1])),
                ],
                onChanged: (v) => setState(() => r.day = v ?? r.day),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _field(p, 'Start', _time(p, r.start, 'Start')),
          const SizedBox(height: 10),
          _field(p, 'End', _time(p, r.end, 'End')),
          if (_own) ...[
            const SizedBox(height: 10),
            _field(p, 'Room (optional)', _time(p, r.room, 'Room')),
          ],
          if (_errors[_own ? '$i' : r.key] case final e?)
            Padding(
              padding: const EdgeInsets.only(top: Space.xs),
              child: Text(e, style: TypeScale.caption.copyWith(color: p.danger)),
            ),
          const SizedBox(height: 10),
        ],
        if (_own) ...[
          Semantics(
            button: true,
            child: InkWell(
              onTap: () => setState(() => _rows.add(_Row.own())),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: Sizes.minTouch),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Add another day',
                    style: TypeScale.body.copyWith(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: p.text,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Text(
            'This course has no published timetable. These times stay on this device.',
            style: TypeScale.caption.copyWith(fontSize: 10.5, height: 1.45, color: p.textMuted),
          ),
        ] else ...[
          if (_gone.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: Text(
                'Your time (published time changed). Reset to follow the new timetable.',
                style: TypeScale.caption.copyWith(color: p.textMuted),
              ),
            ),
          Text(
            'The published time stays for everyone else. You can reset to it any time.',
            style: TypeScale.caption.copyWith(fontSize: 10.5, height: 1.45, color: p.textMuted),
          ),
          if (_rows.any((r) => r.edited) || _gone.isNotEmpty)
            Semantics(
              button: true,
              child: InkWell(
                onTap: _restore,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: Sizes.minTouch),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Reset to published',
                      style: TypeScale.body.copyWith(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: p.accent,
                        decoration: TextDecoration.underline,
                        decorationColor: p.accent,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

TextStyle _ink(AppPalette p) =>
    TypeScale.body.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: p.text);

Widget _chevron(AppPalette p) =>
    Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: p.textMuted);

/// The board's field: a small upper-case label over a white 46-tall box.
Widget _field(AppPalette p, String label, Widget child) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(
        label.toUpperCase(),
        style: TypeScale.label.copyWith(fontSize: 10.5, letterSpacing: 0.5, color: p.textMuted),
      ),
    ),
    Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.outline),
      ),
      child: child,
    ),
  ],
);

Widget _time(AppPalette p, TextEditingController c, String label) => Semantics(
  label: label,
  textField: true,
  child: TextField(
    controller: c,
    style: _ink(p),
    cursorColor: p.text,
    decoration: const InputDecoration(
      isDense: true,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      filled: false,
      contentPadding: EdgeInsets.zero,
    ),
  ),
);

/// Give a date from Marks a start and end on the calendar page: pops
/// `(s: , e: )` (a [MarkTime]), `'clear'` to go back to all day, or `'open'`
/// for the course.
class MarkTimeSheet extends StatefulWidget {
  const MarkTimeSheet({
    super.key,
    required this.courseId,
    required this.label,
    required this.date,
    this.current,
    this.canOpenCourse = false,
  });

  final String courseId, label, date;
  final MarkTime? current;
  final bool canOpenCourse;

  @override
  State<MarkTimeSheet> createState() => _MarkTimeSheetState();
}

class _MarkTimeSheetState extends State<MarkTimeSheet> {
  late final _start = TextEditingController(text: clock(widget.current?.s ?? 540)),
      _end = TextEditingController(text: clock(widget.current?.e ?? 660));
  String? _error;

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  void _save() {
    final s = parseClock(_start.text), e = parseClock(_end.text);
    if (s == null || e == null) return setState(() => _error = 'Use a time like 9:00 AM');
    if (e <= s) return setState(() => _error = 'End must be after start');
    Navigator.pop<MarkTime>(context, (s: s, e: e));
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    Widget link(String label, String result) => Semantics(
      button: true,
      child: InkWell(
        onTap: () => Navigator.pop<String>(context, result),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Sizes.minTouch),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: TypeScale.body.copyWith(fontSize: 12.5, fontWeight: FontWeight.w700, color: p.text),
            ),
          ),
        ),
      ),
    );
    return CalSheet(
      title: '${widget.courseId} ${widget.label}',
      subtitle: '${dateLabel(widget.date)} · Added by you',
      footer: SheetButton('Save time', onPressed: _save),
      children: [
        Text(
          'You entered this date in Marks, so it has no time yet. Add one to see it on the grid.',
          style: TypeScale.caption.copyWith(fontSize: 10.5, height: 1.45, color: p.textMuted),
        ),
        const SizedBox(height: 12),
        _field(p, 'Start', _time(p, _start, 'Start')),
        const SizedBox(height: 10),
        _field(p, 'End', _time(p, _end, 'End')),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: Space.xs),
            child: Text(_error!, style: TypeScale.caption.copyWith(color: p.danger)),
          ),
        const SizedBox(height: 6),
        if (widget.current != null) link('Back to all day', 'clear'),
        if (widget.canOpenCourse) link('Open course', 'open'),
      ],
    );
  }
}
