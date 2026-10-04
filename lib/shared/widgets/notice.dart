import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:flutter/material.dart';

/// The amber notice card (§3.10): an icon, then text with a bold key
/// phrase. Marks' inline notice moved here.
class Notice extends StatelessWidget {
  const Notice({
    super.key,
    required this.text,
    this.icon = Icons.info_outline_rounded,
    this.warning = false,
  });

  final InlineSpan text;
  final IconData icon;

  /// A stronger (red-leaning) tone for an actual problem, not just a hint.
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final tone =
        warning
            ? GradeTone(p.behind.withValues(alpha: 0.14), p.behind)
            : p.noticeTone;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: tone.fill,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: tone.text),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              text,
              style: TypeScale.caption.copyWith(
                fontSize: 10.5,
                height: 1.45,
                color: tone.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
