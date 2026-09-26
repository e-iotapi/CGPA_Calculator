import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:flutter/material.dart';

/// "Retired", beside a course the catalogue no longer offers. The word
/// carries it; the outline only sets it apart from the title.
class RetiredTag extends StatelessWidget {
  const RetiredTag({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: p.surfaceSunken,
        border: Border.all(color: p.outline),
        borderRadius: BorderRadius.circular(Radii.check),
      ),
      child: Text(
        'Retired',
        maxLines: 1,
        style: TypeScale.caption.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: p.textMuted,
        ),
      ),
    );
  }
}
