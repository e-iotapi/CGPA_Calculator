import 'package:cgpa_calculator/core/storage/courses.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/calendar/calendar_page.dart';
import 'package:cgpa_calculator/features/marks/marks_page.dart';
import 'package:cgpa_calculator/features/settings/settings_page.dart';
import 'package:cgpa_calculator/features/stats/stats_page.dart';
import 'package:cgpa_calculator/home_page.dart';
import 'package:cgpa_calculator/script.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Paths of the screens that exist today (ARCHITECTURE.md §16.1), relative
/// to the `/calculator/` base href.
abstract final class Routes {
  static const home = '/';
  static const stats = '/stats';
  static const calendar = '/calendar';
  static const settings = '/settings';
  static String course(String id) => '/course/${Uri.encodeComponent(id)}';
}

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
    ],
  ),
];

Course? _course(GoRouterState s) {
  final id = s.pathParameters['id'];
  return allCourses().where((c) => c.id == id).firstOrNull;
}

/// Opens [location] above the current screen and completes when it closes.
/// Without a router above (widget tests pump screens bare) it pushes [page].
Future<void> openRoute(
  BuildContext context,
  String location,
  Widget Function() page, {
  Object? extra,
}) async {
  if (GoRouter.maybeOf(context) != null) {
    await context.push(location, extra: extra);
    return;
  }
  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page()));
}
