import 'package:cgpa_calculator/admin/admin.dart' deferred as admin;
import 'package:cgpa_calculator/app/routes.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/core/storage/courses.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/calendar/calendar_page.dart';
import 'package:cgpa_calculator/features/marks/marks_page.dart';
import 'package:cgpa_calculator/features/roles/role_switch_page.dart';
import 'package:cgpa_calculator/features/settings/settings_page.dart';
import 'package:cgpa_calculator/features/stats/stats_page.dart';
import 'package:cgpa_calculator/home_page.dart';
import 'package:cgpa_calculator/script.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

export 'package:cgpa_calculator/app/routes.dart';

/// Every screen is nested under Home, so a deep link still has Home beneath
/// it and Back behaves exactly as the old pushed routes did.
final GoRouter appRouter = GoRouter(routes: appRoutes);

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
          _admin('terms', () => admin.TermsPage(), _adminOnly),
          _admin('contact', () => admin.PublicContactPage(), _adminOnly),
          _admin('audit', () => admin.AuditLogPage(), _staff),
          _admin('roster', () => admin.RosterPage(), _staff),
          _admin('open-as', () => admin.OpenAsPage(), _ownerOnly),
        ],
      ),
    ],
  ),
];

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
