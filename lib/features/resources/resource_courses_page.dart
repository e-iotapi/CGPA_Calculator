import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/routes.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/catalog/catalog.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/features/resources/resource_course_page.dart';
import 'package:cgpa_calculator/features/resources/resources_page.dart';
import 'package:cgpa_calculator/features/setup/campus_pick_page.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:cgpa_calculator/shared/widgets/search_box.dart';
import 'package:cgpa_calculator/shared/widgets/segmented.dart';
import 'package:cgpa_calculator/shared/widgets/sliver_row_group.dart';
import 'package:flutter/material.dart';

/// Board `ResourceCourses`: any course by code or name (no degree barrier),
/// or with the box empty this semester's courses, or All.
class ResourceCoursesPage extends StatefulWidget {
  const ResourceCoursesPage({super.key});

  @override
  State<ResourceCoursesPage> createState() => _ResourceCoursesPageState();
}

class _ResourceCoursesPageState extends State<ResourceCoursesPage> {
  final _search = TextEditingController();
  bool _all = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final campus = viewCampus();
    final header = PageHeader(
      eyebrow: campus == null ? 'Resources' : campusName(campus).toUpperCase(),
      title: 'Course resources',
    );
    if (roleStore == null || campus == null) {
      return PageFrame(
        header: header,
        children: [
          if (roleStore == null)
            const Note('Sign in with your BITS account to see resources.')
          else
            campusPrompt(context),
        ],
      );
    }
    final q = _search.text.trim().toLowerCase();
    final now = takingNow();
    // Every catalogue course plus the student's own (a manual add may not be
    // charted). A search covers them all; the pills only shape the empty box.
    final titles = {for (final m in catalog.master) m.id: m.title};
    for (final id in now) {
      titles.putIfAbsent(id, () => courseTitle(id));
    }
    final courses = [
      for (final e in titles.entries)
        if (q.isNotEmpty
            ? e.key.toLowerCase().contains(q) ||
                e.value.toLowerCase().contains(q)
            : _all || now.contains(e.key))
          e.key,
    ]..sort();
    return PageFrame(
      header: header,
      children: [
        SearchBox(
          controller: _search,
          hint: 'Search a course',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: Space.sm),
        SegmentedPair<bool>(
          a: (false, 'This semester'),
          b: (true, 'All'),
          value: _all,
          onChanged: (v) => setState(() => _all = v),
        ),
        const SizedBox(height: Space.sm),
        if (courses.isEmpty)
          Note(
            q.isNotEmpty
                ? 'No course code or name matches “${_search.text.trim()}”.'
                : 'Nothing for your courses this semester. Tap All, or search '
                    'for any course.',
          )
        else
          SliverRowGroup(
            count: courses.length,
            row:
                (context, i) => InkWell(
                  onTap:
                      () => openRoute(
                        context,
                        Routes.resourceCourse(courses[i]),
                        () => ResourceCoursePage(courseId: courses[i]),
                      ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 52),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${courses[i]} · ${titles[courses[i]]}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TypeScale.body.copyWith(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right, size: 18, color: p.icon),
                      ],
                    ),
                  ),
                ),
          ),
      ],
    );
  }
}
