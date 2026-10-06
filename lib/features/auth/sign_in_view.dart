import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/dashed_outline.dart';
import 'package:cgpa_calculator/shared/widgets/pointer_mark.dart';
import 'package:flutter/material.dart';

/// The sign-in screen: what Pointer does, and one button.
class SignInView extends StatelessWidget {
  const SignInView({
    super.key,
    required this.busy,
    required this.onSignIn,
    this.onTestSignIn,
    this.entrance = _none,
  });

  final bool busy;
  final VoidCallback onSignIn;

  /// Staging only: sign in with a test account.
  final VoidCallback? onTestSignIn;

  /// Wraps each block for a staggered intro; identity by default.
  final Widget Function(int order, Widget child) entrance;

  static Widget _none(int _, Widget child) => child;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    Widget feature(IconData icon, String text, {bool mint = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: mint ? p.hero : p.surface,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 16, color: mint ? p.onHero : p.text),
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
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: LayoutBuilder(
              builder:
                  (context, c) => SingleChildScrollView(
                    // Scrolls rather than overflowing on short windows.
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: c.maxHeight),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(26, Space.xxl, 26, 24),
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
                                  'An all-in-one academics manager, and a '
                                  'lovely community of BITSians.',
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
                                      'Live SGPA and CGPA, every BITS rule '
                                      'built in',
                                    ),
                                    feature(
                                      Icons.calendar_month_outlined,
                                      'Your timetable, filled in from the '
                                      'campus timetable',
                                    ),
                                    feature(
                                      Icons.fact_check_outlined,
                                      'Every evaluative, with class averages',
                                    ),
                                    feature(
                                      Icons.forum_outlined,
                                      'Reviews and resources for every course, '
                                      'from BITSians',
                                      mint: true,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              DashedOutline(
                                color: p.textMuted,
                                radius: 16,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    14,
                                    11,
                                    14,
                                    11,
                                  ),
                                  child: Text(
                                    'Already a few semesters in? Sign in, then '
                                    'drop your ERP performance sheet — it is '
                                    'read on your device and never uploaded.',
                                    style: TypeScale.caption.copyWith(
                                      fontSize: 12,
                                      height: 1.5,
                                      color: p.textMuted,
                                    ),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              const SizedBox(height: 20),
                              if (onTestSignIn case final test?) ...[
                                OutlinedButton(
                                  onPressed: busy ? null : test,
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(48),
                                    shape: const StadiumBorder(),
                                  ),
                                  child: const Text('Use test account'),
                                ),
                                const SizedBox(height: 10),
                              ],
                              entrance(
                                4,
                                PrimaryButton(
                                  tall: true,
                                  label:
                                      busy
                                          ? 'Signing in…'
                                          : 'Continue with Google',
                                  onPressed: busy ? null : onSignIn,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Use your BITS campus ID — Pilani, Goa, '
                                'Hyderabad or Dubai.',
                                textAlign: TextAlign.center,
                                style: TypeScale.caption.copyWith(
                                  height: 1.1,
                                  color: p.textMuted,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Your grades stay private to your account.\n'
                                'Reviews you write never carry your name.',
                                textAlign: TextAlign.center,
                                style: TypeScale.caption.copyWith(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                  height: 1.1,
                                  color: p.textMuted,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Built By Siddharth Mishra',
                                textAlign: TextAlign.center,
                                style: TypeScale.caption.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                  color: p.text,
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
}
