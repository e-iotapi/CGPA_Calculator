import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/models/semesters.dart';
import 'package:cgpa_calculator/core/search/hints.dart';
import 'package:cgpa_calculator/core/professors/professor.dart';
import 'package:cgpa_calculator/core/reviews/gate.dart';
import 'package:cgpa_calculator/core/storage/courses.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/marks/official.dart';
import 'package:cgpa_calculator/features/reviews/gate_ui.dart';
import 'package:cgpa_calculator/features/reviews/pick_sheet.dart';
import 'package:cgpa_calculator/features/reviews/review_form.dart';
import 'package:cgpa_calculator/features/reviews/review_widgets.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/bottom_action.dart';
import 'package:cgpa_calculator/shared/widgets/icon_dialog.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:cgpa_calculator/shared/widgets/pill_button.dart';
import 'package:cgpa_calculator/shared/widgets/search_box.dart';
import 'package:flutter/material.dart';

/// One elective being reviewed here: the answers so far, and the term and
/// professor its review will carry (from the grades and that term's offering).
class _Draft {
  _Draft(this.course)
    : grade = ownGrade(course.id) ?? 'ND',
      marks = TextEditingController(
        text: switch (ownMarks(course.id)) {
          final m? => marksText(m),
          _ => '',
        },
      ),
      // A graded elective was taken whatever its row's term says; its review
      // still counts when the course is offered again.
      term = tookIt(course.id)?.term ?? currentTerm(DateTime.now());

  final Course course;
  final String? term;
  final TextEditingController marks;

  /// Professors picked from the campus search, beyond [profs].
  final found = <String, Professor>{};
  int stars = 0;
  bool? recommend;
  String grade;

  /// Who the review can name ([reviewProfessors]) once read; null until then.
  List<Professor>? profs;
  String? profId;

  num? get marksValue {
    final m = num.tryParse(marks.text.trim());
    return m != null && m >= 0 && m <= 1000 ? m : null;
  }

  bool get marksBad => marks.text.trim().isNotEmpty && marksValue == null;

  bool get complete =>
      term != null &&
      profs != null &&
      stars > 0 &&
      recommend != null &&
      !marksBad;
}

/// Board `CompulsoryPick`: the electives the student has taken, last
/// semester's ticked; each opens its stars, would-take answer, grade and
/// marks here, and Post N reviews sends them all. Unlocks when enough are in.
class CompulsoryPickPage extends StatefulWidget {
  const CompulsoryPickPage({super.key});

  @override
  State<CompulsoryPickPage> createState() => _CompulsoryPickPageState();
}

class _CompulsoryPickPageState extends State<CompulsoryPickPage> {
  final _drafts = <String, _Draft>{};
  final _ticked = <String>{};
  final _search = TextEditingController();
  final _learner = QueryLearner();
  bool _busy = false, _searching = false;

  @override
  void initState() {
    super.initState();
    final done = myReviewedCourses().toSet();
    final pool = [
      for (final c in electivesTaken())
        if (!done.contains(c.id)) c,
    ];
    int at(Course c) => baseSemesters.indexOf(c.sem);
    final last = pool.fold<int>(-1, (m, c) => at(c) > m ? at(c) : m);
    for (final c in pool) {
      _drafts[c.id] = _Draft(c);
      if (at(c) == last) _tick(c.id);
    }
  }

  @override
  void dispose() {
    _learner.dispose();
    _search.dispose();
    for (final d in _drafts.values) {
      d.marks.dispose();
    }
    super.dispose();
  }

  void _tick(String id) {
    _ticked.add(id);
    _read(_drafts[id]!);
  }

  Future<void> _read(_Draft d) async {
    if (d.profs != null || d.term == null) return;
    try {
      final r =
          peekReviewProfessors(d.course.id, myCampus!, d.term!) ??
          await reviewProfessors(d.course.id, myCampus!, d.term!);
      d.profs = r.list;
      d.profId = r.taught;
    } catch (_) {
      d.profs = const []; // none to pick: the course alone
    }
    if (mounted) setState(() {});
  }

  List<_Draft> get _chosen => [
    for (final e in _drafts.entries)
      if (_ticked.contains(e.key)) e.value,
  ];

