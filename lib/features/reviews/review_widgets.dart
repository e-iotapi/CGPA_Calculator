import 'package:cgpa_calculator/admin/widgets.dart' show problem;
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
import 'package:cgpa_calculator/shared/widgets/pill_button.dart';
import 'package:cgpa_calculator/features/setup/campus_pick_page.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';

ReviewStore? get reviewStore => switch (roleStore) {
  final r? => ReviewStore(r.db, uid: myUid, roles: r),
  null => null,
};

/// The signed-in student's campus, from their address.
String? get myCampus => viewCampus();

// ---- Your reviews (§16.3 fix 4): course ids in the user's own data --------

const _myReviewsKey = 'myReviews';

Box? get _settings =>
    Hive.isBoxOpen('settingsBox') ? Hive.box('settingsBox') : null;

List<String> myReviewedCourses() => [
  for (final c in _settings?.get(_myReviewsKey) as List? ?? const []) '$c',
];

Future<void> rememberReview(String courseId) async {
  final s = _settings;
  if (s == null) return;
  final all = {...myReviewedCourses(), courseId};
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

/// The overall rating on the review form (board `ReviewWrite` §8.8): five
/// 48 × 48 buttons spread across the width, the chosen ones mint.
class StarPicker extends StatelessWidget {
  const StarPicker({super.key, required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 1; i <= 5; i++)
          Semantics(
            button: true,
            selected: i <= value,
            label: '$i of 5 stars',
            excludeSemantics: true,
            onTap: () => onChanged(i),
            child: Material(
              color: i <= value ? p.hero : p.background,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onChanged(i),
                child: SizedBox.square(
                  dimension: 48,
                  child: Icon(
                    i <= value ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 24,
                    color: i <= value ? p.onHero : p.textMuted,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The summary card (boards `ProfessorReviews`, `Reviews`): the average of
/// five with stars, how many would take it, and a mint bar of that share.
/// White, and the right column scales down rather than overflow (N27).
class StatsCard extends StatelessWidget {
  const StatsCard({super.key, required this.stats, this.note, this.label});
  final ReviewStats stats;
  final String? note;

  /// "CS F301 · GOA · 41 REVIEWS", above the number.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final avg = stats.average;
    final share = stats.recommendPercent;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[
            Text(
              label!.toUpperCase(),
              style: TypeScale.label.copyWith(color: p.textMuted),
            ),
            const SizedBox(height: 6),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                avg == null ? '—' : avg.toStringAsFixed(1),
                style: TypeScale.title.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.9,
                ),
              ),
              Text(
                ' / 5',
                style: TypeScale.caption.copyWith(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: p.textMuted,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Stars(value: (avg ?? 0).round(), size: 13),
              ),
              const Spacer(),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        share == null ? '—' : '$share%',
                        style: TypeScale.body.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'WOULD TAKE IT',
                        style: TypeScale.label.copyWith(
                          fontSize: 9,
                          letterSpacing: 0.3,
                          color: p.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: LinearProgressIndicator(
                value: (share ?? 0) / 100,
                backgroundColor: const Color(0xFF4A4A40),
                color: p.hero,
              ),
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: 8),
            Text(
              note!,
              style: TypeScale.caption.copyWith(
                fontSize: 10,
                color: p.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A 20 tall chip: the term, the professor, or (mint) the course.
class _Chip extends StatelessWidget {
  const _Chip(this.text, {this.ink = false});
  final String text;
  final bool ink;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: ink ? p.hero : p.surfaceSunken,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          text,
          style: TypeScale.label.copyWith(
            fontSize: 9.5,
            color: ink ? p.onHero : (p.isDark ? p.text : p.textMuted),
          ),
        ),
      ),
    );
  }
}

/// One review as students see it (board `Reviews` §8.7): stars and a TAKE IT
/// or SKIP IT tag, chips for the term and professor, the text, then a
/// "Helpful · n" chip and Report.
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
    final take = r.recommend;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Stars(value: r.stars, size: 14),
              const SizedBox(width: 6),
              Text(
                '${r.stars} of 5',
                style: TypeScale.caption.copyWith(color: p.textMuted),
              ),
              const Spacer(),
              Container(
                constraints: const BoxConstraints(minHeight: 22),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: take ? p.hero : p.surfaceSunken,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  take ? 'TAKE IT' : 'SKIP IT',
                  style: TypeScale.label.copyWith(
                    fontSize: 9.5,
                    color: take ? p.onHero : p.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (showCourse) _Chip(r.courseId, ink: true),
              _Chip(termLabel(r.term).toUpperCase()),
              if (professor != null) _Chip(professor!.toUpperCase()),
            ],
          ),
          if (r.text != null) ...[
            const SizedBox(height: 8),
            Text(
              r.text!,
              style: TypeScale.body.copyWith(
                fontSize: 12.5,
                height: 1.45,
                color: p.text,
              ),
            ),
          ],
          if (showCourse && onHelpful == null && r.helpful > 0) ...[
            const SizedBox(height: 6),
            Text(
              '${r.helpful} found it helpful',
              style: TypeScale.caption.copyWith(color: p.textMuted),
            ),
          ],
          if (r.edited) ...[
            const SizedBox(height: 4),
            Text(
              'edited',
              style: TypeScale.caption.copyWith(color: p.textMuted),
            ),
          ],
          if (onHelpful != null || onReport != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (onHelpful != null)
                  Material(
                    color: Colors.transparent,
                    shape: StadiumBorder(side: BorderSide(color: p.outline)),
                    child: InkWell(
                      onTap: onHelpful,
                      customBorder: const StadiumBorder(),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 26),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 2,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Helpful · ${r.helpful}',
                          style: TypeScale.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: p.text,
                          ),
                        ),
                      ),
                    ),
                  ),
                const Spacer(),
                if (onReport != null)
                  InkWell(
                    onTap: onReport,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: Text(
                        'Report',
                        style: TypeScale.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: p.textMuted,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (footer != null) footer!,
        ],
      ),
    );
  }
}

/// The sort row: four equal pills on the board, wrapping once text is large.
class SortPills extends StatelessWidget {
  const SortPills({super.key, required this.value, required this.onChanged});
  final ReviewOrder value;
  final ValueChanged<ReviewOrder> onChanged;

  @override
  Widget build(BuildContext context) {
    PillButton pill(ReviewOrder o, {double padding = 15}) => PillButton(
      label: o.label,
      height: 30,
      padding: padding,
      selected: value == o,
      onPressed: () => onChanged(o),
    );
    if (MediaQuery.textScalerOf(context).scale(10) > 13) {
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [for (final o in ReviewOrder.values) pill(o)],
      );
    }
    return Row(
      children: [
        for (final (i, o) in ReviewOrder.values.indexed) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(child: pill(o, padding: 4)),
        ],
      ],
    );
  }
}

/// A failed review action, said plainly.
void sayReview(BuildContext context, Object e) =>
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(e is String ? e : problem(e))));
