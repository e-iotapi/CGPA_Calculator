import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/grading/cgpa.dart';
import 'package:cgpa_calculator/core/grading/grade_scale.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/semester/add_course_controller.dart';
import 'package:cgpa_calculator/features/semester/semester_controller.dart';
import 'package:cgpa_calculator/features/semester/widgets/grade_menu.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/mastercourselist.dart';
import 'package:flutter/material.dart';

/// Opens the add sheet. Resolves to the course to store, or null.
Future<Course?> showAddCourseSheet(
  BuildContext context, {
  required Iterable<Course> held,
  required String sem,
  required String discipline,
  required Profile profile,
  required VoidCallback onManual,
}) {
  return showModalBottomSheet<Course>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppPalette.of(context).background,
    constraints: const BoxConstraints(maxWidth: 640),
    builder:
        (_) => FractionallySizedBox(
          heightFactor: 0.88,
          child: AddCourseSheet(
            held: held,
            sem: sem,
            discipline: discipline,
            profile: profile,
            onManual: onManual,
          ),
        ),
  );
}

class AddCourseSheet extends StatefulWidget {
  const AddCourseSheet({
    super.key,
    required this.held,
    required this.sem,
    required this.discipline,
    required this.profile,
    required this.onManual,
    this.master,
  });

  /// Overrides the master course list (tests).
  final List<Mastercourselist>? master;
  final Iterable<Course> held;
  final String sem;
  final String discipline;
  final Profile profile;
  final VoidCallback onManual;

  @override
  State<AddCourseSheet> createState() => _AddCourseSheetState();
}

class _AddCourseSheetState extends State<AddCourseSheet> {
  final _query = TextEditingController();
  List<CourseHit> _hits = const [];
  CourseHit? _picked;
  String _category = noCategory;
  int _grade = GradeCode.clr;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _search(String q) => setState(() {
    _hits = searchCourses(
      q,
      held: widget.held,
      discipline: widget.discipline,
      master: widget.master,
    );
    if (_picked != null && !_hits.any((h) => h.id == _picked!.id)) {
      _picked = null;
    }
  });

  void _pick(CourseHit h) => setState(() {
    _picked = h;
    _category = h.category;
    _grade = GradeCode.clr;
  });

