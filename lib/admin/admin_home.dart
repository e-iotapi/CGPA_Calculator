import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:cgpa_calculator/app/routes.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/roles/capabilities.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Board `AdminHome`: tier and scope, then the sections this person can
/// reach. Publishing and ownership are owner only (§4).
class AdminHome extends StatelessWidget {
  const AdminHome({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final r = myRoles.value;
    // Under Open as › Admin an owner sees what an admin sees.
    final owner = r.owner && viewAs.value?.role != Role.admin;
    void go(String to) => context.push(to);

    return PageFrame(
      header: const PageHeader(eyebrow: 'POINTER · ADMIN', title: 'Controls'),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
          decoration: BoxDecoration(
            color: p.inverse,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TierTag(owner ? 'OWNER' : 'ADMIN'),
              const SizedBox(height: Space.sm),
              Text(
                owner
                    ? 'Every campus, every department'
                    : 'Appointments, every campus',
                style: TypeScale.body.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: p.onInverse,
                ),
              ),
              const SizedBox(height: Space.xs),
              Text(
                owner
                    ? 'Owners publish, appoint admins and add other owners. Any '
                        'verified Google account can be one — keep at least one '
                        'that survives graduation.'
                    : 'Admins appoint presidents and CRs and keep the public '
                        'contact. Publishing and ownership stay with owners.',
                style: TypeScale.caption.copyWith(
                  fontSize: 10.5,
                  height: 1.45,
                  color: p.onInverse.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
        const SectionLabel('People'),
        RowGroup(
          children: [
            NavRow(
              icon: Icons.group_outlined,
              title: 'Maintainers',
              subtitle: 'Every grant: presidents, course managers, admins',
              onTap: () => go(Routes.adminPeople),
            ),
            NavRow(
              icon: Icons.add_rounded,
              title: 'Appoint someone',
              accent: true,
              onTap: () => go(Routes.adminGrant),
            ),
            NavRow(
              icon: Icons.badge_outlined,
              title: 'Roster',
              subtitle: 'By campus, with volunteers',
              onTap: () => go(Routes.adminRoster),
            ),
          ],
        ),
        const SectionLabel('Owners and admins'),
        RowGroup(
          children: [
            NavRow(
              icon: Icons.event_outlined,
              title: 'Grant terms',
              subtitle: 'How long a CR, president and admin grant lasts',
              onTap: () => go(Routes.adminTerms),
            ),
            NavRow(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Public contact',
              subtitle: 'Shown on empty pages',
              onTap: () => go(Routes.adminContact),
            ),
            NavRow(
              icon: Icons.merge_type_rounded,
              title: 'Merge professors',
              subtitle: 'Two entries for one person',
              onTap: () => go(Routes.adminMerge),
            ),
            NavRow(
              icon: Icons.notes_rounded,
              title: 'Audit log',
              subtitle: 'Append-only · nothing here can be deleted',
              onTap: () => go(Routes.adminAudit),
            ),
          ],
        ),
        if (owner) ...[
          const SectionLabel('Owner only'),
          RowGroup(
            children: [
              NavRow(
                icon: Icons.person_outline_rounded,
                title: 'Owners',
                subtitle: 'You cannot remove yourself',
                onTap: () => go(Routes.adminOwners),
              ),
              NavRow(
                icon: Icons.publish_rounded,
                title: 'Publish catalogue',
                subtitle: 'The diff in CGPA terms, then Publish',
                onTap: () => go(Routes.adminPublish),
              ),
              NavRow(
                icon: Icons.visibility_outlined,
                title: 'Open Pointer as',
                subtitle: 'See the app as any role; saves stay yours',
                onTap: () => go(Routes.openAs),
              ),
            ],
          ),
        ],
        const Note(
          'An admin sees everything above Owner only. Publishing and ownership '
          'stay with owners; the admin term is set by owners alone.',
        ),
      ],
    );
  }
}
