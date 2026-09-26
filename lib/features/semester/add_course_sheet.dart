import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/grading/cgpa.dart';
import 'package:cgpa_calculator/core/grading/grade_scale.dart';
import 'package:cgpa_calculator/core/models/course_names.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/semester/add_course_controller.dart';
import 'package:cgpa_calculator/features/semester/semester_controller.dart';
import 'package:cgpa_calculator/features/semester/widgets/course_fields.dart';
import 'package:cgpa_calculator/features/semester/widgets/grade_menu.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/circle_icon_button.dart';
import 'package:cgpa_calculator/mastercourselist.dart';
import 'package:flutter/material.dart';

/// Opens the add sheet. Resolves to the course to store, or null.
Future<Course?> showAddCourseSheet(
  BuildContext context, {
  required Iterable<Course> held,
  required String sem,
  required String discipline,
  required Profile profile,
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
    this.master,
  });

  /// Overrides the master course list (tests).
  final List<Mastercourselist>? master;
  final Iterable<Course> held;
  final String sem;
  final String discipline;
  final Profile profile;

  @override
  State<AddCourseSheet> createState() => _AddCourseSheetState();
}

class _AddCourseSheetState extends State<AddCourseSheet> {
  final _query = TextEditingController();
  List<CourseHit> _hits = const [];
  CourseHit? _picked;
  String _category = noCategory;
  int _grade = GradeCode.clr;

  // Manual entry, for courses not in the BITS list.
  bool _manual = false;
  final _dept = TextEditingController();
  final _number = TextEditingController();
  final _title = TextEditingController();
  int _credits = 3;
  String? _manualCategory;
  int _manualGrade = GradeCode.clr;

