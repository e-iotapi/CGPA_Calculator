import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/grading/minor_progress.dart';
import 'package:cgpa_calculator/core/storage/courses.dart';
import 'package:cgpa_calculator/core/storage/minor.dart';
import 'package:cgpa_calculator/core/storage/stats.dart';
import 'package:cgpa_calculator/features/stats/stats_controller.dart';
import 'package:cgpa_calculator/features/stats/widgets/degree_view.dart';
import 'package:cgpa_calculator/features/stats/widgets/minor_view.dart';
import 'package:cgpa_calculator/features/stats/widgets/progression_view.dart';
import 'package:cgpa_calculator/shared/widgets/circle_icon_button.dart';
import 'package:cgpa_calculator/shared/widgets/pill_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum StatsView { progression, degree, minor }

/// Stats: where the CGPA is heading, and how much of the degree is done.
/// Reads the Actual profile only.
class StatsPage extends StatefulWidget {
  const StatsPage({super.key, required this.discipline});

  /// "B3A7", "--A7"…
  final String discipline;

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  var _view = StatsView.progression;
  late double? _target = statsTarget;
  late final Map<String, double> _plan = statsPlan;

  StatsData get _data => StatsData.from(
    all: allCourses(),
    discipline: widget.discipline,
    target: _target,
    plan: _plan,
    needs: degreeNeeds,
    totalSet: degreeTotalFor(widget.discipline),
  );

  Future<void> _editTotal() async {
    final data = _data;
    final shown = data.audit.totalCredits + data.degreeLeft;
    final controller = TextEditingController(text: shown.round().toString());
    int? read() => int.tryParse(controller.text.trim());
    final result = await showDialog<(int?,)>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: const Text('Credits your degree needs'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pointer works this out from your courses or your ERP '
                  'sheet. If yours is different, set it here.',
                ),
                const SizedBox(height: Space.md),
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    suffixText: 'credits',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) {
                    if ((read() ?? 0) > 0) Navigator.pop(c, (read(),));
                  },
                ),
              ],
            ),
            actions: [
              if (data.totalSet != null)
                TextButton(
                  onPressed: () => Navigator.pop(c, (null,)),
                  child: const Text('Use Pointer\'s'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  if ((read() ?? 0) > 0) Navigator.pop(c, (read(),));
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
    if (result == null || !mounted) return;
    await setDegreeTotal(widget.discipline, result.$1);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return StatsScreen(
      data: _data,
      view: _view,
      onViewChanged: (v) => setState(() => _view = v),
      onTargetChanged: (t) {
        setState(() => _target = t);
        setStatsTarget(t);
      },
      onPlanChanged: (sem, sgpa) {
        setState(() => _plan[sem] = sgpa);
        setStatsPlan(_plan);
      },
      onBack: () => Navigator.of(context).maybePop(),
      onEditTotal: _editTotal,
      minor: switch (chosenMinor) {
        final m? => minorProgress(m, allCourses(), widget.discipline),
        null => null,
      },
    );
  }
}

/// The presentational half of [StatsPage].
class StatsScreen extends StatelessWidget {
  const StatsScreen({
    super.key,
    required this.data,
    required this.view,
    required this.onViewChanged,
    required this.onTargetChanged,
    required this.onPlanChanged,
    required this.onBack,
    this.onEditTotal,
    this.minor,
  });

  final StatsData data;
  final StatsView view;
  final ValueChanged<StatsView> onViewChanged;
  final ValueChanged<double> onTargetChanged;
  final void Function(String sem, double sgpa) onPlanChanged;
  final VoidCallback onBack;
  final VoidCallback? onEditTotal;

  /// The minor being pursued; its tab shows only then.
  final MinorProgress? minor;

  String get _halves {
    final d = data.discipline;
    final parts = [d.substring(0, 2), d.substring(2, 4)]
      ..removeWhere((h) => h == '--');
    return parts.length == 2
        ? '${parts.join(' ')} · dual degree'
        : parts.join();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final pr = minor;
    // Without a minor, its tab falls back to the degree.
    final shown =
        view == StatsView.minor && pr == null ? StatsView.degree : view;
    final degree = shown == StatsView.degree;
    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.gutter,
                    Space.lg,
                    Space.gutter,
                    0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              switch (shown) {
                                StatsView.progression => 'Progression',
                                StatsView.degree => _halves,
                                StatsView.minor => 'Minor in ${pr!.minor.name}',
                              },
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TypeScale.caption.copyWith(
                                fontSize: 12.5,
                                color: p.textMuted,
                              ),
                            ),
                            Text(
                              switch (shown) {
                                StatsView.progression => 'Where you land',
                                StatsView.degree => 'Degree progress',
                                StatsView.minor => 'Minor requirements',
                              },
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TypeScale.title.copyWith(color: p.text),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: Space.md),
                      CircleIconButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Back',
                        onPressed: onBack,
                        size: 44,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                  child: Row(
                    children: [
                      for (final v in StatsView.values)
                        if (v != StatsView.minor || pr != null) ...[
                          if (v != StatsView.values.first)
                            const SizedBox(width: 7),
                          Expanded(
                            child: PillButton(
                              label: switch (v) {
                                StatsView.progression => 'Progression',
                                StatsView.degree => 'Degree',
                                StatsView.minor => 'Minor',
                              },
                              selected: shown == v,
                              onPressed: () => onViewChanged(v),
                              height: 38,
                              expand: true,
                            ),
                          ),
                        ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child:
                      shown == StatsView.minor
                          ? MinorView(progress: pr!)
                          : degree
                          ? DegreeView(data: data, onEditTotal: onEditTotal)
                          : ProgressionView(
                            data: data,
                            onTargetChanged: onTargetChanged,
                            onPlanChanged: onPlanChanged,
                          ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dark bar pinned to the bottom of both views.
class StatsFooter extends StatelessWidget {
  const StatsFooter({
    super.key,
    required this.label,
    required this.value,
    required this.trailing,
  });

  final String label;
  final String value;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      decoration: BoxDecoration(
        color: p.navBackground,
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TypeScale.label.copyWith(
                    fontSize: 9.5,
                    color: p.navIcon,
                  ),
                ),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TypeScale.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: p.isDark ? p.text : p.onInverse,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Space.md),
          trailing,
        ],
      ),
    );
  }
}

/// Scrolls [children] with room under them for a pinned [footer].
class StatsBody extends StatelessWidget {
  const StatsBody({super.key, required this.children, required this.footer});

  final List<Widget> children;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              0,
              Space.gutter,
              Space.lg,
            ),
            children: children,
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            Space.gutter,
            0,
            Space.gutter,
            Space.lg + bottom,
          ),
          child: footer,
        ),
      ],
    );
  }
}
