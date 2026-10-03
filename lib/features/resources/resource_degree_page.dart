import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/routes.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/models/programmes.dart';
import 'package:cgpa_calculator/core/resources/resource.dart';
import 'package:cgpa_calculator/core/roles/capabilities.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/features/resources/resources_page.dart';
import 'package:cgpa_calculator/features/setup/campus_pick_page.dart';
import 'package:cgpa_calculator/script.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/bottom_action.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Board `ResourceDegree`: one degree's department and this semester's course
/// links, the body the Resources page had before it became a hub.
class ResourceDegreePage extends StatelessWidget {
  const ResourceDegreePage({
    super.key,
    required this.code,
    this.onRepresentatives,
  });
  final String code;
  final VoidCallback? onRepresentatives;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final campus = viewCampus();
    final dual = programmesOf(selecteddiscipline).length > 1;
    final now = takingNow();
    return Loaded<List<ResourceDegreeData>>(
      cacheKey: degreesKey(campus),
      load: loadDegrees,
      peek: peekDegrees,
      builder: (context, all, reload) {
        final degrees = [
          for (final d in all)
            if (d.code == code) d,
        ];
        final keep = [
          for (final d in degrees)
            if (campus != null &&
                myRoles.value.may(
                  Capability.departmentResources,
                  campus: campus,
                  scope: d.dept,
                ))
              d.dept,
        ];
        return PageFrame(
          header: PageHeader(
            eyebrow: resourcesEyebrow(campus, dual: dual),
            title: 'Resources',
          ),
          bottom:
              keep.isEmpty
                  ? null
                  : BottomAction(
                    child: PrimaryButton(
                      label: 'Add a link',
                      icon: Icons.add_rounded,
                      onPressed:
                          () => GoRouter.maybeOf(
                            context,
                          )?.push(Routes.deptResources(campus!, keep.first)),
                    ),
                  ),
          children: [
            if (roleStore == null)
              const Note('Sign in with your BITS account to see resources.')
            else if (campus == null)
              campusPrompt(context),
            for (final d in degrees) ...[
              Row(
                children: [
                  _CodeTile(
                    d.code,
                    second:
                        programmesOf(selecteddiscipline).indexOf(d.code) > 0,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      programmeName(d.code),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TypeScale.body.copyWith(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              if (d.links.isEmpty)
                ResourcesEmpty(onRepresentatives: onRepresentatives)
              else
                _degree(context, d, now, p),
            ],
            if (degrees.any((d) => d.links.any((r) => r.rolledUp))) ...[
              const SizedBox(height: 11),
              Text(
                'A course link tagged FROM is also listed under its '
                'department, so everyone in the degree finds it.',
                style: TypeScale.caption.copyWith(
                  height: 1.45,
                  color: p.textMuted,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _degree(
    BuildContext context,
    ResourceDegreeData d,
    Set<String> now,
    AppPalette p,
  ) {
    final dept = departmentList(d.links);
    final courseLinks = [
      for (final r in d.links)
        if (!r.removed && r.courseIds.any(now.contains)) r,
    ]..sort((a, b) => a.courseIds.first.compareTo(b.courseIds.first));
    final label = TypeScale.label.copyWith(color: p.textMuted);
    Widget rows(List<Resource> links, String? Function(Resource) tag) => Column(
      children: [
        for (final (i, r) in links.indexed) ...[
          if (i > 0) Divider(height: 1, indent: 15, color: p.divider),
          LinkRow(r: r, tag: tag(r), onReport: () => reportLink(context, r)),
        ],
      ],
    );
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 10, 15, 6),
            child: Text('DEPARTMENT · ${dept.length}', style: label),
          ),
          if (dept.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 0, 15, 12),
              child: Text(
                'No department links yet.',
                style: TypeScale.caption.copyWith(color: p.textMuted),
              ),
            )
          else
            rows(dept, (r) => r.rolledUp ? 'FROM ${r.fromCourse}' : null),
          Divider(height: 1, color: p.divider),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 10, 15, 6),
            child: Text('COURSES THIS SEMESTER', style: label),
          ),
          if (courseLinks.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 4, 15, 14),
              child: Text(
                'Nothing for your courses this semester. Open Course '
                'resources for every course.',
                style: TypeScale.caption.copyWith(color: p.textMuted),
              ),
            )
          else
            rows(
              courseLinks,
              (r) => r.courseIds.firstWhere(
                now.contains,
                orElse: () => r.courseIds.first,
              ),
            ),
        ],
      ),
    );
  }
}

/// A 30 × 24 code tile: the first degree mint, the second ink with mint text.
class _CodeTile extends StatelessWidget {
  const _CodeTile(this.code, {this.second = false});
  final String code;
  final bool second;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 30, minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: second ? p.inverse : p.hero,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: Text(
          code,
          style: TypeScale.label.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: second ? (p.isDark ? p.onInverse : p.hero) : p.onHero,
          ),
        ),
      ),
    );
  }
}
