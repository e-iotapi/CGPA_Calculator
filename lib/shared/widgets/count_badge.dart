import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:flutter/material.dart';

/// The colouring of a count badge.
enum CountTone { waiting, on, neutral }

/// A small count or state pill (T3.7): "3 pending", "ON", "12".
class CountBadge extends StatelessWidget {
  const CountBadge(this.text, {super.key, this.tone = CountTone.waiting});
  final String text;
  final CountTone tone;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final (fill, ink) = switch (tone) {
      CountTone.waiting => (p.noticeTone.fill, p.noticeTone.text),
      CountTone.on => (p.hero, p.onHero),
      CountTone.neutral => (p.mutedTone.fill, p.mutedTone.text),
    };
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: Text(
          text,
          style: TypeScale.caption.copyWith(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: ink,
          ),
        ),
      ),
    );
  }
}
