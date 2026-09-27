import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/models/offering.dart';
import 'package:cgpa_calculator/core/professors/professor.dart';
import 'package:cgpa_calculator/core/professors/professor_store.dart';
import 'package:cgpa_calculator/core/reviews/review.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/features/marks/official.dart';
import 'package:cgpa_calculator/features/reviews/review_widgets.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:flutter/material.dart';

typedef _Took = ({String term, Offering? offering, List<Professor> professors});

/// Boards `ReviewWrite` and `ReviewEdit`: the term and professor come from
/// the student's grades and that term's offering, never typed (§10.3, fix
/// 5). Posted without a name or id; editable and deletable later (fix 6).
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

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete your review?'),
            content: const Text('It comes off the course\'s rating at once.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (ok != true) return;
    try {
      await reviewStore!.delete(widget.existing!);
      await rememberReview(widget.courseId, remove: true);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) sayReview(context, e);
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
        final prof =
            t.professors.where((x) => x.id == _professorId).firstOrNull;
        return PageFrame(
          header: header,
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'YOU TOOK IT',
                    style: TypeScale.label.copyWith(color: p.textMuted),
                  ),
                  Text(
                    termLabel(t.term),
                    style: TypeScale.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (t.professors.length > 1 && !editing)
                    ChoicePills<String>(
                      values: [for (final x in t.professors) x.id],
                      selected: _professorId,
                      label:
                          (id) =>
                              t.professors.firstWhere((x) => x.id == id).name,
                      onSelected: (id) => setState(() => _professorId = id),
                    )
                  else
                    Text(
                      prof?.name ?? 'No professor recorded',
                      style: TypeScale.body,
                    ),
                  const SizedBox(height: Space.xs),
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
            const SectionLabel('Overall'),
            Stars(
              value: _stars,
              size: 30,
              onChanged: (v) => setState(() => _stars = v),
            ),
            const SectionLabel('Would you take it again, from them?'),
            ChoicePills<bool>(
              values: const [true, false],
              selected: _recommend,
              label: (v) => v ? 'Yes' : 'No',
              onSelected: (v) => setState(() => _recommend = v),
            ),
            const SectionLabel('What should the next batch know?'),
            AppTextField(
              controller: _text,
              label: 'Optional',
              onChanged: (_) => setState(() {}),
            ),
            Text(
              '${_text.text.length} / $reviewTextLimit',
              style: TypeScale.caption.copyWith(
                color:
                    _text.text.length > reviewTextLimit
                        ? p.behind
                        : p.textMuted,
              ),
            ),
            const SizedBox(height: Space.sm),
            Text(
              editing
                  ? 'Still without your name or ID. An edit keeps its helpful '
                      'votes and says “edited”.'
                  : 'Posted without your name or ID. One review per course; '
                      'you can edit or delete it later.',
              style: caption,
            ),
            const SizedBox(height: Space.md),
            Row(
              children: [
                if (editing) ...[
                  TextButton(onPressed: _delete, child: const Text('Delete')),
                  const SizedBox(width: Space.sm),
                ],
                Expanded(
                  child: PrimaryButton(
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
              ],
            ),
          ],
        );
      },
    );
  }
}
