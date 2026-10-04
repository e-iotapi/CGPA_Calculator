import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:flutter/material.dart';

/// The rounded surface everything sits on: course rows, chart panels,
/// settings groups.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
    this.radius = Radii.row,
    this.color,
    this.border,
    this.onTap,
    this.clip,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Defaults to the palette's surface.
  final Color? color;
  final BorderSide? border;
  final VoidCallback? onTap;

  /// Clip the content to the rounded corners, for content that reaches the
  /// edge. By default only a card with no padding clips: its rows run edge
  /// to edge and their press highlight must stay inside the corners. A
  /// padded card doesn't, which saves a clip layer per card (UI_OPT O4.2).
  final bool? clip;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: border ?? BorderSide.none,
    );
    return Material(
      color: color ?? p.surface,
      shape: shape,
      // The shape rounds the card and InkWell's customBorder clips its own
      // splash; only edge-to-edge content needs the clip.
      clipBehavior:
          (clip ?? padding == EdgeInsets.zero) ? Clip.antiAlias : Clip.none,
      child: InkWell(
        onTap: onTap,
        customBorder: shape,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
