import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/grading/grade_scale.dart';
import 'package:cgpa_calculator/core/grading/requirements.dart';
import 'package:cgpa_calculator/core/models/course_names.dart';
import 'package:cgpa_calculator/core/models/elective.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/semester/widgets/course_fields.dart';
import 'package:cgpa_calculator/features/semester/semester_controller.dart';
import 'package:cgpa_calculator/features/stats/stats_controller.dart';
import 'package:cgpa_calculator/features/stats/stats_page.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/dashed_outline.dart';
import 'package:flutter/material.dart';

/// Changes what [Course] counts as: the same setter as "Counts as" when a
/// course is added or edited.
typedef AssignCourse = Future<void> Function(Course course, String tag);

/// The degree audit: credits earned overall, then one card per requirement,
/// each opening to its courses, and any courses in none.
class DegreeView extends StatelessWidget {
  const DegreeView({
    super.key,
    required this.data,
    this.onEditTotal,
    this.onAssign,
  });

  final StatsData data;

  /// Null leaves each course's category read-only.
  final AssignCourse? onAssign;

  /// Tapping the credits card: set the degree's total by hand.
  final VoidCallback? onEditTotal;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final a = data.audit;
    if (a.categories.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(Space.gutter),
        child: Text(
          'Choose your discipline in Settings to see degree progress.',
          style: TypeScale.body.copyWith(color: p.textMuted),
        ),
      );
    }
    final total = a.totalCredits + data.degreeLeft;
    final pct = (data.degreeShare * 100).round();
    final toClear = [
      for (final c in a.categories)
        if (c.requiredCourses != null && c.courses < c.requiredCourses!)
          '${c.requiredCourses! - c.courses} ${_short(c)}',
    ];
    return StatsBody(
      footer: StatsFooter(
        label: 'STILL TO CLEAR',
        value: toClear.isEmpty ? 'Every requirement met' : toClear.join(' · '),
        trailing: Text(
          '$pct%',
          style: TypeScale.title.copyWith(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: p.hero,
          ),
        ),
      ),
      children: [
        Semantics(
          label:
              'Credits earned ${formatCredits(a.totalCredits)} of '
              '${formatCredits(total)}, ${formatCredits(data.degreeLeft)} left'
              '${a.ongoingCredits > 0 ? ', ${formatCredits(a.ongoingCredits)} of them ongoing' : ''}',
          button: onEditTotal != null,
          hint: onEditTotal == null ? null : 'Change the total',
          excludeSemantics: true,
          child: Material(
            color: p.hero,
            borderRadius: BorderRadius.circular(Radii.card),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onEditTotal,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 17, 18, 17),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'CREDITS EARNED',
                      style: TypeScale.label.copyWith(color: p.onHeroMuted),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          formatCredits(a.totalCredits),
                          style: TypeScale.display.copyWith(
                            fontWeight: FontWeight.w800,
                            color: p.onHero,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'of ${formatCredits(total)}',
                          style: TypeScale.section.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: p.onHeroMuted,
                          ),
                        ),
                        if (onEditTotal != null) ...[
                          const SizedBox(width: 5),
                          Icon(
                            Icons.edit_rounded,
                            size: 14,
                            color: p.onHeroMuted,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 9),
                    _Bar(
                      value: data.degreeShare,
                      color: p.onHero,
                      track: p.onHero.withValues(alpha: 0.13),
                      height: 7,
                    ),
                    const SizedBox(height: 9),
                    Text(
                      '${formatCredits(data.degreeLeft)} credits left'
                      '${data.totalSet != null ? ' · total set by you' : ''}',
                      style: TypeScale.caption.copyWith(
                        fontSize: 10.5,
                        color: p.onHeroMuted,
                      ),
                    ),
                    if (a.ongoingCredits > 0)
                      Text(
                        '${formatCredits(a.ongoingCredits)} of these '
                        'credits are ongoing — counted here, not yet in '
                        'your CGPA',
                        style: TypeScale.caption.copyWith(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: p.onHero,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 13),
        Text(
          'By requirement',
          style: TypeScale.section.copyWith(color: p.text),
        ),
        const SizedBox(height: Space.sm),
        for (final c in a.categories) ...[
          _CategoryCard(c: c, discipline: data.discipline, onAssign: onAssign),
          const SizedBox(height: Space.sm),
        ],
        if (a.unassigned.isNotEmpty)
          _Unassigned(
            courses: a.unassigned,
            discipline: data.discipline,
            onAssign: onAssign,
          ),
      ],
    );
  }

  String _short(AuditCategory c) => switch (c.category) {
    Elective.cdc1 || Elective.cdc2 => 'core',
    Elective.del1 => 'DEl 1',
    Elective.del2 => 'DEl 2',
    Elective.humanity => 'HuEl',
    Elective.open => 'OpEl',
  };
}

class _CategoryCard extends StatefulWidget {
  const _CategoryCard({
    required this.c,
    required this.discipline,
    required this.onAssign,
  });

  final AuditCategory c;
  final String discipline;
  final AssignCourse? onAssign;

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  var _open = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final p = AppPalette.of(context);
    final title = TypeScale.body.copyWith(
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
      color: c.notStarted ? p.textMuted : p.text,
    );
    final small = TypeScale.caption.copyWith(
      fontSize: 10.5,
      color: p.textMuted,
    );
    final cr = formatCredits(c.credits);
    final courses = '${c.courses} course${c.courses == 1 ? '' : 's'}';
    final canOpen = c.members.isNotEmpty;
    final chevron = Icon(
      _open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
      size: 18,
      color: p.textMuted,
    );

