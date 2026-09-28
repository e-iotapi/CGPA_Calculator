import 'package:cgpa_calculator/app/routes.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/models/offering.dart';
import 'package:cgpa_calculator/features/marks/official.dart';
import 'package:cgpa_calculator/features/more/representatives_page.dart';
import 'package:cgpa_calculator/features/resources/resources_page.dart';
import 'package:cgpa_calculator/features/reviews/reviews_home.dart';
import 'package:cgpa_calculator/script.dart' as app;
import 'package:cgpa_calculator/shared/widgets/circle_icon_button.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:flutter/material.dart';

/// "GOA · B3 A7 · 2026-27 SEM 1": campus, degrees and the running term.
String moreEyebrow({DateTime? now}) =>
    [
      if (app.campus case final c?) c.label,
      [
        app.selecteddiscipline.substring(0, 2),
        app.selecteddiscipline.substring(2),
      ].where((h) => h != '--' && h != 'B-').join(' '),
      termLabel(currentTerm(now ?? DateTime.now())),
    ].where((s) => s.isNotEmpty).join(' · ').toUpperCase();

/// Board `More`: the bottom bar's fifth item, holding what is not a grade
/// profile (§12). Representatives lives here, not as a destination.
class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final campus = app.campus?.label;
    return PageFrame(
      header: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  moreEyebrow(),
                  style: TypeScale.label.copyWith(color: p.textMuted),
                ),
                const SizedBox(height: 3),
                Semantics(
                  header: true,
                  child: Text(
                    'More',
                    style: TypeScale.title.copyWith(
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                      color: p.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (Navigator.of(context).canPop())
            CircleIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Back',
              size: 44,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
        ],
      ),
      children: [
        _MoreCard(
          icon: Icons.groups_outlined,
          title: 'Representatives',
          subtitle: 'Your department president and the CR for each course',
          onTap:
              () => openRoute(
                context,
                Routes.representatives,
                () => const RepresentativesPage(),
              ),
        ),
        const SizedBox(height: 9),
        _MoreCard(
          icon: Icons.rate_review_outlined,
          title: 'Course reviews',
          subtitle: 'Search any course, filter by the professor teaching it',
          onTap:
              () =>
                  openRoute(context, Routes.reviews, () => const ReviewsHome()),
        ),
        const SizedBox(height: 9),
        _MoreCard(
          icon: Icons.link_rounded,
          title: 'Resources',
          subtitle: 'Drive links, notes and papers, by degree',
          onTap:
              () => openRoute(
                context,
                Routes.resources,
                () => const ResourcesPage(),
              ),
        ),
        if (campus != null) ...[
          const SizedBox(height: 13),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Everything here is for '),
                TextSpan(
                  text: campus,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const TextSpan(
                  text:
                      ' only. Reviews, resources and representatives differ '
                      'per campus because the teaching does.',
                ),
              ],
            ),
            style: TypeScale.caption.copyWith(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              height: 1.45,
              color: p.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}

class _MoreCard extends StatelessWidget {
  const _MoreCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 76),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: p.hero,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, size: 21, color: p.onHero),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TypeScale.body.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: p.text,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TypeScale.caption.copyWith(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                          color: p.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: p.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
