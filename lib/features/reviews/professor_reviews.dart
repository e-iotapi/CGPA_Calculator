import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/routes.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/catalog/catalog.dart';
import 'package:cgpa_calculator/core/professors/professor.dart';
import 'package:cgpa_calculator/core/professors/professor_store.dart';
import 'package:cgpa_calculator/core/reviews/review.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/core/models/offering.dart';
import 'package:cgpa_calculator/features/reviews/course_reviews.dart';
import 'package:cgpa_calculator/features/reviews/review_widgets.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:cgpa_calculator/features/setup/campus_pick_page.dart';
import 'package:flutter/material.dart';

typedef _Taught = ({String courseId, List<String> terms, ReviewStats stats});

/// One professor, reached from Reviews search: every course they are
/// recorded as teaching on the student's campus, with their reviews for
/// each. Merged duplicates count as the survivor (§10.1).
class ProfessorReviewsPage extends StatelessWidget {
  const ProfessorReviewsPage({super.key, required this.professorId});
  final String professorId;

  Future<(Professor?, List<_Taught>)> _load() async {
    final campus = myCampus!;
    final profs = ProfessorStore(roleStore!.db);
    final p = await profs.get(professorId);
    if (p == null) return (null, const <_Taught>[]);
    final taught = await profs.taught(p, campus);
    final out = <_Taught>[
      for (final e in taught.entries)
        (
          courseId: e.key,
          terms: e.value,
          stats: await reviewStore!.stats(
            e.key,
            campus,
            professorIds: p.allIds,
          ),
        ),
    ]..sort((a, b) => b.terms.first.compareTo(a.terms.first));
    return (p, out);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    if (roleStore == null || myCampus == null) {
      return PageFrame(
        header: const PageHeader(eyebrow: 'PROFESSOR', title: 'Reviews'),
        children: [
          if (roleStore != null)
            campusPrompt(context)
          else
            const Note('Sign in with your BITS account to read reviews.'),
        ],
      );
    }
    return Loaded<(Professor?, List<_Taught>)>(
      load: _load,
      builder: (context, data, _) {
        final (prof, taught) = data;
        final header = PageHeader(
          eyebrow:
              prof == null
                  ? 'PROFESSOR'
                  : '${departments[prof.department]?.name ?? prof.department} · '
                          '${campusName(prof.campus)}'
                      .toUpperCase(),
          title: prof?.name ?? 'Not found',
        );
        final all = taught.fold(const ReviewStats(), (s, t) => s + t.stats);
        return PageFrame(
          header: header,
          children: [
            if (prof != null) ...[
              StatsCard(
                stats: all,
                note:
                    all.count == 0
                        ? null
                        : 'Across ${taught.length} '
                            'course${taught.length == 1 ? '' : 's'}, '
                            '${all.count} review${all.count == 1 ? '' : 's'}.',
              ),
              const SectionLabel('Courses taught'),
              if (taught.isEmpty)
                const Note(
                  'No course on this campus records them yet. The course '
                  'CR or department adds who teaches each term.',
                )
              else
                AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Column(
                    children: [
                      for (final (i, t) in taught.indexed) ...[
                        if (i > 0) Divider(height: 1, color: p.divider),
                        _CourseRow(
                          title:
                              '${t.courseId} · '
                              '${catalog.master.where((m) => m.id == t.courseId).firstOrNull?.title ?? ''}',
                          subtitle:
                              '${[for (final x in t.terms.take(3)) termLabel(x)].join(', ')}'
                              '${t.terms.length > 3 ? ' and ${t.terms.length - 3} more' : ''}'
                              ' · ${t.stats.count} review${t.stats.count == 1 ? '' : 's'}',
                          onTap:
                              () => openRoute(
                                context,
                                Routes.courseReviews(
                                  t.courseId,
                                  professor: prof.id,
                                ),
                                () => CourseReviewsPage(
                                  courseId: t.courseId,
                                  professorId: prof.id,
                                ),
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: Space.sm),
              Text(
                'Each course opens filtered to ${prof.name}.',
                style: TypeScale.caption.copyWith(color: p.textMuted),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// A 64 px row: the course on one line over its terms and review count.
class _CourseRow extends StatelessWidget {
  const _CourseRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final String title, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return InkWell(
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
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TypeScale.body.copyWith(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TypeScale.caption.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: p.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: p.icon),
          ],
        ),
      ),
    );
  }
}
