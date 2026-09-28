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
    this.labelAbove = false,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;

  /// Decimal keyboard, digits and one point only.
  final bool number;
  final ValueChanged<String>? onChanged;
  final bool dense;
  final String? suffix;

  /// The board form style (§3.18): the label sits above the 46-tall box,
  /// upper case, instead of floating inside it.
  final bool labelAbove;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(dense ? 12 : 14),
      borderSide: BorderSide(color: p.outline),
    );
    final field = TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType:
          number ? const TextInputType.numberWithOptions(decimal: true) : null,
      inputFormatters:
          number
              ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
              : null,
      style: TypeScale.body.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: p.text,
      ),
      cursorColor: p.text,
      decoration: InputDecoration(
        isDense: true,
        labelText: labelAbove || dense ? null : label,
        hintText: hint ?? (labelAbove || dense ? label : null),
        suffixText: suffix,
        filled: true,
        fillColor: labelAbove ? p.background : p.surface,
        contentPadding: EdgeInsets.symmetric(
          horizontal: dense ? 10 : 14,
          vertical: dense ? 11 : (labelAbove ? 16 : 14),
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
    if (!labelAbove) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            label.toUpperCase(),
            style: TypeScale.label.copyWith(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: p.textMuted,
            ),
          ),
        ),
        SizedBox(height: 46, child: field),
      ],
    );
  }
}

/// The value grid on Edit evaluative (§3.19): 36 tall, radius 11. An
/// official value becomes a mint-wash box with a small "OFFICIAL" tag.
class CompactField extends StatelessWidget {
  const CompactField({
    super.key,
    required this.c,
    this.hint,
    this.official = false,
    this.onChanged,
  });

  final TextEditingController c;
  final String? hint;
  final bool official;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    if (official) {
      return Container(
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Color.lerp(p.surface, p.hero, 0.35),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              c.text,
              style: TypeScale.body.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'OFFICIAL',
              style: TypeScale.caption.copyWith(
                fontSize: 7.5,
                fontWeight: FontWeight.w800,
                color: p.isDark ? p.hero : const Color(0xFF1F5240),
              ),
            ),
          ],
        ),
      );
    }
    return SizedBox(
      height: 36,
      child: TextField(
        controller: c,
        onChanged: onChanged,
        textAlign: TextAlign.center,
        style: TypeScale.body.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: p.text,
        ),
        cursorColor: p.text,
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: const Color(0xFFF8F8F5),
          hintText: hint,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: BorderSide.none,
          ),
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
    this.tall = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// 56 tall, 14.5/700 — sign-in and setup (§3.21).
  final bool tall;

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
            height: tall ? 56 : 48,
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
                      fontSize: tall ? 14.5 : null,
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

/// [AppTextField]'s look for a raw [TextField] that needs more than it
/// offers (autofocus, several lines, a length cap), as in a dialog. Filled
/// with the background so it reads on a surface.
InputDecoration appFieldDecoration(
  AppPalette p, {
  String? label,
  String? hint,
  String? suffix,
  String? helper,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: p.outline),
  );
  final caption = TypeScale.caption.copyWith(color: p.textMuted);
  return InputDecoration(
    isDense: true,
    labelText: label,
    hintText: hint,
    suffixText: suffix,
    helperText: helper,
    filled: true,
    fillColor: p.background,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    labelStyle: caption,
    floatingLabelStyle: caption,
    hintStyle: caption.copyWith(fontSize: 12),
    suffixStyle: caption,
    helperStyle: caption,
    counterStyle: caption,
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: BorderSide(color: p.text, width: 1.5),
    ),
  );
}

/// The typed text in an [appFieldDecoration] field.
TextStyle appFieldStyle(AppPalette p) => TypeScale.body.copyWith(
  fontSize: 13,
  fontWeight: FontWeight.w600,
  color: p.text,
);
