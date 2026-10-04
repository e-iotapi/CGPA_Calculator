import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/shared/debounce.dart';
import 'package:cgpa_calculator/core/grading/cgpa.dart';
import 'package:cgpa_calculator/core/grading/grade_scale.dart';
import 'package:cgpa_calculator/core/models/course_names.dart';
import 'package:cgpa_calculator/core/reviews/review.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/reviews/review_widgets.dart';
import 'package:cgpa_calculator/features/semester/add_course_controller.dart';
import 'package:cgpa_calculator/features/semester/semester_controller.dart';
import 'package:cgpa_calculator/features/semester/widgets/course_fields.dart';
import 'package:cgpa_calculator/features/semester/widgets/grade_menu.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/mastercourselist.dart';
import 'package:cgpa_calculator/shared/widgets/confirm_dialog.dart';
import 'package:cgpa_calculator/shared/widgets/notice.dart';
import 'package:flutter/material.dart';

/// Opens the add sheet. Resolves to the course to store, or null.
Future<Course?> showAddCourseSheet(
  BuildContext context, {
  required Iterable<Course> held,
  required String sem,
  required String discipline,
  required Profile profile,
}) {
  final p = AppPalette.of(context);
  return showModalBottomSheet<Course>(
    context: context,
    isScrollControlled: true,
    backgroundColor: p.isDark ? p.surface : p.onInverse,
    barrierColor: p.inverse.withValues(alpha: 0.34),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
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

/// The sheet that adds a course to a semester, from the catalogue or by hand.
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
  double _credits = 3;
  String? _manualCategory;
  int _manualGrade = GradeCode.clr;

  /// Hits follow the search after a pause in typing (UI_OPT O5.2).
  final _typed = Debouncer();

  /// Every course's rating on my campus: the saved copy at once, the fresh
  /// one when it lands. Null = none yet; never a spinner.
  Map<String, ReviewStats>? _ratings;
  bool _ratingsFailed = false;

  @override
  void initState() {
    super.initState();
    final store = reviewStore, campus = myCampus;
    if (store == null || campus == null) return;
    _ratings = store.peekIndex(campus);
    store
        .index(campus)
        .then(
          (m) {
            if (mounted) setState(() => _ratings = m);
          },
          onError: (_) {
            // A saved copy stays; with none, rows go without stars.
            if (mounted && _ratings == null) {
              setState(() => _ratingsFailed = true);
            }
          },
        );
  }

  @override
  void dispose() {
    _typed.dispose();
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
        credits: _credits,
        category: category,
      ),
      sem: widget.sem,
      discipline: widget.discipline,
      category: category,
      profile: widget.profile,
      grade: _manualGrade,
    );
  }

  // The debounced search (UI_OPT O5.2) means the box can outrun _hits while
  // typing; track which query _hits answers so a still-pending search can't
  // leave the previous query's rows on screen and tappable (BUG-17).
  String _hitsQuery = '';

  void _search(String q) => setState(() {
    _hitsQuery = q;
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

  List<CourseHit> get _currentHits =>
      _hitsQuery == _query.text ? _hits : const [];

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
          20,
          10,
          20,
          Space.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: p.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_manual)
              ..._manualView(context)
            else ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add a course',
                          style: TypeScale.sheetTitle.copyWith(color: p.text),
                        ),
                        Text(
                          'to semester $sem · $mode',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TypeScale.caption.copyWith(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: p.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  _SheetCircle(
                    icon: Icons.close_rounded,
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
              const SizedBox(height: Space.md),
              TextField(
                controller: _query,
                autofocus: true,
                onChanged:
                    (q) => _typed(() {
                      if (mounted) _search(q);
                    }),
                style: TypeScale.body.copyWith(color: p.text),
                decoration: InputDecoration(
                  hintText: 'Code or name',
                  prefixIcon: Icon(Icons.search_rounded, color: p.icon),
                  suffixText:
                      _query.text.trim().isEmpty
                          ? null
                          : '${_currentHits.length} found',
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
                    if (_ratingsFailed) ...[
                      const Notice(
                        text: TextSpan(text: 'Ratings did not load'),
                      ),
                      const SizedBox(height: Space.sm),
                    ],
                    for (final h in _currentHits) ...[
                      _HitRow(
                        hit: h,
                        rating: _ratings?[h.id],
                        rated: _ratings != null,
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

    // `.fld`: white, no border, radius 15, 46 tall.
    InputDecoration field(String hintText) => InputDecoration(
      hintText: hintText,
      isDense: true,
      counterText: '',
      filled: true,
      fillColor: p.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: p.text, width: 1.5),
      ),
    );
    final input = TypeScale.body.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.35,
      color: p.text,
    );
    void edited(String _) => setState(() {});

    Widget section(String name, Widget child, [String? note]) =>
        FieldSection(label: name, note: note, child: child);

    Widget step(IconData icon, String tip, double to) => _StepBox(
      icon: icon,
      tooltip: tip,
      onPressed:
          to < 0.5 || to > 20 ? null : () => setState(() => _credits = to),
    );

    // The header scrolls with the fields, so large text leaves room.
    return [
      Expanded(
        child: ListView(
          children: [
            Row(
              children: [
                _SheetCircle(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back to search',
                  onPressed: () => setState(() => _manual = false),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enter it manually',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TypeScale.sheetTitle.copyWith(
                          fontSize: 20,
                          color: p.text,
                        ),
                      ),
                      Text(
                        'for courses not in the BITS list',
                        style: TypeScale.caption.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: p.textMuted,
                        ),
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
                  : 'Department, then number — like AN and F311.',
            ),
            section(
              'TITLE',
              TextField(
                controller: _title,
                minLines: 1,
                maxLines: 2,
                // Unbounded titles made a course card run to ~6 lines
                // (BUG-30).
                maxLength: 80,
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
                  step(
                    Icons.remove_rounded,
                    'Fewer credits',
                    _credits > 1 ? _credits - 1 : _credits - 0.5,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        formatCredits(_credits),
                        style: TypeScale.body.copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: p.text,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  step(
                    Icons.add_rounded,
                    'More credits',
                    _credits < 1 ? 1 : _credits + 1,
                  ),
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
      final go = await confirmDialog(
        context,
        title: 'Over ${f(maxSemesterCredits)} credits',
        body:
            'This takes ${semLabel(widget.sem)} to ${f(total)} credits. '
            'A semester can carry at most ${f(maxSemesterCredits)} unless '
            'the administration on your campus has approved more.',
        action: 'I have approval, add it',
      );
      if (!go) return;
    }
    if (context.mounted) Navigator.pop(context, course);
  }

  Widget _submit(BuildContext context, Course? course, String sem) {
    final p = AppPalette.of(context);
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
                child: Text(
                  'Add to $sem',
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
        label: 'Grade $text',
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: p.onHero.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  '${formatCredits(h.credits)} cr',
                  style: TypeScale.caption.copyWith(
                    fontSize: 11,
                    color: p.onHero,
                    fontWeight: FontWeight.w700,
                  ),
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
    required this.rating,
    required this.rated,
  });

  /// The course's counters; [rated] is false when no ratings are known.
  final ReviewStats? rating;
  final bool rated;
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
    // Held: a "not counted" card, surface at 55% with muted text (UI.md
    // §2.1), in colour rather than an Opacity layer (UI_OPT O4.1).
    return AppCard(
      onTap: onTap,
      color: held != null ? p.surface.withValues(alpha: 0.55) : null,
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
                    color: held != null ? p.textMuted : p.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TypeScale.caption.copyWith(color: p.textMuted),
                ),
                if (held == null && rated) _ratingLine(p),
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
    );
  }

  Widget _ratingLine(AppPalette p) {
    final r = rating;
    final style = TypeScale.caption.copyWith(color: p.textMuted);
    if (r == null || r.count == 0) return Text('No ratings yet', style: style);
    final avg = r.average!;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Stars(value: avg.round(), size: 13),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '${avg.toStringAsFixed(1)} · ${r.count} review'
              '${r.count == 1 ? '' : 's'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}

/// A 34 px circle with a 44 px hit area, for the sheet's Close and Back.
class _SheetCircle extends StatelessWidget {
  const _SheetCircle({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        child: InkResponse(
          onTap: onPressed,
          radius: 22,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: p.isDark ? p.surfaceSunken : const Color(0xFFE8E8E1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 15, color: p.icon),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The credits stepper's − and + : 42 px white boxes.
class _StepBox extends StatelessWidget {
  const _StepBox({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(
              icon,
              size: 19,
              color: onPressed == null ? p.textMuted : p.icon,
            ),
          ),
        ),
      ),
    );
  }
}
