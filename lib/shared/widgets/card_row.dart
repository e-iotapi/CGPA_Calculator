import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:flutter/material.dart';

/// A hairline between rows in a card, inset 13 (§3.13 `.hr`).
class CardDivider extends StatelessWidget {
  const CardDivider({super.key});

  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    indent: 13,
    endIndent: 13,
    color: AppPalette.of(context).divider,
  );
}

/// A list row inside a card (`.row`, §3.13): a leading badge or icon, a
/// title, an optional subtitle, and a trailing value or chevron.
class CardRow extends StatelessWidget {
  const CardRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.minHeight = 52,
  });

  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 10)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TypeScale.body.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TypeScale.caption.copyWith(
                        fontSize: 10.5,
                        color: p.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: Space.sm),
              trailing!,
            ] else if (onTap != null)
              Icon(Icons.chevron_right_rounded, color: p.textMuted),
          ],
        ),
      ),
    );
    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }
}