  Future<void> _post() async {
    final store = reviewStore!;
    setState(() => _busy = true);
    Object? err;
    for (final d in _chosen) {
      try {
        await store.save(
          courseId: d.course.id,
          campus: myCampus!,
          term: d.term!,
          professorId: d.profId,
          stars: d.stars,
          recommend: d.recommend!,
          grade: d.grade,
          marks: d.marksValue,
        );
        await rememberReview(d.course.id);
        _ticked.remove(d.course.id);
        _drafts.remove(d.course.id);
      } catch (e) {
        err = e;
        break;
      }
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) return sayReview(context, err);
    if (myGate(myCampus!) == GateState.locked) {
      return sayReview(
        context,
        'Posted. Review more of your electives to open reviews.',
      );
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => const IconDialog(
            icon: Icons.check_rounded,
            title: 'Reviews unlocked',
            body:
                'You reviewed your electives. Every course’s reviews are open '
                'to you now. Thank you.',
            primary: 'See course reviews',
          ),
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _openForm(_Draft d) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ReviewFormPage(courseId: d.course.id)),
    );
    if (saved != true || !mounted) return;
    setState(() {
      _ticked.remove(d.course.id);
      _drafts.remove(d.course.id);
    });
    if (myGate(myCampus!) != GateState.locked) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final chosen = _chosen;
    final q = _search.text.trim();
    final done = myReviewedCourses().toSet();
    final found =
        q.length < 2
            ? const <Course>[]
            : widen(
              q,
              (ph) => [
                for (final c in allCourses())
                  if (!_drafts.containsKey(c.id) &&
                      !done.contains(c.id) &&
                      tookIt(c.id) != null &&
                      textMatches(ph, '${c.id} ${c.title}'))
                    c,
              ],
              (c) => c.id,
            ).take(5).toList();
    if (q.length >= 2) _learner.typed(q, found: found.isNotEmpty);
    return PageFrame(
      header: const PageHeader(
        eyebrow: 'COMPULSORY REVIEWS',
        title: 'Pick electives',
      ),
      bottom: BottomAction(
        child: PrimaryButton(
          tall: true,
          label: _busy ? 'Posting…' : 'Review ${chosen.length} selected',
          onPressed:
              _busy || chosen.isEmpty || !chosen.every((d) => d.complete)
                  ? null
                  : _post,
        ),
      ),
      children: [
        Text(
          'We picked last semester’s electives. Fill the stars here; grade '
          'and marks are optional and filled in when we know them.',
          style: TypeScale.caption.copyWith(fontSize: 11.5, color: p.textMuted),
        ),
        const SizedBox(height: Space.xs),
        for (final d in _drafts.values) ...[
          _Card(
            d: d,
            on: _ticked.contains(d.course.id),
            onTick: (v) {
              setState(
                () => v ? _tick(d.course.id) : _ticked.remove(d.course.id),
              );
            },
            onOpen: () => _openForm(d),
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: Space.xs),
        ],
        if (_drafts.isEmpty)
          const Note('No electives left to review. Add one below.'),
        if (!_searching)
          InkWell(
            onTap: () => setState(() => _searching = true),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: Sizes.minTouch),
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: 1,
                child: Text(
                  'Not listed? Search for an elective',
                  style: TypeScale.body.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: p.accent,
                    decoration: TextDecoration.underline,
                    decorationColor: p.accent,
                  ),
                ),
              ),
            ),
          )
        else
          SearchBox(
            controller: _search,
            hint: 'Search for an elective',
            onChanged: (_) => setState(() {}),
          ),
        if (found.isNotEmpty) ...[
          const SizedBox(height: Space.xs),
          RowGroup(
            children: [
              for (final c in found)
                NavRow(
                  icon: Icons.add_rounded,
                  title: '${c.id} · ${c.title}',
                  onTap: () {
                    _learner.picked(q);
                    _search.clear();
                    setState(() {
                      _drafts[c.id] = _Draft(c);
                      _tick(c.id);
                    });
                  },
                ),
            ],
          ),
        ] else if (q.length >= 2)
          Padding(
            padding: const EdgeInsets.only(top: Space.xs),
            child: Text(
              'None of your courses match that.',
              style: TypeScale.caption.copyWith(color: p.textMuted),
            ),
          ),
      ],
    );
  }
}

/// One elective: the tick, name and where it was taken, and when ticked its
/// stars, would-take answer, grade and marks (board `PfForcedPick`).
class _Card extends StatelessWidget {
  const _Card({
    required this.d,
    required this.on,
    required this.onTick,
    required this.onOpen,
    required this.onChanged,
  });

