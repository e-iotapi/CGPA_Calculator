import 'dart:io';

import 'package:cgpa_calculator/admin/roster.dart';
import 'package:cgpa_calculator/app/router.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/shared/widgets/not_found_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  final sources = [
    for (final line in File('landing/_redirects').readAsLinesSync())
      if (line.trim().isNotEmpty && !line.startsWith('#'))
        line.trim().split(RegExp(r'\s+')).first,
  ];

  // Top-level segments under Home: 'stats', 'course' (from 'course/:id')…
  final home = appRoutes.single as GoRoute;
  final segments = [
    for (final r in home.routes.whereType<GoRoute>()) r.path.split('/').first,
  ];

  test('every top-level route segment has a _redirects line', () {
    expect(segments, isNotEmpty);
    for (final s in segments) {
      final hasChildren = home.routes.whereType<GoRoute>().any(
        (r) => r.path.startsWith('$s/'),
      );
      final route = home.routes.whereType<GoRoute>().firstWhere(
        (r) => r.path.split('/').first == s,
      );
      final nested = route.routes.isNotEmpty;
      expect(
        sources,
        contains(hasChildren || nested ? '/calculator/$s/*' : '/calculator/$s'),
        reason:
            'deep links to /calculator/$s need a line in landing/_redirects',
      );
      // A page with pages beneath it needs its own line as well: `/x/*`
      // does not match `/x`.
      if (nested) expect(sources, contains('/calculator/$s'));
    }
  });

  test('no catch-all rule rewrites the app\'s own files', () {
    expect(sources, isNot(contains('/calculator/*')));
    expect(sources.where((s) => s.startsWith('/calculator/:')), isEmpty);
  });

  group('T3.4: router error page and the volunteers route', () {
    setUp(() => myRoles.value = MyRoles.none);
    tearDown(() => myRoles.value = MyRoles.none);

    // The real 'admin' GoRoute, re-rooted straight under '/': every screen
    // is nested under Home in the live app (see router.dart's own comment),
    // so pumping appRoutes as-is always mounts MyHomePage too, which needs
    // FirebaseAuth.instance and has no fake in this harness. Re-rooting
    // reuses the same route/redirect/builder objects the router.dart wires,
    // just without Home in the stack.
    testWidgets(
      '/admin/roster/volunteers resolves to RosterPage with initialVolunteers',
      (t) async {
        myRoles.value = const MyRoles(email: 'owner@example.com', owner: true);
        final admin = home.routes.whereType<GoRoute>().firstWhere(
          (r) => r.path == 'admin',
        );
        final router = GoRouter(
          initialLocation: '/admin/roster/volunteers',
          routes: [
            GoRoute(
              path: '/admin',
              redirect: admin.redirect,
              builder: admin.builder,
              routes: admin.routes,
            ),
          ],
        );
        await t.pumpWidget(MaterialApp.router(routerConfig: router));
        await t.pumpAndSettle();
        final page = t.widget<RosterPage>(find.byType(RosterPage));
        expect(page.initialVolunteers, isTrue);
      },
    );

    testWidgets('/nope builds NotFoundPage', (t) async {
      final router = GoRouter(
        routes: appRoutes,
        initialLocation: '/nope',
        errorBuilder: (_, _) => const NotFoundPage(),
      );
      await t.pumpWidget(MaterialApp.router(routerConfig: router));
      await t.pumpAndSettle();
      expect(find.byType(NotFoundPage), findsOneWidget);
    });
  });
}
