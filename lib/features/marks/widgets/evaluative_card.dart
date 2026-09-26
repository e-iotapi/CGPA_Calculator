import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/grading/marks.dart';
import 'package:cgpa_calculator/core/models/marks.dart';
import 'package:cgpa_calculator/features/marks/marks_format.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/dashed_outline.dart';
import 'package:flutter/material.dart';

/// One evaluative: name, how many parts count, its weight and what it gives.
/// Groups list their parts, with dropped ones kept visible and labelled;
/// long dated series collapse to their date range.
class EvaluativeCard extends StatelessWidget {
  const EvaluativeCard({
    super.key,
    required this.e,
    required this.weighted,
    required this.onTap,
  });

  final Evaluative e;
  final bool weighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final value = contribution(e);
    final ungraded = value == null;
    final group = e.parts.length > 1;
    final collapsed = e.parts.length > 3;
    final counted = countedParts(e).toSet();
    final dropped = droppedParts(e).toSet();
    final dates = [
      for (final part in e.parts)
        if (part.date != null) part.date!,
    ]..sort();

    final head = Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                e.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TypeScale.body.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: ungraded ? p.textMuted : p.text,
                ),
              ),
              if (collapsed)
                Text(
                  dates.isEmpty
                      ? '${e.parts.length} parts'
                      : '${dates.length} dated parts · '
                          '${shortDate(dates.first)} → ${shortDate(dates.last)}',
                  style: TypeScale.caption.copyWith(
                    fontSize: 10,
                    color: p.textMuted,
                  ),
                ),
            ],
          ),
        ),
        if (group) ...[
          const SizedBox(width: Space.sm),
          _Badge(
            e.countBest > 0 && e.countBest < e.parts.length
                ? 'BEST ${e.countBest}/${e.parts.length}'
                : 'ALL ${e.parts.length}',
            best: e.countBest > 0 && e.countBest < e.parts.length,
          ),
        ],
        const SizedBox(width: Space.sm),
        Text(
          weighted ? '${marks2(e.weight)}%' : '${marks2(e.weight)} marks',
          style: TypeScale.caption.copyWith(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: p.textMuted,
          ),
        ),
        const SizedBox(width: Space.sm),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 40),
          child: Text(
            ungraded ? '—' : value.toStringAsFixed(2),
            textAlign: TextAlign.right,
            style: TypeScale.body.copyWith(
              fontSize: ungraded ? 11.5 : 14,
              fontWeight: ungraded ? FontWeight.w600 : FontWeight.w800,
              color: ungraded ? p.textMuted : p.text,
            ),
          ),
        ),
      ],
    );

    final card = AppCard(
      onTap: onTap,
      radius: Radii.row - 2,
      color: ungraded ? p.surface.withValues(alpha: 0.55) : null,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          head,
          if (group && !collapsed) ...[
            const SizedBox(height: 9),
            for (final part in e.parts)
              _PartLine(
                part: part,
                counted: counted.contains(part),
                dropped: dropped.contains(part),
              ),
          ],
        ],
      ),
    );
    final label = [
      e.name,
      if (ungraded) 'not graded yet' else '${value.toStringAsFixed(2)} secured',
      weighted ? '${marks2(e.weight)} percent' : '${marks2(e.weight)} marks',
      if (dropped.isNotEmpty)
        'dropped: ${dropped.map((d) => d.name).join(', ')}',
    ].join(', ');
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child:
          ungraded
              ? DashedOutline(
                color: p.outline,
                radius: Radii.row - 2,
                child: card,
              )
              : card,
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, {required this.best});
  final String text;
  final bool best;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final tone = best ? p.gradeTone('A') : p.mutedTone;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: tone.fill,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        text,
        style: TypeScale.label.copyWith(fontSize: 9.5, color: tone.text),
      ),
    );
  }
}

class _PartLine extends StatelessWidget {
  const _PartLine({
    required this.part,
    required this.counted,
    required this.dropped,
  });

  final EvalPart part;
  final bool counted;
  final bool dropped;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final dim = !counted;
    final style = TypeScale.caption.copyWith(
      fontSize: 11.5,
      color: dim ? p.textMuted : p.icon,
    );
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 5),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: counted ? p.ahead : null,
              border: counted ? null : Border.all(color: p.textMuted),
            ),
          ),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: part.name.isEmpty ? 'Part' : part.name,
                children: [
                  if (dropped)
                    TextSpan(
                      text: ' · DROPPED',
                      style: style.copyWith(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          Text.rich(
            TextSpan(
              text: part.marks == null ? '—' : marks2(part.marks!),
              children: [
                TextSpan(
                  text: ' / ${marks2(part.outOf)}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            style: style.copyWith(
              fontWeight: FontWeight.w700,
              color: dim ? p.textMuted : p.text,
            ),
          ),
        ],
      ),
    );
  }
}
