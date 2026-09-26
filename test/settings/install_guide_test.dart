import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/features/settings/install_guide.dart';
import 'package:cgpa_calculator/core/platform/browser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every platform has three steps ending in the confirm button', () {
    for (final p in InstallPlatform.values) {
      final s = installSteps(p);
      expect(s, hasLength(3), reason: '$p');
      expect(s.last.mark, isNotNull, reason: '$p');
    }
    expect(installSteps(InstallPlatform.ios).first.text, contains('Share'));
  });

  for (final platform in InstallPlatform.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('$platform guide at 320px, text ×$scale', (t) async {
        t.view.physicalSize = const Size(320, 640);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(
          MaterialApp(
            theme: AppPalette.light.materialTheme,
            builder:
                (c, child) => MediaQuery(
                  data: MediaQuery.of(
                    c,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
            home: Builder(
              builder:
                  (c) => Scaffold(
                    body: TextButton(
                      onPressed: () => showInstallGuide(c, platform),
                      child: const Text('open'),
                    ),
                  ),
            ),
          ),
        );
        await t.tap(find.text('open'));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        expect(find.text('Add Pointer to your home screen'), findsOneWidget);
        await t.scrollUntilVisible(
          find.text('Got it'),
          100,
          scrollable: find.byType(Scrollable).last,
        );
        await t.tap(find.text('Got it'));
        await t.pumpAndSettle();
        expect(find.text('Add Pointer to your home screen'), findsNothing);
      });
    }
  }
}