  final _Draft d;
  final bool on;
  final ValueChanged<bool> onTick;
  final VoidCallback onOpen;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return AppCard(
      padding: EdgeInsets.symmetric(horizontal: 15, vertical: on ? 13 : 11),
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Semantics(
                label: 'Review ${d.course.id}',
                checked: on,
                child: InkWell(
                  onTap: () => onTick(!on),
                  customBorder: const CircleBorder(),
                  child: SizedBox.square(
                    dimension: Sizes.minTouch,
                    child: Center(child: ReviewTick(on: on)),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: onOpen,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: Sizes.minTouch,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            spacing: 2,
                            children: [
                              Text(
                                '${d.course.id} · ${d.course.title}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TypeScale.body.copyWith(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                [
                                  electiveCode(d.course.elective),
                                  if (d.term != null) d.term!,
                                ].join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TypeScale.caption.copyWith(
                                  fontSize: 10.5,
                                  color: p.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: p.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (on) ...[
            const SizedBox(height: Space.xs),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.end,
              runSpacing: 6,
              children: [
                Stars(
                  value: d.stars,
                  size: 24,
                  onChanged: (v) {
                    d.stars = v;
                    onChanged();
                  },
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  spacing: 8,
                  children: [_gradeField(context, p), _marksField(p)],
                ),
              ],
            ),
            const SizedBox(height: Space.xs),
            Wrap(
              spacing: Space.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final v in const [true, false])
                  PillButton(
                    label: v ? 'Yes' : 'No',
                    height: 36,
                    selected: d.recommend == v,
                    onPressed: () {
                      d.recommend = v;
                      onChanged();
                    },
                  ),
                Text(
                  'Will I take it',
                  style: TypeScale.caption.copyWith(
                    fontSize: 10.5,
                    color: p.textMuted,
                  ),
                ),
              ],
            ),
            // Shown even with none suggested: the search reaches the campus.
            if (d.profs case final profs?) ...[
              const SizedBox(height: Space.sm),
              SelectRow(
                text: _name(d) ?? 'Not sure who taught it',
                placeholder: d.profId == null,
                onTap: () async {
                  final v = await pickSheet<String?>(
                    context,
                    title: 'Professor',
                    selected: d.profId,
                    searchHint: 'Search professors',
                    options: [
                      (null, 'Not sure who taught it'),
                      for (final x in profs) (x.id, x.name),
                    ],
                    more: (q) => searchCampusProfessors(q, d.found),
                  );
                  if (v != null) {
                    d.profId = v.value;
                    onChanged();
                  }
                },
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _cap(AppPalette p, String text) => SizedBox(
    width: 70,
    child: Text(
      text,
      style: TypeScale.label.copyWith(
        fontSize: 8.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: p.textMuted,
      ),
    ),
  );

  BoxDecoration _box(AppPalette p) => BoxDecoration(
    color: p.surface,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: p.outline),
  );

  Widget _gradeField(BuildContext context, AppPalette p) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 2,
    children: [
      _cap(p, 'GRADE · OPTIONAL'),
      InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final v = await pickSheet<String>(
            context,
            title: 'Grade',
            selected: d.grade,
            options: [for (final g in reviewGrades) (g, gradeName(g))],
          );
          if (v != null) {
            d.grade = v.value;
            onChanged();
          }
        },
        child: Container(
          width: 70,
          height: 34,
          alignment: Alignment.center,
          decoration: _box(p),
          child: Text(
            d.grade == 'ND' ? '—' : d.grade,
            style: TypeScale.body.copyWith(
              fontSize: 12,
              fontWeight: d.grade == 'ND' ? FontWeight.w500 : FontWeight.w600,
              color: d.grade == 'ND' ? p.textMuted : p.text,
            ),
          ),
        ),
      ),
    ],
  );

  Widget _marksField(AppPalette p) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 2,
    children: [
      _cap(p, 'MARKS · OPTIONAL'),
      Container(
        width: 70,
        height: 34,
        decoration: _box(p),
        child: TextField(
          controller: d.marks,
          textAlign: TextAlign.center,
          textAlignVertical: TextAlignVertical.center,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => onChanged(),
          style: TypeScale.body.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: '—',
            hintStyle: TypeScale.body.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: p.textMuted,
            ),
            border: InputBorder.none,
            isCollapsed: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 6),
          ),
        ),
      ),
      if (d.marksBad)
        Text(
          '0 to 1000',
          style: TypeScale.caption.copyWith(
            fontSize: 9,
            color: p.rejectedTone.text,
          ),
        ),
    ],
  );

  String? _name(_Draft d) =>
      d.profs?.where((x) => x.id == d.profId).firstOrNull?.name ??
      d.found[d.profId]?.name;
}
