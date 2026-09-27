import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/grading/marks.dart';
import 'package:cgpa_calculator/core/models/marks.dart';
import 'package:cgpa_calculator/features/marks/marks_format.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/dashed_outline.dart';
import 'package:flutter/material.dart';

/// One evaluative, as a compact row (board `Marks`): name, a line saying how
/// many parts it has and its published class average, the counting rule,
/// its weight and what it gives. A group with a dropped part lists its parts,
/// the dropped ones greyed. Not graded yet: dashed and faded, "not yet".
/// Every card carries a Duplicate button (kept at the user's request; the
/// board has none).
class EvaluativeCard extends StatelessWidget {
  const EvaluativeCard({
    super.key,
    required this.e,
    required this.weighted,
    required this.onTap,
    this.onDuplicate,
    this.classAverage,
    this.showAverage = true,
    this.tag,
  });

  final Evaluative e;
  final bool weighted;
  final VoidCallback onTap;

  /// A copy with the next name and no marks.
  final VoidCallback? onDuplicate;

  /// The published component average; the Marks screen shows only this,
  /// unlabelled (§8).
  final double? classAverage;
  final bool showAverage;

  /// Where it stands against the official scheme: "YOURS", "NOT OFFICIAL",
  /// or null for an official component that updates, or the student's own.
  final String? tag;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final value = contribution(e);
    final ungraded = value == null;
    final group = e.parts.length > 1;
    final counted = countedParts(e).toSet();
    final dropped = droppedParts(e).toSet();
    final datedParts = e.parts.where((x) => x.date != null).length;
    // Board: a small group with a part dropped opens up; the rest stay
    // one line.
    final expanded = group && e.parts.length <= 3 && dropped.isNotEmpty;
    final muted = TypeScale.caption.copyWith(fontSize: 10, color: p.textMuted);

    final sub = <Widget>[
      if (ungraded)
        Text('not yet', style: muted)
      else ...[
        if (group && !expanded)
          Text(
            datedParts == e.parts.length
                ? '${e.parts.length} dated parts ·'
                : '${e.parts.length} parts ·',
            style: muted,
          ),
        if (showAverage)
          _ClassAverage(e: e, official: classAverage, style: muted),
      ],
    ];

    final head = Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  text: e.name,
                  children: [
                    if (tag != null)
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: _Tag(tag!),
                        ),
                      ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TypeScale.body.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: ungraded ? p.textMuted : p.text,
                ),
              ),
              if (sub.isNotEmpty) ...[
                const SizedBox(height: 2),
                // Wraps rather than overflowing at large text sizes.
                Wrap(
                  spacing: 5,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: sub,
                ),
              ],
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

    final label = [
      e.name,
      if (ungraded) 'not graded yet' else '${value.toStringAsFixed(2)} secured',
      weighted ? '${marks2(e.weight)} percent' : '${marks2(e.weight)} marks',
      if (dropped.isNotEmpty)
        'dropped: ${dropped.map((d) => d.name).join(', ')}',
    ].join(', ');
    final dup = onDuplicate;
    final card = AppCard(
      radius: 20,
      color: ungraded ? p.surface.withValues(alpha: 0.55) : null,
      padding: EdgeInsets.zero,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: label,
              excludeSemantics: true,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    14,
                    10,
                    dup == null ? 14 : 0,
                    10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      head,
                      if (expanded) ...[
                        const SizedBox(height: 7),
                        for (final part in e.parts)
                          _PartLine(
                            part: part,
                            counted: counted.contains(part),
                            dropped: dropped.contains(part),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (dup != null)
            // 44px target beside the row, not nested inside it.
            IconButton(
              tooltip: 'Duplicate ${e.name}',
              onPressed: dup,
              constraints: const BoxConstraints.tightFor(
                width: Sizes.minTouch,
                height: Sizes.minTouch + 12,
              ),
              padding: EdgeInsets.zero,
              icon: Icon(Icons.copy_rounded, size: 16, color: p.textMuted),
            ),
        ],
      ),
    );
    return ungraded
        ? DashedOutline(color: p.outline, radius: 20, child: card)
        : card;
  }
}

/// "class avg 14.20 / 25", or "no class avg yet", and how far ahead or
/// behind you are against the average in play.
class _ClassAverage extends StatelessWidget {
  const _ClassAverage({
    required this.e,
    required this.official,
    required this.style,
  });

  final Evaluative e;
  final double? official;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final delta = componentDelta(e);
    final outOf = e.parts.fold(0.0, (s, x) => s + x.outOf);
    return Wrap(
      spacing: 5,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          official == null
              ? 'no class avg yet'
              : 'class avg ${marks2(official!)}'
                  '${outOf > 0 ? ' / ${marks2(outOf)}' : ''}',
          style: style,
        ),
        // Not on the board, kept: the per-component comparison (§8).
        if (delta != null)
          Semantics(
            label: deltaWords(delta, 'of the class'),
            excludeSemantics: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  deltaIcon(delta),
                  size: 13,
                  color: delta < 0 ? p.behind : p.ahead,
                ),
                Text(
                  deltaWords(delta),
                  style: style.copyWith(
                    fontWeight: FontWeight.w700,
                    color: delta < 0 ? p.behind : p.ahead,
                  ),
                ),
              ],
            ),
          ),
      ],
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
                if (part.average != null)
                  TextSpan(
                    text: ' · avg ${marks2(part.average!)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: p.textMuted,
                    ),
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

class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = AppPalette.of(context).noticeTone;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: t.fill,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TypeScale.caption.copyWith(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
          color: t.text,
        ),
      ),
    );
  }
}
