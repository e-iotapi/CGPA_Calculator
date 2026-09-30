import 'package:cgpa_calculator/app/theme/circle_reveal.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/features/settings/settings_view.dart';
import 'package:cgpa_calculator/script.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/fonts.dart';

// BUG-30: switching Light/Dark in Settings must not move the list.
void main() {
  testWidgets('Settings keeps its scroll offset across a theme switch', (
    t,
  ) async {
    await loadAppFonts();
    t.view.physicalSize = const Size(390, 700);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    selected_theme = 'White';
    thm = AppPalette.byName('White');
    void noop() {}
    late StateSetter set;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder:
              (c, _) => TextButton(
                onPressed: () => c.push('/settings'),
                child: const Text('open'),
              ),
          routes: [
            GoRoute(
              path: 'settings',
              // Like the app: a Theme over the view, rebuilt by setState.
              builder:
                  (_, _) => StatefulBuilder(
                    builder: (_, s) {
                      set = s;
                      return Theme(
                        data: thm.materialTheme,
                        child: SettingsView(
                          name: 'A',
                          email: 'a@goa.bits-pilani.ac.in',
                          discipline: 'B3A7',
                          batch: 24,
                          isDark: thm.isDark,
                          profiles: const ['a', 'b', 'c', 'd', 'e'],
                          onClose: noop,
                          onPickDiscipline: (_) {},
                          onTheme:
                              (d) => ThemeReveal.run(() {
                                thm = AppPalette.byName(d ? 'Black' : 'White');
                                themeVersion.value++;
                                set(() {});
                              }),
                          onRenameProfile: (_) {},
                          onExport: noop,
                          onImportOld: noop,
                          onReport: noop,
                          onReset: noop,
                          onSignOut: noop,
                          campus: 'Goa',
                        ),
                      );
                    },
                  ),
            ),
          ],
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
                  (_, child) =>
                      ThemeReveal.root(TapOriginTracker(child: child!)),
            ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    final list = find.byType(Scrollable).first;
    await t.drag(list, const Offset(0, -250));
    await t.pumpAndSettle();
    double offset() => t.state<ScrollableState>(list).position.pixels;
    final before = offset();
    expect(before, greaterThan(100));

    await t.tap(find.text('Dark'));
    for (var i = 0; i < 60; i++) {
      await t.pump(const Duration(milliseconds: 20));
      expect(offset(), before, reason: 'frame $i');
    }
    await t.pumpAndSettle();
    expect(thm.isDark, isTrue);
    expect(offset(), before);
  });
}