  Course? get _course =>
      _picked == null
          ? null
          : newCourse(
            _picked!,
            sem: widget.sem,
            discipline: widget.discipline,
            category: _category,
            profile: widget.profile,
            grade: _grade,
          );

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final sem = semLabel(widget.sem);
    final course = _course;
    final mode = widget.profile == Profile.actual ? 'Actual' : 'Expected';

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Space.gutter,
          0,
          Space.gutter,
          Space.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add a course',
              style: TypeScale.title.copyWith(color: p.text),
            ),
            Text(
              'to semester $sem · $mode',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TypeScale.caption.copyWith(color: p.textMuted),
            ),
            const SizedBox(height: Space.md),
            TextField(
              controller: _query,
              autofocus: true,
              onChanged: _search,
              style: TypeScale.body.copyWith(color: p.text),
              decoration: InputDecoration(
                hintText: 'Search by code or name',
                prefixIcon: Icon(Icons.search_rounded, color: p.icon),
                suffixText:
                    _query.text.trim().isEmpty ? null : '${_hits.length} found',
                filled: true,
                fillColor: p.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: p.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: p.text, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: Space.md),
            Expanded(
              child: ListView(
                children: [
                  for (final h in _hits) ...[
                    _HitRow(
                      hit: h,
                      picked: h.id == _picked?.id,
                      discipline: widget.discipline,
                      onTap: h.heldIn == null ? () => _pick(h) : null,
                    ),
                    if (h.id == _picked?.id) _selectedCard(context, h),
                    const SizedBox(height: Space.sm - 1),
                  ],
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onManual();
                      },
                      child: Text(
                        'Not in the list? Enter it manually',
                        style: TypeScale.caption.copyWith(
                          color: p.accent,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.sm),
            _submit(context, course, sem),
          ],
        ),
      ),
    );
  }

  Widget _submit(BuildContext context, Course? course, String sem) {
    final p = AppPalette.of(context);
    String? change;
    if (course != null) {
      final (before, after) = sgpaChange(
        widget.held,
        course,
        sem: widget.sem,
        discipline: widget.discipline,
        profile: widget.profile,
      );
      String f(double? v) => v == null ? '–' : v.toStringAsFixed(2);
      if (after != null) {
        change =
            before == after
                ? 'SGPA stays ${f(after)}'
                : 'SGPA ${f(before)} → ${f(after)}';
      }
    }
    return Semantics(
      button: true,
      enabled: course != null,
      child: Material(
        color: p.inverse.withValues(alpha: course == null ? 0.4 : 1),
        borderRadius: BorderRadius.circular(19),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: course == null ? null : () => Navigator.pop(context, course),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 54),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.lg),
              child: Center(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: 'Add to $sem'),
                      if (change != null)
                        TextSpan(
                          text: '  $change',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: p.hero,
                          ),
                        ),
                    ],
                  ),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TypeScale.button.copyWith(color: p.onInverse),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _selectedCard(BuildContext context, CourseHit h) {
    final p = AppPalette.of(context);
    final label = TypeScale.label.copyWith(color: p.onHeroMuted);
    Widget pill(String text, int value, {bool quiet = false}) {
      final on = _grade == value;
      return Semantics(
        button: true,
        selected: on,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _grade = value),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Sizes.minTouch),
            child: Center(
              widthFactor: 1,
              child: Container(
                height: 31,
                padding: const EdgeInsets.symmetric(horizontal: 11),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color:
                      on
                          ? p.inverse
                          : p.surface.withValues(alpha: quiet ? 0.5 : 1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  text,
                  style: TypeScale.caption.copyWith(
                    fontSize: 12.5,
                    fontWeight: on ? FontWeight.w700 : FontWeight.w600,
                    color: on ? p.onInverse : p.text,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: Space.xs),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.hero,
        borderRadius: BorderRadius.circular(Radii.row),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SELECTED', style: label),
                    Text(
                      h.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TypeScale.body.copyWith(
                        color: p.onHero,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Space.sm),
              Text(
                '${formatCredits(h.credits)} cr',
                style: TypeScale.caption.copyWith(
                  color: p.onHero,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          Text('COUNTS AS', style: label),
          const SizedBox(height: Space.xs),
          DropdownButtonHideUnderline(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: Space.md),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(13),
              ),
              child: DropdownButton<String>(
                value: _category,
                isExpanded: true,
                dropdownColor: p.surface,
                style: TypeScale.caption.copyWith(
                  color: p.text,
                  fontWeight: FontWeight.w600,
                ),
                items: [
                  for (final t in {
                    ...categoryOptions(widget.discipline),
                    _category,
                  })
                    DropdownMenuItem(
                      value: t,
                      child: Text(
                        categoryLabel(t, widget.discipline),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (t) => setState(() => _category = t ?? _category),
              ),
            ),
          ),
          const SizedBox(height: Space.md),
          Text('GRADE', style: label),
          Wrap(
            spacing: 5,
            children: [
              for (final g in letterGrades)
                pill(g.replaceAll('-', '−'), reversegradecalc(g)),
              for (final (g, _) in specialGrades)
                pill(g, reversegradecalc(g), quiet: true),
              pill('Not yet', GradeCode.clr, quiet: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _HitRow extends StatelessWidget {
  const _HitRow({
    required this.hit,
    required this.picked,
    required this.discipline,
    required this.onTap,
  });

  final CourseHit hit;
  final bool picked;
  final String discipline;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final held = hit.heldIn;
    final cr = formatCredits(hit.credits);
    final detail =
        held != null
            ? '${hit.id} · already in ${semLabel(held)}'
            : '${hit.id} · $cr credit${cr == '1' ? '' : 's'} · '
                '${categoryLabel(hit.category, discipline)}';
    return Opacity(
      opacity: held != null ? 0.55 : 1,
      child: AppCard(
        onTap: onTap,
        radius: 17,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        border: picked ? BorderSide(color: p.text, width: 1.5) : null,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hit.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TypeScale.body.copyWith(
                      color: p.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TypeScale.caption.copyWith(color: p.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.md),
            if (held != null)
              Text('ADDED', style: TypeScale.label.copyWith(color: p.textMuted))
            else
              Icon(
                picked ? Icons.check_circle_rounded : Icons.add_rounded,
                size: 22,
                color: picked ? p.text : p.textMuted,
              ),
          ],
        ),
      ),
    );
  }
}
