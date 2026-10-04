import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Two equal buttons, radius 14, ink selected (§3.7): "One mark" / "Several
/// parts".
class SegmentedPair<T> extends StatelessWidget {
  const SegmentedPair({
    super.key,
    required this.a,
    required this.b,
    required this.value,
    required this.onChanged,
    this.height = 44,
    this.c,
  });

  final (T, String) a;
  final (T, String) b;

  /// An optional third button.
  final (T, String)? c;
  final T value;
  final ValueChanged<T> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    Widget seg((T, String) pair) {
      final on = pair.$1 == value;
      return Expanded(
        child: Semantics(
          selected: on,
          button: true,
          child: Material(
            color: on ? p.inverse : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onChanged(pair.$1),
              child: Container(
                height: height,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: on ? null : Border.all(color: p.outline),
                ),
                child: Text(
                  pair.$2,
                  style: TypeScale.body.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: on ? p.onInverse : p.text,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        seg(a),
        const SizedBox(width: 8),
        seg(b),
        if (c case final c?) ...[const SizedBox(width: 8), seg(c)],
      ],
    );
  }
}

/// A tabbed track, 40 tall, radius 20, selected ink over `mutedTone.fill`
/// (Roster, ReviewsSearch).
class SegmentedTrack<T> extends StatelessWidget {
  const SegmentedTrack({
    super.key,
    required this.tabs,
    required this.value,
    required this.onChanged,
    this.height = 40,
  });

  final List<(T, String)> tabs;
  final T value;
  final ValueChanged<T> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      height: height,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: p.mutedTone.fill,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: Row(
        children: [
          for (final tab in tabs)
            Expanded(
              child: Semantics(
                selected: tab.$1 == value,
                button: true,
                child: Material(
                  color: tab.$1 == value ? p.inverse : Colors.transparent,
                  borderRadius: BorderRadius.circular(height / 2 - 3),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(height / 2 - 3),
                    onTap: () => onChanged(tab.$1),
                    child: Container(
                      alignment: Alignment.center,
                      child: Text(
                        tab.$2,
                        style: TypeScale.body.copyWith(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: tab.$1 == value ? p.onInverse : p.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
