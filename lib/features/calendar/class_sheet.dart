import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/timetable/calendar_store.dart';
import 'package:cgpa_calculator/core/timetable/occurrences.dart';
import 'package:cgpa_calculator/core/timetable/timetable.dart';
import 'package:cgpa_calculator/features/calendar/cal_sheet.dart';
import 'package:cgpa_calculator/features/calendar/calendar_time.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/card_row.dart';
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
    final weeklyDays = <String>[];
    if (isClass && sec != null) {
      for (final sl in sec.slots) {
        final e = state.slotOverrides['${sec.key(o.courseId)}|${sl.id}'];
        weeklyDays.add(dayShort(e?.d ?? sl.d));
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
      if (isClass && sec != null) ...[
        if (weeklyDays.isNotEmpty) weeklyDays.join(', '),
        '${clockShort(o.start)}–${clockShort(o.end)}',
      ] else ...[
        if (sec != null) '${typeWord(sec.ty)} ${sec.no}',
        if (o.kind == OccKind.midsem) 'Midsem',
        if (o.kind == OccKind.compre) 'Compre',
      ],
    ].join(' · ');

    Widget action(String label, ClassAct a, {bool danger = false}) => Semantics(
      button: true,
      child: InkWell(
        onTap: () => Navigator.pop(context, a),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 36),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: TypeScale.body.copyWith(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: danger ? p.danger : p.text,
              ),
            ),
          ),
        ),
      ),
    );

    return CalSheet(
      title: o.title,
      subtitle: sub.isEmpty ? null : sub,
      footer: canOpenCourse && o.courseId.isNotEmpty
          ? SheetButton('Open course', onPressed: () => Navigator.pop(context, ClassAct.open))
          : null,
      children: [
        AppCard(
          radius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          child: Column(
            children: [
              for (final (n, r) in [
                ('DATE', dateLabel(o.date)),
                if (o.room != null && o.room!.isNotEmpty) ('ROOM', o.room!),
                if (weeklyDays.isNotEmpty) ('DAYS', weeklyDays.join(' · ')),
                ('TIME', '${clockShort(o.start)} – ${clockShort(o.end)}'),
                if (o.prof.isNotEmpty) ('TAUGHT BY', o.prof.join(', ')),
                if (until != null) ('REPEATS UNTIL', dateLabel(until)),
              ].indexed) ...[
                if (n > 0) Divider(height: 17, thickness: 1, color: p.divider),
                _line(p, r.$1, r.$2),
              ],
            ],
          ),
        ),
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
        if (others.length > 1) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Text('SECTION', style: _lbl(p)),
          ),
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
        ],
        if (isClass) ...[
          const SizedBox(height: 10),
          Semantics(
            button: true,
            child: Material(
              color: Colors.transparent,
              shape: StadiumBorder(side: BorderSide(color: p.outline)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Navigator.pop(context, ClassAct.changeTime),
                child: SizedBox(
                  height: 44,
                  child: Center(
                    child: Text(
                      'Change time, only for me',
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
          ),
          const SizedBox(height: 4),
          if (o.edited)
            Semantics(
              button: true,
              child: InkWell(
                onTap: () => Navigator.pop(context, ClassAct.reset),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 28),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Reset to the published time',
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
          action('Repeat until a different date', ClassAct.repeat),
          action('Remove this day only', ClassAct.removeOne),
          action('Remove from my timetable', ClassAct.removeCourse, danger: true),
          Text(
            'Removing only hides it from the timetable. Your grades stay.',
            style: TypeScale.caption.copyWith(fontSize: 10.5, height: 1.45, color: p.textMuted),
          ),
        ],
        if (o.kind == OccKind.midsem || o.kind == OccKind.compre)
          action('Hide this course\'s exams', ClassAct.hideExams),
        if (o.kind == OccKind.custom)
          action('Remove this event', ClassAct.removeCustom, danger: true),
      ],
    );
  }

  TextStyle _lbl(AppPalette p) => TypeScale.label.copyWith(
    fontSize: 10.5,
    letterSpacing: 0.5,
    color: p.textMuted,
  );

  Widget _line(AppPalette p, String label, String value) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: _lbl(p)),
      const SizedBox(width: Space.md),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: TypeScale.body.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: p.text,
          ),
        ),
      ),
    ],
  );
}
