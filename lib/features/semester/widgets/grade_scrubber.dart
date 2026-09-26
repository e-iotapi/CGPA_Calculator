import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/grading/grade_scale.dart';
import 'package:flutter/material.dart';

/// Hold [child] to open a grade wheel beside the finger; drag up or down to
/// move through it, release to pick. The same gesture the original list had.
class GradeScrubber extends StatefulWidget {
  const GradeScrubber({
    super.key,
    required this.grade,
    required this.onPicked,
    required this.child,
    this.onTap,
  });

  /// A plain tap. Handled here so it never reaches a tappable parent.
  final VoidCallback? onTap;

  /// The stored grade value.
  final int grade;

  /// Called with the stored value of the picked grade.
  final ValueChanged<int> onPicked;
  final Widget child;

  @override
  State<GradeScrubber> createState() => _GradeScrubberState();
}

class _GradeScrubberState extends State<GradeScrubber> {
  static const _extent = 45.0;
  static const _wheelSize = Size(120, 250);

  OverlayEntry? _wheel;
  FixedExtentScrollController? _controller;
  final _index = ValueNotifier<int>(0);
  double _startY = 0;
  int _startIndex = 0;

  int _initialIndex() {
    final letter = gradecalc(widget.grade);
    var i = pickerGrades.indexOf(letter);
    if (i == -1 && letter == '–') i = pickerGrades.indexOf('GD');
    return i == -1 ? 0 : i;
  }

  void _open(LongPressStartDetails d) {
    // The overlay sits above this subtree's Theme, so the palette is captured
    // here rather than looked up inside it.
    final p = AppPalette.of(context);
    final screen = MediaQuery.sizeOf(context);
    _startIndex = _initialIndex();
    _index.value = _startIndex;
    _startY = d.globalPosition.dy;
    _controller = FixedExtentScrollController(initialItem: _startIndex);
    final left = (d.globalPosition.dx - _wheelSize.width / 2).clamp(
      8.0,
      screen.width - _wheelSize.width - 8,
    );
    final top = (d.globalPosition.dy - _wheelSize.height / 2).clamp(
      8.0,
      screen.height - _wheelSize.height - 8,
    );
    _wheel = OverlayEntry(
      builder:
          (_) => Positioned(
            left: left,
            top: top,
            child: Material(
              color: p.surface,
              elevation: 8,
              borderRadius: BorderRadius.circular(Radii.badge),
              child: SizedBox.fromSize(
                size: _wheelSize,
                child: ListWheelScrollView.useDelegate(
                  controller: _controller,
                  itemExtent: _extent,
                  physics: const NeverScrollableScrollPhysics(),
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: pickerGrades.length,
                    builder:
                        (_, i) => ValueListenableBuilder<int>(
                          valueListenable: _index,
                          builder: (_, selected, _) {
                            final on = i == selected;
                            return Center(
                              child: Text(
                                pickerGrades[i].isEmpty ? '–' : pickerGrades[i],
                                style: TextStyle(
                                  fontFamily: TypeScale.family,
                                  fontSize: on ? 24 : 18,
                                  fontWeight:
                                      on ? FontWeight.w700 : FontWeight.w500,
                                  color:
                                      on
                                          ? p.accent
                                          : p.text.withValues(alpha: 0.5),
                                ),
                              ),
                            );
                          },
                        ),
                  ),
                ),
              ),
            ),
          ),
    );
    Overlay.of(context).insert(_wheel!);
  }

  void _move(LongPressMoveUpdateDetails d) {
    final c = _controller;
    if (c == null) return;
    final offset = (_startIndex * _extent - (d.globalPosition.dy - _startY))
        .clamp(0.0, (pickerGrades.length - 1) * _extent);
    if (c.hasClients) c.jumpTo(offset);
    _index.value = (offset / _extent).round().clamp(0, pickerGrades.length - 1);
  }

  void _close() {
    _wheel?.remove();
    _wheel = null;
    _controller?.dispose();
    _controller = null;
  }

  @override
  void dispose() {
    _close();
    _index.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onLongPressStart: _open,
      onLongPressMoveUpdate: _move,
      onLongPressEnd: (_) {
        final picked = pickerGrades[_index.value];
        _close();
        widget.onPicked(reversegradecalc(picked));
      },
      onLongPressCancel: _close,
      child: Semantics(
        hint: 'Tap for grades, or hold and drag to change',
        // Pad the 34px chip out to a 44px target.
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: Sizes.minTouch,
            minHeight: Sizes.minTouch,
          ),
          child: Center(widthFactor: 1, heightFactor: 1, child: widget.child),
        ),
      ),
    );
  }
}
