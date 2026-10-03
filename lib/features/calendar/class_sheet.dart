import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/timetable/calendar_store.dart';
import 'package:cgpa_calculator/core/timetable/occurrences.dart';
import 'package:cgpa_calculator/core/timetable/timetable.dart';
import 'package:cgpa_calculator/features/calendar/calendar_time.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/card_row.dart';
import 'package:cgpa_calculator/shared/widgets/outlined_pill.dart';
import 'package:cgpa_calculator/shared/widgets/tag_badge.dart';
import 'package:flutter/material.dart';

/// What the student chose in the sheet; the Calendar page does it. Picking another
/// section pops the new section's key (a String) instead.
enum ClassAct {
  open,
  changeTime,
  reset,
  repeat,
  removeOne,
  removeCourse,
  hideExams,
  removeCustom,
}

/// The section [o] belongs to in [t], or null.
TtSection? sectionOf(Timetable? t, Occurrence o) {
  final c = t?.courses[o.courseId];
  if (c == null) return null;
  for (final s in c.sections) {
    if (s.key(c.id) == o.sectionKey) return s;
  }
  return null;
}

/// Section type as a word: L Lecture, T Tutorial, P Practical.
String typeWord(String ty) =>
    switch (ty) { 'L' => 'Lecture', 'T' => 'Tutorial', 'P' => 'Practical', _ => ty };

/// One class, one exam or one event: details and what can be done to it.
class ClassSheet extends StatelessWidget {
  const ClassSheet({
    super.key,
    required this.occ,
    required this.timetable,
    required this.state,
    required this.canOpenCourse,
  });

  final Occurrence occ;
  final Timetable? timetable;
  final CalendarState state;
  final bool canOpenCourse;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final o = occ;
    final sec = sectionOf(timetable, o);
    final isClass = o.kind == OccKind.cls;
    final weekly = <String>[];
    if (isClass && sec != null) {
      for (final sl in sec.slots) {
        final e = state.slotOverrides['${sec.key(o.courseId)}|${sl.id}'];
        weekly.add(
          '${dayShort(e?.d ?? sl.d)} ${span(e?.s ?? sl.s, e?.e ?? sl.e)}',
        );
      }
    }
    final until = isClass
        ? state.repeatUntil[o.courseId] ?? timetable?.lastClassworkDay()
        : null;
    final course = timetable?.courses[o.courseId];
    final others = isClass && sec != null && course != null
        ? course.sections.where((s) => s.ty == sec.ty).toList()
        : const <TtSection>[];
    final sub = [
      if (o.courseId.isNotEmpty) o.courseId,
      if (sec != null) '${typeWord(sec.ty)} ${sec.no}',
      if (o.kind == OccKind.midsem) 'Midsem',
      if (o.kind == OccKind.compre) 'Compre',
    ].join(' · ');

    Widget action(String label, ClassAct a, {bool danger = false}) => Semantics(
      button: true,
      child: InkWell(
        onTap: () => Navigator.pop(context, a),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Sizes.minTouch),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: TypeScale.button.copyWith(color: danger ? p.behind : p.text),
            ),
          ),
        ),
      ),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, Space.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: p.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  Text(o.title, style: TypeScale.sheetTitle.copyWith(color: p.text)),
                  if (sub.isNotEmpty)
                    Text(sub, style: TypeScale.caption.copyWith(color: p.textMuted)),
                  const SizedBox(height: Space.md),
                  _line(p, dateLabel(o.date), span(o.start, o.end)),
                  if (o.room != null && o.room!.isNotEmpty) _line(p, 'Room', o.room!),
                  if (o.prof.isNotEmpty) _line(p, 'Taught by', o.prof.join(', ')),
                  if (weekly.isNotEmpty) _line(p, 'Every week', weekly.join(', ')),
                  if (until != null) _line(p, 'Repeats until', dateLabel(until)),
                  if (o.edited)
                    Padding(
                      padding: const EdgeInsets.only(top: Space.sm),
                      child: Row(
                        children: [
                          const TagBadge('Your time', tone: TagTone.yours),
                          if (o.stale) ...[
                            const SizedBox(width: Space.sm),
                            Expanded(
                              child: Text(
                                'Published time changed',
                                style: TypeScale.caption.copyWith(color: p.textMuted),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: Space.md),
                  if (canOpenCourse && o.courseId.isNotEmpty)
                    OutlinedPill(
                      label: 'Open course',
                      onPressed: () => Navigator.pop(context, ClassAct.open),
                    ),
                  if (others.length > 1) ...[
                    Text('Section', style: TypeScale.label.copyWith(color: p.textMuted)),
                    const SizedBox(height: Space.xs),
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (final s in others)
                            CardRow(
                              title: '${typeWord(s.ty)} ${s.no}${s.prof.isEmpty ? '' : ' · ${s.prof.join(', ')}'}',
                              subtitle: [
                                for (final sl in s.slots) '${dayShort(sl.d)} ${clockShort(sl.s)}-${clockShort(sl.e)}',
                                if (s.room != null && s.room!.isNotEmpty) s.room!,
                              ].join(' · '),
                              titleLines: 2,
                              trailing: Icon(
                                s == sec ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                                size: 20,
                                color: p.text,
                              ),
                              onTap: s == sec ? null : () => Navigator.pop(context, s.key(course!.id)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Space.sm),
                  ],
                  if (isClass) ...[
                    const SizedBox(height: Space.sm),
                    PrimaryButton(
                      label: 'Change time, only for me',
                      onPressed: () => Navigator.pop(context, ClassAct.changeTime),
                    ),
                    action('Repeat until a different date', ClassAct.repeat),
                    if (o.edited) action('Reset to the published time', ClassAct.reset),
                    action('Remove this day only', ClassAct.removeOne),
                    action('Remove from my timetable', ClassAct.removeCourse, danger: true),
                  ],
                  if (o.kind == OccKind.midsem || o.kind == OccKind.compre)
                    action('Hide this course\'s exams', ClassAct.hideExams),
                  if (o.kind == OccKind.custom)
                    action('Remove this event', ClassAct.removeCustom, danger: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(AppPalette p, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: Space.xs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(label, style: TypeScale.caption.copyWith(color: p.textMuted)),
        ),
        Expanded(
          child: Text(
            value,
            style: TypeScale.body.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: p.text,
            ),
          ),
        ),
      ],
    ),
  );
}
