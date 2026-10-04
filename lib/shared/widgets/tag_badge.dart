import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:flutter/material.dart';

/// The colouring of a tag badge.
enum TagTone { official, yours, updated, fromParts, dropped, confirm }

/// A source or state tag (`.tier`, `.src`, §3.9): "OFFICIAL", "YOURS",
/// "UPDATED", "FROM PARTS", "DROPPED".
class TagBadge extends StatelessWidget {
  const TagBadge(this.text, {super.key, this.tone = TagTone.official});
  final String text;
  final TagTone tone;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final (fill, ink) = switch (tone) {
      TagTone.official => (
        Color.lerp(p.surface, p.hero, 0.4)!,
        p.isDark ? p.hero : const Color(0xFF1F5240),
      ),
      TagTone.yours => (p.noticeTone.fill, p.noticeTone.text),
      TagTone.updated => (p.hero, p.onHero),
      TagTone.fromParts => (p.mutedTone.fill, p.mutedTone.text),
      TagTone.dropped => (p.surfaceSunken, p.textMuted),
      TagTone.confirm => (p.inverse, p.onInverse),
    };
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: Text(
          text.toUpperCase(),
          style: TypeScale.caption.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
            color: ink,
          ),
        ),
      ),
    );
  }
}
