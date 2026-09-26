import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/grading/grade_scale.dart';
import 'package:cgpa_calculator/features/semester/add_course_controller.dart';
import 'package:cgpa_calculator/features/semester/widgets/grade_menu.dart';
import 'package:flutter/material.dart';

/// All twelve grades as a six-column grid of pills. Tapping the selected one
/// clears it back to "not graded yet".
class GradeGrid extends StatelessWidget {
  const GradeGrid({super.key, required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  static final _grades = [
    for (final g in letterGrades) (g.replaceAll('-', '−'), reversegradecalc(g)),
    for (final (g, _) in specialGrades) (g, reversegradecalc(g)),
  ];

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    Widget pill(String text, int grade) {
      final on = value == grade;
      return Semantics(
        button: true,
        selected: on,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => onChanged(on ? GradeCode.clr : grade),
          child: Container(
            constraints: const BoxConstraints(minHeight: Sizes.minTouch),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: on ? p.inverse : p.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: on ? p.inverse : p.border),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                text,
                style: TypeScale.caption.copyWith(
                  fontWeight: on ? FontWeight.w700 : FontWeight.w600,
                  color: on ? p.onInverse : p.text,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (var r = 0; r < _grades.length; r += 6)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              children: [
                for (var i = r; i < r + 6; i++) ...[
                  if (i > r) const SizedBox(width: 5),
                  Expanded(child: pill(_grades[i].$1, _grades[i].$2)),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// The "counts as" menu: the discipline's categories plus [value].
class CategoryDropdown extends StatelessWidget {
  const CategoryDropdown({
    super.key,
    required this.value,
    required this.discipline,
    required this.onChanged,
    this.bordered = true,
  });

  final String value;
  final String discipline;
  final ValueChanged<String> onChanged;

  /// Off on a coloured card, where the white field needs no outline.
  final bool bordered;

  /// A menu anchored under the field, as wide as it.
  Future<void> _open(BuildContext context) async {
    final p = AppPalette.of(context);
    final box = context.findRenderObject()! as RenderBox;
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final topLeft = box.localToGlobal(
      Offset(0, box.size.height + 4),
      ancestor: overlay,
    );
    final picked = await showMenu<String>(
      context: context,
      color: p.surface,
      constraints: BoxConstraints.tightFor(width: box.size.width),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      position: RelativeRect.fromRect(
        topLeft & Size(box.size.width, 0),
        Offset.zero & overlay.size,
      ),
      items: [
        for (final t in {...categoryOptions(discipline), value})
          PopupMenuItem(
            value: t,
            height: 40,
            child: Text(
              categoryLabel(t, discipline),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TypeScale.caption.copyWith(
                color: p.text,
                fontWeight: t == value ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
      ],
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final label = categoryLabel(value, discipline);
    return Semantics(
      button: true,
      label: 'Counts as $label',
      excludeSemantics: true,
      child: Material(
        color: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
          side: bordered ? BorderSide(color: p.border) : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _open(context),
          child: SizedBox(
            height: 38,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.md),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TypeScale.caption.copyWith(
                        color: p.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: Space.xs),
                  Icon(
                    Icons.expand_more_rounded,
                    size: 16,
                    color: p.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A capitalised field label with an optional hint under the field.
class FieldSection extends StatelessWidget {
  const FieldSection({
    super.key,
    required this.label,
    required this.child,
    this.note,
  });

  final String label;
  final Widget child;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: TypeScale.label.copyWith(color: p.textMuted)),
          const SizedBox(height: Space.xs),
          child,
          if (note != null) ...[
            const SizedBox(height: Space.xs),
            Text(note!, style: TypeScale.caption.copyWith(color: p.textMuted)),
          ],
        ],
      ),
    );
  }
}
