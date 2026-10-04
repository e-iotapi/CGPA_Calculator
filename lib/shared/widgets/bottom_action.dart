import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:flutter/material.dart';

/// A CTA pinned above the safe bottom, over a fade to the background
/// (§3.24). Place as the last child of a `Stack` over the scrolling body,
/// which should pad its bottom by [heightOf].
class BottomAction extends StatelessWidget {
  const BottomAction({
    super.key,
    required this.child,
    this.caption,
    this.fade = 132,
  });

  final Widget child;
  final String? caption;

  /// The gradient's height; the fade starts this far above the bottom.
  final double fade;

  /// How much bottom padding the scrolling body needs to clear this bar.
  static double heightOf(BuildContext context, {bool hasCaption = false}) =>
      76 + (hasCaption ? 20 : 0) + MediaQuery.paddingOf(context).bottom;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          IgnorePointer(
            child: Container(
              width: double.infinity,
              height: fade,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [p.background.withValues(alpha: 0), p.background],
                  stops: const [0, 0.6],
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                0,
                Space.gutter,
                Space.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  child,
                  if (caption != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      caption!,
                      style: TypeScale.caption.copyWith(
                        fontSize: 10.5,
                        color: p.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
