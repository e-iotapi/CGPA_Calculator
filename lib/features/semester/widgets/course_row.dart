import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/grading/grade_scale.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/semester/semester_controller.dart';
import 'package:cgpa_calculator/features/semester/widgets/grade_menu.dart';
import 'package:cgpa_calculator/features/semester/widgets/grade_scrubber.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/core/models/course_names.dart';
import 'package:cgpa_calculator/features/marks/marks_format.dart';
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
    this.classDelta,
    this.compared = (1, 2),
    this.onCompareGradePicked,
  });

  final Course course;
  final SemesterMode mode;
  final VoidCallback? onTap;

  /// Called with the new stored grade after a hold-and-drag.
  final ValueChanged<int>? onGradePicked;

  /// Marks minus the class average; null shows nothing.
  final double? classDelta;

  /// The two profile ids Compare shows.
  final (int, int) compared;

  /// Called with a profile id and its new grade from a Compare chip.
  final void Function(int profile, int grade)? onCompareGradePicked;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final compare = mode == SemesterMode.compare;

    final titles = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          displayTitle(course.id, course.title),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TypeScale.body.copyWith(color: p.text),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Flexible(
              child: Text(
                course.id,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TypeScale.caption.copyWith(color: p.textMuted),
              ),
            ),
            if (classDelta case final d?) ...[
              const SizedBox(width: 3),
              // Arrow and word carry it; the colour only reinforces.
              Icon(deltaIcon(d), size: 16, color: d < 0 ? p.behind : p.ahead),
              Text(
                deltaWords(d),
                maxLines: 1,
                style: TypeScale.caption.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: d < 0 ? p.behind : p.ahead,
                ),
              ),
            ],
          ],
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
            SizedBox(width: compareGradeWidth, child: _scrubber(compared.$1)),
            const SizedBox(width: Space.sm),
            SizedBox(width: compareGradeWidth, child: _scrubber(compared.$2)),
          ] else
            _scrubber(null),
        ],
      ),
    );
  }

  int get _grade =>
      mode == SemesterMode.expected ? course.grade2 : course.grade1;

  /// The grade chip, editable by drag or tap. [profile] is a Compare column;
  /// null is the tab's own profile.
  Widget _scrubber(int? profile) {
    final grade = profile == null ? _grade : course.gradeFor(profile);
    final ValueChanged<int>? picked =
        profile == null
            ? onGradePicked
            : onCompareGradePicked == null
            ? null
            : (g) => onCompareGradePicked!(profile, g);
    return GradeScrubber(
      grade: grade,
      onPicked: (g) => picked?.call(g),
      onTap:
          picked == null
              ? null
              : (anchor) async {
                final g = await showGradeMenu(
                  anchor,
                  current: grade,
                  title: displayTitle(course.id, course.title),
                );
                if (g != null) picked(g);
              },
      child: _chip(grade),
    );
  }

  static Widget _chip(int grade) {
    final ungraded = grade == GradeCode.clr;
    return Semantics(
      label: ungraded ? 'No grade' : 'Grade ${gradeWords(grade)}',
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
        // Fixed size, so large text scales down inside it.
        padding: const EdgeInsets.all(3),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
      ),
    );
  }
}
