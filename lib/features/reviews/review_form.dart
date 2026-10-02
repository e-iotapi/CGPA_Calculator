import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/models/offering.dart';
import 'package:cgpa_calculator/core/professors/professor.dart';
import 'package:cgpa_calculator/core/professors/professor_store.dart';
import 'package:cgpa_calculator/core/reviews/review.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/core/storage/offerings.dart';
import 'package:cgpa_calculator/features/marks/official.dart';
import 'package:cgpa_calculator/features/reviews/review_widgets.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/bottom_action.dart';
import 'package:cgpa_calculator/shared/widgets/pill_button.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:flutter/material.dart';

typedef _Took = ({String term, Offering? offering, List<Professor> professors});

/// Boards `ReviewWrite` and `ReviewEdit`: the term and professor come from
/// the student's grades and that term's offering, never typed (§10.3, fix
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
  String? _professorId;
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<_Took?> _load() async {
    final e = widget.existing;
    final campus = myCampus;
    final term = e?.term ?? tookIt(widget.courseId)?.term;
    if (campus == null || term == null) return null;
    final off = await offeringSource?.get(widget.courseId, campus, term);
    final ids =
        e == null
            ? off?.professors ?? const <String>[]
            : [if (e.professorId != null) e.professorId!];
    final store = ProfessorStore(roleStore!.db);
    final profs = <Professor>[];
    for (final id in ids) {
      // Kept under the id the offering names, even if merged since.
      final p = await store.get(id);
      if (p != null) {
        profs.add(
          Professor(
            id: id,
            name: p.name,
            campus: p.campus,
            department: p.department,
          ),
        );
      }
    }
    _professorId ??= e?.professorId ?? profs.firstOrNull?.id;
    return (term: term, offering: off, professors: profs);
  }

  /// [_load] from the saved copies; null if any part is not saved.
  _Took? _peek() {
    final e = widget.existing;
    final campus = myCampus;
    final term = e?.term ?? tookIt(widget.courseId)?.term;
    if (campus == null || term == null) return null;
    final off = cachedOffering(widget.courseId, campus, term);
    if (e == null && off == null) return null;
    final ids =
        e == null
            ? off?.professors ?? const <String>[]
            : [if (e.professorId != null) e.professorId!];
    final store = ProfessorStore(roleStore!.db);
    final profs = <Professor>[];
    for (final id in ids) {
      final p = store.peekResolved(id);
      if (p == null) {
        if (store.peekSaved(id)) continue; // gone: skipped, as _load does
        return null;
      }
      profs.add(
        Professor(
          id: id,
          name: p.name,
          campus: p.campus,
          department: p.department,
        ),
      );
    }
    _professorId ??= e?.professorId ?? profs.firstOrNull?.id;
    return (term: term, offering: off, professors: profs);
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
        if (!editing && t.offering == null) {
          return PageFrame(
            header: header,
            children: [
              Note(
                'Nothing is recorded for ${termLabel(t.term)} yet. Reviews '
                'open once the course\'s CR or department sets that term up.',
              ),
            ],
          );
        }
        // A saved offering may name someone no longer on it.
        if (!editing && !t.professors.any((x) => x.id == _professorId)) {
          _professorId = t.professors.firstOrNull?.id;
        }
        final prof =
            t.professors.where((x) => x.id == _professorId).firstOrNull;
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
                      if (prof != null && (t.professors.length < 2 || editing))
                        ScopeChip(prof.name),
                    ],
                  ),
                  if (t.professors.length > 1 && !editing) ...[
                    const SizedBox(height: Space.sm),
                    ChoicePills<String>(
                      values: [for (final x in t.professors) x.id],
                      selected: _professorId,
                      label:
                          (id) =>
                              t.professors.firstWhere((x) => x.id == id).name,
                      onSelected: (id) => setState(() => _professorId = id),
                    ),
                  ],
                  const SizedBox(height: Space.sm),
                  Text(
                    prof == null
                        ? 'From your grades. With no professor recorded, it '
                            'counts toward the course only.'
                        : 'From your grades and that term\'s professor. Your '
                            'review counts toward ${prof.name}, not the '
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
