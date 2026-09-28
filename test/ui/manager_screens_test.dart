// Every manager screen (canvas page 2), rendered as its role over the fake
// data in test/helpers/fake_data.dart: light and dark at 390 and 320, and 320
// at 150% text. Fails on any layout error. With SHOTS_DIR set, writes PNGs
// to lay beside the boards (UI.md §14):
//
//   SHOTS_DIR=/some/dir flutter test test/ui/manager_screens_test.dart
import 'package:cgpa_calculator/admin/admin.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/features/more/representatives_page.dart';
import 'package:cgpa_calculator/features/roles/rep_profile.dart';
import 'package:cgpa_calculator/features/roles/role_switch_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_data.dart';
import '../helpers/fonts.dart';

/// Screens that still fail, and why (UI.md §15). A fix makes its test fail
/// until it is taken off this list.
const known = <String, String>{};

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await seedAll();
  });

  final screens = <(String, Widget Function(), As, double)>[
    ('m_admin_home', () => const AdminHome(), As.owner, 900),
    ('m_admin_home_admin', () => const AdminHome(), As.admin, 900),
    ('m_admin_home_pres', () => const AdminHome(), As.president, 900),
    ('m_people', () => const AdminPeople(), As.owner, 900),
    ('m_person', () => PersonPage(grant: presGrant), As.owner, 900),
    (
      'm_grant',
      // The board's state: an address that resolves, president of ELEC.
      () => const AdminGrant(
        prefill: (role: GrantRole.dept, email: presEmail, scope: 'ELEC'),
      ),
      As.owner,
      1130,
    ),
    ('m_grant_pres', () => const AdminGrant(), As.president, 1130),
    ('m_owners', () => const OwnersPage(), As.owner, 860),
    ('m_terms', () => const TermsPage(), As.owner, 844),
    ('m_terms_admin', () => const TermsPage(), As.admin, 844),
    ('m_contact', () => const PublicContactPage(), As.owner, 900),
    ('m_audit', () => const AuditLogPage(), As.owner, 844),
    (
      'm_audit_pres',
      () => const AuditLogPage(campus: 'goa'),
      As.president,
      844,
    ),
    (
      'm_roster',
      () => RosterPage(volunteersTab: (c) => VolunteersTab(campus: c)),
      As.president,
      980,
    ),
    (
      'm_roster_volunteers',
      () => RosterPage(
        initialVolunteers: true,
        volunteersTab: (c) => VolunteersTab(campus: c),
      ),
      As.president,
      980,
    ),
    ('m_open_as', () => const OpenAsPage(), As.owner, 844),
    ('m_view_as_dept', () => const ViewAsDeptPage(), As.owner, 1400),
    ('m_view_as_course', () => const ViewAsCoursePage(), As.owner, 844),
    ('m_publish', () => const PublishPage(), As.owner, 844),
    ('m_merge', () => const ProfessorMerge(), As.owner, 844),
    (
      'm_merge_pres',
      () => const ProfessorMerge(campus: 'goa', dept: 'CS'),
      As.president2,
      844,
    ),
    (
      'm_dept_home',
      () => const DeptHome(campus: 'goa', dept: 'ELEC'),
      As.president,
      844,
    ),
    (
      'm_dept_courses',
      () => const DeptCourses(campus: 'goa', dept: 'ELEC'),
      As.president,
      844,
    ),
    (
      'm_dept_profs',
      () => const DeptProfessors(campus: 'goa', dept: 'CS'),
      As.president2,
      880,
    ),
    (
      'm_dept_reviews',
      () => const DeptReviews(campus: 'goa', dept: 'ELEC'),
      As.president,
      844,
    ),
    (
      'm_dept_resources',
      () => const DeptResources(campus: 'goa', dept: 'ELEC'),
      As.president,
      860,
    ),
    (
      'm_dept_reported',
      () => const DeptResources(campus: 'goa', dept: 'ELEC', initialTab: 2),
      As.president,
      844,
    ),
    (
      'm_succession',
      () => const Succession(campus: 'goa', dept: 'ELEC'),
      As.president,
      844,
    ),
    (
      'm_succession_confirm',
      () => const SuccessionConfirm(
        campus: 'goa',
        dept: 'ELEC',
        to: 'f20240101@goa.bits-pilani.ac.in',
      ),
      As.president,
      844,
    ),
    (
      'm_cr_home',
      () => const CrHome(campus: 'goa', courseId: 'CS F372'),
      As.cr,
      900,
    ),
    ('m_role_switch', () => const RoleSwitchPage(), As.president, 844),
    (
      'm_rep_profile',
      // Forced, as the board draws it: served first after an appointment.
      () {
        profileDue.value = true;
        addTearDown(() => profileDue.value = false);
        return RepProfilePage(onSignOut: () {});
      },
      As.president,
      1100,
    ),
    ('m_representatives', () => const RepresentativesPage(), As.student, 844),
  ];

  for (final (name, screen, who, tall) in screens) {
    testWidgets(name, (t) async {
      final errors = await renderScreen(t, name, screen, who: who, tall: tall);
      expectRender(name, errors, known);
    });
  }
}
