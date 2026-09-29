import 'package:cgpa_calculator/admin/admin.dart' deferred as admin;
import 'package:cgpa_calculator/app/routes.dart';
import 'package:cgpa_calculator/core/roles/capabilities.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/core/storage/courses.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/calendar/calendar_page.dart';
import 'package:cgpa_calculator/features/marks/marks_page.dart';
import 'package:cgpa_calculator/features/more/more_page.dart';
import 'package:cgpa_calculator/features/more/representatives_page.dart';
import 'package:cgpa_calculator/features/resources/resources_page.dart';
import 'package:cgpa_calculator/features/roles/rep_profile.dart';
import 'package:cgpa_calculator/features/reviews/course_reviews.dart';
import 'package:cgpa_calculator/features/reviews/professor_reviews.dart';
import 'package:cgpa_calculator/features/reviews/reviews_home.dart';
import 'package:cgpa_calculator/features/roles/role_switch_page.dart';
import 'package:cgpa_calculator/features/settings/settings_page.dart';
import 'package:cgpa_calculator/features/stats/stats_page.dart';
import 'package:cgpa_calculator/home_page.dart';
import 'package:cgpa_calculator/features/setup/owner_setup_page.dart';
import 'package:cgpa_calculator/script.dart';
import 'package:cgpa_calculator/shared/widgets/not_found_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

export 'package:cgpa_calculator/app/routes.dart';

/// Every screen is nested under Home, so a deep link still has Home beneath
/// it and Back behaves exactly as the old pushed routes did.
final GoRouter appRouter = GoRouter(
  routes: appRoutes,
  refreshListenable: Listenable.merge([profileDue, ownerSetupDue]),
  redirect: (_, s) => profileGate(s.matchedLocation),
  errorBuilder: (_, _) => const NotFoundPage(),
);

/// RepProfile comes first after an appointment (§16.3 fix 8): while it is
/// due, every location resolves to it.
/// A non-BITS owner sets campus and batch before anything else (§10.21).
String? profileGate(String location) {
  if (ownerSetupDue.value) {
    return location == Routes.ownerSetup ? null : Routes.ownerSetup;
  }
  return profileDue.value && location != Routes.welcome ? Routes.welcome : null;
}

