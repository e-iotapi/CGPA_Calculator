import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A filled input on the palette's surface. [label] is announced to screen
/// readers even when [hint] shows instead of it.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.number = false,
    this.onChanged,
    this.dense = false,
    this.suffix,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;

  /// Decimal keyboard, digits and one point only.
  final bool number;
  final ValueChanged<String>? onChanged;
  final bool dense;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(dense ? 12 : 16),
      borderSide: BorderSide(color: p.outline),
    );
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType:
          number ? const TextInputType.numberWithOptions(decimal: true) : null,
      inputFormatters:
          number
              ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
              : null,
      style: TypeScale.body.copyWith(color: p.text),
      cursorColor: p.text,
      decoration: InputDecoration(
        isDense: true,
        labelText: dense ? null : label,
        hintText: hint ?? (dense ? label : null),
        suffixText: suffix,
        filled: true,
        fillColor: p.surface,
        contentPadding: EdgeInsets.symmetric(
          horizontal: dense ? 10 : 14,
          vertical: dense ? 11 : 14,
        ),
        labelStyle: TypeScale.caption.copyWith(color: p.textMuted),
        floatingLabelStyle: TypeScale.caption.copyWith(color: p.textMuted),
        hintStyle: TypeScale.caption.copyWith(fontSize: 12, color: p.textMuted),
        suffixStyle: TypeScale.caption.copyWith(color: p.textMuted),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: p.text, width: 1.5),
        ),
      ),
    );
  }
}

/// Upper-case section label ("STRUCTURE").
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Space.lg, bottom: Space.sm),
    child: Text(
      text.toUpperCase(),
      style: TypeScale.label.copyWith(color: AppPalette.of(context).textMuted),
    ),
  );
}

/// Full-width dark action button ("Save evaluative").
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final fg = p.onInverse.withValues(alpha: onPressed == null ? 0.5 : 1);
    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: Material(
        color: p.inverse.withValues(alpha: onPressed == null ? 0.4 : 1),
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            height: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: fg),
                  const SizedBox(width: 7),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TypeScale.body.copyWith(
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
