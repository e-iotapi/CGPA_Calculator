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
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    Widget pill(String label, {required bool ink, Color? text, bool? value}) =>
        Expanded(
          child: Material(
            color: ink ? p.inverse : Colors.transparent,
            shape: StadiumBorder(
              side: ink ? BorderSide.none : BorderSide(color: p.outline),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.pop(context, value),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TypeScale.button.copyWith(
                        fontSize: 13,
                        color: text ?? (ink ? p.onInverse : p.text),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
    return Dialog(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
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
              const SizedBox(height: Space.sm),
              Text(
                body,
                style: TypeScale.body.copyWith(
                  fontWeight: FontWeight.w500,
                  color: p.textMuted,
                ),
              ),
              const SizedBox(height: Space.lg),
              Row(
                spacing: 8,
                children: [
                  pill(cancel, ink: false, value: false),
                  pill(
                    action,
                    ink: !danger,
                    text: danger ? p.behind : null,
                    value: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
