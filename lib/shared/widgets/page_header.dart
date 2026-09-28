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
    this.leading = true,
    this.close = false,
  });

  final String eyebrow;
  final String title;

  /// Defaults to popping the route.
  final VoidCallback? onBack;
  final List<Widget> actions;

  /// `[Back 44] 12 [eyebrow / title]`, the layout for pushed screens (N3).
  /// `false` keeps the old `[eyebrow / title] [actions] [Back]`, for the
  /// four top-level screens (Controls, Your department, Stats, Marks).
  final bool leading;

  /// Draws a close (✕) button instead of the back arrow (Course setup, Edit
  /// evaluative).
  final bool close;

  @override
  Widget build(BuildContext context) {
    final back = CircleIconButton(
      icon: close ? Icons.close_rounded : Icons.arrow_back_rounded,
      tooltip: close ? 'Close' : 'Back',
      onPressed: onBack ?? () => Navigator.of(context).maybePop(),
      size: 42,
    );
    final block = _TitleBlock(eyebrow: eyebrow, title: title, leading: leading);
    if (leading) {
      return Row(
        children: [
          back,
          const SizedBox(width: 12),
          Expanded(child: block),
          for (final a in actions) ...[const SizedBox(width: Space.sm), a],
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: block),
        const SizedBox(width: Space.md),
        for (final a in actions) ...[a, const SizedBox(width: Space.sm)],
        back,
      ],
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({
    required this.eyebrow,
    required this.title,
    required this.leading,
  });

  final String eyebrow;
  final String title;
  final bool leading;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final titleStyle = TypeScale.title.copyWith(
      fontSize: leading ? 21 : 22,
      letterSpacing: leading ? -0.5 : -0.7,
      color: p.text,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TypeScale.label.copyWith(color: p.textMuted),
        ),
        const SizedBox(height: 1),
        LayoutBuilder(
          builder: (context, c) {
            final merged = DefaultTextStyle.of(context).style.merge(titleStyle);
            final ambient = MediaQuery.textScalerOf(context);
            double longestWord(TextScaler scaler) {
              var longest = 0.0;
              for (final w in title.split(' ')) {
                final tp = TextPainter(
                  text: TextSpan(text: w, style: merged),
                  textDirection: TextDirection.ltr,
                  textScaler: scaler,
                )..layout();
                if (tp.width > longest) longest = tp.width;
              }
              return longest;
            }

            final text = Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: titleStyle,
            );
            if (c.maxWidth <= 0 || longestWord(ambient) <= c.maxWidth) {
              return text;
            }
            final atScale1 = longestWord(TextScaler.noScaling);
            final fit =
                atScale1 > 0
                    ? (c.maxWidth / atScale1).clamp(1.0, double.infinity)
                    : 1.0;
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(fit)),
              child: text,
            );
          },
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