    final Widget head;
    final String said;
    // No requirement to measure against: just the totals.
    if (c.requiredCredits == null) {
      said = '${c.label}: $courses, $cr credits';
      head = Row(
        children: [
          Expanded(child: Text(c.label, style: title)),
          Text(courses, style: small),
          const SizedBox(width: Space.sm),
          Text('$cr cr', style: title.copyWith(fontSize: 11)),
          if (canOpen) ...[const SizedBox(width: 4), chevron],
        ],
      );
    } else {
      final req = c.requiredCredits!;
      final reqCourses = c.requiredCourses ?? 0;
      final left = req - c.credits;
      final status =
          c.complete
              ? 'complete'
              : c.notStarted
              ? 'not started'
              : left > 0
              ? '${formatCredits(left)} credits to go'
              : '${reqCourses - c.courses} to choose';
      final green = p.isDark ? p.ahead : const Color(0xFF2C7A62);
      said =
          '${c.label}: $cr of $req credits, '
          '${c.courses} of $reqCourses courses, $status';
      head = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(c.label, style: title)),
              if (c.complete) ...[
                Icon(Icons.check_circle_rounded, size: 14, color: p.ahead),
                const SizedBox(width: 4),
              ],
              Text(
                '$cr / $req cr',
                style: title.copyWith(
                  fontSize: 11,
                  color: c.complete ? p.ahead : null,
                ),
              ),
              if (canOpen) ...[const SizedBox(width: 4), chevron],
            ],
          ),
          const SizedBox(height: 7),
          _Bar(
            value: req == 0 ? 1 : c.credits / req,
            color: c.complete ? green : p.inverse,
            track: p.divider,
            height: 5,
          ),
          const SizedBox(height: 7),
          Text(
            '${c.courses} of $reqCourses courses · $status',
            style: small.copyWith(fontSize: 10),
          ),
        ],
      );
    }

    final card = AppCard(
      radius: 18,
      color: c.notStarted ? p.surface.withValues(alpha: 0.55) : null,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label: said,
            button: canOpen,
            expanded: canOpen ? _open : null,
            excludeSemantics: true,
            child: InkWell(
              onTap: canOpen ? () => setState(() => _open = !_open) : null,
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                child: head,
              ),
            ),
          ),
          if (_open)
            _Members(
              courses: c.members,
              discipline: widget.discipline,
              onAssign: widget.onAssign,
            ),
        ],
      ),
    );
    return c.notStarted
        ? DashedOutline(color: p.outline, radius: 18, child: card)
        : card;
  }
}

/// Courses that count toward the degree but toward no requirement, to be
/// assigned. Shown only when there are some.
class _Unassigned extends StatefulWidget {
  const _Unassigned({
    required this.courses,
    required this.discipline,
    required this.onAssign,
  });

  final List<Course> courses;
  final String discipline;
  final AssignCourse? onAssign;

  @override
  State<_Unassigned> createState() => _UnassignedState();
}

class _UnassignedState extends State<_Unassigned> {
  var _open = false;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final n = widget.courses.length;
    final cr = formatCredits(widget.courses.fold(0.0, (s, c) => s + c.credits));
    final what = '$n course${n == 1 ? '' : 's'} · $cr cr';
    return DashedOutline(
      color: p.behind,
      radius: 18,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              label:
                  'Unassigned: $what, counted in your credits but toward no '
                  'requirement',
              button: true,
              expanded: _open,
              excludeSemantics: true,
              child: InkWell(
                onTap: () => setState(() => _open = !_open),
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Unassigned',
                              style: TypeScale.body.copyWith(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: p.text,
                              ),
                            ),
                            Text(
                              'In your credits, but in no requirement. Say '
                              'what each counts as.',
                              style: TypeScale.caption.copyWith(
                                fontSize: 10,
                                color: p.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: Space.sm),
                      Text(
                        what,
                        style: TypeScale.caption.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: p.behind,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _open
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: 18,
                        color: p.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_open)
              _Members(
                courses: widget.courses,
                discipline: widget.discipline,
                onAssign: widget.onAssign,
              ),
          ],
        ),
      ),
    );
  }
}

/// An opened requirement's courses, each with what it counts as.
class _Members extends StatelessWidget {
  const _Members({
    required this.courses,
    required this.discipline,
    required this.onAssign,
  });

  final List<Course> courses;
  final String discipline;
  final AssignCourse? onAssign;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final c in courses) ...[
            Divider(height: 13, color: p.divider),
            Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: c.id,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      children: [
                        TextSpan(
                          text: '  ${displayTitle(c.id, c.title)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: p.textMuted,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TypeScale.caption.copyWith(
                      fontSize: 11.5,
                      color: p.text,
                    ),
                  ),
                ),
                const SizedBox(width: Space.sm),
                Text(
                  '${formatCredits(c.credits)} cr · '
                  '${c.grade1 == GradeCode.ongoing ? 'ongoing' : gradecalc(c.grade1)}',
                  style: TypeScale.caption.copyWith(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: p.textMuted,
                  ),
                ),
              ],
            ),
            if (onAssign != null) ...[
              const SizedBox(height: 5),
              CategoryDropdown(
                // Where it counts now, which the department rules may have
                // decided, rather than the tag it was stored with.
                value: auditCategory(c, discipline)?.tag ?? c.elective,
                discipline: discipline,
                onChanged: (t) => onAssign!(c, t),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.value,
    required this.color,
    required this.track,
    required this.height,
  });

  final double value;
  final Color color;
  final Color track;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(height / 2),
    child: LinearProgressIndicator(
      value: value.clamp(0.0, 1.0),
      minHeight: height,
      color: color,
      backgroundColor: track,
    ),
  );
}
