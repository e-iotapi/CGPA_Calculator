import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/grading/minor_progress.dart';
import 'package:cgpa_calculator/core/models/minors.dart';
import 'package:cgpa_calculator/features/stats/stats_page.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:flutter/material.dart';

/// The minor's requirements, one card each, for the Degree page's Minor tab.
class MinorView extends StatelessWidget {
  const MinorView({super.key, required this.progress});

  final MinorProgress progress;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final pr = progress;
    final m = pr.minor;
    String n(num v) => v == v.roundToDouble() ? '${v.round()}' : '$v';

    final cards = <_Need>[
      _Need('Core courses', pr.coreDone, m.core.length, 'all required'),
      for (final (i, pool) in m.pools.indexed)
        if (pool.min > 0)
          _Need(
            pool.name ?? 'Electives',
            pr.doneIn(i),
            pool.min,
            'at least ${pool.min}',
          ),
      _Need(
        'Electives',
        pr.electivesDone,
        m.electives,
        'at least ${m.electives}',
      ),
      _Need('Courses', pr.courses, m.courses, 'at least ${m.courses}'),
      _Need('Units', pr.units, m.units, 'at least ${m.units}'),
    ];
    final gpa = pr.gpa;
    final toClear = [
      for (final c in cards)
        if (c.done < c.need) '${n(c.need - c.done)} ${c.label.toLowerCase()}',
      if (gpa != null && gpa < minorMinGpa) 'GPA to $minorMinGpa',
    ];

    return StatsBody(
      footer: StatsFooter(
        label: 'STILL TO CLEAR',
        value:
            pr.complete
                ? 'Every requirement met'
                : toClear.isEmpty
                ? 'Grades still to come'
                : toClear.join(' · '),
        trailing: Icon(
          pr.complete ? Icons.check_circle_rounded : Icons.school_rounded,
          color: p.hero,
        ),
      ),
      children: [
        Text(
          'Minor in ${m.name}',
          style: TypeScale.section.copyWith(color: p.text),
        ),
        const SizedBox(height: Space.sm),
        for (final c in cards) ...[
          _NeedCard(c),
          const SizedBox(height: Space.sm),
        ],
        _NeedCard(
          _Need(
            'GPA in the minor',
            gpa ?? 0,
            minorMinGpa,
            gpa == null
                ? 'no grades yet'
                : '${gpa.toStringAsFixed(2)} of $minorMinGpa needed',
          ),
          fraction: false,
        ),
        const SizedBox(height: Space.md),
        Text(
          [
            'At most $minorOverlapCourses courses ($minorOverlapUnits units) '
                'that your degree also requires can count, and one project.',
            if (pr.overlapDropped > 0)
              '${pr.overlapDropped} of yours past that are left out.',
            if (pr.projectsDropped > 0) 'A second project is left out.',
          ].join(' '),
          style: TypeScale.caption.copyWith(
            fontSize: 11,
            height: 1.5,
            color: p.textMuted,
          ),
        ),
      ],
    );
  }
}

class _Need {
  const _Need(this.label, this.done, this.need, this.note);
  final String label;
  final num done;
  final num need;
  final String note;
}

class _NeedCard extends StatelessWidget {
  const _NeedCard(this.c, {this.fraction = true});

  final _Need c;

  /// Show "done / need"; off for the GPA, which the note says in words.
  final bool fraction;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final met = c.done >= c.need;
    String n(num v) => v == v.roundToDouble() ? '${v.round()}' : '$v';
    final title = TypeScale.body.copyWith(
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
      color: p.text,
    );
    return Semantics(
      label:
          '${c.label}: ${fraction ? '${n(c.done)} of ${n(c.need)}, ' : ''}'
          '${c.note}',
      excludeSemantics: true,
      child: AppCard(
        radius: 18,
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(c.label, style: title)),
                if (met) ...[
                  Icon(Icons.check_circle_rounded, size: 14, color: p.ahead),
                  const SizedBox(width: 4),
                ],
                if (fraction)
                  Text(
                    '${n(c.done)} / ${n(c.need)}',
                    style: title.copyWith(fontSize: 11),
                  ),
              ],
            ),
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(2.5),
              child: LinearProgressIndicator(
                value: c.need == 0 ? 1 : (c.done / c.need).clamp(0.0, 1.0),
                minHeight: 5,
                color: met ? p.ahead : p.inverse,
                backgroundColor: p.divider,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              c.note,
              style: TypeScale.caption.copyWith(
                fontSize: 10,
                color: p.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
