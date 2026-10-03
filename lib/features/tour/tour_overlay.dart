import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/features/tour/tour_controller.dart';
import 'package:cgpa_calculator/shared/widgets/pill_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The tour's whole screen: a dim scrim with a hole over the highlighted
/// control, and the step card. It sits in the root Navigator overlay and
/// swallows every touch, so nothing under it can be tapped or scrolled while
/// the tour runs (TM-6/K15). The hole is shown, not live: a sheet opened
/// through it would open beneath the scrim.
class TourOverlay extends StatefulWidget {
  const TourOverlay({super.key, required this.controller});

  final TourController controller;

  @override
  State<TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends State<TourOverlay> {
  final _focus = FocusNode(debugLabel: 'tour');

  TourController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    // The page under the overlay owns the focus; take it so Esc and the
    // arrow keys reach the tour.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      onKeyEvent: (_, e) {
        if (e is! KeyDownEvent || !controller.active) {
          return KeyEventResult.ignored;
        }
        if (e.logicalKey == LogicalKeyboardKey.escape) {
          controller.skip();
        } else if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
          controller.next();
        } else if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
          controller.back();
        } else {
          return KeyEventResult.ignored;
        }
        return KeyEventResult.handled;
      },
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final size = MediaQuery.sizeOf(context);
          final hole = controller.hole?.inflate(6);
          return Stack(
            children: [
              // Absorbs every tap, drag and wheel turn.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _nothing,
                  onVerticalDragStart: _ignoreDrag,
                  onHorizontalDragStart: _ignoreDrag,
                ),
              ),
              Positioned.fill(
                child: RepaintBoundary(
                  child: IgnorePointer(
                    child: CustomPaint(size: size, painter: _HolePainter(hole)),
                  ),
                ),
              ),
              if (!controller.busy && hole != null)
                Positioned.fill(
                  child: CustomSingleChildLayout(
                    delegate: _CardLayout(
                      hole: hole,
                      padding: MediaQuery.paddingOf(context),
                    ),
                    child: _StepCard(controller: controller),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

void _nothing() {}
void _ignoreDrag(DragStartDetails _) {}

class _HolePainter extends CustomPainter {
  _HolePainter(this.hole);
  final Rect? hole;

  @override
  void paint(Canvas canvas, Size size) {
    final path =
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(Offset.zero & size);
    if (hole != null) {
      path.addRRect(RRect.fromRectAndRadius(hole!, const Radius.circular(14)));
    }
    canvas.drawPath(path, Paint()..color = const Color(0xB3000000));
  }

  @override
  bool shouldRepaint(_HolePainter old) => old.hole != hole;
}

/// Puts the card under the hole, or above it when there is no room below.
class _CardLayout extends SingleChildLayoutDelegate {
  _CardLayout({required this.hole, required this.padding});

  final Rect hole;
  final EdgeInsets padding;
  static const _gap = 12.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints c) => BoxConstraints(
    maxWidth: (c.maxWidth - 2 * Space.lg).clamp(0, 360),
    maxHeight: c.maxHeight - padding.vertical,
  );

  @override
  Offset getPositionForChild(Size size, Size child) {
    final x = (hole.center.dx - child.width / 2).clamp(
      Space.lg,
      size.width - Space.lg - child.width,
    );
    final below = hole.bottom + _gap;
    final above = hole.top - _gap - child.height;
    final top = padding.top + Space.sm;
    final bottom = size.height - padding.bottom - Space.sm - child.height;
    final y =
        below <= bottom
            ? below
            : above >= top
            ? above
            // Nothing fits beside it (a tall control): overlap the far end.
            : (hole.center.dy < size.height / 2 ? bottom : top);
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_CardLayout old) =>
      old.hole != hole || old.padding != padding;
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.controller});

  final TourController controller;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final s = controller.step;
    return Material(
      color: p.surfaceRaised,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.row),
        side: BorderSide(color: p.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              liveRegion: true,
              child: Text(
                'Step ${controller.index + 1} of ${controller.total} · '
                '${controller.chapter}',
                style: TypeScale.label.copyWith(color: p.textMuted),
              ),
            ),
            const SizedBox(height: Space.xs),
            Text(s.title, style: TypeScale.sheetTitle.copyWith(color: p.text)),
            const SizedBox(height: Space.xs),
            Text(s.line, style: TypeScale.body.copyWith(color: p.textMuted)),
            const SizedBox(height: Space.md),
            Row(
              children: [
                TextButton(
                  onPressed: controller.skip,
                  child: Text(
                    'Skip',
                    style: TypeScale.button.copyWith(color: p.textMuted),
                  ),
                ),
                const Spacer(),
                PillButton(
                  label: 'Back',
                  height: Sizes.minTouch,
                  onPressed: controller.canBack ? controller.back : null,
                ),
                const SizedBox(width: Space.sm),
                PillButton(
                  label: controller.isLast ? 'Done' : 'Next',
                  height: Sizes.minTouch,
                  selected: true,
                  onPressed: controller.next,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
