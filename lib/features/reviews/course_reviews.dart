import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/routes.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/catalog/catalog.dart';
import 'package:cgpa_calculator/core/professors/professor.dart';
import 'package:cgpa_calculator/core/professors/professor_store.dart';
import 'package:cgpa_calculator/core/reviews/gate.dart';
import 'package:cgpa_calculator/core/reviews/review.dart';
import 'package:cgpa_calculator/core/reviews/review_filter.dart';
import 'package:cgpa_calculator/core/reviews/review_stats.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/core/storage/offerings.dart';
import 'package:cgpa_calculator/features/marks/official.dart';
import 'package:cgpa_calculator/features/resources/resource_course_page.dart';
import 'package:cgpa_calculator/features/reviews/gate_ui.dart';
import 'package:cgpa_calculator/features/reviews/pick_sheet.dart';
import 'package:cgpa_calculator/features/reviews/review_form.dart';
import 'package:cgpa_calculator/features/reviews/review_widgets.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/bottom_action.dart';
import 'package:cgpa_calculator/shared/widgets/circle_icon_button.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:cgpa_calculator/shared/widgets/search_box.dart';
import 'package:cgpa_calculator/features/setup/campus_pick_page.dart';
import 'package:flutter/material.dart';

typedef _Meta =
    ({
      ReviewStats course,
      List<(Professor, ReviewStats)> taughtBy,
      String? now,
      Review? mine,
    });

