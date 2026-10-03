import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/timetable/calendar_store.dart';
import 'package:cgpa_calculator/core/timetable/timetable.dart';
import 'package:cgpa_calculator/features/calendar/calendar_time.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
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
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 10, 20, Space.lg + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Change time', style: TypeScale.sheetTitle.copyWith(color: p.text)),
            Text(
              'Only on your calendar. The published timetable stays as it is.',
              style: TypeScale.caption.copyWith(color: p.textMuted),
            ),
            const SizedBox(height: Space.md),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final r in _rows) ...[
                    Row(
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
                    const SizedBox(height: Space.xs),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _day(p, r),
                        const SizedBox(width: Space.sm),
                        Expanded(child: AppTextField(controller: r.start, label: 'Start', dense: true)),
                        const SizedBox(width: Space.sm),
                        Expanded(child: AppTextField(controller: r.end, label: 'End', dense: true)),
                      ],
                    ),
                    if (_errors[r.key] case final e?)
                      Padding(
                        padding: const EdgeInsets.only(top: Space.xs),
                        child: Text(e, style: TypeScale.caption.copyWith(color: p.behind)),
                      ),
                    const SizedBox(height: Space.md),
                  ],
                ],
              ),
            ),
            if (_gone.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.sm),
                child: Text(
                  'Your time (published time changed). Reset to follow the new timetable.',
                  style: TypeScale.caption.copyWith(color: p.textMuted),
                ),
              ),
            PrimaryButton(label: 'Save', onPressed: _save),
            if (_rows.any((r) => r.edited) || _gone.isNotEmpty)
              TextButton(
                onPressed: _restore,
                child: Text('Reset to published', style: TypeScale.button.copyWith(color: p.text)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _day(AppPalette p, _Row r) => SizedBox(
    height: Sizes.minTouch + 4,
    child: DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        value: r.day,
        dropdownColor: p.surface,
        style: TypeScale.body.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: p.text),
        items: [for (var d = 1; d <= 6; d++) DropdownMenuItem(value: d, child: Text(dayShort(d)))],
        onChanged: (v) => setState(() => r.day = v ?? r.day),
      ),
    ),
  );
}
