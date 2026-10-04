import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:flutter/material.dart';

/// The 52-tall pill of a board sheet or dialog: outlined, ink, or [fill]
/// with [fg] text (the red Revoke / Send).
class SheetButton extends StatelessWidget {
  const SheetButton(
    this.label, {
    super.key,
    required this.onTap,
    this.ink = false,
    this.fill,
    this.fg,
  });
  final String label;
  final VoidCallback onTap;
  final bool ink;
  final Color? fill, fg;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Material(
      color: fill ?? (ink ? p.inverse : p.surface),
      shape: StadiumBorder(
        side:
            ink || fill != null
                ? BorderSide.none
                : BorderSide(color: p.outline),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Center(
            child: Text(
              label,
              style: TypeScale.body.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: fg ?? (ink ? p.onInverse : p.text),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The board's confirm dialog: a tinted icon tile, a title, a few lines, then
/// a 52-tall [primary] pill and (when [secondary] is given) an outlined one.
/// Pops true for [primary] and false for [secondary].
class IconDialog extends StatelessWidget {
  const IconDialog({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.primary,
    this.secondary,
    this.tint,
    this.tintFg,
    this.primaryFill,
    this.primaryFg,
  });
  final IconData icon;
  final String title, body, primary;
  final String? secondary;

  /// The tile's fill and icon colour; the mint hero pair when null.
  final Color? tint, tintFg;
  final Color? primaryFill, primaryFg;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Dialog(
      backgroundColor: p.background,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tint ?? p.hero,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, size: 20, color: tintFg ?? p.onHero),
              ),
            ),
            Semantics(
              header: true,
              child: Text(
                title,
                style: TypeScale.title.copyWith(
                  fontSize: 18,
                  letterSpacing: -0.3,
                  height: 1.25,
                  color: p.text,
                ),
              ),
            ),
            Text(
              body,
              style: TypeScale.caption.copyWith(
                fontSize: 12,
                height: 1.45,
                color: p.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            SheetButton(
              primary,
              onTap: () => Navigator.pop(context, true),
              ink: primaryFill == null,
              fill: primaryFill,
              fg: primaryFg,
            ),
            if (secondary != null)
              SheetButton(
                secondary!,
                onTap: () => Navigator.pop(context, false),
              ),
          ],
        ),
      ),
    );
  }
}
