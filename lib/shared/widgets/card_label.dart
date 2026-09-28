import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:flutter/material.dart';

/// A card's small-caps label ("STRUCTURE"), no padding — `.lbl` (§3.4).
class CardLabel extends StatelessWidget {
  const CardLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: TypeScale.label.copyWith(
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
      color: AppPalette.of(context).textMuted,
    ),
  );
}
