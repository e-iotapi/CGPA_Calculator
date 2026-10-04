import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/storage/courses.dart';
import 'package:cgpa_calculator/core/models/offering.dart' show termLabel;
import 'package:cgpa_calculator/core/professors/professor.dart';
import 'package:cgpa_calculator/core/professors/professor_store.dart';
import 'package:cgpa_calculator/core/reviews/review.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/core/storage/offerings.dart';
import 'package:cgpa_calculator/features/marks/official.dart';
import 'package:cgpa_calculator/features/reviews/pick_sheet.dart';
import 'package:cgpa_calculator/features/reviews/review_widgets.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/bottom_action.dart';
import 'package:cgpa_calculator/shared/widgets/pill_button.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:flutter/material.dart';

typedef _Took = ({String term, ReviewProfs profs});

/// Who a review can name: the course's department on a campus, the term's
/// offering's professors first. A review is of the course under a
/// professor; the term (or whether it was offered) only orders the list.
typedef ReviewProfs = ({List<Professor> list, String? taught});

ReviewProfs _ordered(
  List<String> offered,
  List<Professor> dept,
  Map<String, Professor> named,
) {
  final out = <String, Professor>{};
  for (final id in offered) {
    // Kept under the id the offering names, even if merged since.
    if (named[id] case final p? when !p.removed) {
      out[id] = Professor(
        id: id,
        name: p.name,
        campus: p.campus,
        department: p.department,
      );
    }
  }
  for (final p in dept) {
    if (!p.removed) out.putIfAbsent(p.id, () => p);
  }
  return (list: out.values.toList(), taught: out.keys.firstOrNull);
}

Future<ReviewProfs> reviewProfessors(
  String courseId,
  String campus,
  String term,
) async {
  final store = ProfessorStore(roleStore!.db);
  var offered = const <String>[];
  try {
    offered =
        (await offeringSource?.get(courseId, campus, term))?.professors ??
        const <String>[];
  } catch (_) {
    // No offering read: the department alone.
  }
  final named = <String, Professor>{};
  for (final id in offered) {
    if (await store.get(id) case final p?) named[id] = p;
  }
  final r = _ordered(
    offered,
    await store.department(campus, deptOf(courseId)),
    named,
  );
  return (list: r.list, taught: offered.isEmpty ? null : r.taught);
}

/// [reviewProfessors] from the saved copies; null if any part is not saved.
ReviewProfs? peekReviewProfessors(String courseId, String campus, String term) {
  final store = ProfessorStore(roleStore!.db);
  final dept = store.peekDepartment(campus, deptOf(courseId));
  if (dept == null) return null;
  final offered =
      cachedOffering(courseId, campus, term)?.professors ?? const <String>[];
  final named = <String, Professor>{};
  for (final id in offered) {
    final p = store.peekResolved(id);
    if (p == null) {
      if (store.peekSaved(id)) continue; // gone: skipped, as the load does
      return null;
    }
    named[id] = p;
  }
  final r = _ordered(offered, dept, named);
  return (list: r.list, taught: offered.isEmpty ? null : r.taught);
}

/// The term a review of [courseId] carries: the one it was taken in, else
/// (tracked in the grades with no term yet begun) the current one.
String? reviewTerm(String courseId) =>
    tookIt(courseId)?.term ??
    (allCourses().any((c) => c.id == courseId)
        ? currentTerm(DateTime.now())
        : null);

/// Boards `ReviewWrite` and `ReviewEdit`: the term and professor come from
/// the student's grades; the professor is picked from the course's
/// department, that term's offering's first, never typed (§10.3, fix
/// 5). Posted without a name or id; editable later, never deleted (fix 6).
class ReviewFormPage extends StatefulWidget {
  const ReviewFormPage({super.key, required this.courseId, this.existing});
  final String courseId;
  final Review? existing;

  @override
  State<ReviewFormPage> createState() => _ReviewFormPageState();
}

class _ReviewFormPageState extends State<ReviewFormPage> {
  late int _stars = widget.existing?.stars ?? 0;
  late bool? _recommend = widget.existing?.recommend;
  late final _text = TextEditingController(text: widget.existing?.text);

