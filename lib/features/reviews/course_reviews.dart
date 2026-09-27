import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/catalog/catalog.dart';
import 'package:cgpa_calculator/core/professors/professor.dart';
import 'package:cgpa_calculator/core/professors/professor_store.dart';
import 'package:cgpa_calculator/core/reviews/review.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/features/marks/official.dart';
import 'package:cgpa_calculator/features/reviews/review_form.dart';
import 'package:cgpa_calculator/features/reviews/review_widgets.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

typedef _Meta =
    ({
      ReviewStats course,
      List<(Professor, ReviewStats)> taughtBy,
      String? now,
      Review? mine,
    });

/// Board `Reviews`: one course on the student's campus, filtered by
/// professor — by default whoever teaches it now (§10.3).
class CourseReviewsPage extends StatefulWidget {
  const CourseReviewsPage({
    super.key,
    required this.courseId,
    this.professorId,
  });
  final String courseId;

  /// Opened from a professor: filtered to them rather than to whoever
  /// teaches it now.
  final String? professorId;

  @override
  State<CourseReviewsPage> createState() => _CourseReviewsPageState();
}

class _CourseReviewsPageState extends State<CourseReviewsPage> {
  late String? _prof = widget.professorId;
  late bool _picked = widget.professorId != null;
  ReviewOrder _order = ReviewOrder.helpful;
  final _reviews = <Review>[];
  DocumentSnapshot? _last;
  bool _more = true, _loading = false;
  int _loads = 0;
  final _names = <String, String>{};

  String get _campus => myCampus ?? '';

  Future<_Meta> _meta() async {
    final store = reviewStore!;
    final profs = ProfessorStore(roleStore!.db);
    final by = await store.byProfessor(widget.courseId, _campus);
    // Merged duplicates count as their survivor (§16.3 fix 7).
    final groups = <String, (Professor, ReviewStats)>{};
    for (final e in by.entries) {
      final p = await profs.get(e.key);
      if (p == null) continue;
      _names[e.key] = p.name;
      final g = groups[p.id];
      groups[p.id] = (p, g == null ? e.value : g.$2 + e.value);
    }
    final off = await offeringSource?.get(
      widget.courseId,
      _campus,
      currentTerm(DateTime.now()),
    );
    String? now;
    for (final id in off?.professors ?? const <String>[]) {
      final p = await profs.get(id);
      if (p != null) {
        now = p.id;
        _names[id] = p.name;
        groups.putIfAbsent(p.id, () => (p, const ReviewStats()));
        break;
      }
    }
    // Opened from a professor who has no reviews here yet.
    if (_prof case final id? when !groups.containsKey(id)) {
      final p = await profs.get(id);
      if (p != null) {
        _names[id] = p.name;
        _prof = p.id;
        groups.putIfAbsent(p.id, () => (p, const ReviewStats()));
      }
    }
    if (!_picked) _prof = now;
    return (
      course: await store.stats(widget.courseId, _campus),
      taughtBy: groups.values.toList()..sort((a, b) => b.$2.count - a.$2.count),
      now: now,
      mine: await store.mine(widget.courseId),
    );
  }

  List<String>? _ids(_Meta m) {
    final g = m.taughtBy.where((x) => x.$1.id == _prof).firstOrNull;
    return g?.$1.allIds;
  }

  Future<void> _page(_Meta m, {bool reset = false}) async {
    if (_loading) return;
    _loading = true;
    try {
      final r = await reviewStore!.page(
        widget.courseId,
        _campus,
        professorIds: _prof == null ? null : _ids(m),
        order: _order,
        after: reset ? null : _last,
      );
      setState(() {
        if (reset) _reviews.clear();
        _reviews.addAll(r.reviews);
        _last = r.last;
        _more = r.reviews.length == 10 && r.last != null;
      });
    } catch (e) {
      if (mounted) sayReview(context, e);
    } finally {
      _loading = false;
    }
  }

