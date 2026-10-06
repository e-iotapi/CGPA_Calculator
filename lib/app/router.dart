import 'dart:async';

import 'package:cgpa_calculator/admin/admin.dart' deferred as admin;
import 'package:cgpa_calculator/app/routes.dart';
import 'package:cgpa_calculator/core/roles/capabilities.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/core/storage/courses.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/calendar/calendar_page.dart';
import 'package:cgpa_calculator/features/marks/marks_page.dart';
import 'package:cgpa_calculator/features/contribute/add_page.dart';
import 'package:cgpa_calculator/features/contribute/apply_page.dart';
import 'package:cgpa_calculator/features/contribute/contribute_page.dart';
import 'package:cgpa_calculator/features/contribute/edit_page.dart';
import 'package:cgpa_calculator/features/contribute/leaderboard_page.dart';
import 'package:cgpa_calculator/features/more/more_page.dart';
import 'package:cgpa_calculator/features/more/representatives_page.dart';
import 'package:cgpa_calculator/features/resources/bookmarks_page.dart';
import 'package:cgpa_calculator/features/resources/resource_course_page.dart';
import 'package:cgpa_calculator/features/resources/resource_courses_page.dart';
import 'package:cgpa_calculator/features/resources/resource_degree_page.dart';
import 'package:cgpa_calculator/features/resources/resources_page.dart';
import 'package:cgpa_calculator/features/roles/rep_profile.dart';
import 'package:cgpa_calculator/features/reviews/compulsory_pick.dart';
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
import 'package:cgpa_calculator/features/setup/campus_pick_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

export 'package:cgpa_calculator/app/routes.dart';

/// Every screen is nested under Home, so a deep link still has Home beneath
/// it and Back behaves exactly as the old pushed routes did.
final GoRouter appRouter = GoRouter(
  routes: appRoutes,
  refreshListenable: Listenable.merge([profileDue, ownerSetupDue]),
  redirect: (_, s) {
    leaveRoleOutside(s.matchedLocation);
    return profileGate(s.matchedLocation) ?? movedPath(s.uri);
  },
  errorBuilder: (_, _) => const NotFoundPage(),
);

/// The pages a role works in; everything else is a student's.
const _rolePaths = ['/admin', '/maintain', '/roles', '/campus'];

/// Whether [location] is one of the role pages.
bool onRolePath(String location) =>
    _rolePaths.any((p) => location == p || location.startsWith('$p/'));

/// On a student page, a president or CR is a student again and an owner is
/// the owner again (not a role they opened as): Switch role and Open as hold
/// only while their pages are open.
void leaveRoleOutside(String location) {
  if (onRolePath(location)) return;
  if (workingAs.value != null) unawaited(setWorkingAs(null));
  viewAs.value = null;
}

/// Where an old or bare address now lives: `/` opens the last tab, and the
/// pages More opens moved under `/more` (owner, 2026-10-06).
String? movedPath(Uri uri) {
  final path = uri.path;
  if (path == Routes.home) return Routes.tab(selectedprofile);
  for (final p in _underMore) {
    if (path == p || path.startsWith('$p/')) {
      return Routes.more + _resourcesPath(uri.toString());
    }
  }
  return null;
}

const _underMore = [
  '/resources',
  '/leaderboard',
  '/contribute',
  '/representatives',
  '/reviews',
];

