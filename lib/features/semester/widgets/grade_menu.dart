import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/grading/grade_scale.dart';
import 'package:cgpa_calculator/shared/widgets/grade_chip.dart';
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

/// Opens the grade menu and returns the stored value picked, or null.
Future<int?> showGradeMenu(
  BuildContext context, {
  required int current,
  required String title,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppPalette.of(context).background,
    builder: (_) => GradeMenu(current: current, title: title),
  );
}

class GradeMenu extends StatelessWidget {
  const GradeMenu({super.key, required this.current, required this.title});

  final int current;
  final String title;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    Widget pick(String letter, Widget child) => Semantics(
      button: true,
      selected: reversegradecalc(letter) == current,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.chip),
        onTap: () => Navigator.pop(context, reversegradecalc(letter)),
        child: child,
      ),
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          Space.gutter,
          0,
          Space.gutter,
          Space.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TypeScale.title.copyWith(color: p.text),
            ),
            const SizedBox(height: Space.md),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                for (final g in letterGrades)
                  pick(
                    g,
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 56,
                        minHeight: Sizes.minTouch,
                      ),
                      child: Center(
                        widthFactor: 1,
                        child: _selected(
                          context,
                          reversegradecalc(g) == current,
                          GradeChip(g),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Space.lg),
            Text(
              'NOT A GRADE',
              style: TypeScale.label.copyWith(color: p.textMuted),
            ),
            const SizedBox(height: Space.xs),
            for (final (g, what) in specialGrades)
              pick(
                g,
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.xs),
                  child: Row(
                    children: [
                      _selected(
                        context,
                        reversegradecalc(g) == current,
                        GradeChip(g, muted: true),
                      ),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: Text(
                          what,
                          style: TypeScale.caption.copyWith(color: p.text),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: Space.sm),
            pick(
              '',
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: Sizes.minTouch),
                child: Row(
                  children: [
                    Icon(
                      current == GradeCode.clr
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      size: 20,
                      color: p.icon,
                    ),
                    const SizedBox(width: Space.md),
                    Text(
                      'Not graded yet',
                      style: TypeScale.body.copyWith(color: p.text),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _selected(BuildContext context, bool on, Widget chip) {
    if (!on) return chip;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.chip + 3),
        border: Border.all(color: AppPalette.of(context).text, width: 2),
      ),
      child: Padding(padding: const EdgeInsets.all(1), child: chip),
    );
  }
}
