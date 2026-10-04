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
    this.error,
    this.fill,
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

  /// Shown under the field in the notice colour; also switches the border.
  final String? error;

  /// Overrides the fill (the contribute boards use white boxes).
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    if (dense && !labelAbove) {
      return BoxedField(
        controller: controller,
        label: label,
        height: 44,
        radius: 14,
        number: number,
        onChanged: onChanged,
        suffix: suffix,
        error: error,
        fill: fill ?? p.surface,
      );
    }
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: p.outline),
    );
    final errorBorder = border.copyWith(
      borderSide: BorderSide(color: p.behind, width: 1.5),
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
        // labelAbove shows the label as its own Text above the box, so the
        // box itself keeps no internal label (hintText carries the
        // placeholder instead). Otherwise: always labelText, never a bare
        // hintText standing in for it — a dense field used to drop the
        // label to null and rely on hintText alone (BUG-29), and that text
        // vanishes once something is typed, so a screen reader announces
        // nothing for the rest of the field's life. never-float keeps the
        // same collapsed-placeholder look dense fields had before.
        labelText: labelAbove ? null : label,
        floatingLabelBehavior:
            !labelAbove && dense
                ? FloatingLabelBehavior.never
                : FloatingLabelBehavior.auto,
        hintText: labelAbove ? (hint ?? label) : (dense ? null : hint),
        suffixText: suffix,
        errorText: error,
        filled: true,
        fillColor: fill ?? (labelAbove ? p.background : p.surface),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: labelAbove ? 16 : 14,
        ),
        labelStyle: TypeScale.caption.copyWith(color: p.textMuted),
        floatingLabelStyle: TypeScale.caption.copyWith(color: p.textMuted),
        hintStyle: TypeScale.caption.copyWith(fontSize: 12, color: p.textMuted),
        suffixStyle: TypeScale.caption.copyWith(color: p.textMuted),
        errorStyle: TypeScale.caption.copyWith(fontSize: 11, color: p.behind),
        errorMaxLines: 2,
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: p.text, width: 1.5),
        ),
        errorBorder: errorBorder,
        focusedErrorBorder: errorBorder,
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

/// A one-line field whose box is drawn by a fixed-height container, not by
/// the TextField's border: a TextField's outline hugs its text (web most of
/// all), so boxes beside pills and selectors came out shorter. The label is
/// the placeholder and stays announced; [error] shows under the box.
class BoxedField extends StatefulWidget {
  const BoxedField({
    super.key,
    required this.controller,
    required this.height,
    required this.radius,
    this.label,
    this.hint,
    this.number = false,
    this.onChanged,
    this.suffix,
    this.error,
    this.errorOutline = false,
    this.fill,
    this.center = false,
    this.fontSize = 13,
    this.width,
  });

  final TextEditingController controller;
  final double height, radius, fontSize;
  final double? width;
  final String? label, hint, suffix, error;
  final bool number, center;

  /// Red outline with no text under it (a 36-tall grid has no room).
  final bool errorOutline;
  final ValueChanged<String>? onChanged;
  final Color? fill;

  @override
  State<BoxedField> createState() => _BoxedFieldState();
}

class _BoxedFieldState extends State<BoxedField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final w = widget;
    final bad = w.error != null || w.errorOutline;
    final box = Container(
      width: w.width,
      height: w.height,
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: w.center ? 4 : 12),
      decoration: BoxDecoration(
        color: w.fill ?? p.surface,
        borderRadius: BorderRadius.circular(w.radius),
        border: Border.all(
          color: bad ? p.behind : (_focus.hasFocus ? p.text : p.outline),
          width: bad || _focus.hasFocus ? 1.5 : 1,
        ),
      ),
      child: Semantics(
        label: w.label,
        textField: true,
        child: TextField(
          controller: w.controller,
          focusNode: _focus,
          onChanged: w.onChanged,
          maxLines: 1,
          textAlign: w.center ? TextAlign.center : TextAlign.start,
          keyboardType:
              w.number
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : null,
          inputFormatters:
              w.number
                  ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
                  : null,
          style: TypeScale.body.copyWith(
            fontSize: w.fontSize,
            fontWeight: FontWeight.w600,
            color: p.text,
          ),
          cursorColor: p.text,
          decoration: InputDecoration(
            isCollapsed: true,
            border: InputBorder.none,
            hintText: w.hint ?? w.label,
            hintMaxLines: 1,
            hintStyle: TypeScale.caption.copyWith(
              fontSize: w.fontSize - 1.5,
              fontWeight: FontWeight.w600,
              color: p.textMuted,
            ),
            suffixText: w.suffix,
            suffixStyle: TypeScale.caption.copyWith(color: p.textMuted),
          ),
        ),
      ),
    );
    if (w.error == null) return box;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        box,
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
          child: Text(
            w.error!,
            maxLines: 2,
            style: TypeScale.caption.copyWith(fontSize: 11, color: p.behind),
          ),
        ),
      ],
    );
  }
}

/// A number box shaped like a `CountPill` (38 tall, stadium, outline), for a
/// value typed in a row of pills.
class PillField extends StatelessWidget {
  const PillField({
    super.key,
    required this.controller,
    this.onChanged,
    this.width = 86,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final double width;

  @override
  Widget build(BuildContext context) => BoxedField(
    controller: controller,
    onChanged: onChanged,
    width: width,
    height: 38,
    radius: 19,
    number: true,
    center: true,
    fontSize: 12.5,
    fill: Colors.transparent,
  );
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
    this.error = false,
  });

  final TextEditingController c;
  final String? hint;
  final bool official;
  final ValueChanged<String>? onChanged;

  /// Red border for an out-of-range value (BUG-04). No room for error text
  /// in a 36-tall box — the page shows one line for the first problem.
  final bool error;

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
    return BoxedField(
      controller: c,
      hint: hint,
      onChanged: onChanged,
      height: 36,
      radius: 11,
      center: true,
      fontSize: 12,
      errorOutline: error,
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
