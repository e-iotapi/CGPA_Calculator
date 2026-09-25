import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:flutter/material.dart';

/// A letter grade in its tone. Never shrinks, so a long title beside it
/// ellipsizes instead of pushing it off screen.
class GradeChip extends StatelessWidget {
  const GradeChip(this.grade, {super.key, this.muted = false});

  /// The letter as shown ("A-", "NC", "GD"…).
  final String grade;

  /// Greys the chip out for a course that does not count.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final tone = muted ? p.mutedTone : p.gradeTone(grade);
    return Container(
      constraints: const BoxConstraints(
        minWidth: Sizes.gradeChipMinWidth,
        minHeight: Sizes.gradeChipHeight,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tone.fill,
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
      child: Text(
        grade,
        maxLines: 1,
        style: TypeScale.gradeChip.copyWith(color: tone.text),
      ),
    );
  }
}