/// Resources dropped `degree/` and `course/` from its paths.
String _resourcesPath(String s) => s.replaceFirst(
  RegExp(r'^/resources/(degree|course)/'),
  '/resources/',
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

/// Every route of the app, for the router in `main.dart`.
final List<RouteBase> appRoutes = [
  GoRoute(
    path: Routes.home,
    pageBuilder: (_, _) => _homePage(null),
    routes: [
      GoRoute(
        path: 'stats',
        builder: (_, _) => StatsPage(discipline: selecteddiscipline),
      ),
      GoRoute(path: 'calendar', builder: (_, _) => const CalendarPage()),
      GoRoute(path: 'settings', builder: (_, _) => const SettingsPage()),
      // More and the pages it opens (owner, 2026-10-06).
      GoRoute(
        path: 'more',
        builder: (_, _) => const MorePage(),
        routes: [
          GoRoute(
            path: 'resources',
            builder: (_, _) => const ResourcesPage(),
            routes: [
              GoRoute(
                path: 'courses',
                builder: (_, _) => const ResourceCoursesPage(),
              ),
              GoRoute(
                path: 'bookmarked',
                builder: (_, _) => const BookmarksPage(),
              ),
              // A degree code (A7) or a course id (CS F372).
              GoRoute(
                path: ':id',
                builder: (c, s) {
                  final id = s.pathParameters['id']!;
                  return departmentOfProgramme(id) != null
                      ? ResourceDegreePage(
                        code: id,
                        onRepresentatives: () => c.push(Routes.representatives),
                      )
                      : ResourceCoursePage(courseId: id);
                },
              ),
            ],
          ),
          GoRoute(path: 'leaderboard', builder: (_, _) => const LeaderboardPage()),
          GoRoute(
            path: 'contribute',
            builder: (_, _) => const ContributePage(),
            routes: [
              GoRoute(path: 'apply', builder: (_, _) => const ApplyPage()),
              GoRoute(
                path: 'add',
                builder:
                    (_, s) =>
                        AddPage(course: s.uri.queryParameters['course'] == '1'),
              ),
              GoRoute(
                path: 'edit/:id',
                builder: (_, s) => EditPage(id: s.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: 'representatives',
            builder: (_, _) => const RepresentativesPage(),
          ),
          GoRoute(
            path: 'reviews',
            builder: (_, _) => const ReviewsHome(),
            routes: [
              // Before :courseId: no course code is "professor".
              GoRoute(
                path: 'compulsory',
                redirect: (_, _) => viewCampus() == null ? Routes.reviews : null,
                builder: (_, _) => const CompulsoryPickPage(),
              ),
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
        ],
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
        path: 'campus',
        redirect: (_, _) => myRoles.value.owner ? null : Routes.home,
        builder: (_, _) => const CampusPickPage(),
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
          _admin('approvals', () => admin.Approvals(), _adminOnly),
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
            path: 'approvals',
            builder:
                (_, s) => _deferred(
                  () => admin.Approvals(
                    campus: s.pathParameters['campus']!,
                    dept: s.pathParameters['dept']!,
                  ),
                ),
          ),
          GoRoute(
            path: 'professors',
            builder:
                (_, s) => _deferred(
                  () => admin.DeptProfessors(
                    campus: s.pathParameters['campus']!,
                    dept: s.pathParameters['dept']!,
                  ),
                ),
            routes: [
              GoRoute(
                path: 'add',
                builder:
                    (_, s) => _deferred(
                      () => admin.ProfessorAdd(
                        campus: s.pathParameters['campus']!,
                        dept: s.pathParameters['dept']!,
                        initial: s.uri.queryParameters['name'] ?? '',
                      ),
                    ),
              ),
            ],
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
  for (final (path, profile) in Routes.tabs)
    GoRoute(path: path, pageBuilder: (_, _) => _homePage(profile)),
];

/// Home under every route, one page whatever the tab: the same key keeps
/// it (and its state) when the tab's path changes.
Page<void> _homePage(int? profile) => MaterialPage(
  key: const ValueKey('home'),
  child: MyHomePage(title: 'Pointer', profile: profile),
);

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
    DeferredPage(load: _loadAdmin(), loaded: _adminReady, page: page);
Future<void>? _adminLoad;
bool _adminReady = false;
Future<void> _loadAdmin() =>
    _adminLoad ??= admin.loadLibrary().then((_) => _adminReady = true);

/// For a department president: loads the admin code and their board's data
/// in the background, so the department pages open with data (TM-16).
Future<void> prefetchPresidentPages() async {
  final presidencies = myRoles.value.presidencies;
  if (presidencies.isEmpty) return;
  await _loadAdmin();
  admin.prefetchDeptScreens(presidencies);
}

/// Shows [page] once the deferred library behind [load] has loaded.
class DeferredPage extends StatelessWidget {
  const DeferredPage({
    super.key,
    required this.load,
    required this.page,
    this.loaded = false,
  });

  /// True once [load] has completed: [page] then draws in the first frame
  /// (a FutureBuilder on a done future still shows one waiting frame).
  final bool loaded;

  /// Completes when the library is loaded.
  final Future<void> load;

  /// Builds the page; called only after [load] completes.
  final Widget Function() page;

  @override
  Widget build(BuildContext context) =>
      loaded
          ? page()
          : FutureBuilder(
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