final List<RouteBase> appRoutes = [
  GoRoute(
    path: Routes.home,
    builder: (_, _) => const MyHomePage(title: 'Pointer'),
    routes: [
      GoRoute(
        path: 'stats',
        builder: (_, _) => StatsPage(discipline: selecteddiscipline),
      ),
      GoRoute(path: 'calendar', builder: (_, _) => const CalendarPage()),
      GoRoute(path: 'settings', builder: (_, _) => const SettingsPage()),
      GoRoute(
        path: 'resources',
        builder:
            (c, _) => ResourcesPage(
              onRepresentatives: () => c.push(Routes.representatives),
            ),
      ),
      GoRoute(path: 'more', builder: (_, _) => const MorePage()),
      GoRoute(
        path: 'representatives',
        builder: (_, _) => const RepresentativesPage(),
      ),
      GoRoute(
        path: 'setup/owner',
        builder:
            (c, _) => OwnerSetupPage(
              email: myRoles.value.email,
              onDone: () {
                ownerSetupDue.value = false;
                c.go(Routes.home);
              },
            ),
      ),
      GoRoute(
        path: 'welcome',
        redirect: (_, _) => roleStore == null ? Routes.home : null,
        builder: (_, _) => const RepProfilePage(onSignOut: signOut),
      ),
      GoRoute(
        path: 'reviews',
        builder: (_, _) => const ReviewsHome(),
        routes: [
          // Before :courseId: no course code is "professor".
          GoRoute(
            path: 'professor/:id',
            builder:
                (_, s) =>
                    ProfessorReviewsPage(professorId: s.pathParameters['id']!),
          ),
          GoRoute(
            path: ':courseId',
            builder:
                (_, s) => CourseReviewsPage(
                  courseId: s.pathParameters['courseId']!,
                  professorId: s.uri.queryParameters['professor'],
                ),
          ),
        ],
      ),
      GoRoute(
        path: 'course/:id',
        // A link to a course this user does not hold goes Home.
        redirect: (_, s) => _course(s) == null ? Routes.home : null,
        builder:
            (_, s) => MarksPage(
              course: _course(s)!,
              onEditCourse: s.extra as VoidCallback?,
            ),
      ),
      GoRoute(
        path: 'roles',
        redirect: (_, _) => myRoles.value.privileged ? null : Routes.home,
        builder: (_, _) => const RoleSwitchPage(),
      ),
      GoRoute(
        path: 'admin',
        redirect: (_, _) => _staff() ? null : Routes.home,
        builder: (_, _) => _deferred(() => admin.AdminHome()),
        routes: [
          _admin('people', () => admin.AdminPeople(), _adminOnly),
          _admin(
            'grant',
            () => admin.AdminGrant(),
            () => _adminOnly() || myRoles.value.presidencies.isNotEmpty,
          ),
          _admin('owners', () => admin.OwnersPage(), _ownerOnly),
          _admin('analytics', () => admin.SiteAnalytics(), _ownerOnly),
          _admin('terms', () => admin.TermsPage(), _adminOnly),
          _admin('contact', () => admin.PublicContactPage(), _adminOnly),
          _admin('audit', () => admin.AuditLogPage(), _staff),
          _admin(
            'roster/volunteers',
            () => admin.RosterPage(
              initialVolunteers: true,
              volunteersTab: (c) => admin.VolunteersTab(campus: c),
            ),
            _staff,
          ),
          _admin(
            'roster',
            () => admin.RosterPage(
              volunteersTab: (c) => admin.VolunteersTab(campus: c),
            ),
            _staff,
          ),
          _admin(
            'open-as/department',
            () => admin.ViewAsDeptPage(),
            _ownerOnly,
          ),
          _admin('open-as/course', () => admin.ViewAsCoursePage(), _ownerOnly),
          _admin('open-as', () => admin.OpenAsPage(), _ownerOnly),
          _admin('publish', () => admin.PublishPage(), _ownerOnly),
          _admin('professors/merge', () => admin.ProfessorMerge(), _staff),
        ],
      ),
      // Presidents and CRs (§13): the scope is in the path. The course route
      // comes first, so "course" is never read as a department.
      GoRoute(
        path: 'maintain/:campus/course/:courseId',
        redirect: (_, s) => _mayMaintain(s, course: true) ? null : Routes.home,
        builder:
            (_, s) => _deferred(
              () => admin.CrHome(
                campus: s.pathParameters['campus']!,
                courseId: s.pathParameters['courseId']!,
              ),
            ),
      ),
      GoRoute(
        path: 'maintain/:campus/:dept',
        redirect: (_, s) => _mayMaintain(s) ? null : Routes.home,
        builder:
            (_, s) => _deferred(
              () => admin.DeptHome(
                campus: s.pathParameters['campus']!,
                dept: s.pathParameters['dept']!,
              ),
            ),
        routes: [
          GoRoute(
            path: 'professors',
            builder:
                (_, s) => _deferred(
                  () => admin.DeptProfessors(
                    campus: s.pathParameters['campus']!,
                    dept: s.pathParameters['dept']!,
                  ),
                ),
          ),
          GoRoute(
            path: 'succession',
            builder:
                (_, s) => _deferred(
                  () => admin.Succession(
                    campus: s.pathParameters['campus']!,
                    dept: s.pathParameters['dept']!,
                  ),
                ),
            routes: [
              GoRoute(
                path: 'confirm',
                builder:
                    (_, s) => _deferred(
                      () => admin.SuccessionConfirm(
                        campus: s.pathParameters['campus']!,
                        dept: s.pathParameters['dept']!,
                        to: s.uri.queryParameters['to'] ?? '',
                        secretary: s.uri.queryParameters['sec'],
                      ),
                    ),
              ),
            ],
          ),
          GoRoute(
            path: 'reviews',
            builder:
                (_, s) => _deferred(
                  () => admin.DeptReviews(
                    campus: s.pathParameters['campus']!,
                    dept: s.pathParameters['dept']!,
                  ),
                ),
          ),
          GoRoute(
            path: 'resources',
            builder:
                (_, s) => _deferred(
                  () => admin.DeptResources(
                    campus: s.pathParameters['campus']!,
                    dept: s.pathParameters['dept']!,
                  ),
                ),
          ),
          GoRoute(
            path: 'courses',
            builder:
                (_, s) => _deferred(
                  () => admin.DeptCourses(
                    campus: s.pathParameters['campus']!,
                    dept: s.pathParameters['dept']!,
                  ),
                ),
          ),
        ],
      ),
    ],
  ),
];

bool _mayMaintain(GoRouterState s, {bool course = false}) => myRoles.value.may(
  course ? Capability.courseStructures : Capability.bulkUpload,
  campus: s.pathParameters['campus'],
  scope: course ? s.pathParameters['courseId'] : s.pathParameters['dept'],
);

bool _ownerOnly() => myRoles.value.owner;
bool _adminOnly() => myRoles.value.reachesAdmin;

/// Owners, admins and presidents reach Controls (§4).
bool _staff() => _adminOnly() || myRoles.value.presidencies.isNotEmpty;

GoRoute _admin(String path, Widget Function() page, bool Function() may) =>
    GoRoute(
      path: path,
      redirect: (_, _) => may() ? null : Routes.home,
      builder: (_, _) => _deferred(page),
    );

/// Admin screens live in a deferred library (§13): loaded on first visit.
Widget _deferred(Widget Function() page) =>
    DeferredPage(load: _adminLoad ??= admin.loadLibrary(), page: page);
Future<void>? _adminLoad;

class DeferredPage extends StatelessWidget {
  const DeferredPage({super.key, required this.load, required this.page});
  final Future<void> load;
  final Widget Function() page;

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: load,
    builder:
        (context, s) =>
            s.connectionState == ConnectionState.done
                ? page()
                : const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),
  );
}

Course? _course(GoRouterState s) {
  final id = s.pathParameters['id'];
  return allCourses().where((c) => c.id == id).firstOrNull;
}
