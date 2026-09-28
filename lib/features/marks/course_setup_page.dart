import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/grading/marks.dart';
import 'package:cgpa_calculator/core/models/marks.dart';
import 'package:cgpa_calculator/core/storage/marks.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/marks/marks_format.dart';
import 'package:cgpa_calculator/features/semester/semester_controller.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:cgpa_calculator/shared/widgets/count_pill.dart';
import 'package:flutter/material.dart';

/// How a course is marked, what it is shown out of, and the class average.
class CourseSetupPage extends StatefulWidget {
  const CourseSetupPage({
    super.key,
    required this.course,
    this.onCourseAverage,
  });

  final Course course;

  /// Sets the course average, asking first when it overrides the official
  /// one. Without it the average is saved with the rest.
  final Future<void> Function(double?)? onCourseAverage;

  @override
  State<CourseSetupPage> createState() => _CourseSetupPageState();
}

class _CourseSetupPageState extends State<CourseSetupPage> {
  late final _evals = [
    for (final (_, e) in evaluativesFor(widget.course.id)) e,
  ];
  late final CourseConfig _saved =
      configFor(widget.course.id) ?? CourseConfig(courseId: widget.course.id);
  late bool _weighted = _saved.weighted;
  late final _total = TextEditingController(
    text: _saved.weighted ? '' : marks2(_saved.courseTotal),
  );
  late double _outOf = _saved.displayOutOf;
  late final _custom = TextEditingController(
    text: [100.0, 200.0, 300.0].contains(_outOf) ? '' : marks2(_outOf),
  );
  late final _classAvg = TextEditingController(
    text: _saved.classAverage == null ? '' : marks2(_saved.classAverage!),
  );
  var _customOn = false;

  @override
  void dispose() {
    _total.dispose();
    _custom.dispose();
    _classAvg.dispose();
    super.dispose();
  }

  double get _assigned => _evals.fold(0.0, (s, e) => s + e.weight);

  CourseConfig get _draft => CourseConfig(
    courseId: widget.course.id,
    weighted: _weighted,
    courseTotal: _weighted ? 100 : (double.tryParse(_total.text) ?? _assigned),
    displayOutOf: _outOf,
    classAverage: double.tryParse(_classAvg.text.trim()),
  );

  Future<void> _save() async {
    final avg = widget.onCourseAverage;
    final draft = _draft;
    if (avg == null) {
      await saveConfig(draft);
    } else {
      final typed = draft.classAverage;
      draft.classAverage = _saved.classAverage;
      await saveConfig(draft);
      if (typed != _saved.classAverage) await avg(typed);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final s = MarksSummary(_evals, _draft);
    void changed(String _) => setState(() {});
    final head = TypeScale.label.copyWith(
      fontSize: 9.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
      color: p.textMuted,
    );
    final small = TypeScale.caption.copyWith(
      fontSize: 10.5,
      fontWeight: FontWeight.w500,
      height: 1.4,
      color: p.textMuted,
    );
    Widget card(List<Widget> children) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 9,
        children: children,
      ),
    );
    Widget field(TextEditingController c, ValueChanged<String> onChanged) =>
        SizedBox(
          width: 86,
          height: 40,
          child: TextField(
            controller: c,
            onChanged: onChanged,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: TypeScale.body.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: p.text,
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: p.isDark ? p.surfaceSunken : const Color(0xFFF8F8F5),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        );
    final custom = ![100.0, 200.0, 300.0].contains(_outOf) || _customOn;
    final delta = s.classDelta;

    return PageFrame(
      header: PageHeader(
        close: true,
        eyebrow:
            '${widget.course.id} · ${formatCredits(widget.course.credits)} '
                    'credits'
                .toUpperCase(),
        title: 'Course setup',
      ),
      children: [
        card([
          Text('HOW THIS COURSE IS GRADED', style: head),
          Row(
            spacing: 8,
            children: [
              for (final w in [true, false])
                Expanded(
                  child: _GradingChoice(
                    title: w ? 'Weighted' : 'Total marks',
                    sub: w ? 'each part has a %' : 'one big total',
                    selected: _weighted == w,
                    onTap: () => setState(() => _weighted = w),
                  ),
                ),
            ],
          ),
        ]),
        const SizedBox(height: 12),
        card([
          if (!_weighted) ...[
            Text('COURSE IS MARKED OUT OF', style: head),
            Row(
              children: [
                field(_total, changed),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your evaluatives add up to ${marks2(_assigned)} marks.',
                    style: small,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
          ],
          Text('SHOW IT OUT OF', style: head),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final v in [100.0, 200.0, 300.0])
                CountPill(
                  label: marks2(v),
                  selected: !custom && _outOf == v,
                  onTap:
                      () => setState(() {
                        _outOf = v;
                        _customOn = false;
                        _custom.clear();
                      }),
                ),
              if (custom)
                field(
                  _custom,
                  (t) => setState(() {
                    final v = double.tryParse(t);
                    if (v != null && v > 0) _outOf = v;
                  }),
                )
              else
                CountPill(
                  label: 'Custom',
                  selected: false,
                  onTap: () => setState(() => _customOn = true),
                ),
            ],
          ),
          Text(
            'Marks stay entered exactly as your instructor gives them. Only '
            'the display is rescaled.',
            style: small,
          ),
        ]),
        const SizedBox(height: 12),
        _RightNow(s: s, outOf: _outOf),
        if (_evals.isNotEmpty) ...[
          const SizedBox(height: 12),
          card([
            Text('EACH COMPONENT\'S SHARE', style: head),
            for (final e in _evals)
              _ShareRow(
                name: e.name,
                note:
                    e.countBest > 0 && e.countBest < e.parts.length
                        ? 'best ${e.countBest} of ${e.parts.length}'
                        : null,
                got: '${marks2(contribution(e) ?? 0)} / ${marks2(e.weight)}',
                share: ((contribution(e) ?? 0) * s.factor).toStringAsFixed(1),
              ),
            Divider(height: 1, color: p.divider),
            _ShareRow(
              name: 'Total',
              got: '${marks2(s.secured)} / ${marks2(s.courseTotal)}',
              share: s.shownSecured.toStringAsFixed(1),
              total: true,
            ),
          ]),
        ],
        const SizedBox(height: 12),
        card([
          Text('CLASS AVERAGE', style: head),
          Row(
            children: [
              field(_classAvg, changed),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'For the '),
                      TextSpan(
                        text: 'components that have happened so far',
                        style: small.copyWith(
                          fontWeight: FontWeight.w700,
                          color: p.text,
                        ),
                      ),
                      const TextSpan(text: ' — not the whole course.'),
                    ],
                  ),
                  style: small,
                ),
              ),
            ],
          ),
          if (delta != null)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: Color.lerp(p.surface, p.hero, 0.3),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(deltaIcon(delta), size: 18, color: p.ahead),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'You are ${deltaWords(delta)} · '
                      '${marks2(s.secured)} against '
                      '${marks2(s.config.classAverage!)}',
                      style: TypeScale.body.copyWith(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: delta < 0 ? p.behind : p.ahead,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Text(
            'Leave it blank and the comparison simply does not appear.',
            style: small.copyWith(fontSize: 10),
          ),
        ]),
        const SizedBox(height: Space.lg),
        PrimaryButton(label: 'Save setup', onPressed: _save),
      ],
    );
  }
}

