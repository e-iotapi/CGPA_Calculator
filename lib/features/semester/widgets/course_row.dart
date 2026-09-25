import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/grading/grade_scale.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/semester/semester_controller.dart';
import 'package:cgpa_calculator/features/semester/widgets/grade_scrubber.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/grade_chip.dart';
import 'package:flutter/material.dart';

/// Width of each grade column in compare mode, shared with its header.
const compareGradeWidth = 58.0;

/// One course. The title takes whatever width is left and ellipsizes; the
/// credits badge and grade chips never shrink.
class CourseRow extends StatelessWidget {
  const CourseRow({
    super.key,
    required this.course,
    required this.mode,
    this.onTap,
    this.onGradePicked,
  });

  final Course course;
  final SemesterMode mode;
  final VoidCallback? onTap;

  /// Called with the new stored grade after a hold-and-drag.
  final ValueChanged<int>? onGradePicked;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final compare = mode == SemesterMode.compare;

    final titles = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          course.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TypeScale.body.copyWith(color: p.text),
        ),
        const SizedBox(height: 2),
        Text(
          course.id,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TypeScale.caption.copyWith(color: p.textMuted),
        ),
      ],
    );

    return AppCard(
      onTap: compare ? null : onTap,
      child: Row(
        children: [
          if (!compare) ...[
            _CreditBadge(course.credits),
            const SizedBox(width: Space.md),
          ],
          Expanded(child: titles),
          const SizedBox(width: Space.md),
          if (compare) ...[
            SizedBox(width: compareGradeWidth, child: _chip(course.grade1)),
            const SizedBox(width: Space.sm),
            SizedBox(width: compareGradeWidth, child: _chip(course.grade2)),
          ] else
            GradeScrubber(
              grade: _grade,
              onPicked: (g) => onGradePicked?.call(g),
              child: _chip(_grade),
            ),
        ],
      ),
    );
  }

  int get _grade =>
      mode == SemesterMode.expected ? course.grade2 : course.grade1;

  static Widget _chip(int grade) {
    final ungraded = grade == GradeCode.clr;
    return Semantics(
      label: ungraded ? 'No grade' : 'Grade ${gradecalc(grade)}',
      excludeSemantics: true,
      child: GradeChip(ungraded ? '–' : gradecalc(grade), muted: ungraded),
    );
  }
}

class _CreditBadge extends StatelessWidget {
  const _CreditBadge(this.credits);
  final double credits;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Semantics(
      label: '${formatCredits(credits)} credits',
      excludeSemantics: true,
      child: Container(
        width: Sizes.creditBadge,
        height: Sizes.creditBadge,
        decoration: BoxDecoration(
          color: p.surfaceSunken,
          borderRadius: BorderRadius.circular(Radii.badge),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              formatCredits(credits),
              style: TextStyle(
                fontFamily: TypeScale.family,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1,
                color: p.text,
              ),
            ),
            Text(
              'CRED',
              style: TextStyle(
                fontFamily: TypeScale.family,
                fontSize: 7.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                color: p.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
