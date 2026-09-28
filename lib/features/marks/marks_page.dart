import 'package:cgpa_calculator/app/routes.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/grading/grade_scale.dart';
import 'package:cgpa_calculator/core/grading/marks.dart';
import 'package:cgpa_calculator/core/grading/official_scheme.dart';
import 'package:cgpa_calculator/core/models/course_names.dart';
import 'package:cgpa_calculator/core/models/marks.dart';
import 'package:cgpa_calculator/core/models/offering.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/core/storage/marks.dart';
import 'package:cgpa_calculator/core/storage/offerings.dart';
import 'package:cgpa_calculator/core/storage/overrides.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/marks/add_evaluative_page.dart';
import 'package:cgpa_calculator/shared/widgets/notice.dart';
import 'package:cgpa_calculator/features/marks/course_setup_page.dart';
import 'package:cgpa_calculator/features/marks/marks_format.dart';
import 'package:cgpa_calculator/features/marks/official.dart';
import 'package:cgpa_calculator/features/marks/widgets/average_sources.dart';
import 'package:cgpa_calculator/features/marks/widgets/divergence.dart';
import 'package:cgpa_calculator/features/marks/widgets/taken_by.dart';
import 'package:cgpa_calculator/features/reviews/course_reviews.dart';
import 'package:cgpa_calculator/features/marks/widgets/evaluative_card.dart';
import 'package:cgpa_calculator/features/semester/semester_controller.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/circle_icon_button.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:cgpa_calculator/shared/widgets/retired_tag.dart';
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

  @override
  void initState() {
    super.initState();
    refreshOfferingFor(widget.course).then((_) {
      if (mounted) setState(() {});
    });
  }

  /// Asks before [granule] of [off] becomes the student's; true when it may
  /// change (it is not official, already theirs, or they said so).
  Future<bool> _mayChange(
    Offering? off,
    String granule,
    String name,
    String change,
  ) async {
    if (off == null || detachedFor(_id).containsKey(granule)) return true;
    final mine = await confirmDivergence(context, name: name, change: change);
    if (mine) await detach(_id, {granule: off.updatedAt});
    return mine;
  }

  Future<void> _useOfficial(Offering off, bool Function(String) which) async {
    await reattach(_id, which);
    await applyOfficial(_id, off);
    if (mounted) setState(() {});
  }

  /// The student's own course average. Cleared, the official one comes
  /// back (§8).
  Future<void> _setCourseAverage(Offering? off, double? v) async {
    final official = off?.courseAverage;
    final config = configFor(_id) ?? CourseConfig(courseId: _id);
    if (v == null && official != null) {
      await reattach(_id, (g) => g == courseAverageGranule);
      config.classAverage = official;
    } else {
      if (official != null &&
          v != official &&
          !await _mayChange(
            off,
            courseAverageGranule,
            'the course average',
            'Course average ${marks2(official)} → '
                '${v == null ? 'blank' : marks2(v)}',
          )) {
        return;
      }
      config.classAverage = v;
    }
    await saveConfig(config);
    if (mounted) setState(() {});
  }

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
    final off = offeringFor(c);
    final detached = detachedFor(_id);
    // What the student made theirs, by name, and what changed since.
    final yours = <String, bool Function(String)>{};
    final changed = <String>[];
    if (off != null) {
      final stale = staleGranules(detached, off).toSet();
      for (final (_, e) in evals) {
        final id = e.sourceId;
        if (id == null) continue;
        final gs = detached.keys.where((g) => ofComponent(g, id));
        if (gs.isEmpty) continue;
        yours[e.name] = (g) => ofComponent(g, id);
        if (gs.any(stale.contains)) changed.add(e.name);
      }
      if (detached.containsKey(courseAverageGranule)) {
        yours['course average'] = (g) => g == courseAverageGranule;
        if (stale.contains(courseAverageGranule)) {
          changed.add('course average');
        }
      }
    }
    String? tag(Evaluative e) {
      final id = e.sourceId;
      if (off == null || id == null) return null;
      if (off.component(id) == null) return 'NOT OFFICIAL';
      return detached.keys.any((g) => ofComponent(g, id)) ? 'YOURS' : null;
    }

    return PageFrame(
      header: PageHeader(
        eyebrow: '${c.id} · ${formatCredits(c.credits)} credits',
        title: displayTitle(c.id, c.title),
        leading: false,
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
        if (isRetired(c.id))
          Padding(
            padding: const EdgeInsets.only(bottom: Space.md),
            child: Row(
              children: [
                const RetiredTag(),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(
                    'No longer offered. It still counts toward your CGPA and '
                    'your degree.',
                    style: TypeScale.caption.copyWith(color: p.textMuted),
                  ),
                ),
              ],
            ),
          ),
        if (off != null && yours.isNotEmpty) ...[
          DivergedCard(
            yours: yours.keys.toList(),
            changed: changed,
            onKeepMine: () async {
              await keepMine(_id, off.updatedAt);
              if (mounted) setState(() {});
            },
          ),
          for (final y in yours.entries)
            UseOfficialButton(
              name: y.key,
              onPressed: () => _useOfficial(off, y.value),
            ),
          const SizedBox(height: Space.sm),
        ],
        if (termFor(c) case final term?
            when off != null ||
                c.grade1 == GradeCode.ongoing ||
                c.grade1 == GradeCode.clr)
          TakenByRow(
            term: term,
            professorIds: off?.professors ?? const [],
            onReviews:
                roleStore == null
                    ? null
                    : () => openRoute(
                      context,
                      Routes.courseReviews(c.id),
                      () => CourseReviewsPage(courseId: c.id),
                    ),
          ),
        _Total(
          s: s,
          grade: grade,
          onSetup: () => _open(CourseSetupPage(course: c)),
        ),
        const SizedBox(height: Space.sm),
        _ClassAverage(
          text: classAvgText(off?.courseAverage),
          onTap:
              () => _open(
                AverageSourcesPage(
                  course: c,
                  courseAverage: s.config.classAverage,
                  evals: [for (final (_, e) in evals) e],
                  official: off,
                  detached: detached,
                  onCourseAverage: (v) => _setCourseAverage(off, v),
                ),
              ),
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
            tag: tag(e),
            classAverage: off?.component(e.sourceId ?? '')?.average,
            onTap:
                () => _open(
                  AddEvaluativePage(
                    courseId: _id,
                    weighted: s.config.weighted,
                    unassigned: s.courseTotal - s.assignedWeight + e.weight,
                    existing: e,
                    existingKey: key,
                    averagesFrom: off,
                    official:
                        off != null &&
                                off.component(e.sourceId ?? '') != null &&
                                !detached.containsKey(
                                  componentGranule(e.sourceId!),
                                )
                            ? off
                            : null,
                  ),
                ),
          ),
          const SizedBox(height: 7),
        ],
        if (off != null && off.hasScheme)
          Padding(
            padding: const EdgeInsets.only(top: Space.xs, bottom: Space.sm),
            child: Notice(
              text: const TextSpan(
                text: 'Changing a component’s ',
                children: [
                  TextSpan(
                    text: 'weight, out of, average or date',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text:
                        ' makes it yours: it stops updating and you keep it '
                        'current. Components you leave alone keep updating. '
                        'Your own marks never detach anything.',
                  ),
                ],
              ),
            ),
          ),
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
            const SizedBox(height: 6),
            _VersusBar(
              you: s.secured,
              classAverage: avg,
              outOf: s.gradedWeight,
            ),
            const SizedBox(height: 5),
            Text(
              'You ${s.secured.toStringAsFixed(2)} · class average '
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

/// Board `Marks`: your share of what is graded as a bar, with a tick where
/// the class average falls.
class _VersusBar extends StatelessWidget {
  const _VersusBar({
    required this.you,
    required this.classAverage,
    required this.outOf,
  });

  final double you;
  final double classAverage;
  final double outOf;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    if (outOf <= 0) return const SizedBox.shrink();
    final a = (you / outOf).clamp(0.0, 1.0);
    final b = (classAverage / outOf).clamp(0.0, 1.0);
    return ExcludeSemantics(
      child: SizedBox(
        height: 11,
        child: LayoutBuilder(
          builder:
              (_, c) => Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 3,
                    height: 5,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: p.onHero.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 3,
                    height: 5,
                    width: c.maxWidth * a,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: p.onHero,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  Positioned(
                    left: (c.maxWidth * b - 1).clamp(0.0, c.maxWidth - 2),
                    top: 0,
                    width: 2,
                    height: 11,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: p.onHero.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ],
              ),
        ),
      ),
    );
  }
}

/// The published course average, unlabelled; opens where every average
/// comes from (§8).
class _ClassAverage extends StatelessWidget {
  const _ClassAverage({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: TypeScale.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: p.textMuted,
                ),
              ),
            ),
            Text(
              'Averages',
              style: TypeScale.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: p.accent,
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: p.accent),
          ],
        ),
      ),
    );
  }
}