  Future<void> _write(Review? mine) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder:
            (_) => ReviewFormPage(courseId: widget.courseId, existing: mine),
      ),
    );
    if (saved == true) setState(() => _loads++);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final title =
        catalog.master.where((m) => m.id == widget.courseId).firstOrNull?.title;
    if (roleStore == null) {
      return PageFrame(
        header: PageHeader(eyebrow: widget.courseId, title: 'Reviews'),
        children: const [
          Note('Sign in with your BITS account to read reviews.'),
        ],
      );
    }
    return Loaded<_Meta>(
      key: ValueKey(_loads),
      load: () async {
        final m = await _meta();
        _last = null;
        await _page(m, reset: true);
        return m;
      },
      builder: (context, m, _) {
        final sel = m.taughtBy.where((x) => x.$1.id == _prof).firstOrNull;
        final stats = sel?.$2 ?? m.course;
        final took = tookIt(widget.courseId);
        return PageFrame(
          header: PageHeader(
            eyebrow: '${widget.courseId} · ${_campus.toUpperCase()}',
            title: title ?? widget.courseId,
          ),
          children: [
            if (m.taughtBy.isNotEmpty) ...[
              const SectionLabel('Taught by'),
              ChoicePills<String?>(
                values: [for (final x in m.taughtBy) x.$1.id, null],
                selected: _prof,
                label:
                    (id) =>
                        id == null
                            ? 'All'
                            : m.taughtBy
                                .firstWhere((x) => x.$1.id == id)
                                .$1
                                .name,
                onSelected: (id) {
                  setState(() {
                    _prof = id;
                    _picked = true;
                  });
                  _page(m, reset: true);
                },
              ),
              const SizedBox(height: Space.xs),
              Text(
                sel == null
                    ? 'Every professor · ${m.course.count} reviews'
                    : '${sel.$1.id == m.now ? 'Teaching this semester · ' : ''}'
                        '${sel.$2.count} of ${m.course.count} reviews',
                style: TypeScale.caption.copyWith(color: p.textMuted),
              ),
              const SizedBox(height: Space.sm),
            ],
            StatsCard(
              stats: stats,
              note:
                  sel == null || m.course.average == null
                      ? null
                      : '${sel.$1.name} only. The whole course sits at '
                          '${m.course.average!.toStringAsFixed(1)} across every '
                          'professor.',
            ),
            const SizedBox(height: Space.sm),
            ChoicePills<ReviewOrder>(
              values: ReviewOrder.values,
              selected: _order,
              label: (o) => o.label,
              onSelected: (o) {
                setState(() => _order = o);
                _page(m, reset: true);
              },
            ),
            const SizedBox(height: Space.sm),
            for (final r in _reviews) ...[
              ReviewTile(
                r: r,
                professor: _names[r.professorId],
                onHelpful:
                    r.id == m.mine?.id
                        ? null
                        : () async {
                          final ok = await reviewStore!.vote(r);
                          if (!context.mounted) return;
                          sayReview(
                            context,
                            ok
                                ? 'Marked helpful.'
                                : 'You have already marked this one.',
                          );
                        },
                onReport:
                    r.id == m.mine?.id
                        ? null
                        : () async {
                          final ok = await reviewStore!.report(r);
                          if (!context.mounted) return;
                          sayReview(
                            context,
                            ok
                                ? 'Reported to the department. It stays up '
                                    'until someone looks.'
                                : 'You have already reported this one.',
                          );
                        },
              ),
              const SizedBox(height: Space.xs),
            ],
            if (_reviews.isEmpty)
              const Note(
                'No reviews here yet. A course taught by someone new starts '
                'a fresh set.',
              ),
            if (_more)
              TextButton(
                onPressed: () => _page(m),
                child: const Text('More reviews'),
              ),
            const SizedBox(height: Space.md),
            if (m.mine != null)
              PrimaryButton(
                label: 'Edit your review',
                onPressed: () => _write(m.mine),
              )
            else if (took != null)
              PrimaryButton(
                label: 'Review ${widget.courseId}',
                icon: Icons.rate_review_outlined,
                onPressed: () => _write(null),
              ),
          ],
        );
      },
    );
  }
}
