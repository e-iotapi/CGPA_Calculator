import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/models/offering.dart';
import 'package:cgpa_calculator/core/reviews/review.dart';
import 'package:cgpa_calculator/core/reviews/review_store.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/core/storage/courses.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/marks/official.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

ReviewStore? get reviewStore => switch (roleStore) {
  final r? => ReviewStore(r.db, uid: myUid, roles: r),
  null => null,
};

/// The signed-in student's campus, from their address.
String? get myCampus => campusOfAddress(roleStore?.me ?? '');

// ---- Your reviews (§16.3 fix 4): course ids in the user's own data --------

const _myReviewsKey = 'myReviews';

Box? get _settings =>
    Hive.isBoxOpen('settingsBox') ? Hive.box('settingsBox') : null;

List<String> myReviewedCourses() => [
  for (final c in _settings?.get(_myReviewsKey) as List? ?? const []) '$c',
];

Future<void> rememberReview(String courseId, {bool remove = false}) async {
  final s = _settings;
  if (s == null) return;
  final all = {...myReviewedCourses()};
  remove ? all.remove(courseId) : all.add(courseId);
  await s.put(_myReviewsKey, all.toList()..sort());
}

/// The course as the student took it: their row and its term, when the
/// term has begun (fix 5: taking a course is self-declared).
({Course course, String term})? tookIt(String courseId) {
  final batch = batchOfAddress(roleStore?.me ?? '');
  if (batch == null) return null;
  for (final c in allCourses()) {
    if (c.id != courseId) continue;
    final term = termOf(batch % 100, c.sem);
    if (term != null && term.compareTo(currentTerm(DateTime.now())) <= 0) {
      return (course: c, term: term);
    }
  }
  return null;
}

/// Five stars, tappable when [onChanged] is set.
class Stars extends StatelessWidget {
  const Stars({super.key, required this.value, this.onChanged, this.size = 16});
  final int value;
  final ValueChanged<int>? onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Semantics(
      label: '$value of 5 stars',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            GestureDetector(
              onTap: onChanged == null ? null : () => onChanged!(i),
              child: Padding(
                padding: EdgeInsets.all(onChanged == null ? 0 : 4),
                child: Icon(
                  i <= value ? Icons.star_rounded : Icons.star_border_rounded,
                  size: size,
                  color: i <= value ? p.accent : p.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The big number: average of five and how many would take it again.
class StatsCard extends StatelessWidget {
  const StatsCard({super.key, required this.stats, this.note});
  final ReviewStats stats;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final avg = stats.average;
    return AppCard(
      color: p.inverse,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                avg == null ? '—' : avg.toStringAsFixed(1),
                style: TypeScale.title.copyWith(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: p.onInverse,
                ),
              ),
              Text(' / 5', style: TextStyle(color: p.onInverse)),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    stats.recommendPercent == null
                        ? '—'
                        : '${stats.recommendPercent}%',
                    style: TypeScale.title.copyWith(
                      fontWeight: FontWeight.w800,
                      color: p.onInverse,
                    ),
                  ),
                  Text(
                    'WOULD TAKE IT',
                    style: TypeScale.label.copyWith(
                      color: p.onInverse.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (note != null)
            Text(
              note!,
              style: TypeScale.caption.copyWith(
                color: p.onInverse.withValues(alpha: 0.7),
              ),
            ),
        ],
      ),
    );
  }
}

/// One review as students see it: take it or skip it, the term, the
/// professor, the text, Helpful and Report.
class ReviewTile extends StatelessWidget {
  const ReviewTile({
    super.key,
    required this.r,
    this.professor,
    this.onHelpful,
    this.onReport,
    this.onTap,
    this.showCourse = false,
    this.footer,
  });

  final Review r;
  final String? professor;
  final VoidCallback? onHelpful, onReport, onTap;
  final bool showCourse;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final muted = TypeScale.caption.copyWith(color: p.textMuted);
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TierTag(r.recommend ? 'TAKE IT' : 'SKIP IT', strong: r.recommend),
              if (showCourse)
                Text(
                  r.courseId,
                  style: TypeScale.label.copyWith(fontWeight: FontWeight.w700),
                ),
              Text(termLabel(r.term).toUpperCase(), style: muted),
              if (professor != null)
                Text(professor!.toUpperCase(), style: muted),
              Stars(value: r.stars, size: 14),
            ],
          ),
          if (r.text != null) ...[
            const SizedBox(height: Space.xs),
            Text(r.text!, style: TypeScale.body.copyWith(height: 1.4)),
          ],
          const SizedBox(height: Space.xs),
          Row(
            children: [
              Expanded(
                child: Text(
                  [
                    if (r.helpful > 0) '${r.helpful} found it helpful',
                    if (r.edited) 'edited',
                  ].join(' · '),
                  style: muted,
                ),
              ),
              if (onHelpful != null)
                TextButton(
                  onPressed: onHelpful,
                  child: Text('Helpful ${r.helpful}'),
                ),
              if (onReport != null)
                TextButton(onPressed: onReport, child: const Text('Report')),
            ],
          ),
          if (footer != null) footer!,
        ],
      ),
    );
  }
}

/// A failed review action, said plainly.
void sayReview(BuildContext context, Object e) =>
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(e is String ? e : problem(e))));
