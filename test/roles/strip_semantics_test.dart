import 'package:cgpa_calculator/app/theme/circle_reveal.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/features/roles/role_switch_page.dart';
import 'package:cgpa_calculator/script.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// QA-10: the Working-as strip sits above the router's navigator; a screen
// reader must still reach its label and its way back to Student.
void main() {
  testWidgets('the Working-as strip is in the semantics tree', (t) async {
    final semantics = t.ensureSemantics();
    selected_theme = 'White';
    thm = AppPalette.byName('White');
    addTearDown(() => workingAs.value = null);
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
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('Home page')),
        ),
      ],
    );
    await t.pumpWidget(
      MaterialApp.router(
        theme: thm.materialTheme,
        routerConfig: router,
        builder:
            (_, child) => ThemeReveal.root(
              TapOriginTracker(child: RoleStrip(child: child!)),
            ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('Working as')), findsOneWidget);
    expect(find.bySemanticsLabel('Home page'), findsOneWidget);
    expect(
      t.getSemantics(find.widgetWithText(TextButton, 'Student')),
      matchesSemantics(
        label: 'Student',
        isButton: true,
        hasTapAction: true,
        isEnabled: true,
        hasEnabledState: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );
    semantics.dispose();
  });
}
