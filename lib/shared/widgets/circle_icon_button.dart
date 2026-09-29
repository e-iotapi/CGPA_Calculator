import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Round header action (analytics, settings…). [tooltip] doubles as the
/// screen-reader label.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = Sizes.iconButton,
  });

  final double size;

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    // Tooltip normally adds its own semantics label; that stacks with the
    // InkWell's button node and screen readers announce the label twice
    // ("Close Close"). excludeFromSemantics + one explicit Semantics node
    // keeps a single, correctly labelled node (BUG-29).
    return Semantics(
      button: true,
      label: tooltip,
      enabled: onPressed != null,
      child: Tooltip(
        message: tooltip,
        excludeFromSemantics: true,
        child: Material(
          color: p.surface,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox.square(
              dimension: size,
              child: Icon(icon, size: 20, color: p.text),
            ),
          ),
        ),
      ),
    );
  }
}
