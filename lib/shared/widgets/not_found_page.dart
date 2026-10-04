import 'package:cgpa_calculator/app/routes.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The router's `errorBuilder` (T3.4): a plain, on-brand page for a bad
/// link, never the exception's own text.
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return PageFrame(
      header: const PageHeader(
        eyebrow: 'POINTER',
        title: "This page doesn't exist",
        leading: false,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.sm),
          child: Text(
            'The link may be old, or the page moved.',
            style: TypeScale.caption.copyWith(
              fontSize: 11,
              height: 1.45,
              color: p.textMuted,
            ),
          ),
        ),
        const SizedBox(height: Space.md),
        PrimaryButton(label: 'Home', onPressed: () => context.go(Routes.home)),
      ],
    );
  }
}
