import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/grading/grade_scale.dart';
import 'package:cgpa_calculator/core/grading/marks.dart';
import 'package:cgpa_calculator/core/models/course_names.dart';
import 'package:cgpa_calculator/core/models/marks.dart';
import 'package:cgpa_calculator/core/storage/marks.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/marks/add_evaluative_page.dart';
import 'package:cgpa_calculator/features/marks/course_setup_page.dart';
import 'package:cgpa_calculator/features/marks/marks_format.dart';
import 'package:cgpa_calculator/features/marks/widgets/evaluative_card.dart';
import 'package:cgpa_calculator/features/semester/semester_controller.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/circle_icon_button.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:flutter/material.dart';

/// One course's marks: the running total, each evaluative, and the class
/// comparison when the user has entered one.
class MarksPage extends StatefulWidget {
  const MarksPage({super.key, required this.course, this.onEditCourse});

  final Course course;

  /// Opens the old course card (grades, credits, delete). Null hides it.
  final VoidCallback? onEditCourse;

  @override
  State<MarksPage> createState() => _MarksPageState();
}

class _MarksPageState extends State<MarksPage> {
  String get _id => widget.course.id;

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final evals = evaluativesFor(_id);
    final s = summaryFor(_id);
    final c = widget.course;
    final grade = c.grade1 > 0 ? gradecalc(c.grade1) : null;

    return PageFrame(
      header: PageHeader(
        eyebrow: '${c.id} · ${formatCredits(c.credits)} credits',
        title: displayTitle(c.id, c.title),
        actions: [
          if (widget.onEditCourse != null)
            CircleIconButton(
              icon: Icons.edit_outlined,
              tooltip: 'Edit course',
              onPressed: () {
                Navigator.of(context).pop();
                widget.onEditCourse!();
              },
              size: 42,
            ),
        ],
      ),
      children: [
        _Total(
          s: s,
          grade: grade,
          onSetup: () => _open(CourseSetupPage(course: c)),
        ),
        const SizedBox(height: Space.sm),
        _CourseAverage(
          value: s.config.classAverage,
          onChanged: (v) async {
            final config = configFor(_id) ?? CourseConfig(courseId: _id);
            config.classAverage = v;
            await saveConfig(config);
            if (mounted) setState(() {});
          },
        ),
        const SizedBox(height: Space.md),
        if (evals.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.lg),
            child: Text(
              'Add each component as it is announced — a quiz series, the '
              'mid-sem, labs. Marks can stay blank until they are out.',
              style: TypeScale.body.copyWith(
                fontWeight: FontWeight.w500,
                color: p.textMuted,
              ),
            ),
          ),
        for (final (key, e) in evals) ...[
          EvaluativeCard(
            e: e,
            weighted: s.config.weighted,
            onDuplicate: () async {
              await saveEvaluative(duplicateEvaluative(e));
              if (mounted) setState(() {});
            },
            onAverage: (v) async {
              e.average = v;
              await saveEvaluative(e, key: key);
              if (mounted) setState(() {});
            },
            onTap:
                () => _open(
                  AddEvaluativePage(
                    courseId: _id,
                    weighted: s.config.weighted,
                    unassigned: s.courseTotal - s.assignedWeight + e.weight,
                    existing: e,
                    existingKey: key,
                  ),
                ),
          ),
          const SizedBox(height: 7),
        ],
        const SizedBox(height: Space.sm),
        PrimaryButton(
          label: 'Add evaluative',
          icon: Icons.add_rounded,
          onPressed:
              () => _open(
                AddEvaluativePage(
                  courseId: _id,
                  weighted: s.config.weighted,
                  unassigned: s.courseTotal - s.assignedWeight,
                ),
              ),
        ),
      ],
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.s, required this.grade, required this.onSetup});

  final MarksSummary s;
  final String? grade;
  final VoidCallback onSetup;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final muted = TypeScale.caption.copyWith(
      fontSize: 10.5,
      color: p.onHeroMuted,
    );
    final pct = (s.gradedShare * 100).round();
    final delta = s.classDelta;
    final avg = s.config.classAverage;
    final mode =
        '${s.config.weighted ? 'Weighted' : 'Total marks'} · out of '
        '${marks2(s.config.displayOutOf)}';

    return Container(
      padding: const EdgeInsets.fromLTRB(17, 15, 15, 15),
      decoration: BoxDecoration(
        color: p.hero,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Semantics(
                  label:
                      'Secured so far ${marks2(s.shownSecured)} of '
                      '${marks2(s.shownGraded)}. $pct% of the course graded.',
                  excludeSemantics: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SECURED SO FAR',
                        style: TypeScale.label.copyWith(
                          fontSize: 10.5,
                          color: p.onHeroMuted,
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              s.shownSecured.toStringAsFixed(2),
                              style: TypeScale.display.copyWith(
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                color: p.onHero,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '/ ${marks2(s.shownGraded)}',
                              style: TypeScale.section.copyWith(
                                fontWeight: FontWeight.w600,
                                color: p.onHeroMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '$pct% of the course graded · ${100 - pct}% pending',
                        style: muted,
                      ),
                    ],
                  ),
                ),
              ),
              if (grade != null)
                Container(
                  constraints: const BoxConstraints(minWidth: 42),
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p.onHero,
                    borderRadius: BorderRadius.circular(Radii.chip),
                  ),
                  child: Text(
                    grade!,
                    style: TypeScale.gradeChip.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: p.hero,
                    ),
                  ),
                ),
            ],
          ),
          if (delta != null && avg != null) ...[
            const SizedBox(height: 9),
            Divider(height: 1, color: p.onHero.withValues(alpha: 0.13)),
            const SizedBox(height: 9),
            Semantics(
              label: deltaWords(delta, 'of the class'),
              excludeSemantics: true,
              child: Row(
                children: [
                  Icon(deltaIcon(delta), size: 18, color: p.onHero),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      deltaWords(delta, 'of the class'),
                      style: TypeScale.body.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: p.onHero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'You ${s.secured.toStringAsFixed(2)} · course average '
              '${avg.toStringAsFixed(2)}',
              style: muted.copyWith(fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: Space.sm),
          Semantics(
            button: true,
            label: 'Course setup: $mode',
            excludeSemantics: true,
            child: Material(
              color: p.onHero.withValues(alpha: 0.09),
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onSetup,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune_rounded, size: 13, color: p.onHero),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          mode,
                          style: TypeScale.caption.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: p.onHero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The course average, entered where marks are read. Compared with what
/// you have secured over the same components.
class _CourseAverage extends StatefulWidget {
  const _CourseAverage({required this.value, required this.onChanged});

  final double? value;
  final ValueChanged<double?> onChanged;

  @override
  State<_CourseAverage> createState() => _CourseAverageState();
}

class _CourseAverageState extends State<_CourseAverage> {
  late final _text = TextEditingController(
    text: widget.value == null ? '' : marks2(widget.value!),
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          controller: _text,
          label: 'Course average',
          hint: 'Optional',
          number: true,
          onChanged: (t) => widget.onChanged(double.tryParse(t)),
        ),
        const SizedBox(height: 4),
        Text(
          'The class average for the components you have entered, not the '
          'whole course. Blank, and no comparison appears.',
          style: TypeScale.caption.copyWith(
            fontSize: 10.5,
            height: 1.4,
            color: p.textMuted,
          ),
        ),
      ],
    );
  }
}
