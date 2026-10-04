import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/models/semesters.dart';
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
import 'package:cgpa_calculator/shared/widgets/confirm_dialog.dart';
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
  bool _busy = false;

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
          (c) => AppDialog(
            title: 'Reviews unlocked',
            body: 'Thank you. Every review on your campus is open to you now.',
            actions: [
              DialogAction('Done', ink: true, onTap: () => Navigator.pop(c)),
            ],
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
    final q = _search.text.trim().toLowerCase();
    final done = myReviewedCourses().toSet();
    final found =
        q.length < 2
            ? const <Course>[]
            : [
              for (final c in allCourses())
                if (!_drafts.containsKey(c.id) &&
                    !done.contains(c.id) &&
                    tookIt(c.id) != null &&
                    (c.id.toLowerCase().contains(q) ||
                        c.title.toLowerCase().contains(q)))
                  c,
            ].take(5).toList();
    return PageFrame(
      header: const PageHeader(
        eyebrow: 'COURSE REVIEWS',
        title: 'Your electives',
      ),
      bottom: BottomAction(
        child: PrimaryButton(
          tall: true,
          label:
              _busy
                  ? 'Posting…'
                  : chosen.length == 1
                  ? 'Post 1 review'
                  : 'Post ${chosen.length} reviews',
          onPressed:
              _busy || chosen.isEmpty || !chosen.every((d) => d.complete)
                  ? null
                  : _post,
        ),
      ),
      children: [
        const Note(
          'Tick the electives you have taken and rate each. Posted without '
          'your name or ID.',
        ),
        const SizedBox(height: Space.sm),
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
        const SizedBox(height: Space.sm),
        SearchBox(
          controller: _search,
          hint: 'Add another elective',
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

/// One elective: the tick and name, and when ticked row 1 (stars and Yes or
/// No) and row 2 (grade and marks).
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Semantics(
                label: 'Review ${d.course.id}',
                child: SizedBox.square(
                  dimension: Sizes.minTouch,
                  child: Checkbox(
                    value: on,
                    onChanged: (v) => onTick(v ?? false),
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
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${d.course.id} · ${d.course.title}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TypeScale.body.copyWith(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (on) ...[
            const SizedBox(height: Space.xs),
            Wrap(
              spacing: Space.sm,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Stars(
                  value: d.stars,
                  size: 24,
                  onChanged: (v) {
                    d.stars = v;
                    onChanged();
                  },
                ),
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
              ],
            ),
            if (d.profs case final profs? when profs.isNotEmpty) ...[
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
                  );
                  if (v != null) {
                    d.profId = v.value;
                    onChanged();
                  }
                },
              ),
            ],
            const SizedBox(height: Space.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SelectRow(
                    text: gradeName(d.grade),
                    onTap: () async {
                      final v = await pickSheet<String>(
                        context,
                        title: 'Grade',
                        selected: d.grade,
                        options: [
                          for (final g in reviewGrades) (g, gradeName(g)),
                        ],
                      );
                      if (v != null) {
                        d.grade = v.value;
                        onChanged();
                      }
                    },
                  ),
                ),
                const SizedBox(width: Space.sm),
                SizedBox(
                  width: 120,
                  child: AppTextField(
                    controller: d.marks,
                    label: 'Marks',
                    number: true,
                    error: d.marksBad ? '0 to 1000' : null,
                    onChanged: (_) => onChanged(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Tap the name to also write a few words.',
              style: TypeScale.caption.copyWith(color: p.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  String? _name(_Draft d) =>
      d.profs?.where((x) => x.id == d.profId).firstOrNull?.name;
}
