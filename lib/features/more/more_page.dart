import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/routes.dart';
import 'package:cgpa_calculator/features/more/representatives_page.dart';
import 'package:cgpa_calculator/features/resources/resources_page.dart';
import 'package:cgpa_calculator/features/reviews/reviews_home.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:flutter/material.dart';

/// Board `More`: the bottom bar's fifth item, holding what is not a grade
/// profile (§12). Representatives lives here, not as a destination.
class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) => PageFrame(
    header: const PageHeader(eyebrow: 'POINTER', title: 'More'),
    children: [
      RowGroup(
        children: [
          NavRow(
            icon: Icons.groups_outlined,
            title: 'Representatives',
            subtitle: 'Your department president and CRs',
            onTap:
                () => openRoute(
                  context,
                  Routes.representatives,
                  () => const RepresentativesPage(),
                ),
          ),
          NavRow(
            icon: Icons.rate_review_outlined,
            title: 'Course reviews',
            subtitle: 'Per professor, without names',
            onTap:
                () => openRoute(
                  context,
                  Routes.reviews,
                  () => const ReviewsHome(),
                ),
          ),
          NavRow(
            icon: Icons.link_rounded,
            title: 'Resources',
            subtitle: 'Links for your courses and department',
            onTap:
                () => openRoute(
                  context,
                  Routes.resources,
                  () => const ResourcesPage(),
                ),
          ),
        ],
      ),
    ],
  );
}