/// Boards `CourseReviews`, `CourseReviewsNoMatch`: one course on the
/// student's campus, filtered by professor (by default whoever teaches it
/// now, §10.3), year, semester and text; the stats follow the filters.
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

  final _q = TextEditingController(), _yearText = TextEditingController();
  String? _sem;

  /// Null is "All": the unsorted default, newest first.
  ReviewOrder? _order;

  /// Reviews shown so far; More reviews adds 10.
  int _visible = 10;

  /// The year as typed: null when empty, [_yearBad] when not a year.
  String? get _year => validYear(_yearText.text);
  bool get _yearBad => _yearText.text.trim().isNotEmpty && _year == null;

  /// Changes a filter and starts the list over from its top.
  void _set(VoidCallback f) => setState(() {
    f();
    _visible = 10;
  });

  @override
  void dispose() {
    _q.dispose();
    _yearText.dispose();
    super.dispose();
  }

  final _reviews = <Review>[];
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

  /// [_meta] and the reviews from the saved copies; null if any part is
  /// not saved.
  _Meta? _peek() {
    final store = reviewStore!;
    final profs = ProfessorStore(roleStore!.db);
    final by = store.peekByProfessor(widget.courseId, _campus);
    final course = store.peekStats(widget.courseId, _campus);
    if (by == null || course == null) return null;
    final names = <String, String>{};
    final groups = <String, (Professor, ReviewStats)>{};
    for (final e in by.entries) {
      final p = profs.peekResolved(e.key);
      // A professor known to be gone is skipped, as [_meta] does; only one
      // never looked up means the copy is incomplete.
      if (p == null) {
        if (profs.peekSaved(e.key)) continue;
        return null;
      }
      names[e.key] = p.name;
      final g = groups[p.id];
      groups[p.id] = (p, g == null ? e.value : g.$2 + e.value);
    }
    final off = cachedOffering(
      widget.courseId,
      _campus,
      currentTerm(DateTime.now()),
    );
    String? now;
    for (final id in off?.professors ?? const <String>[]) {
      final p = profs.peekResolved(id);
      if (p != null) {
        now = p.id;
        names[id] = p.name;
        groups.putIfAbsent(p.id, () => (p, const ReviewStats()));
        break;
      }
    }
    var prof = _prof;
    if (prof != null && !groups.containsKey(prof)) {
      final p = profs.peekResolved(prof);
      if (p != null) {
        names[prof] = p.name;
        prof = p.id;
        groups.putIfAbsent(p.id, () => (p, const ReviewStats()));
      } else if (!profs.peekSaved(prof)) {
        return null;
      }
    }
    if (!_picked) prof = now;
    final all = store.peekAll(widget.courseId, _campus);
    if (all == null) return null;
    _names.addAll(names);
    _prof = prof;
    _reviews
      ..clear()
      ..addAll(all);
    return (
      course: course,
      taughtBy: groups.values.toList()..sort((a, b) => b.$2.count - a.$2.count),
      now: now,
      mine: store.peekMine(widget.courseId),
    );
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

  Widget _resourcesButton() => CircleIconButton(
    icon: Icons.folder_open_rounded,
    tooltip: 'Course resources',
    onPressed:
        () => openRoute(
          context,
          Routes.resourceCourse(widget.courseId),
          () => ResourceCoursePage(courseId: widget.courseId),
        ),
  );

  @override
  Widget build(BuildContext context) {
    final title =
        catalog.master.where((m) => m.id == widget.courseId).firstOrNull?.title;
    if (roleStore == null || myCampus == null) {
      return PageFrame(
        header: PageHeader(eyebrow: widget.courseId, title: 'Reviews'),
        children: [
          if (roleStore != null)
            campusPrompt(context)
          else
            const Note('Sign in with your BITS account to read reviews.'),
        ],
      );
    }
    // Locked: no reviews, no stats; the course's resources stay open.
    if (myGate(_campus) == GateState.locked) {
      return PageFrame(
        header: PageHeader(
          eyebrow: '${widget.courseId} · ${_campus.toUpperCase()}',
          title: title ?? widget.courseId,
          actions: [_resourcesButton()],
        ),
        children: [LockedReviews(onBack: () => setState(() => _loads++))],
      );
    }
    return Loaded<_Meta>(
      key: ValueKey(_loads),
      peek: _peek,
      load: () async {
        final m = await _meta();
        _reviews
          ..clear()
          ..addAll(await reviewStore!.all(widget.courseId, _campus));
        return m;
      },
      builder: (context, m, _) {
        final sel = m.taughtBy.where((x) => x.$1.id == _prof).firstOrNull;
        final yr = _year;
        final text = _q.text.trim();
        final filtered =
            _prof != null || yr != null || _sem != null || text.isNotEmpty;
        final shown = applyQuery(
          _reviews,
          ReviewQuery(
            professorIds: sel == null ? const {} : sel.$1.allIds.toSet(),
            year: yr,
            sem: _sem,
            text: _q.text,
            sort:
                _order == null
                    ? ReviewSort.recent
                    : ReviewSort.values.byName(_order!.name),
          ),
          _names,
        );
        final years = ReviewFilter.yearsIn(_reviews);
        final took = tookIt(widget.courseId);
        final action =
            m.mine != null
                ? PrimaryButton(
                  label: 'Edit your review',
                  tall: true,
                  onPressed: () => _write(m.mine),
                )
                : PrimaryButton(
                  label: 'Review ${widget.courseId}',
                  icon: Icons.rate_review_outlined,
                  tall: true,
                  // A review carries the term from the student's grades.
                  onPressed:
                      took != null || reviewTerm(widget.courseId) != null
                          ? () => _write(null)
                          : () => ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Add ${widget.courseId} to your grades in the '
                                'semester you took it, then review it here.',
                              ),
                            ),
                          ),
                );
        return PageFrame(
          bottom: BottomAction(child: action),
          header: PageHeader(
            eyebrow: '${widget.courseId} · ${_campus.toUpperCase()}',
            title: title ?? widget.courseId,
            actions: [_resourcesButton()],
          ),
          children: [
            if (m.taughtBy.isNotEmpty) ...[
              const SectionLabel('Professor'),
              SelectRow(
                text:
                    sel == null
                        ? 'All professors'
                        : sel.$1.id == m.now
                        ? '${sel.$1.name} · now'
                        : sel.$1.name,
                onTap: () async {
                  final v = await pickSheet<String?>(
                    context,
                    title: 'Professor',
                    searchHint: 'Search a professor, even past ones',
                    selected: _prof,
                    options: [
                      (null, 'All professors'),
                      for (final x in m.taughtBy)
                        (
                          x.$1.id,
                          x.$1.id == m.now ? '${x.$1.name} · now' : x.$1.name,
                        ),
                    ],
                  );
                  if (v == null) return;
                  _set(() {
                    _prof = v.value;
                    _picked = true;
                  });
                },
              ),
              const SizedBox(height: Space.sm),
            ],
            SearchBox(
              controller: _q,
              hint: 'Search reviews',
              onChanged: (_) => _set(() {}),
            ),
            const SizedBox(height: Space.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _yearText,
                    label: 'Year',
                    hint: years.isEmpty ? '2023-24' : years.first,
                    dense: true,
                    error: _yearBad ? 'Use a year like 2023-24' : null,
                    onChanged: (_) => _set(() {}),
                  ),
                ),
                const SizedBox(width: Space.xs),
                Expanded(
                  child: SelectRow(
                    text: _sem == null ? 'Any semester' : semesterLabels[_sem]!,
                    placeholder: _sem == null,
                    onTap: () async {
                      final v = await pickSheet<String?>(
                        context,
                        title: 'Semester',
                        selected: _sem,
                        options: [
                          (null, 'Any semester'),
                          for (final e in semesterLabels.entries)
                            (e.key, e.value),
                        ],
                      );
                      if (v != null) _set(() => _sem = v.value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.sm),
            StatsCard(
              stats: ReviewFilter.statsOf(shown),
              summary: statsOf(shown),
              note:
                  filtered
                      ? [
                        yr ?? 'All years',
                        if (_sem != null) semesterLabels[_sem],
                        '${shown.length} of ${_reviews.length} reviews',
                      ].join(' · ')
                      : null,
            ),
            const SizedBox(height: Space.sm),
            SortPills(
              value: _order,
              onAll: () => _set(() => _order = null),
              onChanged: (o) => _set(() => _order = o),
            ),
            const SizedBox(height: Space.sm),
            for (final r in shown.take(_visible)) ...[
              ReviewTile(
                r: r,
                professor: _names[r.professorId],
                showGrade: true,
                onHelpful:
                    r.id == m.mine?.id
                        ? null
                        : () async {
                          final ok = await reviewStore!.vote(r);
                          if (ok) {
                            final i = _reviews.indexWhere((x) => x.id == r.id);
                            if (i != -1) {
                              setState(
                                () =>
                                    _reviews[i] = r.withHelpful(r.helpful + 1),
                              );
                            }
                          }
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
            if (_reviews.isNotEmpty && shown.isEmpty)
              const Note('No reviews match'),
            if (filtered && _reviews.isNotEmpty)
              TextButton(
                onPressed:
                    () => _set(() {
                      _q.clear();
                      _yearText.clear();
                      _sem = null;
                      _order = null;
                      _prof = null;
                      _picked = true;
                    }),
                child: const Text('Clear filters'),
              ),
            if (_reviews.isEmpty)
              const Note(
                'No reviews here yet. A course taught by someone new starts '
                'a fresh set.',
              ),
            if (shown.length > _visible)
              TextButton(
                onPressed: () => setState(() => _visible += 10),
                child: const Text('More reviews'),
              ),
          ],
        );
      },
    );
  }
}
