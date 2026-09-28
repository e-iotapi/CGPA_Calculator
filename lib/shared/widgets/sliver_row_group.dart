import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:flutter/material.dart';

/// A long card of rows that builds only the rows on screen (UI_OPT O5.1):
/// the same rounded `surface` card and inset hairlines as `RowGroup`, as a
/// sliver. `PageFrame` places it among its children as it is; elsewhere put
/// it in a `CustomScrollView`. Keep `RowGroup` for groups under about 12
/// rows.
class SliverRowGroup extends StatelessWidget {
  const SliverRowGroup({
    super.key,
    required this.count,
    required this.row,
    this.inset = 15,
    this.radius = Radii.row,
  });

  final int count;
  final IndexedWidgetBuilder row;

  /// How far the hairlines stop short of each edge.
  final double inset;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final corner = Radius.circular(radius);
    return DecoratedSliver(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.all(corner),
      ),
      sliver: SliverList.separated(
        itemCount: count,
        separatorBuilder:
            (_, _) => Divider(
              height: 1,
              indent: inset,
              endIndent: inset,
              color: p.divider,
            ),
        // Each row hosts its own ink over the card's fill; the end rows
        // clip it to the card's corners.
        itemBuilder:
            (context, i) => Material(
              type: MaterialType.transparency,
              borderRadius: BorderRadius.vertical(
                top: i == 0 ? corner : Radius.zero,
                bottom: i == count - 1 ? corner : Radius.zero,
              ),
              clipBehavior:
                  i == 0 || i == count - 1 ? Clip.antiAlias : Clip.none,
              child: row(context, i),
            ),
      ),
    );
  }
}