/// A two-line choice, 46 tall: ink when selected, outlined otherwise.
class _GradingChoice extends StatelessWidget {
  const _GradingChoice({
    required this.title,
    required this.sub,
    required this.selected,
    required this.onTap,
  });

  final String title, sub;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? p.inverse : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? p.inverse : p.outline),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 46),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TypeScale.body.copyWith(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: selected ? p.onInverse : p.text,
                    ),
                  ),
                  Text(
                    sub,
                    textAlign: TextAlign.center,
                    style: TypeScale.caption.copyWith(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w500,
                      color: selected ? const Color(0xFFB0B0A4) : p.textMuted,
                    ),
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

/// The mint card: entered → shown, and the factor.
class _RightNow extends StatelessWidget {
  const _RightNow({required this.s, required this.outOf});

  final MarksSummary s;
  final double outOf;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final cap = TypeScale.caption.copyWith(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: p.onHeroMuted,
    );
    Widget number(String v, String c) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          v,
          style: TypeScale.display.copyWith(
            fontSize: 25,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
            color: p.onHero,
          ),
        ),
        Text(c, style: cap),
      ],
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(17, 15, 17, 15),
      decoration: BoxDecoration(
        color: p.hero,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RIGHT NOW',
            style: TypeScale.label.copyWith(color: p.onHeroMuted),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              number(marks2(s.secured), 'of ${marks2(s.courseTotal)} entered'),
              Icon(Icons.arrow_forward_rounded, size: 22, color: p.onHero),
              number(
                s.shownSecured.toStringAsFixed(1),
                'shown out of ${marks2(outOf)}',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${marks2(s.secured)} × ${marks2(outOf)} ÷ '
            '${marks2(s.courseTotal)}. The same factor is applied to every '
            'component.',
            style: cap.copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _ShareRow extends StatelessWidget {
  const _ShareRow({
    required this.name,
    required this.got,
    required this.share,
    this.note,
    this.total = false,
  });

  final String name, got, share;
  final String? note;
  final bool total;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Row(
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(
              text: name,
              children: [
                if (note != null)
                  TextSpan(
                    text: ' · $note',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: p.textMuted,
                    ),
                  ),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TypeScale.body.copyWith(
              fontSize: 12,
              fontWeight: total ? FontWeight.w700 : FontWeight.w600,
              color: p.text,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          got,
          style: TypeScale.caption.copyWith(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: p.textMuted,
          ),
        ),
        SizedBox(
          width: 46,
          child: Text(
            share,
            textAlign: TextAlign.right,
            style: TypeScale.body.copyWith(
              fontSize: total ? 13.5 : 12.5,
              fontWeight: FontWeight.w800,
              color: p.text,
            ),
          ),
        ),
      ],
    );
  }
}
