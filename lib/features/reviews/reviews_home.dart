import 'dart:async';

import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/routes.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/catalog/catalog.dart';
import 'package:cgpa_calculator/core/search/hints.dart';
import 'package:cgpa_calculator/core/professors/professor.dart';
import 'package:cgpa_calculator/core/professors/professor_store.dart';
import 'package:cgpa_calculator/core/reviews/gate.dart';
import 'package:cgpa_calculator/core/reviews/review.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/core/storage/courses.dart';
import 'package:cgpa_calculator/script.dart' show selecteddiscipline;
import 'package:cgpa_calculator/features/resources/resources_page.dart';
import 'package:cgpa_calculator/features/reviews/course_reviews.dart';
import 'package:cgpa_calculator/features/reviews/gate_ui.dart';
import 'package:cgpa_calculator/features/reviews/mine_filter.dart';
import 'package:cgpa_calculator/features/reviews/pick_sheet.dart';
import 'package:cgpa_calculator/features/reviews/professor_reviews.dart';
import 'package:cgpa_calculator/features/reviews/review_form.dart';
import 'package:cgpa_calculator/features/reviews/review_widgets.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/bottom_action.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:cgpa_calculator/shared/widgets/pill_button.dart';
import 'package:cgpa_calculator/shared/widgets/search_box.dart';
import 'package:cgpa_calculator/shared/widgets/segmented.dart';
import 'package:cgpa_calculator/features/setup/campus_pick_page.dart';
import 'package:flutter/material.dart';

String _line(ReviewStats s) =>
    s.count == 0
        ? 'No reviews yet'
        : '${s.recommendPercent}% take it · ${s.count} review'
            '${s.count == 1 ? '' : 's'}';

/// Boards `ReviewsSearch` and `YourReviews`: any course by code or name,
/// your courses this semester, the campus's most reviewed, and your own.
class ReviewsHome extends StatefulWidget {
  const ReviewsHome({super.key, this.yours = false});
  final bool yours;

  @override
  State<ReviewsHome> createState() => _ReviewsHomeState();
}

class _ReviewsHomeState extends State<ReviewsHome> {
  late bool _yours = widget.yours;
  final _search = TextEditingController();
  final _learner = QueryLearner();
  final _mine = TextEditingController();
  Timer? _debounce;
  Future<List<Professor>>? _profs;
  ReviewOrder _order = ReviewOrder.recent;
  MineFilter _filter = MineFilter.all;
  int _loads = 0;

