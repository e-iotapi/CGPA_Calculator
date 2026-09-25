import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Stadium-shaped button: semester pills, sort, export, mode toggles.
///
/// Selected pills are filled with the palette's inverse colour; the rest are
/// outlined.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required String this.label,
    required this.onPressed,
    this.icon,
    this.selected = false,
    this.height = Sizes.pill,
    this.expand = false,
  }) : semanticLabel = null;

  /// Round, icon-only. [semanticLabel] is what a screen reader announces.
  const PillButton.icon({
    super.key,
    required IconData this.icon,
    required String this.semanticLabel,
    required this.onPressed,
    this.selected = false,
    this.height = Sizes.pillSmall,
  }) : label = null,
       expand = false;

  final String? label;
  final IconData? icon;
  final String? semanticLabel;
  final VoidCallback? onPressed;
  final bool selected;
  final double height;

  /// Fill the available width, for equal-width toggle pairs.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final fg = selected ? p.onInverse : p.icon;
    final shape = StadiumBorder(
      side: selected ? BorderSide.none : BorderSide(color: p.outline),
    );

    final Widget content;
    if (label == null) {
      content = SizedBox.square(
        dimension: height,
        child: Icon(icon, size: 15, color: fg),
      );
    } else {
      final text = Text(
        label!,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TypeScale.button.copyWith(
          color: fg,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      );
      // No `alignment` here: with one, the Container grows to the full width
      // it is offered instead of hugging the label.
      content = Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 6),
            ],
            Flexible(child: text),
          ],
        ),
      );
    }

    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: Material(
        color: selected ? p.inverse : Colors.transparent,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onPressed, customBorder: shape, child: content),
      ),
    );
  }
}
