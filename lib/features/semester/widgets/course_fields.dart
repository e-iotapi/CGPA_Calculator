import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/grading/grade_scale.dart';
import 'package:cgpa_calculator/features/semester/add_course_controller.dart';
import 'package:cgpa_calculator/features/semester/widgets/grade_menu.dart';
import 'package:cgpa_calculator/shared/widgets/card_row.dart';
import 'package:flutter/material.dart';

/// Every grade as a six-column grid of 31 px pills, then Ongoing and Not
/// yet as two half-width pills. Tapping the selected one clears it.
class GradeGrid extends StatelessWidget {
  const GradeGrid({super.key, required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  static final _grades = [
    for (final g in letterGrades)
      (g.replaceAll('-', '−'), reversegradecalc(g), false),
    for (final (g, _) in specialGrades) (g, reversegradecalc(g), true),
  ];

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    Widget pill(String text, int grade, {bool quiet = false}) {
      final on = value == grade;
      return Semantics(
        button: true,
        selected: on,
        label: 'Grade $text',
        child: Material(
          color: on ? p.inverse : p.surface,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap:
                () => onChanged(
                  on && grade != GradeCode.clr ? GradeCode.clr : grade,
                ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 31),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 4,
                  ),
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: TypeScale.caption.copyWith(
                      fontSize: 12.5,
                      fontWeight: on ? FontWeight.w700 : FontWeight.w600,
                      color:
                          on
                              ? p.onInverse
                              : quiet
                              ? p.icon
                              : p.text,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    Widget row(List<Widget> cells) => Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, c) in cells.indexed) ...[
              if (i > 0) const SizedBox(width: 5),
              Expanded(child: c),
            ],
          ],
        ),
      ),
    );

    return Column(
      children: [
        for (var r = 0; r < _grades.length; r += 6)
          row([
            for (var i = r; i < r + 6; i++)
              i < _grades.length
                  ? pill(_grades[i].$1, _grades[i].$2, quiet: _grades[i].$3)
                  : const SizedBox(),
          ]),
        row([
          pill('Ongoing', GradeCode.ongoing, quiet: true),
          pill('Not yet', GradeCode.clr, quiet: true),
        ]),
      ],
    );
  }
}

/// "Counts as": a sheet of the discipline's categories plus [value], the
/// current one ticked.
Future<String?> pickCategory(
  BuildContext context, {
  required String value,
  required String discipline,
}) async {
  final p = AppPalette.of(context);
  final options = {...categoryOptions(discipline), value};
  final picked = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: p.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    constraints: const BoxConstraints(maxWidth: 640),
    builder:
        (c) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                  child: Text(
                    'COUNTS AS',
                    style: TypeScale.label.copyWith(color: p.textMuted),
                  ),
                ),
                for (final t in options)
                  CardRow(
                    title: categoryLabel(t, discipline),
                    minHeight: 48,
                    trailing:
                        t == value
                            ? Icon(Icons.check_rounded, color: p.text)
                            : const SizedBox.shrink(),
                    onTap: () => Navigator.pop(c, t),
                  ),
              ],
            ),
          ),
        ),
  );
  return picked;
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

  Future<void> _open(BuildContext context) async {
    final picked = await pickCategory(
      context,
      value: value,
      discipline: discipline,
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
                  Icon(Icons.expand_more_rounded, size: 16, color: p.textMuted),
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
