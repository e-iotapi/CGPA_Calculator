import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/features/import/import_plan.dart';
import 'package:cgpa_calculator/features/import/performance_sheet.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:flutter/material.dart';

/// What an import will change, before it changes anything. True to go ahead.
Future<bool> showImportPreview(
  BuildContext context, {
  required PerformanceSheet sheet,
  required ImportPlan plan,
  bool newNeeds = false,
}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppPalette.of(context).background,
    constraints: const BoxConstraints(maxWidth: 640),
    builder:
        (_) => ImportPreview(sheet: sheet, plan: plan, newNeeds: newNeeds),
  );
  return ok ?? false;
}

class ImportPreview extends StatelessWidget {
  const ImportPreview({
    super.key,
    required this.sheet,
    required this.plan,
    this.newNeeds = false,
  });

  final PerformanceSheet sheet;
  final ImportPlan plan;

  /// The sheet's elective requirements differ from what Pointer has.
  final bool newNeeds;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final muted = TypeScale.caption.copyWith(color: p.textMuted, height: 1.4);
    String n(int k, String one, String many) => '$k ${k == 1 ? one : many}';
    final needs = {'CDC': sheet.cdc, ...sheet.needs};
    final units = needs.values.fold(0, (s, n) => s + (n?.units ?? 0));
    String need(String tag) => switch (needs[tag]) {
      (courses: 0, units: 0) || null => '$tag none',
      final r => '$tag ${n(r.courses, 'course', 'courses')}, ${r.units} units',
    };

    final lines = [
      if (plan.graded > 0) n(plan.graded, 'grade set', 'grades set'),
      if (plan.add.isNotEmpty)
        n(plan.add.length, 'course added', 'courses added'),
      if (plan.moved > 0)
        '${n(plan.moved, 'course', 'courses')} moved to the semester you '
            'took ${plan.moved == 1 ? 'it' : 'them'}',
      if (plan.retakes > 0)
        '${n(plan.retakes, 'retake', 'retakes')}: only the latest attempt '
            'is kept',
      if (plan.renumbered > 0)
        '${n(plan.renumbered, 'course', 'courses')} renamed to the code on '
            'your sheet',
      if (plan.running.isNotEmpty)
        '${n(plan.running.length, 'running course', 'running courses')} '
            'cleared until results: ${plan.running.join(', ')}',
      if (plan.unchanged > 0) '${plan.unchanged} already up to date',
      if (newNeeds)
        'Degree page set from your sheet: $units units in all. '
            '${['CDC', 'HEL', 'DEL', 'EL'].map(need).join(' · ')}',
    ];

    final after = plan.cgpaAfter?.toStringAsFixed(2);
    final stated = sheet.cgpa?.toStringAsFixed(2);
    final matches = after != null && after == stated;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          Space.gutter,
          0,
          Space.gutter,
          Space.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Import from ERP',
              style: TypeScale.title.copyWith(color: p.text),
            ),
            if (sheet.studentId != null)
              Text('Performance sheet for ${sheet.studentId}', style: muted),
            const SizedBox(height: Space.md),
            if (plan.isEmpty && !newNeeds)
              Text(
                'Everything on your sheet is already in Pointer.',
                style: TypeScale.body.copyWith(color: p.text),
              ),
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: p.accent,
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Text(
                        l,
                        style: TypeScale.body.copyWith(color: p.text),
                      ),
                    ),
                  ],
                ),
              ),
            if (after != null) ...[
              const SizedBox(height: Space.sm),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: matches ? p.hero : p.surface,
                  borderRadius: BorderRadius.circular(Radii.row),
                ),
                child: Text(
                  matches
                      ? 'CGPA after import: $after, the same as your sheet.'
                      : 'CGPA after import: $after. Your sheet says '
                          '${stated ?? 'nothing'}, so a course may be counted '
                          'differently; you can fix it after importing.',
                  style: TypeScale.body.copyWith(
                    color: matches ? p.onHero : p.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            if (plan.dropped.isNotEmpty) ...[
              const FieldLabel('Removed: not on your sheet'),
              Text(
                '${plan.dropped.join(', ')}. Your sheet lists every course '
                'you took in these semesters, so these would count twice or '
                'not at all.',
                style: muted,
              ),
            ],
            if (plan.cleared.isNotEmpty) ...[
              const FieldLabel('Actual grade cleared'),
              Text(
                '${plan.cleared.join(', ')}. These semesters have not happened '
                'yet; the courses stay, and Expected keeps its grades.',
                style: muted,
              ),
            ],
            if (plan.unknownGrades.isNotEmpty) ...[
              const FieldLabel('Grades Pointer does not know'),
              Text(
                '${plan.unknownGrades.join(', ')}. These are left ungraded.',
                style: muted,
              ),
            ],
            if (sheet.unplaced.isNotEmpty) ...[
              const FieldLabel('Not imported'),
              Text(
                '${sheet.unplaced.join(', ')}: Pointer has no semester for '
                'these.',
                style: muted,
              ),
            ],
            const SizedBox(height: Space.md),
            Text(
              'Only Actual grades change. Expected and your other profiles '
              'stay as they are. Your PDF was read on this device and not '
              'uploaded.',
              style: muted,
            ),
            const SizedBox(height: Space.lg),
            PrimaryButton(
              label: 'Import',
              onPressed:
                  plan.isEmpty && !newNeeds
                      ? null
                      : () => Navigator.pop(context, true),
            ),
            const SizedBox(height: Space.sm),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: TypeScale.button.copyWith(color: p.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
