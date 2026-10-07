import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/routes.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/catalog/catalog.dart';
import 'package:cgpa_calculator/features/contribute/add_page.dart';
import 'package:cgpa_calculator/core/prefs/prefs_store.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/search/hints.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/features/resources/resource_course_page.dart';
import 'package:cgpa_calculator/features/resources/resources_page.dart';
import 'package:cgpa_calculator/features/setup/campus_pick_page.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/bottom_action.dart';
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
  final _learner = QueryLearner();

  /// 'now' (this semester), 'starred' or 'all'.
  var _show = 'now';

  @override
  void dispose() {
    _learner.dispose();
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
    final q = _search.text.trim();
    final now = takingNow(), starred = starredCourses();
    // Every catalogue course plus the student's own (a manual add may not be
    // charted). A search covers them all; the pills only shape the empty box.
    final titles = {for (final m in catalog.master) m.id: m.title};
    for (final id in now) {
      titles.putIfAbsent(id, () => courseTitle(id));
    }
    // A search widens with synonyms and what students taught it.
    final courses =
        q.isNotEmpty
            ? (widen(
                q,
                // The typed query's own matches first.
                (ph) => [
                  for (final e in titles.entries)
                    if (textMatches(ph, '${e.key} ${e.value}'))
                      e.key,
                ]..sort(),
                (id) => id,
              ))
            : ([
              for (final e in titles.entries)
                if (switch (_show) {
                  'all' => true,
                  'starred' => starred.contains(e.key),
                  _ => now.contains(e.key),
                })
                  e.key,
            ]..sort());
    if (q.isNotEmpty) _learner.typed(q, found: courses.isNotEmpty);
    return PageFrame(
      header: header,
      bottom:
          linkDepts(campus).isEmpty
              ? null
              : BottomAction(
                child: PrimaryButton(
                  label: 'Add a link',
                  icon: Icons.add_rounded,
                  onPressed:
                      () => openRoute(
                        context,
                        Routes.contributeAddCourse,
                        () => const AddPage(course: true),
                      ),
                ),
              ),
      children: [
        SearchBox(
          controller: _search,
          hint: 'Search a course',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: Space.sm),
        SegmentedPair<String>(
          a: ('now', 'This semester'),
          b: ('starred', 'Starred'),
          c: ('all', 'All'),
          value: _show,
          onChanged: (v) => setState(() => _show = v),
        ),
        const SizedBox(height: Space.sm),
        if (courses.isEmpty)
          Note(
            q.isNotEmpty
                ? 'No course code or name matches “${_search.text.trim()}”.'
                : _show == 'starred'
                ? 'No starred courses yet. Tap the star on any course to keep '
                    'it here.'
                : 'Nothing for your courses this semester. Tap All, or search '
                    'for any course.',
          )
        else
          SliverRowGroup(
            count: courses.length,
            row:
                (context, i) => InkWell(
                  onTap: () {
                    _learner.picked(q);
                    openRoute(
                      context,
                      Routes.resourceCourse(courses[i]),
                      () => ResourceCoursePage(courseId: courses[i]),
                    );
                  },
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 52),
                    padding: const EdgeInsets.only(left: 15, right: 8),
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
                        IconButton(
                          tooltip:
                              starred.contains(courses[i]) ? 'Unstar' : 'Star',
                          onPressed:
                              () => setState(() => toggleStar(courses[i])),
                          icon: Icon(
                            starred.contains(courses[i])
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            size: 20,
                            color:
                                starred.contains(courses[i])
                                    ? p.text
                                    : p.textMuted,
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
