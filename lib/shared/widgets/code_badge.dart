import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:flutter/material.dart';

/// The colouring of a [CodeBadge].
enum CodeTone { neutral, first, second, selected, empty }

/// A course/degree code chip (§3.14): "A7", "B3", the empty dashed slot.
class CodeBadge extends StatelessWidget {
  const CodeBadge(this.code, {super.key, this.tone = CodeTone.neutral});
  final String code;
  final CodeTone tone;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    if (tone == CodeTone.empty) {
      return Container(
        width: 38,
        height: 29,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: p.outline, width: 1),
        ),
      );
    }
    final (fill, ink) = switch (tone) {
      CodeTone.neutral => (const Color(0xFFF0F0EA), const Color(0xFF45453C)),
      CodeTone.first => (p.hero, p.onHero),
      CodeTone.second => (p.inverse, p.hero),
      CodeTone.selected => (p.inverse, p.onInverse),
      CodeTone.empty => (p.surface, p.text),
    };
    return Container(
      width: 38,
      height: 29,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        code,
        style: TypeScale.body.copyWith(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: ink,
        ),
      ),
    );
  }
}
