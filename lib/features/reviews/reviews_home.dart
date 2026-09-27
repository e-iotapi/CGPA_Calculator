import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/routes.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/catalog/catalog.dart';
import 'package:cgpa_calculator/core/reviews/review.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/features/resources/resources_page.dart';
import 'package:cgpa_calculator/features/reviews/course_reviews.dart';
import 'package:cgpa_calculator/features/reviews/review_form.dart';
import 'package:cgpa_calculator/features/reviews/review_widgets.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:flutter/material.dart';

String _title(String id) =>
    catalog.master.where((m) => m.id == id).firstOrNull?.title ?? '';

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
  ReviewOrder _order = ReviewOrder.recent;
  int _loads = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _open(String id) async {
    await openRoute(
      context,
      Routes.courseReviews(id),
      () => CourseReviewsPage(courseId: id),
    );
    setState(() => _loads++);
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
        children: const [
          Note('Sign in with your BITS account to read reviews.'),
        ],
      );
    }
    final mineCount = myReviewedCourses().length;
    final tabs = ChoicePills<bool>(
      values: const [false, true],
      selected: _yours,
      label: (v) => v ? 'Your reviews · $mineCount' : 'Courses',
      onSelected: (v) => setState(() => _yours = v),
    );
    if (_yours) {
      return Loaded<List<Review>>(
        key: ValueKey('mine$_loads'),
        load:
            () async => [
              for (final id in myReviewedCourses())
                if (await store.mine(id) case final r?) r,
            ],
        builder: (context, mine, _) {
          final sorted = [...mine]..sort(
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
              ChoicePills<ReviewOrder>(
                values: ReviewOrder.values,
                selected: _order,
                label: (o) => o.label,
                onSelected: (o) => setState(() => _order = o),
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
                const Note(
                  'You have not reviewed anything yet. Open a course you took '
                  'to add one.',
                ),
            ],
          );
        },
      );
    }

    final q = _search.text.trim().toLowerCase();
    final found =
        q.length < 2
            ? const []
            : catalog.master
                .where(
                  (m) =>
                      m.id.toLowerCase().contains(q) ||
                      m.title.toLowerCase().contains(q),
                )
                .take(20)
                .toList();
    final now = takingNow().toList()..sort();
    return Loaded<
      ({
        List<ReviewStats> now,
        List<({String courseId, ReviewStats stats})> top,
      })
    >(
      key: ValueKey('courses$_loads'),
      load:
          () async => (
            now: [for (final id in now) await store.stats(id, campus)],
            top: await store.mostReviewed(campus),
          ),
      builder:
          (context, data, _) => PageFrame(
            header: header,
            children: [
              tabs,
              const SizedBox(height: Space.sm),
              AppTextField(
                controller: _search,
                label: 'Course code or name',
                dense: true,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: Space.sm),
              if (found.isNotEmpty)
                RowGroup(
                  children: [
                    for (final m in found)
                      NavRow(
                        icon: Icons.menu_book_outlined,
                        title: '${m.id} · ${m.title}',
                        onTap: () => _open(m.id),
                      ),
                  ],
                )
              else ...[
                if (now.isNotEmpty) ...[
                  const SectionLabel('Your courses this semester'),
                  RowGroup(
                    children: [
                      for (final (i, id) in now.indexed)
                        NavRow(
                          icon: Icons.menu_book_outlined,
                          title: '$id · ${_title(id)}',
                          subtitle: _line(data.now[i]),
                          onTap: () => _open(id),
                        ),
                    ],
                  ),
                ],
                if (data.top.isNotEmpty) ...[
                  SectionLabel('Most reviewed at ${campusName(campus)}'),
                  RowGroup(
                    children: [
                      for (final t in data.top)
                        NavRow(
                          icon: Icons.trending_up_rounded,
                          title: '${t.courseId} · ${_title(t.courseId)}',
                          subtitle: _line(t.stats),
                          onTap: () => _open(t.courseId),
                        ),
                    ],
                  ),
                ],
              ],
              const SizedBox(height: Space.sm),
              Text(
                'Reviews are written per professor and per semester, so a course '
                'taught by someone new starts a fresh set rather than inheriting '
                'an old reputation.',
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
