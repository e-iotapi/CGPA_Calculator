import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/features/semester/semester_controller.dart';
import 'package:cgpa_calculator/features/stats/stats_controller.dart';
import 'package:cgpa_calculator/features/stats/stats_page.dart';
import 'package:cgpa_calculator/features/stats/widgets/cgpa_chart.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:flutter/material.dart';

/// Chart, the average needed for the target, and a slider per future
/// semester.
class ProgressionView extends StatelessWidget {
  const ProgressionView({
    super.key,
    required this.data,
    required this.onTargetChanged,
    required this.onPlanChanged,
  });

  final StatsData data;
  final ValueChanged<double> onTargetChanged;
  final void Function(String sem, double sgpa) onPlanChanged;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final muted = TypeScale.caption.copyWith(
      fontSize: 10.5,
      color: p.textMuted,
    );
    // Anything that rounds to 0.00 is no change.
    final delta = double.parse(data.delta.toStringAsFixed(2));
    return StatsBody(
      footer: StatsFooter(
        label: 'ON THIS PLAN YOU FINISH AT',
        value: '${data.finish.toStringAsFixed(2)} CGPA',
        trailing: Semantics(
          label:
              '${delta.abs().toStringAsFixed(2)} '
              '${delta < 0 ? 'down' : 'up'} on today',
          excludeSemantics: true,
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  delta < 0
                      ? Icons.trending_down_rounded
                      : delta > 0
                      ? Icons.trending_up_rounded
                      : Icons.trending_flat_rounded,
                  size: 15,
                  color: p.hero,
                ),
                const SizedBox(width: 5),
                Text(
                  '${delta < 0 ? '−' : '+'}${delta.abs().toStringAsFixed(2)}',
                  style: TypeScale.button.copyWith(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: p.hero,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      children: [
        AppCard(
          radius: Radii.card,
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: Space.md,
                runSpacing: Space.xs,
                children: [
                  Text(
                    'CGPA by semester',
                    style: TypeScale.body.copyWith(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: p.text,
                    ),
                  ),
                  Wrap(
                    spacing: 10,
                    children: [
                      _key('Actual', p.text, muted),
                      _key('Forecast', CgpaChart.forecastColor(p), muted),
                      _key('Target', p.behind, muted),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              CgpaChart(
                actual: data.actual,
                forecast: data.forecast,
                target: data.target,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _ask(p),
        if (data.planned.isNotEmpty) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Plan the rest',
                  style: TypeScale.section.copyWith(color: p.text),
                ),
              ),
              Text('drag to adjust', style: muted),
            ],
          ),
          const SizedBox(height: Space.sm),
          for (final s in data.planned) ...[
            _PlanCard(s: s, onChanged: (v) => onPlanChanged(s.sem, v)),
            const SizedBox(height: Space.sm),
          ],
        ],
      ],
    );
  }

  Widget _key(String label, Color c, TextStyle style) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 13,
        height: 3,
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 4),
      Text(label, style: style.copyWith(fontSize: 9.5)),
    ],
  );

  Widget _ask(AppPalette p) {
    final req = data.required;
    final strong = TypeScale.editorial.copyWith(
      fontSize: 20,
      fontWeight: FontWeight.w800,
      color: p.onHero,
    );
    final body = strong.copyWith(fontWeight: FontWeight.w500);
    final t = data.target.toStringAsFixed(2);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 12, 17),
      decoration: BoxDecoration(
        color: p.hero,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'TO REACH $t',
                  style: TypeScale.label.copyWith(color: p.onHeroMuted),
                ),
              ),
              _step(p, Icons.remove_rounded, 'Lower target', -0.1),
              const SizedBox(width: 6),
              _step(p, Icons.add_rounded, 'Raise target', 0.1),
            ],
          ),
          const SizedBox(height: 4),
          Text.rich(
            req == null
                ? TextSpan(text: 'Nothing left to plan.', style: body)
                : TextSpan(
                  style: body,
                  children: [
                    const TextSpan(text: 'You need '),
                    TextSpan(text: req.toStringAsFixed(2), style: strong),
                    const TextSpan(text: ' average across your remaining '),
                    TextSpan(
                      text: '${formatCredits(data.remaining)} credits',
                      style: strong,
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
          ),
          if (data.note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              data.note,
              style: TypeScale.caption.copyWith(
                height: 1.45,
                color: p.onHeroMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _step(AppPalette p, IconData icon, String tip, double by) {
    final next = double.parse((data.target + by).toStringAsFixed(2));
    final ok = next >= 4 && next <= 10;
    return Tooltip(
      message: tip,
      child: Material(
        color: p.onHero.withValues(alpha: 0.1),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: ok ? () => onTargetChanged(next) : null,
          child: SizedBox.square(
            dimension: Sizes.minTouch,
            child: Icon(
              icon,
              size: 18,
              color: p.onHero.withValues(alpha: ok ? 1 : 0.3),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.s, required this.onChanged});

  final PlannedSemester s;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return AppCard(
      radius: Radii.row - 2,
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: s.sem,
                    children: [
                      TextSpan(
                        text: ' · ${formatCredits(s.credits)} credits',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: p.textMuted,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TypeScale.body.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: p.text,
                  ),
                ),
              ),
              Text(
                s.sgpa.toStringAsFixed(2),
                style: TypeScale.section.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: p.text,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                'SGPA',
                style: TypeScale.caption.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: p.textMuted,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 6,
              activeTrackColor: p.inverse,
              inactiveTrackColor: p.divider,
              thumbColor: p.surface,
              overlayColor: p.inverse.withValues(alpha: 0.08),
              thumbShape: _RingThumb(p.inverse),
            ),
            child: Slider(
              value: s.sgpa,
              min: 4,
              max: 10,
              divisions: 120,
              label: s.sgpa.toStringAsFixed(2),
              semanticFormatterCallback:
                  (v) => '${s.sem} SGPA ${v.toStringAsFixed(2)}',
              onChanged: onChanged,
            ),
          ),
          Text.rich(
            TextSpan(
              text: 'CGPA moves to ',
              children: [
                TextSpan(
                  text: s.cgpaAfter.toStringAsFixed(2),
                  style: TextStyle(fontWeight: FontWeight.w700, color: p.text),
                ),
              ],
            ),
            style: TypeScale.caption.copyWith(
              fontSize: 10.5,
              color: p.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// White thumb with a dark ring, as on the design board.
class _RingThumb extends SliderComponentShape {
  const _RingThumb(this.ring);
  final Color ring;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.square(18);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final c = context.canvas;
    c.drawCircle(center, 9, Paint()..color = sliderTheme.thumbColor!);
    c.drawCircle(
      center,
      7.75,
      Paint()
        ..color = ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }
}