  /// Prefilled from the review being edited, else from the student's own
  /// course; else Not disclosed (contract B5: ND is the UI default).
  late String? _grade =
      widget.existing?.grade ?? ownGrade(widget.courseId) ?? 'ND';
  late final _marks = TextEditingController(
    text: switch (widget.existing?.marks ?? ownMarks(widget.courseId)) {
      final m? => marksText(m),
      _ => '',
    },
  );

  /// The marks typed: null when empty or not 0 to 1000 ([_marksBad]).
  num? get _marksValue {
    final m = num.tryParse(_marks.text.trim());
    return m != null && m >= 0 && m <= 1000 ? m : null;
  }

  bool get _marksBad => _marks.text.trim().isNotEmpty && _marksValue == null;
  String? _professorId;
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    _marks.dispose();
    super.dispose();
  }

  Future<_Took?> _load() async {
    final e = widget.existing;
    final campus = myCampus;
    final term = e?.term ?? reviewTerm(widget.courseId);
    if (campus == null || term == null) return null;
    final profs =
        e == null
            ? await reviewProfessors(widget.courseId, campus, term)
            : await _theirs(e);
    _professorId ??= e?.professorId ?? profs.taught;
    return (term: term, profs: profs);
  }

  /// An edit keeps the professor posted (rules: never changed).
  Future<ReviewProfs> _theirs(Review e) async {
    final id = e.professorId;
    final p = id == null ? null : await ProfessorStore(roleStore!.db).get(id);
    return _ordered([if (id != null) id], const [], {if (p != null) id!: p});
  }

  /// [_load] from the saved copies; null if any part is not saved.
  _Took? _peek() {
    final e = widget.existing;
    final campus = myCampus;
    final term = e?.term ?? reviewTerm(widget.courseId);
    if (campus == null || term == null) return null;
    final ReviewProfs? profs;
    if (e == null) {
      profs = peekReviewProfessors(widget.courseId, campus, term);
    } else {
      final id = e.professorId;
      final p =
          id == null ? null : ProfessorStore(roleStore!.db).peekResolved(id);
      profs =
          id != null && p == null
              ? null
              : _ordered(
                [if (id != null) id],
                const [],
                {if (p != null) id!: p},
              );
    }
    if (profs == null) return null;
    _professorId ??= e?.professorId ?? profs.taught;
    return (term: term, profs: profs);
  }

  Future<void> _save(_Took t) async {
    final store = reviewStore!;
    setState(() => _busy = true);
    try {
      await store.save(
        courseId: widget.courseId,
        campus: myCampus!,
        term: t.term,
        professorId: _professorId,
        stars: _stars,
        recommend: _recommend!,
        grade: _grade!,
        marks: _marksValue,
        text: _text.text,
        before: widget.existing,
      );
      await rememberReview(widget.courseId);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        sayReview(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final caption = TypeScale.caption.copyWith(
      height: 1.45,
      color: p.textMuted,
    );
    final editing = widget.existing != null;
    return Loaded<_Took?>(
      load: _load,
      peek: _peek,
      builder: (context, t, _) {
        final header = PageHeader(
          eyebrow: '${widget.courseId} · ${(myCampus ?? '').toUpperCase()}',
          title: editing ? 'Edit your review' : 'Your review',
        );
        if (t == null) {
          return PageFrame(
            header: header,
            children: const [
              Note(
                'Reviews come from courses you have taken. Add this course, '
                'with its semester, to your grades first.',
              ),
            ],
          );
        }
        final prof =
            t.profs.list.where((x) => x.id == _professorId).firstOrNull;
        final label = TypeScale.label.copyWith(color: p.textMuted);
        final e = widget.existing;
        return PageFrame(
          header: header,
          bottom: BottomAction(
            child: PrimaryButton(
              tall: true,
              label:
                  _busy
                      ? 'Saving…'
                      : editing
                      ? 'Save changes'
                      : 'Post review',
              onPressed:
                  _busy ||
                          _stars == 0 ||
                          _recommend == null ||
                          _grade == null ||
                          _marksBad ||
                          _text.text.length > reviewTextLimit
                      ? null
                      : () => _save(t),
            ),
          ),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('YOU TOOK IT', style: label),
                  const SizedBox(height: Space.sm),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ScopeChip(termLabel(t.term).toUpperCase(), muted: true),
                      if (prof != null && editing) ScopeChip(prof.name),
                    ],
                  ),
                  if (!editing) ...[
                    const SizedBox(height: Space.sm),
                    SelectRow(
                      text: prof?.name ?? 'Not sure who taught it',
                      placeholder: prof == null,
                      onTap: () async {
                        final v = await pickSheet<String?>(
                          context,
                          title: 'Professor',
                          selected: _professorId,
                          searchHint: 'Search professors',
                          options: [
                            (null, 'Not sure who taught it'),
                            for (final x in t.profs.list) (x.id, x.name),
                          ],
                        );
                        if (v != null) setState(() => _professorId = v.value);
                      },
                    ),
                  ],
                  const SizedBox(height: Space.sm),
                  Text(
                    prof == null
                        ? 'From your grades. With no professor picked, it '
                            'counts toward the course only.'
                        : 'Your review counts toward ${prof.name}, not the '
                            'course as a whole.',
                    style: caption,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('OVERALL', style: label),
                  const SizedBox(height: Space.sm),
                  StarPicker(
                    value: _stars,
                    onChanged: (v) => setState(() => _stars = v),
                  ),
                  const SizedBox(height: Space.md),
                  Text('WOULD YOU TAKE IT AGAIN, FROM THEM?', style: label),
                  const SizedBox(height: Space.sm),
                  Row(
                    children: [
                      for (final v in const [true, false]) ...[
                        if (!v) const SizedBox(width: Space.sm),
                        Expanded(
                          child: PillButton(
                            label: v ? 'Yes' : 'No',
                            height: 44,
                            expand: true,
                            selected: _recommend == v,
                            onPressed: () => setState(() => _recommend = v),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Board ReviewForm: grade and marks side by side.
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 13,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('GRADE', style: label),
                            const SizedBox(height: 6),
                            _Field(
                              onTap: () async {
                                final v = await pickSheet<String>(
                                  context,
                                  title: 'Grade',
                                  selected: _grade,
                                  options: [
                                    for (final g in reviewGrades)
                                      (g, gradeName(g)),
                                  ],
                                );
                                if (v != null) setState(() => _grade = v.value);
                              },
                              child: Row(
                                children: [
                                  Expanded(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        _grade == null
                                            ? 'Choose'
                                            : gradeName(_grade!),
                                        maxLines: 1,
                                        style: TypeScale.body.copyWith(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: p.text,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.expand_more_rounded,
                                    size: 18,
                                    color: p.textMuted,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 10,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text('MARKS', style: label),
                                Text(
                                  'optional',
                                  style: TypeScale.caption.copyWith(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w500,
                                    color: p.textMuted,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            _Field(
                              child: TextField(
                                key: const ValueKey('review-marks'),
                                controller: _marks,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                onChanged: (_) => setState(() {}),
                                style: TypeScale.body.copyWith(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: p.text,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isCollapsed: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_marksBad) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Marks are between 0 and 1000',
                      style: TypeScale.caption.copyWith(color: p.behind),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('WHAT SHOULD THE NEXT BATCH KNOW?', style: label),
                  const SizedBox(height: Space.sm),
                  TextField(
                    controller: _text,
                    minLines: 4,
                    maxLines: 8,
                    style: TypeScale.body,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText:
                          'Grading, workload, what the exams look like, what '
                          'actually helped.',
                      hintMaxLines: 3,
                      hintStyle: TypeScale.body.copyWith(color: p.textMuted),
                      filled: true,
                      fillColor: p.background,
                      contentPadding: const EdgeInsets.all(12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: p.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: p.text, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_text.text.length} / $reviewTextLimit',
                    style: TypeScale.caption.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color:
                          _text.text.length > reviewTextLimit
                              ? p.behind
                              : p.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Note(
              e != null
                  ? 'Still without your name or ID. Posted '
                      '${shortDay(DateTime.fromMillisecondsSinceEpoch(e.createdAt), year: true)}; '
                      'an edit keeps its helpful votes and says “edited”. '
                      'Reviews are edited, never deleted.'
                  : 'Posted without your name or ID. One review per course; '
                      'you can edit it later.',
            ),
          ],
        );
      },
    );
  }
}

/// A 40 tall sunken box with an outline, for the grade and marks.
class _Field extends StatelessWidget {
  const _Field({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Material(
      color: p.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: p.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 40,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: child,
        ),
      ),
    );
  }
}