  @override
  void initState() {
    super.initState();
    // The saved gate draws the first frame; a changed one lands behind it.
    if (myCampus case final c?) {
      refreshGate(c).then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _learner.dispose();
    _debounce?.cancel();
    _search.dispose();
    _mine.dispose();
    super.dispose();
  }

  void _searchChanged(String campus) {
    setState(() {});
    _debounce?.cancel();
    final q = _search.text.trim();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final next =
          q.length < 2 ? null : ProfessorStore(roleStore!.db).search(campus, q);
      setState(() {
        _profs = next;
      });
    });
  }

  Future<void> _open(String id) async {
    await openRoute(
      context,
      Routes.courseReviews(id),
      () => CourseReviewsPage(courseId: id),
    );
    setState(() => _loads++);
  }

  /// Pick one of the courses the student took, then its review form (an
  /// existing review of it opens from its course page instead).
  Future<void> _writeAny() async {
    final done = myReviewedCourses().toSet();
    final took =
        {
            for (final c in allCourses())
              if (!done.contains(c.id) && tookIt(c.id) != null) c.id,
          }.toList()
          ..sort();
    if (took.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add the courses you took to your grades first, or you have '
            'reviewed them all.',
          ),
        ),
      );
      return;
    }
    final v = await pickSheet<String>(
      context,
      title: 'Which course?',
      searchHint: 'Search your courses',
      options: [for (final id in took) (id, '$id · ${courseTitle(id)}')],
    );
    if (v == null || !mounted) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ReviewFormPage(courseId: v.value)),
    );
    if (saved == true) setState(() => _loads++);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final store = reviewStore;
    final campus = myCampus;
    final header = PageHeader(
      eyebrow:
          campus == null ? 'COURSE REVIEWS' : campusName(campus).toUpperCase(),
      title: 'Course reviews',
    );
    if (store == null || campus == null) {
      return PageFrame(
        header: header,
        children: [
          if (campus == null && store != null)
            campusPrompt(context)
          else
            const Note('Sign in with your BITS account to read reviews.'),
        ],
      );
    }
    final mineCount = myReviewedCourses().length;
    final tabs = SegmentedTrack<bool>(
      tabs: [(false, 'Courses'), (true, 'Your reviews · $mineCount')],
      value: _yours,
      onChanged: (v) => setState(() => _yours = v),
    );
    if (_yours) {
      return Loaded<List<Review>>(
        key: ValueKey('mine$_loads'),
        cacheKey: 'reviews-mine|${myReviewedCourses().join(',')}',
        load:
            () async => [
              for (final id in myReviewedCourses())
                if (await store.mine(id) case final r?) r,
            ],
        peek: () {
          final out = <Review>[];
          for (final id in myReviewedCourses()) {
            final r = store.peekMine(id);
            if (r == null) return null;
            out.add(r);
          }
          return out;
        },
        builder: (context, mine, _) {
          final mq = _mine.text.trim();
          final phrases = queryPhrases(mq);
          final shown = filterMine(
            mine,
            _filter,
            taking: takingNow(),
            electives: electiveIds(allCourses(), selecteddiscipline),
          );
          final sorted = [
            for (final r in shown)
              if (mq.isEmpty ||
                  phrases.any(
                    (ph) => textMatches(
                      ph,
                      '${r.courseId} ${courseTitle(r.courseId)} ${r.text ?? ''}',
                    ),
                  ))
                r,
          ]..sort(
            (a, b) => switch (_order) {
              ReviewOrder.recent => b.createdAt - a.createdAt,
              ReviewOrder.helpful => b.helpful - a.helpful,
              ReviewOrder.highest => b.stars - a.stars,
              ReviewOrder.lowest => a.stars - b.stars,
            },
          );
          return PageFrame(
            header: header,
            children: [
              tabs,
              const SizedBox(height: Space.sm),
              SearchBox(
                controller: _mine,
                hint: 'Search your reviews',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: Space.sm),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final f in MineFilter.values)
                    PillButton(
                      label: f.label,
                      height: 30,
                      selected: _filter == f,
                      onPressed: () => setState(() => _filter = f),
                    ),
                ],
              ),
              const SizedBox(height: Space.sm),
              SortPills(
                value: _order,
                onChanged: (o) => setState(() => _order = o),
              ),
              const SizedBox(height: Space.sm),
              for (final r in sorted) ...[
                ReviewTile(
                  r: r,
                  showCourse: true,
                  onTap: () async {
                    final saved = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder:
                            (_) => ReviewFormPage(
                              courseId: r.courseId,
                              existing: r,
                            ),
                      ),
                    );
                    if (saved == true) setState(() => _loads++);
                  },
                  footer:
                      r.hidden
                          ? Text(
                            'Hidden by a moderator: ${r.reason ?? ''}',
                            style: TypeScale.caption.copyWith(color: p.behind),
                          )
                          : null,
                ),
                const SizedBox(height: Space.xs),
              ],
              if (sorted.isEmpty)
                Note(
                  mine.isEmpty
                      ? 'You have not reviewed anything yet. Open a course '
                          'you took to add one.'
                      : 'No reviews here',
                ),
            ],
          );
        },
      );
    }

    // Board ReviewsLocked: no search, no course rows, only the way out.
    if (myGate(campus) == GateState.locked) {
      return PageFrame(
        header: header,
        children: [
          tabs,
          const SizedBox(height: Space.sm),
          LockedReviews(onBack: () => setState(() => _loads++)),
        ],
      );
    }
    final q = _search.text.trim();
    final found =
        q.length < 2
            ? const []
            : widen(
              q,
              (ph) => catalog.master.where(
                (m) => textMatches(ph, '${m.id} ${m.title}'),
              ),
              (m) => m.id,
            ).take(20).toList();
    if (q.length >= 2) _learner.typed(q, found: found.isNotEmpty);
    final now = takingNow().toList()..sort();
    return Loaded<
      ({
        List<ReviewStats> now,
        List<({String courseId, ReviewStats stats})> top,
      })
    >(
      key: ValueKey('courses$_loads'),
      // A reopen shows the last numbers at once and refreshes behind them.
      cacheKey: 'reviews-courses|$campus|${now.join(',')}',
      load:
          () async => (
            now: [for (final id in now) await store.stats(id, campus)],
            top: await store.mostReviewed(campus),
          ),
      peek: () {
        final stats = <ReviewStats>[];
        for (final id in now) {
          final s = store.peekStats(id, campus);
          if (s == null) return null;
          stats.add(s);
        }
        final top = store.peekMostReviewed(campus);
        return top == null ? null : (now: stats, top: top);
      },
      builder:
          (context, data, _) => PageFrame(
            header: header,
            bottom: BottomAction(
              child: PrimaryButton(
                label: 'Write a review',
                icon: Icons.rate_review_outlined,
                tall: true,
                onPressed: _writeAny,
              ),
            ),
            children: [
              tabs,
              const SizedBox(height: Space.sm),
              SearchBox(
                controller: _search,
                hint: 'Course or professor',
                onChanged: (_) => _searchChanged(campus),
              ),
              const SizedBox(height: Space.sm),
              if (q.length >= 2 && _profs != null)
                FutureBuilder<List<Professor>>(
                  future: _profs,
                  builder: (context, s) {
                    final profs = s.data ?? const <Professor>[];
                    if (profs.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SectionLabel('Professors'),
                        RowGroup(
                          children: [
                            for (final pr in profs)
                              NavRow(
                                icon: Icons.person_outline,
                                title: pr.name,
                                subtitle:
                                    departments[pr.department]?.name ??
                                    pr.department,
                                onTap:
                                    () => openRoute(
                                      context,
                                      Routes.professorReviews(pr.id),
                                      () => ProfessorReviewsPage(
                                        professorId: pr.id,
                                      ),
                                    ),
                              ),
                          ],
                        ),
                        const SizedBox(height: Space.sm),
                      ],
                    );
                  },
                ),
              if (found.isNotEmpty) ...[
                const SectionLabel('Courses'),
                RowGroup(
                  children: [
                    for (final m in found)
                      NavRow(
                        icon: Icons.menu_book_outlined,
                        title: '${m.id} · ${m.title}',
                        onTap: () {
                          _learner.picked(q);
                          _open(m.id);
                        },
                      ),
                  ],
                ),
              ] else if (q.length >= 2) ...[
                const SectionLabel('Courses'),
                AppCard(
                  child: Text(
                    'No course code or name matches “${_search.text.trim()}”.',
                    style: TypeScale.body.copyWith(fontSize: 12.5),
                  ),
                ),
              ] else ...[
                if (now.isNotEmpty) ...[
                  const SectionLabel('Your courses this semester'),
                  _Rows([
                    for (final (i, id) in now.indexed)
                      (id, data.now[i], () => _open(id)),
                  ]),
                ],
                if (data.top.isNotEmpty) ...[
                  SectionLabel('Most reviewed at ${campusName(campus)}'),
                  _Rows([
                    for (final t in data.top)
                      (t.courseId, t.stats, () => _open(t.courseId)),
                  ]),
                ],
              ],
              const SizedBox(height: Space.sm),
              Text(
                q.length >= 2
                    ? 'One box for both. Any word of a name finds a professor, '
                        'and their old names too after a merge.'
                    : 'Reviews are written per professor and per semester, so '
                        'a course taught by someone new starts a fresh set '
                        'rather than inheriting an old reputation.',
                style: TypeScale.caption.copyWith(
                  height: 1.45,
                  color: p.textMuted,
                ),
              ),
            ],
          ),
    );
  }
}

/// Board rows (§8.4): one-line title, small stars and the take-it line, a
/// chevron; no leading icon.
class _Rows extends StatelessWidget {
  const _Rows(this.rows);
  final List<(String, ReviewStats, VoidCallback)> rows;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Column(
        children: [
          for (final (i, (id, st, onTap)) in rows.indexed) ...[
            if (i > 0) Divider(height: 1, color: p.divider),
            InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 64),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$id · ${courseTitle(id)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TypeScale.body.copyWith(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              if (st.count > 0) ...[
                                Stars(
                                  value: (st.average ?? 0).round(),
                                  size: 11,
                                ),
                                const SizedBox(width: 6),
                              ],
                              Flexible(
                                child: Text(
                                  _line(st),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TypeScale.caption.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: p.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 18, color: p.icon),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
