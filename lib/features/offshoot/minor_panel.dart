import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/grading/grade_scale.dart';
import 'package:cgpa_calculator/core/grading/minor_progress.dart';
import 'package:cgpa_calculator/core/models/minors.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/grade_chip.dart';
import 'package:cgpa_calculator/shared/widgets/pill_button.dart';
import 'package:flutter/material.dart';

/// Whether [minor] is open to [discipline] ("B3A7", "--A7"…).
bool minorOpenTo(Minor minor, String discipline) =>
    !minor.notFor.contains(discipline.substring(0, 2)) &&
    !minor.notFor.contains(discipline.substring(2, 4));

/// The minor view of the offshoot tab: the minors to choose from, or the
/// chosen one's courses and where each stands.
class MinorPanel extends StatelessWidget {
  const MinorPanel({
    super.key,
    required this.progress,
    required this.discipline,
    required this.onChoose,
  });

  /// Null while no minor is chosen.
  final MinorProgress? progress;
  final String discipline;

  /// Null stops pursuing the minor.
  final ValueChanged<Minor?> onChoose;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final muted = TypeScale.caption.copyWith(
      fontSize: 11.5,
      height: 1.5,
      color: p.textMuted,
    );
    final pr = progress;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.sm,
        Space.gutter,
        Space.xxl,
      ),
      children:
          pr == null
              ? [
                Text(
                  'A minor is declared at the end of the second year. Pick '
                  'one to see its courses and how far you are.',
                  style: muted,
                ),
                const SizedBox(height: Space.lg),
                MinorList(discipline: discipline, onChoose: onChoose),
              ]
              : [
                _Summary(
                  progress: pr,
                  onChange: () => _change(context),
                  onStop: () => onChoose(null),
                ),
                const SizedBox(height: Space.lg),
                _Section('Core · all required'),
                for (final s in pr.core) _SlotRow(s),
                for (final (i, pool) in pr.minor.pools.indexed) ...[
                  const SizedBox(height: Space.md),
                  _Section(_poolTitle(pr.minor, pool)),
                  for (final s in pr.pools[i]) _SlotRow(s),
                ],
                const SizedBox(height: Space.lg),
                Text(
                  'Grades come from your Actual profile. At most '
                  '$minorOverlapCourses courses ($minorOverlapUnits units) '
                  'that your own degree requires can count, at most one '
                  'project, and the minor\'s courses need a GPA of '
                  '$minorMinGpa or more.',
                  style: muted,
                ),
              ],
    );
  }

  String _poolTitle(Minor m, MinorPool pool) {
    final name = pool.name == null ? 'Electives' : '${pool.name} electives';
    final min = m.pools.length == 1 ? m.electives : pool.min;
    return min > 0 ? '$name · at least $min' : name;
  }

  Future<void> _change(BuildContext context) async {
    final picked = await showModalBottomSheet<Minor>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppPalette.of(context).background,
      constraints: const BoxConstraints(maxWidth: 640),
      builder:
          (c) => DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.8,
            builder:
                (c, scroll) => ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(
                    Space.gutter,
                    0,
                    Space.gutter,
                    Space.xxl,
                  ),
                  children: [
                    MinorList(
                      discipline: discipline,
                      selected: progress?.minor,
                      onChoose: (m) => Navigator.pop(c, m),
                    ),
                  ],
                ),
          ),
    );
    if (picked != null) onChoose(picked);
  }
}

/// Every minor, one card each.
class MinorList extends StatelessWidget {
  const MinorList({
    super.key,
    required this.discipline,
    required this.onChoose,
    this.selected,
  });

