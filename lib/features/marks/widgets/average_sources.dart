import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/grading/average_sources.dart';
import 'package:cgpa_calculator/core/models/marks.dart';
import 'package:cgpa_calculator/core/models/offering.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/marks/marks_format.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:flutter/material.dart';

/// "class avg 14.20" from what is published, or "no class avg yet". The
/// Marks screen shows official averages only, unlabelled (§8).
String classAvgText(double? official, {double? outOf}) =>
    official == null
        ? 'no class avg yet'
        : 'class avg ${marks2(official)}'
            '${outOf == null || outOf <= 0 ? '' : ' / ${marks2(outOf)}'}';

/// Board `AverageSources`: every average in play for one course, where it
/// comes from, and the student's own course average.
class AverageSourcesPage extends StatefulWidget {
  const AverageSourcesPage({
    super.key,
    required this.course,
    required this.courseAverage,
    required this.evals,
    required this.official,
    required this.detached,
    required this.onCourseAverage,
  });

  final Course course;
  final double? courseAverage;
  final List<Evaluative> evals;
  final Offering? official;
  final Map<String, int> detached;

  /// The student typed (or cleared) their own course average.
  final Future<void> Function(double?) onCourseAverage;

  @override
  State<AverageSourcesPage> createState() => _AverageSourcesPageState();
}

class _AverageSourcesPageState extends State<AverageSourcesPage> {
  late final _mine = TextEditingController(
    text: widget.courseAverage == null ? '' : marks2(widget.courseAverage!),
  );
  late double? _course = widget.courseAverage;

  @override
  void dispose() {
    _mine.dispose();
    super.dispose();
  }

  Widget _row(
    AppPalette p, {
    required String level,
    required String name,
    required SourcedAverage? a,
    double? outOf,
    int parts = 0,
  }) {
    final (fill, ink) = switch (a?.source) {
      AverageSource.official => (p.accent, p.onInverse),
      AverageSource.yours => (p.inverse, p.onInverse),
      _ => (p.surfaceSunken, p.text),
    };
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  level,
                  style: TypeScale.label.copyWith(color: p.textMuted),
                ),
                Text(
                  name,
                  style: TypeScale.body.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  a == null ? 'No average yet' : sourceLine(a, parts: parts),
                  style: TypeScale.caption.copyWith(color: p.textMuted),
                ),
              ],
            ),
          ),
          if (a != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${marks2(a.value)}'
                '${outOf == null || outOf <= 0 ? '' : ' / ${marks2(outOf)}'}',
                style: TypeScale.body.copyWith(
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final c = widget.course;
    final off = widget.official;
    final d = widget.detached;
    return PageFrame(
      header: PageHeader(
        eyebrow: '${c.id} · ${marks2(c.credits)} CREDITS',
        title: c.title,
      ),
      children: [
        Text(
          'CLASS AVERAGES',
          style: TypeScale.label.copyWith(color: p.textMuted),
        ),
        const SizedBox(height: Space.sm),
        _row(
          p,
          level: 'COURSE',
          name: c.title,
          a: courseAverageOf(_course, off, d),
        ),
        const SizedBox(height: Space.xs),
        for (final e in widget.evals) ...[
          _row(
            p,
            level: 'COMPONENT',
            name: e.name,
            a: componentAverageOf(e, off, d),
            outOf: e.parts.fold<double>(0, (s, x) => s + x.outOf),
            parts: e.parts.where((x) => x.average != null).length,
          ),
          const SizedBox(height: Space.xs),
          if (e.parts.length > 1)
            for (final (i, part) in e.parts.indexed)
              if (partAverageOf(e, i, off, d) case final a?) ...[
                _row(
                  p,
                  level: 'PART',
                  name: part.name.isEmpty ? 'Part ${i + 1}' : part.name,
                  a: a,
                  outOf: part.outOf,
                ),
                const SizedBox(height: Space.xs),
              ],
        ],
        const SizedBox(height: Space.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: AppTextField(
                controller: _mine,
                label: 'Your course average',
                hint:
                    off?.courseAverage == null
                        ? 'From your instructor'
                        : 'Blank uses the official ${marks2(off!.courseAverage!)}',
                number: true,
                dense: true,
              ),
            ),
            const SizedBox(width: Space.sm),
            TextButton(
              onPressed: () async {
                final v = double.tryParse(_mine.text.trim());
                await widget.onCourseAverage(v);
                if (mounted) setState(() => _course = v ?? off?.courseAverage);
              },
              child: const Text('Save'),
            ),
          ],
        ),
        const SizedBox(height: Space.lg),
        Text(
          'WHICH NUMBER WINS',
          style: TypeScale.label.copyWith(color: p.textMuted),
        ),
        const SizedBox(height: Space.xs),
        Wrap(
          spacing: Space.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final (i, s) in AverageSource.values.indexed) ...[
              Text(
                s.label.toUpperCase(),
                style: TypeScale.label.copyWith(fontWeight: FontWeight.w700),
              ),
              if (i < 2) Text('then', style: TypeScale.caption),
            ],
          ],
        ),
        const SizedBox(height: Space.xs),
        Text(
          'Decided separately for the course, each component and each part. '
          'Clear a number you typed and the official one comes back.',
          style: TypeScale.caption.copyWith(height: 1.45, color: p.textMuted),
        ),
      ],
    );
  }
}
