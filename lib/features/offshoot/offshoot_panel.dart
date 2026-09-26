import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/grading/grade_scale.dart';
import 'package:cgpa_calculator/core/grading/offshoot.dart';
import 'package:cgpa_calculator/shared/layout/breakpoints.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/dashed_outline.dart';
import 'package:cgpa_calculator/shared/widgets/grade_chip.dart';
import 'package:cgpa_calculator/shared/widgets/pill_button.dart';
import 'package:flutter/material.dart';

/// The offshoot tab below the header: the total, the /50 or /60 toggle and
/// the six courses, each tickable. Purely presentational.
class OffshootPanel extends StatelessWidget {
  const OffshootPanel({
    super.key,
    required this.score,
    required this.onToggleCourse,
    required this.onOutOfSelected,
  });

  final OffshootScore score;

  /// Course id to tick or untick.
  final ValueChanged<String> onToggleCourse;

  /// 50 or 60.
  final ValueChanged<int> onOutOfSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = Breakpoints.of(c.maxWidth) != WindowSize.compact;
        final rows = [
          for (final r in _ordered()) ...[
            _CourseTile(
              row: r,
              counted: score.isCounted(r),
              reason: _reason(r),
              onTap: () => onToggleCourse(r.course.id),
            ),
            const SizedBox(height: Space.sm),
          ],
        ];
        final summary = [
          _Total(score: score, caption: _caption()),
          const SizedBox(height: Space.lg),
          _denominators(),
          const SizedBox(height: Space.lg),
        ];

        if (!wide) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.sm,
              Space.gutter,
              Space.xxl,
            ),
            children: [
              ...summary,
              _note(context),
              const SizedBox(height: Space.lg),
              ...rows,
            ],
          );
        }
        // Tablet and up: the total moves into a right rail, as the stat
        // cards do on the semester screen.
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Space.gutter,
                  Space.sm,
                  Space.gutter,
                  Space.xxl,
                ),
                children: [
                  _note(context),
                  const SizedBox(height: Space.lg),
                  ...rows,
                ],
              ),
            ),
            SizedBox(
              width: 260,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  0,
                  Space.sm,
                  Space.gutter,
                  0,
                ),
                child: Column(children: summary),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Counted courses best first, then the rest in their usual order.
  List<OffshootRow> _ordered() => [
    for (final id in score.counted)
      score.rows.firstWhere((r) => r.course.id == id),
    ...score.rows.where((r) => !score.isCounted(r)),
  ];

  Widget _denominators() => Row(
    children: [
      for (final v in offshootDenominators) ...[
        if (v != offshootDenominators.first) const SizedBox(width: 9),
        Expanded(
          child: PillButton(
            label: v == 50 ? 'Best 5 · / 50' : 'All 6 · / 60',
            selected: score.outOf == v,
            onPressed: () => onOutOfSelected(v),
            height: Sizes.iconButton,
            expand: true,
          ),
        ),
      ],
    ],
  );

  Widget _note(BuildContext context) => Text(
    'Grades come from your Actual profile. Untick any course a company '
    'does not ask for.',
    style: TypeScale.caption.copyWith(
      fontSize: 11.5,
      height: 1.5,
      color: AppPalette.of(context).textMuted,
    ),
  );

  String _caption() {
    final take = score.takeCount;
    final n = score.scorableCount;
    if (n < take) return '$n of the $take counted courses graded so far';
    final dropped = score.dropped.map((r) => r.course.id).join(', ');
    return [
      take == n
          ? 'All $n graded courses count'
          : 'Best $take of $n graded courses',
      if (dropped.isNotEmpty) 'dropping $dropped',
    ].join(' · ');
  }

  /// Why [r] is not counted, or null if it is.
  String? _reason(OffshootRow r) {
    if (score.isCounted(r)) return null;
    if (r.excluded) return 'Unticked · not counted';
    if (r.grade == null) return 'Not in your course list';
    if (!r.scorable) return 'No letter grade yet';
    return score.dropped.length == 1 && score.scorableCount == 6
        ? 'Not counted · lowest of the six'
        : 'Not counted · outside the best ${score.takeCount}';
  }
}

/// The hero card: total, a bar to the maximum, and what went into it.
class _Total extends StatelessWidget {
  const _Total({required this.score, required this.caption});

  final OffshootScore score;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Semantics(
      label: 'Offshoot total ${score.total} out of ${score.outOf}. $caption',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
        decoration: BoxDecoration(
          color: p.hero,
          borderRadius: BorderRadius.circular(Radii.hero),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${score.total}',
                    style: TypeScale.display.copyWith(
                      fontSize: 62,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -3,
                      height: 0.92,
                      color: p.onHero,
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Text(
                    '/ ${score.outOf}',
                    style: TypeScale.title.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                      color: p.onHeroMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: score.total / score.outOf,
                minHeight: 7,
                color: p.onHero,
                backgroundColor: p.onHero.withValues(alpha: 0.13),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              caption,
              style: TypeScale.caption.copyWith(
                fontSize: 12,
                color: p.onHeroMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One of the six courses. Counted rows are outlined solid; the rest are
/// dimmed with a dashed outline and say in words why they do not count.
class _CourseTile extends StatelessWidget {
  const _CourseTile({
    required this.row,
    required this.counted,
    required this.reason,
    required this.onTap,
  });

  final OffshootRow row;
  final bool counted;
  final String? reason;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final g = row.grade;
    final letter = g == null || g == GradeCode.clr ? '–' : gradecalc(g);
    final ticked = !row.excluded;

    final content = Row(
      children: [
        _Check(ticked: ticked),
        const SizedBox(width: Space.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.course.id,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TypeScale.body.copyWith(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: counted ? p.text : p.textMuted,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                reason ?? row.course.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TypeScale.caption.copyWith(
                  fontSize: 10.5,
                  color: p.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: Space.md),
        GradeChip(letter, muted: !counted),
      ],
    );

    final radius = Radii.row - 2;
    final card = AppCard(
      onTap: onTap,
      radius: radius,
      color: counted ? p.surface : p.surface.withValues(alpha: 0.55),
      border:
          counted
              ? BorderSide(color: p.isDark ? p.accent : p.border, width: 1.5)
              : null,
      child: content,
    );

    return MergeSemantics(
      child: Semantics(
        checked: ticked,
        label:
            '${row.course.title}, '
            '${g == null ? 'not taken' : 'grade $letter'}, '
            '${counted ? 'counted' : 'not counted'}',
        excludeSemantics: true,
        child:
            counted
                ? card
                : DashedOutline(color: p.outline, radius: radius, child: card),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.ticked});

  final bool ticked;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: ticked ? p.inverse : null,
        borderRadius: BorderRadius.circular(Radii.check),
        border: ticked ? null : Border.all(color: p.textMuted, width: 1.5),
      ),
      child:
          ticked
              ? Icon(Icons.check_rounded, size: 15, color: p.onInverse)
              : null,
    );
  }
}
