import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/grading/grade_scale.dart';
import 'package:flutter/material.dart';

/// The eight letter grades, which all count the same way.
const letterGrades = ['A', 'A-', 'B', 'B-', 'C', 'C-', 'D', 'E'];

/// Codes that are not grades, with what each does to the CGPA (§2.1). This
/// is where a wrong tap costs a believable CGPA, so the menu says it.
const specialGrades = [
  ('NC', 'Not cleared. No credits, and no effect on the CGPA until repeated.'),
  ('RC', 'Repeat course. The credits leave the CGPA entirely.'),
  ('W', 'Withdrawn. The credits leave the CGPA entirely.'),
  ('GD', 'Passed without points. Credits count, the CGPA does not change.'),
];

/// The rule for the four codes above, in one line under them.
const specialGradesNote =
    'RC and W drop the credits from your CGPA. GD keeps them but not the '
    'points.';

/// Opens the grade menu under [anchor] (the chip), right-aligned to it, and
/// returns the stored value picked, or null. The row stays visible behind.
Future<int?> showGradeMenu(
  BuildContext anchor, {
  required int current,
  required String title,
}) {
  final box = anchor.findRenderObject()! as RenderBox;
  final rect = box.localToGlobal(Offset.zero) & box.size;
  return showGeneralDialog<int>(
    context: anchor,
    barrierDismissible: true,
    barrierLabel: 'Close grade menu',
    barrierColor: Colors.transparent,
    transitionDuration: Motion.fast,
    transitionBuilder:
        (_, a, _, child) => FadeTransition(
          opacity: a,
          child: ScaleTransition(
            alignment: Alignment.topRight,
            scale: Tween(begin: 0.94, end: 1.0).animate(a),
            child: child,
          ),
        ),
    pageBuilder:
        (context, _, _) => CustomSingleChildLayout(
          delegate: _Anchored(rect, MediaQuery.paddingOf(context)),
          child: Semantics(
            scopesRoute: true,
            explicitChildNodes: true,
            namesRoute: true,
            label: 'Grade for $title',
            child: GradeMenu(current: current),
          ),
        ),
  );
}

/// Below the anchor if it fits, else above; never off screen.
class _Anchored extends SingleChildLayoutDelegate {
  const _Anchored(this.anchor, this.padding);

  final Rect anchor;
  final EdgeInsets padding;
  static const _gap = 8.0, _edge = Space.gutter;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints c) => BoxConstraints(
    maxWidth: c.maxWidth - 2 * _edge,
    maxHeight: c.maxHeight - padding.vertical - 2 * _edge,
  );

  @override
  Offset getPositionForChild(Size size, Size child) {
    final x = (anchor.right - child.width).clamp(
      _edge,
      size.width - _edge - child.width,
    );
    final top = padding.top + _edge, bottom = size.height - padding.bottom;
    var y = anchor.bottom + _gap;
    if (y + child.height > bottom - _edge) y = anchor.top - _gap - child.height;
    return Offset(x, y.clamp(top, bottom - _edge - child.height));
  }

  @override
  bool shouldRelayout(_Anchored old) =>
      old.anchor != anchor || old.padding != padding;
}

/// The board's card: a 4-column grid of grades, the four codes that are not
/// grades under a hairline with their rule, then "Not graded yet".
class GradeMenu extends StatelessWidget {
  const GradeMenu({super.key, required this.current});

  final int current;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    // Grows with large text so the pills are not squeezed.
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    final small = TypeScale.label.copyWith(fontSize: 9.5, color: p.textMuted);

    Widget pill(String letter, {bool quiet = false, String? text}) {
      final value = reversegradecalc(letter);
      final on = value == current;
      return Semantics(
        button: true,
        selected: on,
        child: Material(
          color: on ? p.inverse : p.surfaceSunken,
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.pop(context, value),
            child: Container(
              constraints: const BoxConstraints(minHeight: 32),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              child: Text(
                text ?? letter.replaceAll('-', '−'),
                textAlign: TextAlign.center,
                style: TypeScale.caption.copyWith(
                  fontSize: quiet ? 11.5 : 12.5,
                  fontWeight: FontWeight.w700,
                  color: on ? p.onInverse : (quiet ? p.textMuted : p.text),
                ),
              ),
            ),
          ),
        ),
      );
    }

    Widget grid(List<String> gs, {bool quiet = false}) => Column(
      children: [
        for (var r = 0; r < gs.length; r += 4)
          Padding(
            padding: EdgeInsets.only(top: r == 0 ? 0 : 5),
            // Equal heights when large text wraps one pill.
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = r; i < r + 4; i++) ...[
                    if (i > r) const SizedBox(width: 5),
                    Expanded(child: pill(gs[i], quiet: quiet)),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
    Widget rule() => Container(height: 1, color: p.divider);

    return Container(
      width: 216 * scale,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2E17170F),
            blurRadius: 34,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Text('CHANGE GRADE', style: small),
              ),
              const SizedBox(height: 9),
              grid(letterGrades),
              const SizedBox(height: 9),
              rule(),
              const SizedBox(height: 9),
              grid([for (final (g, _) in specialGrades) g], quiet: true),
              const SizedBox(height: 9),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Text(
                  specialGradesNote,
                  style: small.copyWith(
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 9),
              rule(),
              const SizedBox(height: 9),
              pill('', quiet: true, text: 'Not graded yet'),
            ],
          ),
        ),
      ),
    );
  }
}
