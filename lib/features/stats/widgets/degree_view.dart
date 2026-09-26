import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/grading/requirements.dart';
import 'package:cgpa_calculator/core/models/elective.dart';
import 'package:cgpa_calculator/features/semester/semester_controller.dart';
import 'package:cgpa_calculator/features/stats/stats_controller.dart';
import 'package:cgpa_calculator/features/stats/stats_page.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/dashed_outline.dart';
import 'package:flutter/material.dart';

/// The degree audit: credits earned overall, then one card per requirement.
class DegreeView extends StatelessWidget {
  const DegreeView({super.key, required this.data, this.onEditTotal});

  final StatsData data;

  /// Tapping the credits card: set the degree's total by hand.
  final VoidCallback? onEditTotal;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final a = data.audit;
    if (a.categories.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(Space.gutter),
        child: Text(
          'Choose your discipline in Settings to see degree progress.',
          style: TypeScale.body.copyWith(color: p.textMuted),
        ),
      );
    }
    final total = a.totalCredits + data.degreeLeft;
    final pct = (data.degreeShare * 100).round();
    final toClear = [
      for (final c in a.categories)
        if (c.requiredCourses != null && c.courses < c.requiredCourses!)
          '${c.requiredCourses! - c.courses} ${_short(c)}',
    ];
    return StatsBody(
      footer: StatsFooter(
        label: 'STILL TO CLEAR',
        value: toClear.isEmpty ? 'Every requirement met' : toClear.join(' · '),
        trailing: Text(
          '$pct%',
          style: TypeScale.title.copyWith(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: p.hero,
          ),
        ),
      ),
      children: [
        Semantics(
          label:
              'Credits earned ${formatCredits(a.totalCredits)} of '
              '${formatCredits(total)}, ${formatCredits(data.degreeLeft)} left',
          button: onEditTotal != null,
          hint: onEditTotal == null ? null : 'Change the total',
          excludeSemantics: true,
          child: Material(
            color: p.hero,
            borderRadius: BorderRadius.circular(Radii.card),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onEditTotal,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 17, 18, 17),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'CREDITS EARNED',
                      style: TypeScale.label.copyWith(color: p.onHeroMuted),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          formatCredits(a.totalCredits),
                          style: TypeScale.display.copyWith(
                            fontWeight: FontWeight.w800,
                            color: p.onHero,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'of ${formatCredits(total)}',
                          style: TypeScale.section.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: p.onHeroMuted,
                          ),
                        ),
                        if (onEditTotal != null) ...[
                          const SizedBox(width: 5),
                          Icon(
                            Icons.edit_rounded,
                            size: 14,
                            color: p.onHeroMuted,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 9),
                    _Bar(
                      value: data.degreeShare,
                      color: p.onHero,
                      track: p.onHero.withValues(alpha: 0.13),
                      height: 7,
                    ),
                    const SizedBox(height: 9),
                    Text(
                      '${formatCredits(data.degreeLeft)} credits left'
                      '${data.totalSet != null ? ' · total set by you' : ''}',
                      style: TypeScale.caption.copyWith(
                        fontSize: 10.5,
                        color: p.onHeroMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 13),
        Text(
          'By requirement',
          style: TypeScale.section.copyWith(color: p.text),
        ),
        const SizedBox(height: Space.sm),
        for (final c in a.categories) ...[
          _CategoryCard(c: c),
          const SizedBox(height: Space.sm),
        ],
      ],
    );
  }

  String _short(AuditCategory c) => switch (c.category) {
    Elective.cdc1 || Elective.cdc2 => 'core',
    Elective.del1 => 'DEl 1',
    Elective.del2 => 'DEl 2',
    Elective.humanity => 'HuEl',
    Elective.open => 'OpEl',
  };
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.c});

  final AuditCategory c;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final title = TypeScale.body.copyWith(
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
      color: c.notStarted ? p.textMuted : p.text,
    );
    final small = TypeScale.caption.copyWith(
      fontSize: 10.5,
      color: p.textMuted,
    );
    final cr = formatCredits(c.credits);
    final courses = '${c.courses} course${c.courses == 1 ? '' : 's'}';

    // No requirement to measure against: just the totals.
    if (c.requiredCredits == null) {
      return AppCard(
        radius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Expanded(child: Text(c.label, style: title)),
            Text(courses, style: small),
            const SizedBox(width: Space.sm),
            Text('$cr cr', style: title.copyWith(fontSize: 11)),
          ],
        ),
      );
    }

    final req = c.requiredCredits!;
    final reqCourses = c.requiredCourses ?? 0;
    final left = req - c.credits;
    final status =
        c.complete
            ? 'complete'
            : c.notStarted
            ? 'not started'
            : left > 0
            ? '${formatCredits(left)} credits to go'
            : '${reqCourses - c.courses} to choose';
    final green = p.isDark ? p.ahead : const Color(0xFF2C7A62);
    final card = AppCard(
      radius: 18,
      color: c.notStarted ? p.surface.withValues(alpha: 0.55) : null,
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(c.label, style: title)),
              if (c.complete) ...[
                Icon(Icons.check_circle_rounded, size: 14, color: p.ahead),
                const SizedBox(width: 4),
              ],
              Text(
                '$cr / $req cr',
                style: title.copyWith(
                  fontSize: 11,
                  color: c.complete ? p.ahead : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          _Bar(
            value: req == 0 ? 1 : c.credits / req,
            color: c.complete ? green : p.inverse,
            track: p.divider,
            height: 5,
          ),
          const SizedBox(height: 7),
          Text(
            '${c.courses} of $reqCourses courses · $status',
            style: small.copyWith(fontSize: 10),
          ),
        ],
      ),
    );
    return Semantics(
      label:
          '${c.label}: $cr of $req credits, '
          '${c.courses} of $reqCourses courses, $status',
      excludeSemantics: true,
      child:
          c.notStarted
              ? DashedOutline(color: p.outline, radius: 18, child: card)
              : card,
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.value,
    required this.color,
    required this.track,
    required this.height,
  });

  final double value;
  final Color color;
  final Color track;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(height / 2),
    child: LinearProgressIndicator(
      value: value.clamp(0.0, 1.0),
      minHeight: height,
      color: color,
      backgroundColor: track,
    ),
  );
}
