import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:flutter/material.dart';

/// A Calendar bottom sheet in the board look (PfCalSheet): sheet fill, radius
/// 30 on top, the board's dimmer behind it.
Future<T?> showCalSheet<T>(BuildContext context, WidgetBuilder builder) {
  final p = AppPalette.of(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: p.sheetFill,
    barrierColor: p.scrim,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    builder: builder,
  );
}

/// The sheet's frame: a grab handle, [title] over [subtitle] with the round
/// close button, a scrolling [children] area and a [footer] pinned below it.
class CalSheet extends StatelessWidget {
  const CalSheet({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    this.footer,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          10,
          20,
          MediaQuery.viewInsetsOf(context).bottom + Space.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: p.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TypeScale.sheetTitle.copyWith(color: p.text),
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: TypeScale.caption.copyWith(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            height: 1.35,
                            color: p.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Semantics(
                  button: true,
                  label: 'Close',
                  excludeSemantics: true,
                  child: Material(
                    color: p.closeFill,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      child: SizedBox.square(
                        dimension: Sizes.minTouch,
                        child: Icon(
                          Icons.close_rounded,
                          size: 17,
                          color: p.icon,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: children,
              ),
            ),
            if (footer != null) ...[const SizedBox(height: 12), footer!],
          ],
        ),
      ),
    );
  }
}

enum SheetButtonTone { ink, outline, danger }

/// The board's sheet and dialog button: a stadium, [height] tall, 14/700.
class SheetButton extends StatelessWidget {
  const SheetButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.tone = SheetButtonTone.ink,
    this.height = 52,
  });

  final String label;
  final VoidCallback? onPressed;
  final SheetButtonTone tone;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final fill = switch (tone) {
      SheetButtonTone.ink => p.inverse,
      SheetButtonTone.outline => p.surface,
      SheetButtonTone.danger => p.danger,
    };
    final ink = switch (tone) {
      SheetButtonTone.ink => p.onInverse,
      SheetButtonTone.outline => p.text,
      SheetButtonTone.danger => p.background,
    };
    final on = onPressed != null;
    return Semantics(
      button: true,
      enabled: on,
      child: Material(
        color: on ? fill : fill.withValues(alpha: .4),
        shape: StadiumBorder(
          side:
              tone == SheetButtonTone.outline
                  ? BorderSide(color: p.outline)
                  : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            height: height,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TypeScale.body.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: on ? ink : ink.withValues(alpha: .6),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The board's remove question (FlS_RemoveClass): a danger-wash bin, the
/// question, a note, then Remove and Keep. True for Remove.
Future<bool> confirmRemove(
  BuildContext context, {
  required String title,
  required String body,
}) async {
  final p = AppPalette.of(context);
  final ok = await showDialog<bool>(
    context: context,
    barrierColor: p.scrim,
    builder:
        (c) => Dialog(
          backgroundColor: p.sheetFill,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: p.dangerSoft,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 21,
                      color: p.danger,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: TypeScale.section.copyWith(
                    fontSize: 18,
                    letterSpacing: -0.3,
                    height: 1.25,
                    color: p.text,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  body,
                  style: TypeScale.caption.copyWith(
                    fontSize: 12,
                    height: 1.45,
                    color: p.textMuted,
                  ),
                ),
                const SizedBox(height: 16),
                SheetButton(
                  'Remove',
                  tone: SheetButtonTone.danger,
                  height: 48,
                  onPressed: () => Navigator.pop(c, true),
                ),
                const SizedBox(height: 8),
                SheetButton(
                  'Keep',
                  tone: SheetButtonTone.outline,
                  height: 48,
                  onPressed: () => Navigator.pop(c, false),
                ),
              ],
            ),
          ),
        ),
  );
  return ok == true;
}
