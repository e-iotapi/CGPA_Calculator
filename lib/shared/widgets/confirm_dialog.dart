import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:flutter/material.dart';

/// A yes / no question (T6.4): Cancel, and [action] in ink — or, when
/// [danger], in the `behind` colour on an outlined pill. True for [action].
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
  String cancel = 'Cancel',
  bool danger = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder:
        (c) => ConfirmDialog(
          title: title,
          body: body,
          action: action,
          cancel: cancel,
          danger: danger,
        ),
  );
  return ok == true;
}

class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    required this.body,
    required this.action,
    this.cancel = 'Cancel',
    this.danger = false,
  });

  final String title, body, action, cancel;
  final bool danger;

  @override
  Widget build(BuildContext context) => AppDialog(
    title: title,
    body: body,
    actions: [
      DialogAction(cancel, onTap: () => Navigator.pop(context, false)),
      DialogAction(
        action,
        onTap: () => Navigator.pop(context, true),
        ink: !danger,
        danger: danger,
      ),
    ],
  );
}

/// One pill along a dialog's foot. [ink] fills it; [danger] draws the label
/// in the `behind` colour on an outline. A null [onTap] greys it out.
class DialogAction {
  const DialogAction(
    this.label, {
    required this.onTap,
    this.ink = false,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool ink, danger;
}

/// The one dialog look (T9.3): surface fill, radius 22, a section title, an
/// optional muted [body] and [content] (a field, a choice), then 44-tall
/// stadium pills — side by side for two, stacked for more.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    this.body,
    this.content,
    required this.actions,
    this.maxWidth = 400,
  });

  final String title;
  final String? body;
  final Widget? content;
  final List<DialogAction> actions;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    Widget pill(DialogAction a) {
      final on = a.onTap != null;
      final ink = a.ink && !a.danger;
      final text = ink ? p.onInverse : (a.danger ? p.behind : p.text);
      return Material(
        color:
            ink
                ? (on ? p.inverse : p.inverse.withValues(alpha: .35))
                : Colors.transparent,
        shape: StadiumBorder(
          side: ink ? BorderSide.none : BorderSide(color: p.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: a.onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Sizes.minTouch),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Text(
                  a.label,
                  textAlign: TextAlign.center,
                  style: TypeScale.button.copyWith(
                    fontSize: 13,
                    color: on ? text : text.withValues(alpha: .5),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Dialog(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: TypeScale.section.copyWith(color: p.text),
                ),
              ),
              if (body != null) ...[
                const SizedBox(height: Space.sm),
                Text(
                  body!,
                  style: TypeScale.body.copyWith(
                    fontWeight: FontWeight.w500,
                    color: p.textMuted,
                  ),
                ),
              ],
              if (content != null) ...[
                const SizedBox(height: Space.md),
                content!,
              ],
              const SizedBox(height: Space.lg),
              if (actions.length <= 2)
                Row(
                  spacing: 8,
                  children: [for (final a in actions) Expanded(child: pill(a))],
                )
              else
                Column(
                  spacing: 8,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [for (final a in actions) pill(a)],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
