import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/grading/average_sources.dart';
import 'package:cgpa_calculator/core/models/marks.dart';
import 'package:cgpa_calculator/core/models/offering.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/marks/marks_format.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:cgpa_calculator/shared/widgets/tag_badge.dart';
import 'package:flutter/material.dart';

/// "class avg 14.20" from what is published, or "no class avg yet". The
/// Marks screen shows official averages only, unlabelled (§8).
String classAvgText(double? official, {double? outOf}) =>
    official == null
        ? 'no class avg yet'
        : 'class avg ${marks2(official)}'
            '${outOf == null || outOf <= 0 ? '' : ' / ${marks2(outOf)}'}';

/// Board `AverageSources`: every average in play for one course and where
/// it comes from. Read-only; a row opens where that number is typed.
class AverageSourcesPage extends StatelessWidget {
  const AverageSourcesPage({
    super.key,
    required this.course,
    required this.courseAverage,
    required this.evals,
    required this.official,
    required this.detached,
    this.onOpenCourse,
    this.onOpenEval,
  });

  final Course course;
  final double? courseAverage;
  final List<Evaluative> evals;
  final Offering? official;
  final Map<String, int> detached;

  /// Course setup's CLASS AVERAGE.
  final VoidCallback? onOpenCourse;

  /// That component's Edit evaluative.
  final void Function(Evaluative e)? onOpenEval;

  static TagTone _tone(AverageSource s) => switch (s) {
    AverageSource.yours => TagTone.yours,
    AverageSource.official => TagTone.official,
    AverageSource.fromParts => TagTone.fromParts,
  };

  Widget _row(
    AppPalette p, {
    required String level,
    required String name,
    required SourcedAverage? a,
    VoidCallback? onTap,
    double? outOf,
    int parts = 0,
  }) {
    final row = Padding(
      padding: const EdgeInsets.fromLTRB(15, 11, 15, 11),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  level,
                  style: TypeScale.label.copyWith(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: p.textMuted,
                  ),
                ),
                Text(
                  name,
                  style: TypeScale.body.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: p.text,
                  ),
                ),
                Text(
                  a == null ? 'No average yet' : sourceLine(a, parts: parts),
                  style: TypeScale.caption.copyWith(
                    fontSize: 11,
                    height: 1.4,
                    color: p.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (a != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              spacing: 4,
              children: [
                Text(
                  '${marks2(a.value)}'
                  '${outOf == null || outOf <= 0 ? '' : ' / ${marks2(outOf)}'}',
                  style: TypeScale.body.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: p.text,
                  ),
                ),
                TagBadge(a.source.label.toUpperCase(), tone: _tone(a.source)),
              ],
            ),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: p.textMuted),
          ],
        ],
      ),
    );
    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final c = course;
    final off = official;
    final d = detached;
    final rows = <Widget>[
      _row(
        p,
        level: 'COURSE',
        name: c.title,
        a: courseAverageOf(courseAverage, off, d),
        onTap: onOpenCourse,
      ),
      for (final e in evals) ...[
        _row(
          p,
          level: 'COMPONENT',
          name: e.name,
          a: componentAverageOf(e, off, d),
          outOf: e.parts.fold<double>(0, (s, x) => s + x.outOf),
          parts: e.parts.where((x) => x.average != null).length,
          onTap: onOpenEval == null ? null : () => onOpenEval!(e),
        ),
        if (e.parts.length > 1)
          for (final (i, part) in e.parts.indexed)
            if (partAverageOf(e, i, off, d) case final a?)
              _row(
                p,
                level: 'PART',
                name: part.name.isEmpty ? 'Part ${i + 1}' : part.name,
                a: a,
                outOf: part.outOf,
                onTap: onOpenEval == null ? null : () => onOpenEval!(e),
              ),
      ],
    ];
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
        Material(
          color: p.surface,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, r) in rows.indexed) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    indent: 15,
                    endIndent: 15,
                    color: p.divider,
                  ),
                r,
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Text(
                'WHICH NUMBER WINS',
                style: TypeScale.label.copyWith(color: p.textMuted),
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final (i, s) in AverageSource.values.indexed) ...[
                    TagBadge(s.label.toUpperCase(), tone: _tone(s)),
                    if (i < 2)
                      Text(
                        'then',
                        style: TypeScale.caption.copyWith(color: p.textMuted),
                      ),
                  ],
                ],
              ),
              Text(
                'Decided separately for the course, each component and each '
                'part. Clear a number you typed and the official one comes '
                'back.',
                style: TypeScale.caption.copyWith(
                  fontSize: 11,
                  height: 1.45,
                  color: p.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
