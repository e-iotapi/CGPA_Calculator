import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/shared/widgets/pill_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Horizontal strip of semester pills that keeps the selected one in view,
/// with arrow buttons to page through it when it overflows.
class SemesterPills extends StatefulWidget {
  const SemesterPills({
    super.key,
    required this.semesters,
    required this.selected,
    required this.onSelected,
  });

  final List<String> semesters;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  State<SemesterPills> createState() => _SemesterPillsState();
}

class _SemesterPillsState extends State<SemesterPills> {
  final _controller = ScrollController();
  final _selectedKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _revealAfterLayout(animate: false);
  }

  @override
  void didUpdateWidget(SemesterPills old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) _revealAfterLayout(animate: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Centres the selected pill. Unlike Scrollable.ensureVisible this leaves
  /// the page's own scroll position alone.
  void _revealAfterLayout({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = _selectedKey.currentContext?.findRenderObject();
      if (box == null || !_controller.hasClients) return;
      final pos = _controller.position;
      final target = RenderAbstractViewport.of(box)
          .getOffsetToReveal(box, 0.5)
          .offset
          .clamp(pos.minScrollExtent, pos.maxScrollExtent);
      animate
          ? _controller.animateTo(
            target,
            duration: Motion.base,
            curve: Motion.curve,
          )
          : _controller.jumpTo(target);
    });
  }

  /// Pages the strip by most of its width; [dir] is -1 or 1.
  void _page(int dir) {
    final pos = _controller.position;
    _controller.animateTo(
      (pos.pixels + dir * pos.viewportDimension * 0.7).clamp(
        pos.minScrollExtent,
        pos.maxScrollExtent,
      ),
      duration: Motion.base,
      curve: Motion.curve,
    );
  }

  @override
  Widget build(BuildContext context) {
    final strip = ListView.separated(
      controller: _controller,
      scrollDirection: Axis.horizontal,
      itemCount: widget.semesters.length,
      separatorBuilder: (_, _) => const SizedBox(width: 7),
      itemBuilder: (_, i) {
        final s = widget.semesters[i];
        final on = s == widget.selected;
        return PillButton(
          key: on ? _selectedKey : null,
          label: s,
          selected: on,
          onPressed: () => widget.onSelected(s),
        );
      },
    );
    return SizedBox(
      height: Sizes.pill,
      child: Row(
        children: [
          Expanded(
            // Layout changes (a resize, a new semester) move the ends too.
            child: NotificationListener<ScrollMetricsNotification>(
              onNotification: (_) {
                setState(() {});
                return false;
              },
              child: strip,
            ),
          ),
          ListenableBuilder(
            listenable: _controller,
            builder: (_, _) {
              if (!_controller.hasClients ||
                  !_controller.position.hasContentDimensions ||
                  _controller.position.maxScrollExtent <= 0) {
                return const SizedBox.shrink();
              }
              final pos = _controller.position;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 7),
                  _ScrollArrow(
                    left: true,
                    onPressed:
                        pos.pixels > pos.minScrollExtent + 0.5
                            ? () => _page(-1)
                            : null,
                  ),
                  const SizedBox(width: 7),
                  _ScrollArrow(
                    left: false,
                    onPressed:
                        pos.pixels < pos.maxScrollExtent - 0.5
                            ? () => _page(1)
                            : null,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// A 30px outlined circle with a chevron, dimmed at the end of the strip.
class _ScrollArrow extends StatelessWidget {
  const _ScrollArrow({required this.left, required this.onPressed});

  final bool left;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final on = onPressed != null;
    return Semantics(
      button: true,
      enabled: on,
      label: left ? 'Scroll semesters left' : 'Scroll semesters right',
      excludeSemantics: true,
      child: Opacity(
        opacity: on ? 1 : 0.4,
        child: Material(
          type: MaterialType.transparency,
          shape: CircleBorder(side: BorderSide(color: p.outline)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox.square(
              dimension: 30,
              child: Icon(
                left ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                size: 18,
                color: on ? p.text : p.navIcon,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
