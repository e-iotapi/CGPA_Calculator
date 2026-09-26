import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/grading/marks.dart';
import 'package:cgpa_calculator/core/models/marks.dart';
import 'package:cgpa_calculator/core/storage/marks.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/marks/marks_format.dart';
import 'package:cgpa_calculator/features/semester/semester_controller.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:cgpa_calculator/shared/widgets/pill_button.dart';
import 'package:flutter/material.dart';

/// How a course is marked and what it is shown out of. The class average is
/// entered where marks are read, on the Marks page.
class CourseSetupPage extends StatefulWidget {
  const CourseSetupPage({super.key, required this.course});

  final Course course;

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

  @override
  void dispose() {
    _total.dispose();
    _custom.dispose();
    super.dispose();
  }

  double get _assigned => _evals.fold(0.0, (s, e) => s + e.weight);

  CourseConfig get _draft => CourseConfig(
    courseId: widget.course.id,
    weighted: _weighted,
    courseTotal: _weighted ? 100 : (double.tryParse(_total.text) ?? _assigned),
    displayOutOf: _outOf,
    // Entered on the Marks page now; kept as it was.
    classAverage: _saved.classAverage,
  );

  Future<void> _save() async {
    await saveConfig(_draft);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final muted = TypeScale.caption.copyWith(color: p.textMuted, height: 1.4);
    final s = MarksSummary(_evals, _draft);
    void changed(String _) => setState(() {});

    return PageFrame(
      header: PageHeader(
        eyebrow:
            '${widget.course.id} · ${formatCredits(widget.course.credits)} '
            'credits',
        title: 'Course setup',
      ),
      children: [
        const FieldLabel('How this course is graded'),
        Row(
          children: [
            for (final w in [true, false]) ...[
              if (!w) const SizedBox(width: Space.sm),
              Expanded(
                child: PillButton(
                  label: w ? 'Weighted · each has a %' : 'Total marks',
                  selected: _weighted == w,
                  expand: true,
                  height: 42,
                  onPressed: () => setState(() => _weighted = w),
                ),
              ),
            ],
          ],
        ),
        if (!_weighted) ...[
          const FieldLabel('Course is marked out of'),
          AppTextField(
            controller: _total,
            label: 'Course total',
            hint: marks2(_assigned),
            suffix: 'marks',
            number: true,
            onChanged: changed,
          ),
          const SizedBox(height: 6),
          Text(
            'Your evaluatives add up to ${marks2(_assigned)} marks.',
            style: muted,
          ),
        ],
        const FieldLabel('Show it out of'),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            for (final v in [100.0, 200.0, 300.0])
              PillButton(
                label: marks2(v),
                selected: _outOf == v && _custom.text.isEmpty,
                onPressed:
                    () => setState(() {
                      _outOf = v;
                      _custom.clear();
                    }),
              ),
            SizedBox(
              width: 120,
              child: AppTextField(
                controller: _custom,
                label: 'Custom',
                number: true,
                dense: true,
                onChanged:
                    (t) => setState(() {
                      final v = double.tryParse(t);
                      if (v != null && v > 0) _outOf = v;
                    }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Marks stay entered exactly as your instructor gives them. Only the '
          'display is rescaled.',
          style: muted,
        ),
        const FieldLabel('Right now'),
        AppCard(
          radius: 18,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${marks2(s.secured)} of ${marks2(s.courseTotal)} secured → '
                '${s.shownSecured.toStringAsFixed(1)} shown out of '
                '${marks2(_outOf)}',
                style: TypeScale.body.copyWith(color: p.text),
              ),
              const SizedBox(height: 4),
              Text(
                '${marks2(s.secured)} × ${marks2(_outOf)} ÷ '
                '${marks2(s.courseTotal)}. The same factor is applied to '
                'every component.',
                style: muted,
              ),
              if (_evals.isNotEmpty) ...[
                const SizedBox(height: Space.md),
                for (final e in _evals)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            e.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TypeScale.caption.copyWith(
                              fontSize: 12,
                              color: p.text,
                            ),
                          ),
                        ),
                        Text(
                          '${marks2(contribution(e) ?? 0)} / ${marks2(e.weight)}',
                          style: muted,
                        ),
                        SizedBox(
                          width: 52,
                          child: Text(
                            ((contribution(e) ?? 0) * s.factor).toStringAsFixed(
                              1,
                            ),
                            textAlign: TextAlign.right,
                            style: TypeScale.caption.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: p.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: Space.xl),
        PrimaryButton(label: 'Save setup', onPressed: _save),
      ],
    );
  }
}
