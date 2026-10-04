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
/// published slot, saved together.
class TimingsSheet extends StatefulWidget {
  const TimingsSheet({super.key, required this.sectionKey, required this.section, required this.state});

  final String sectionKey;
  final TtSection section;
  final CalendarState state;

  @override
  State<TimingsSheet> createState() => _TimingsSheetState();
}

class _Row {
  _Row(this.slot, this.key, SlotEdit? e)
    : day = e?.d ?? slot.d,
      start = TextEditingController(text: clock(e?.s ?? slot.s)),
      end = TextEditingController(text: clock(e?.e ?? slot.e)),
      edited = e != null;
  final TtSlot slot;
  final String key;
  final bool edited;
  int day;
  final TextEditingController start, end;
}

class _TimingsSheetState extends State<TimingsSheet> {
  late final List<_Row> _rows = [
    for (final sl in widget.section.slots)
      _Row(sl, '${widget.sectionKey}|${sl.id}', widget.state.slotOverrides['${widget.sectionKey}|${sl.id}']),
  ];
  final _errors = <String, String>{};

  /// Edits whose published slot is gone: only "Reset" applies to them.
  late final _gone = [
    for (final k in widget.state.slotOverrides.keys)
      if (k.startsWith('${widget.sectionKey}|') && !_rows.any((r) => r.key == k)) k,
  ];

  @override
  void dispose() {
    for (final r in _rows) {
      r.start.dispose();
      r.end.dispose();
    }
    super.dispose();
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
      } else if (r.day == r.slot.d && s == r.slot.s && e == r.slot.e) {
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
    final course = widget.sectionKey.split('|').first;
    return CalSheet(
      title: 'Change time',
      subtitle: '$course · only for you',
      footer: SheetButton('Save', onPressed: _save),
      children: [
        for (final r in _rows) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Published ${dayShort(r.slot.d)} ${span(r.slot.s, r.slot.e)}',
                    style: TypeScale.caption.copyWith(color: p.textMuted),
                  ),
                ),
                if (r.edited) const TagBadge('Your time', tone: TagTone.yours),
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
                  for (var d = 1; d <= 6; d++)
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
          if (_errors[r.key] case final e?)
            Padding(
              padding: const EdgeInsets.only(top: Space.xs),
              child: Text(e, style: TypeScale.caption.copyWith(color: p.danger)),
            ),
          const SizedBox(height: 10),
        ],
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
    );
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
}
