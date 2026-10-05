// Every student screen on canvas page 1 that has no shot test of its own,
// rendered for a student over the fake data in test/helpers/fake_data.dart:
// a B3 A7 dual degree at Goa, batch 23, taking CS F372 with its published
// scheme, marks and reviews. Light and dark at 390 and 320, and 320 at 150%
// text. Fails on any layout error.
//
//   SHOTS_DIR=/some/dir flutter test test/ui/student_screens_test.dart
import 'package:cgpa_calculator/core/models/marks.dart';
import 'package:cgpa_calculator/core/models/programmes.dart';
import 'package:cgpa_calculator/core/storage/courses.dart';
import 'package:cgpa_calculator/core/storage/marks.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/auth/sign_in_view.dart';
import 'package:cgpa_calculator/features/calendar/calendar_page.dart';
import 'package:cgpa_calculator/features/import/erp_import_page.dart';
import 'package:cgpa_calculator/features/marks/add_evaluative_page.dart';
import 'package:cgpa_calculator/features/marks/course_setup_page.dart';
import 'package:cgpa_calculator/features/marks/marks_page.dart';
import 'package:cgpa_calculator/features/marks/official.dart';
import 'package:cgpa_calculator/features/more/more_page.dart';
import 'package:cgpa_calculator/features/resources/resource_course_page.dart';
import 'package:cgpa_calculator/features/resources/resource_courses_page.dart';
import 'package:cgpa_calculator/features/resources/resource_degree_page.dart';
import 'package:cgpa_calculator/features/resources/resources_page.dart';
import 'package:cgpa_calculator/features/reviews/course_reviews.dart';
import 'package:cgpa_calculator/features/reviews/professor_reviews.dart';
import 'package:cgpa_calculator/features/reviews/review_form.dart';
import 'package:cgpa_calculator/features/reviews/reviews_home.dart';
import 'package:cgpa_calculator/features/setup/campus_pick_page.dart';
import 'package:cgpa_calculator/features/setup/degree_setup_page.dart';
import 'package:cgpa_calculator/features/setup/programme_pick_page.dart';
import 'package:cgpa_calculator/features/stats/stats_page.dart';
import 'package:cgpa_calculator/script.dart' as app;
import 'package:cgpa_calculator/shared/widgets/page_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_data.dart';
import '../helpers/fonts.dart';

/// Screens that still fail, and why (UI.md §15).
const known = <String, String>{};

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await seedAll();
    offeringSource = publishedOfferings();
  });
  tearDownAll(() => offeringSource = null);

  // Read after setUpAll has filled the device.
  Course taking() => allCourses().firstWhere((c) => c.id == takingId);
  (String, Evaluative) kernel() => evaluativesFor(
    takingId,
  ).firstWhere((e) => e.$2.name == 'Kernel Assignments');

  final screens = <(String, Widget Function(), double)>[
    ('s_sign_in', () => SignInView(busy: false, onSignIn: () {}), 844),
    ('s_setup', () => DegreeSetupPage(email: studentEmail, onDone: () {}), 844),
    (
      's_pick',
      () => ProgrammePickPage(
        heading: 'Pick a programme',
        options: programmesAt(Campus.goa),
        selected: 'A7',
      ),
      844,
    ),
    ('s_campus', () => const CampusPickPage(), 700),
    ('s_import', () => ErpImportPage(onDone: () {}, installable: true), 870),
    ('s_marks', () => MarksPage(course: taking()), 1060),
    ('s_course_setup', () => CourseSetupPage(course: taking()), 970),
    (
      's_add_eval',
      () =>
          AddEvaluativePage(courseId: takingId, weighted: true, unassigned: 15),
      990,
    ),
    (
      's_edit_eval',
      () => AddEvaluativePage(
        courseId: takingId,
        weighted: true,
        unassigned: 15,
        existing: kernel().$2,
        existingKey: kernel().$1,
      ),
      990,
    ),
    ('s_stats', () => const StatsPage(discipline: 'B3A7'), 980),
    ('s_calendar', () => const CalendarPage(), 844),
    ('s_more', () => const MorePage(), 844),
    ('s_reviews_home', () => const ReviewsHome(), 844),
    ('s_your_reviews', () => const ReviewsHome(yours: true), 844),
    (
      's_course_reviews',
      () => const CourseReviewsPage(courseId: takingId),
      880,
    ),
    ('s_review_form', () => const ReviewFormPage(courseId: takingId), 844),
    (
      's_prof_reviews',
      () => const ProfessorReviewsPage(professorId: 'p1'),
      844,
    ),
    ('s_resources', () => const ResourcesPage(), 920),
    (
      's_resource_degree',
      () => ResourceDegreePage(code: 'A7', onRepresentatives: () {}),
      844,
    ),
    ('s_resource_courses', () => const ResourceCoursesPage(), 844),
    (
      's_resource_course',
      () => const ResourceCoursePage(courseId: takingId),
      844,
    ),
    (
      's_resources_empty',
      () => PageFrame(
        header: const PageHeader(eyebrow: 'GOA', title: 'Resources'),
        children: [ResourcesEmpty(onRepresentatives: () {})],
      ),
      844,
    ),
  ];

  for (final (name, screen, tall) in screens) {
    testWidgets(name, (t) async {
      final errors = await renderScreen(t, name, screen, tall: tall);
      expectRender(name, errors, known);
    });
  }

  testWidgets('from the 2026 batch, Degree says the requirements are coming', (
    t,
  ) async {
    final was = app.batch;
    addTearDown(() => app.batch = was);
    for (final (batch, shown) in [(26, findsOneWidget), (25, findsNothing)]) {
      app.batch = batch;
      await renderScreen(
        t,
        's_stats_degree_$batch',
        () => const StatsPage(discipline: 'B3A7'),
        tall: 980,
        open: (t) async {
          await t.tap(find.text('Degree').first);
          await settle(t);
          expect(find.textContaining('Senate explains'), shown);
        },
      );
    }
  });
}