  @override
  void dispose() {
    for (final c in [_query, _dept, _number, _title]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _manualId =>
      '${_dept.text.trim().toUpperCase()} ${_number.text.trim().toUpperCase()}';

  String? get _manualHeldIn =>
      widget.held.where((c) => sameCourseId(c.id, _manualId)).firstOrNull?.sem;

  Course? get _manualCourse {
    if (_dept.text.trim().isEmpty ||
        _number.text.trim().isEmpty ||
        _title.text.trim().isEmpty ||
        _manualHeldIn != null) {
      return null;
    }
    final category =
        _manualCategory ?? categoryFor(_manualId, widget.discipline);
    return newCourse(
      CourseHit(
        id: _manualId,
        title: _title.text.trim(),
        credits: _credits.toDouble(),
        category: category,
      ),
      sem: widget.sem,
      discipline: widget.discipline,
      category: category,
      profile: widget.profile,
      grade: _manualGrade,
    );
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
    final course = _manual ? _manualCourse : _course;
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
            if (_manual)
              ..._manualView(context)
            else ...[
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
                      _query.text.trim().isEmpty
                          ? null
                          : '${_hits.length} found',
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
                        onPressed: () => setState(() => _manual = true),
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
            ],
            const SizedBox(height: Space.sm),
            _submit(context, course, sem),
          ],
        ),
      ),
    );
  }

  /// The AddManual board: every field labelled, the title never cut.
  List<Widget> _manualView(BuildContext context) {
    final p = AppPalette.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final held = _manualHeldIn;
    final category =
        _manualCategory ??
        categoryFor(
          _dept.text.trim().isEmpty ? '' : _manualId,
          widget.discipline,
        );

    InputDecoration field(String hintText) => InputDecoration(
      hintText: hintText,
      isDense: true,
      counterText: '',
      filled: true,
      fillColor: p.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: p.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: p.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: p.text, width: 1.5),
      ),
    );
    final input = TypeScale.body.copyWith(color: p.text);
    void edited(String _) => setState(() {});

    Widget section(String name, Widget child, [String? note]) =>
        FieldSection(label: name, note: note, child: child);

    Widget step(IconData icon, String tip, int to) => CircleIconButton(
      icon: icon,
      tooltip: tip,
      onPressed: to < 1 || to > 9 ? null : () => setState(() => _credits = to),
    );

    // The header scrolls with the fields, so large text leaves room.
    return [
      Expanded(
        child: ListView(
          children: [
            Row(
              children: [
                CircleIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back to search',
                  onPressed: () => setState(() => _manual = false),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enter it manually',
                        style: TypeScale.title.copyWith(color: p.text),
                      ),
                      Text(
                        'for courses not in the BITS list',
                        style: TypeScale.caption.copyWith(color: p.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.md),
            section(
              'COURSE CODE',
              Row(
                children: [
                  SizedBox(
                    width: 108,
                    child: TextField(
                      controller: _dept,
                      autofocus: true,
                      maxLength: 5,
                      onChanged: edited,
                      textCapitalization: TextCapitalization.characters,
                      style: input,
                      decoration: field('CS'),
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: TextField(
                      controller: _number,
                      maxLength: 6,
                      onChanged: edited,
                      textCapitalization: TextCapitalization.characters,
                      style: input,
                      decoration: field('F301'),
                    ),
                  ),
                ],
              ),
              held != null
                  ? '$_manualId is already in ${semLabel(held)}'
                  : 'Department, then number, as on your timetable',
            ),
            section(
              'TITLE',
              TextField(
                controller: _title,
                minLines: 1,
                maxLines: null,
                onChanged: edited,
                textCapitalization: TextCapitalization.words,
                style: input,
                decoration: field('Course name'),
              ),
            ),
            section(
              'CREDITS',
              Row(
                children: [
                  step(Icons.remove_rounded, 'Fewer credits', _credits - 1),
                  SizedBox(
                    width: 56,
                    child: Text(
                      '$_credits',
                      textAlign: TextAlign.center,
                      style: TypeScale.title.copyWith(color: p.text),
                    ),
                  ),
                  step(Icons.add_rounded, 'More credits', _credits + 1),
                ],
              ),
            ),
            section(
              'COUNTS AS',
              CategoryDropdown(
                value: category,
                discipline: widget.discipline,
                onChanged: (t) => setState(() => _manualCategory = t),
              ),
            ),
            section(
              'GRADE',
              GradeGrid(
                value: _manualGrade,
                onChanged: (g) => setState(() => _manualGrade = g),
              ),
              'Leave it blank if the grade is not out yet',
            ),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF3A2A12) : const Color(0xFFFFF4E3),
                borderRadius: BorderRadius.circular(Radii.row),
              ),
              child: Text(
                'A manual course is not in the BITS list, so Degree progress '
                'counts it only under the category you pick here.',
                style: TypeScale.caption.copyWith(
                  color:
                      dark ? const Color(0xFFF2C98A) : const Color(0xFF7A4E12),
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  /// Adds [course], after an override when it takes the semester past
  /// [maxSemesterCredits].
  Future<void> _add(BuildContext context, Course course) async {
    final total = semesterCredits(widget.held, widget.sem) + course.credits;
    if (total > maxSemesterCredits) {
      String f(double v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';
      final go = await showDialog<bool>(
        context: context,
        builder:
            (c) => AlertDialog(
              title: Text('Over ${f(maxSemesterCredits)} credits'),
              content: Text(
                'This takes ${semLabel(widget.sem)} to ${f(total)} credits. '
                'A semester can carry at most ${f(maxSemesterCredits)} unless '
                'the administration on your campus has approved more.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('I have approval, add it'),
                ),
              ],
            ),
      );
      if (go != true) return;
    }
    if (context.mounted) Navigator.pop(context, course);
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
          onTap: course == null ? null : () => _add(context, course),
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
            // 31px pills in 36px rows: all fourteen wrap into four short
            // rows, so the card fits above the action bar.
            constraints: const BoxConstraints(minHeight: 36),
            child: Center(
              widthFactor: 1,
              // No alignment on the Container: it would stretch each pill
              // to the full row. The Center below sizes it to its text.
              child: Container(
                height: 31,
                padding: const EdgeInsets.symmetric(horizontal: 9),
                decoration: BoxDecoration(
                  color:
                      on
                          ? p.inverse
                          : p.surface.withValues(alpha: quiet ? 0.5 : 1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  widthFactor: 1,
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
                    // Two lines: an alias-joined title (§2.10) is long.
                    Text(
                      h.title,
                      maxLines: 2,
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
          CategoryDropdown(
            value: _category,
            discipline: widget.discipline,
            bordered: false,
            onChanged: (t) => setState(() => _category = t),
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
              pill('Ongoing', GradeCode.ongoing, quiet: true),
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
