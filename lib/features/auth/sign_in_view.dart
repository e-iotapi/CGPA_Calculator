import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/shared/widgets/pointer_mark.dart';
import 'package:flutter/material.dart';

/// The sign-in screen: what Pointer does, and one button.
class SignInView extends StatelessWidget {
  const SignInView({
    super.key,
    required this.busy,
    required this.onSignIn,
    this.entrance = _none,
  });

  final bool busy;
  final VoidCallback onSignIn;

  /// Wraps each block for a staggered intro; identity by default.
  final Widget Function(int order, Widget child) entrance;

  static Widget _none(int _, Widget child) => child;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    Widget feature(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 16, color: p.text),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              text,
              style: TypeScale.body.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: p.icon,
              ),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder:
              (context, c) => SingleChildScrollView(
                // Scrolls rather than overflowing on short windows.
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: c.maxHeight),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(26, 40, 26, 24),
                        child: IntrinsicHeight(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              entrance(
                                0,
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: p.inverse,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    alignment: Alignment.center,
                                    child: PointerMark(
                                      color: p.isDark ? p.onInverse : p.hero,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 30),
                              entrance(
                                1,
                                Semantics(
                                  header: true,
                                  child: Text(
                                    'Pointer',
                                    style: TypeScale.display.copyWith(
                                      fontSize: 52,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -2.4,
                                      height: 0.98,
                                      color: p.text,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              entrance(
                                2,
                                Text(
                                  'Your CGPA, every semester behind it, and '
                                  'where the next one lands. Built for BITS.',
                                  style: TypeScale.body.copyWith(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    height: 1.5,
                                    color: p.textMuted,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 26),
                              entrance(
                                3,
                                Column(
                                  children: [
                                    feature(
                                      Icons.show_chart_rounded,
                                      'See what SGPA you need to hit your target',
                                    ),
                                    feature(
                                      Icons.fact_check_outlined,
                                      'Track marks per evaluative, best-of rules '
                                      'included',
                                    ),
                                    feature(
                                      Icons.workspace_premium_outlined,
                                      'Offshoot scored out of 50 or 60, best 5 of 6',
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              const SizedBox(height: 20),
                              entrance(4, _button(p)),
                              const SizedBox(height: 14),
                              Text(
                                'Use your BITS campus ID — Pilani, Goa, '
                                'Hyderabad or Dubai.',
                                textAlign: TextAlign.center,
                                style: TypeScale.caption.copyWith(
                                  height: 1.5,
                                  color: p.textMuted,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Based on the CGPA Calculator by Srijen Raja · '
                                'Apache-2.0',
                                textAlign: TextAlign.center,
                                style: TypeScale.caption.copyWith(
                                  fontSize: 9.5,
                                  color: p.textMuted.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
        ),
      ),
    );
  }

  Widget _button(AppPalette p) => Semantics(
    button: true,
    label: busy ? 'Signing in' : 'Continue with Google',
    excludeSemantics: true,
    child: Material(
      color: p.inverse,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : onSignIn,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            // Shrinks rather than overflowing at large text sizes.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (busy)
                    SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: p.onInverse,
                      ),
                    )
                  else
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: p.background,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'G',
                        style: TypeScale.body.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: p.accent,
                        ),
                      ),
                    ),
                  const SizedBox(width: 11),
                  Text(
                    busy ? 'Signing in…' : 'Continue with Google',
                    style: TypeScale.body.copyWith(
                      fontSize: 15,
                      color: p.onInverse,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