  final String discipline;
  final ValueChanged<Minor> onChoose;
  final Minor? selected;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final m in minors) ...[
          Builder(
            builder: (context) {
              final open = minorOpenTo(m, discipline);
              final chosen = m == selected;
              return AppCard(
                radius: Radii.row - 2,
                onTap: open ? () => onChoose(m) : null,
                border: chosen ? BorderSide(color: p.accent, width: 1.5) : null,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.name,
                            style: TypeScale.body.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: open ? p.text : p.textMuted,
                            ),
                          ),
                          Text(
                            open
                                ? '${m.courses} courses · ${m.units} units'
                                : 'Not open to your degree',
                            style: TypeScale.caption.copyWith(
                              fontSize: 10.5,
                              color: p.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (chosen)
                      Icon(Icons.check_rounded, size: 18, color: p.accent),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: Space.sm),
        ],
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.progress,
    required this.onChange,
    required this.onStop,
  });

  final MinorProgress progress;
  final VoidCallback onChange;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final m = progress.minor;
    final share = (progress.units / m.units).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
        color: p.hero,
        borderRadius: BorderRadius.circular(Radii.hero),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'MINOR IN',
            style: TypeScale.label.copyWith(color: p.onHeroMuted),
          ),
          Text(m.name, style: TypeScale.title.copyWith(color: p.onHero)),
          const SizedBox(height: Space.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: share,
              minHeight: 7,
              color: p.onHero,
              backgroundColor: p.onHero.withValues(alpha: 0.13),
            ),
          ),
          const SizedBox(height: Space.sm),
          Text(
            '${progress.courses} of ${m.courses} courses · '
            '${_units(progress.units)} of ${m.units} units passed',
            style: TypeScale.caption.copyWith(
              fontSize: 12,
              color: p.onHeroMuted,
            ),
          ),
          const SizedBox(height: Space.md),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              _HeroButton('Change', onChange),
              _HeroButton('Stop pursuing', onStop),
            ],
          ),
        ],
      ),
    );
  }
}

String _units(double u) => u == u.roundToDouble() ? '${u.round()}' : '$u';

class _HeroButton extends StatelessWidget {
  const _HeroButton(this.label, this.onPressed);

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: p.onHero,
        side: BorderSide(color: p.onHero.withValues(alpha: 0.4)),
        minimumSize: const Size(0, 36),
        shape: const StadiumBorder(),
      ),
      child: Text(label, style: TypeScale.button.copyWith(color: p.onHero)),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.sm),
    child: Text(
      title,
      style: TypeScale.section.copyWith(color: AppPalette.of(context).text),
    ),
  );
}

/// One course of the minor: its code (or the alternatives), title, and a
/// chip with the grade, "Planned" or a dash.
class _SlotRow extends StatelessWidget {
  const _SlotRow(this.s);

  final MinorSlotStatus s;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final done = s.state == MinorState.done;
    final code = s.course?.id ?? s.slot.join(' or ');
    final chip = switch (s.state) {
      MinorState.done => GradeChip(gradecalc(s.course!.grade1)),
      MinorState.planned => const GradeChip('Planned', muted: true),
      MinorState.missing => const GradeChip('–', muted: true),
    };
    final note = [
      if (s.title.isNotEmpty) s.title,
      '${_units(s.units)} units',
      if (s.overlap) 'also your degree\'s',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Semantics(
        label: '$code, $note, ${s.state.name}',
        excludeSemantics: true,
        child: AppCard(
          radius: Radii.row - 2,
          color: done ? null : p.surface.withValues(alpha: 0.55),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      code,
                      style: TypeScale.body.copyWith(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: done ? p.text : p.textMuted,
                      ),
                    ),
                    Text(
                      note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TypeScale.caption.copyWith(
                        fontSize: 10.5,
                        color: p.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Space.md),
              chip,
            ],
          ),
        ),
      ),
    );
  }
}

/// The offshoot tab: the offshoot score or the minor, with a switch on top.
class OffshootTab extends StatefulWidget {
  const OffshootTab({
    super.key,
    required this.offshoot,
    required this.minor,
    required this.showMinor,
    required this.onShowMinor,
  });

  final Widget offshoot;
  final Widget minor;
  final bool showMinor;
  final ValueChanged<bool> onShowMinor;

  @override
  State<OffshootTab> createState() => _OffshootTabState();
}

class _OffshootTabState extends State<OffshootTab> {
  late var _minor = widget.showMinor;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.gutter,
          Space.sm,
          Space.gutter,
          Space.sm,
        ),
        child: Row(
          children: [
            for (final minor in [false, true]) ...[
              if (minor) const SizedBox(width: 7),
              Expanded(
                child: PillButton(
                  label: minor ? 'Minor' : 'Offshoot',
                  selected: _minor == minor,
                  onPressed: () {
                    setState(() => _minor = minor);
                    widget.onShowMinor(minor);
                  },
                  height: 38,
                  expand: true,
                ),
              ),
            ],
          ],
        ),
      ),
      Expanded(child: _minor ? widget.minor : widget.offshoot),
    ],
  );
}
