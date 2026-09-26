import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/shared/widgets/circle_icon_button.dart';
import 'package:flutter/material.dart';

/// Eyebrow, title and a round back button, for pushed screens.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.onBack,
    this.actions = const [],
  });

  final String eyebrow;
  final String title;

  /// Defaults to popping the route.
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TypeScale.label.copyWith(color: p.textMuted),
              ),
              const SizedBox(height: 1),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TypeScale.title.copyWith(fontSize: 22, color: p.text),
              ),
            ],
          ),
        ),
        const SizedBox(width: Space.md),
        for (final a in actions) ...[a, const SizedBox(width: Space.sm)],
        CircleIconButton(
          icon: Icons.arrow_back_rounded,
          tooltip: 'Back',
          onPressed: onBack ?? () => Navigator.of(context).maybePop(),
          size: 42,
        ),
      ],
    );
  }
}

/// Background, safe area, max width and padding for a pushed screen.
class PageFrame extends StatelessWidget {
  const PageFrame({super.key, required this.header, required this.children});

  final Widget header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, Space.lg, 18, Space.xxl),
              children: [header, const SizedBox(height: Space.md), ...children],
            ),
          ),
        ),
      ),
    );
  }
}
