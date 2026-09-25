import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/shared/widgets/pill_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Horizontal strip of semester pills that keeps the selected one in view.
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
            duration: Motion.medium,
            curve: Curves.easeOutCubic,
          )
          : _controller.jumpTo(target);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: Sizes.pill,
      child: ListView.separated(
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
      ),
    );
  }
}
