// The sheets and dialogs a student opens, each opened from a launcher over
// the fake data in test/helpers/fake_data.dart, then rendered like a screen.
//
//   SHOTS_DIR=/some/dir flutter test test/ui/sheet_screens_test.dart
import 'package:cgpa_calculator/core/grading/cgpa.dart';
import 'package:cgpa_calculator/core/platform/browser.dart';
import 'package:cgpa_calculator/core/resources/resource.dart';
import 'package:cgpa_calculator/core/storage/courses.dart';
import 'package:cgpa_calculator/core/storage/marks.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/marks/widgets/average_sources.dart';
import 'package:cgpa_calculator/features/marks/widgets/divergence.dart';
import 'package:cgpa_calculator/features/resources/resources_page.dart';
import 'package:cgpa_calculator/features/semester/add_course_sheet.dart';
import 'package:cgpa_calculator/features/semester/edit_course_sheet.dart';
import 'package:cgpa_calculator/features/semester/widgets/grade_menu.dart';
import 'package:cgpa_calculator/features/settings/install_guide.dart';
import 'package:cgpa_calculator/shared/widgets/confirm_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_data.dart';
import '../helpers/fonts.dart';

/// Sheets that still fail, and why (UI.md §15).
const known = <String, String>{
  'd_report_link':
      'N37: the sheet does not scroll; overflows at 320 with 2x text',
};

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await seedAll();
  });

  Course taking() => allCourses().firstWhere((c) => c.id == takingId);

  final sheets = <(String, Future<void> Function(BuildContext))>[
    (
      'd_divergence',
      (c) => confirmDivergence(
        c,
        name: 'Mid Semester',
        change: 'Weight 25% → 30%',
      ),
    ),
    ('d_grade_menu', (c) => showGradeMenu(c, current: 9, title: takingTitle)),
    (
      'd_confirm',
      (c) => confirmDialog(
        c,
        title: 'Remove this course?',
        body: 'CS F372 leaves 3 − 1, with its grades.',
        cancel: 'Keep',
        action: 'Remove',
        danger: true,
      ),
    ),
    (
      'd_edit_course',
      (c) => showEditCourseSheet(
        c,
        course: taking(),
        discipline: 'B3A7',
        profile: Profile.actual,
      ),
    ),
    (
      'd_add_course',
      (c) => showAddCourseSheet(
        c,
        held: allCourses(),
        sem: '4 - 1',
        discipline: 'B3A7',
        profile: Profile.actual,
      ),
    ),
    (
      'd_report_link',
      (c) => reportLink(
        c,
        const Resource(
          id: 'r1',
          title: 'ELEC past papers — all years',
          url: 'https://drive.google.com/drive/folders/elec-papers',
          campus: 'goa',
          department: 'ELEC',
        ),
      ),
    ),
    (
      'd_install_guide',
      (c) => showInstallGuide(c, (
        device: InstallDevice.ios,
        browser: InstallBrowser.safari,
      )),
    ),
  ];

  for (final (name, open) in sheets) {
    testWidgets(name, (t) async {
      final errors = await renderScreen(
        t,
        name,
        () => launcher(open),
        open: tapLauncher,
      );
      expectRender(name, errors, known);
    });
  }

  // A full page pushed from Marks' "Averages ›".
  testWidgets('d_average_sources', (t) async {
    final errors = await renderScreen(
      t,
      'd_average_sources',
      () => AverageSourcesPage(
        course: taking(),
        courseAverage: 63.5,
        evals: [for (final (_, e) in evaluativesFor(takingId)) e],
        official: takingOffering(),
        detached: const {},
        onOpenCourse: () {},
      ),
    );
    expectRender('d_average_sources', errors, known);
  });
}
