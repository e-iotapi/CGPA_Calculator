import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:flutter/material.dart';

/// A labelled headline number, e.g. SGPA 9.17 · 24 credits.
///
/// [hero] fills it with the accent; use it for at most one card per screen.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.hero = false,
    this.onTap,
    this.tapHint,
  });

  final String label;
  final String value;
  final String? caption;
  final bool hero;

  /// Makes the card a button; the label gets a chevron.
  final VoidCallback? onTap;

  /// What tapping does, for screen readers ("Change profile").
  final String? tapHint;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final fg = hero ? p.onHero : p.text;
    final muted = hero ? p.onHeroMuted : p.textMuted;
    final labelText = Text(
      label.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TypeScale.label.copyWith(color: muted),
    );
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onTap == null)
            labelText
          else
            Row(
              children: [
                Flexible(child: labelText),
                Icon(Icons.expand_more_rounded, size: 16, color: muted),
              ],
            ),
          const SizedBox(height: 1),
          // Shrinks rather than clipping when the card is very narrow.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: TypeScale.display.copyWith(color: fg)),
          ),
          if (caption != null) ...[
            const SizedBox(height: 1),
            Text(
              caption!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TypeScale.caption.copyWith(color: muted),
            ),
          ],
        ],
      ),
    );
    return Semantics(
      button: onTap != null,
      hint: tapHint,
      child: Material(
        color: hero ? p.hero : p.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? body : InkWell(onTap: onTap, child: body),
      ),
    );
  }
}
