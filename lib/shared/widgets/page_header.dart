import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/shared/widgets/circle_icon_button.dart';
import 'package:cgpa_calculator/shared/widgets/bottom_action.dart';
import 'package:cgpa_calculator/shared/widgets/sliver_row_group.dart';
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
    this.back = true,
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

  /// False on a page there is no leaving (Before you start while forced).
  final bool back;

  @override
  Widget build(BuildContext context) {
    final button = CircleIconButton(
      icon: close ? Icons.close_rounded : Icons.arrow_back_rounded,
      tooltip: close ? 'Close' : 'Back',
      onPressed: onBack ?? () => Navigator.of(context).maybePop(),
      size: 42,
    );
    final block = _TitleBlock(eyebrow: eyebrow, title: title, leading: leading);
    if (leading && back) {
      return Row(
        children: [
          button,
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
        for (final (i, a) in actions.indexed) ...[
          a,
          if (back || i < actions.length - 1) const SizedBox(width: Space.sm),
        ],
        if (back) button,
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
  const PageFrame({
    super.key,
    required this.header,
    required this.children,
    this.bottom,
  });

  final Widget header;
  final List<Widget> children;

  /// A pinned `BottomAction`; the list pads itself clear of it.
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    // Box children run in lazy lists between any SliverRowGroup, which
    // goes in as the sliver it is: a long card builds only what is on
    // screen (UI_OPT O5.1).
    final slivers = <Widget>[];
    var boxes = <Widget>[];
    void flush() {
      if (boxes.isEmpty) return;
      slivers.add(SliverList.list(children: boxes));
      boxes = [];
    }

    for (final c in [header, const SizedBox(height: Space.md), ...children]) {
      if (c is SliverRowGroup) {
        flush();
        slivers.add(c);
      } else {
        boxes.add(c);
      }
    }
    flush();
    final list = CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            18,
            Space.lg,
            18,
            bottom == null
                ? Space.xxl
                : BottomAction.heightOf(context) + Space.md,
          ),
          sliver: SliverMainAxisGroup(slivers: slivers),
        ),
      ],
    );
    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: bottom == null ? list : Stack(children: [list, bottom!]),
          ),
        ),
      ),
    );
  }
}
