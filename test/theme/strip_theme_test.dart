import 'package:cgpa_calculator/app/theme/circle_reveal.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/features/roles/role_switch_page.dart';
import 'package:cgpa_calculator/script.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// The Working-as strip moves the page when it comes or goes; the theme
// switch must still reach the page afterwards.
void main() {
  testWidgets('the theme switches under and after the Working-as strip', (
    t,
  ) async {
    selected_theme = 'Black';
    thm = AppPalette.byName('Black');
    addTearDown(() => workingAs.value = null);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          // Like the home page: reads the palette from the app theme.
          builder:
              (_, _) => Builder(
                builder:
                    (c) => ColoredBox(
                      key: const Key('page'),
                      color: AppPalette.of(c).background,
                      child: const SizedBox.expand(),
                    ),
              ),
        ),
      ],
    );
    await t.pumpWidget(
      ValueListenableBuilder(
        valueListenable: themeVersion,
        builder:
            (_, _, _) => MaterialApp.router(
              theme: thm.materialTheme,
              themeAnimationDuration: Duration.zero,
              routerConfig: router,
              builder:
                  (_, child) => ThemeReveal.root(
                    TapOriginTracker(child: RoleStrip(child: child!)),
                  ),
            ),
      ),
    );
    await t.pumpAndSettle();

    Future<void> switchAndCheck() async {
      final done = ThemeReveal.run(() {
        selected_theme = thm.isDark ? 'White' : 'Black';
        thm = AppPalette.byName(selected_theme);
        themeVersion.value++;
      });
      await t.pumpAndSettle();
      await done;
      expect(
        t.widget<ColoredBox>(find.byKey(const Key('page'))).color,
        thm.background,
      );
    }

    await switchAndCheck();
    workingAs.value = Grant(
      role: GrantRole.dept,
      email: 'x@goa.bits-pilani.ac.in',
      name: 'X',
      campus: 'goa',
      scope: 'ELEC',
      programme: 'A3',
      active: true,
      expiresAt: DateTime(2030),
    );
    await t.pumpAndSettle();
    await switchAndCheck();
    await switchAndCheck();
    workingAs.value = null; // Student
    await t.pumpAndSettle();
    await switchAndCheck();
    await switchAndCheck();
  });
}
