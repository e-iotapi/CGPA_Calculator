import 'package:cgpa_calculator/app/theme/circle_reveal.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app({bool reduced = false}) => MaterialApp(
  theme: AppPalette.light.materialTheme,
  builder:
      (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(disableAnimations: reduced),
        child: ThemeReveal.root(TapOriginTracker(child: child!)),
      ),
  home: Builder(
    builder:
        (c) => Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: TextButton(
              onPressed:
                  () => Navigator.of(c).push(
                    MaterialPageRoute(
                      builder: (_) => const Scaffold(body: Text('next')),
                    ),
                  ),
              child: const Text('open'),
            ),
          ),
        ),
  ),
);

Finder _clip() =>
    find.ancestor(of: find.text('next'), matching: find.byType(ClipPath));

void main() {
  testWidgets('pages open as a circle from the tap', (t) async {
    await t.pumpWidget(_app());
    final tap = t.getCenter(find.text('open'));
    await t.tap(find.text('open'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 200));
    expect(TapOrigin.last, tap);
    expect(_clip(), findsOneWidget);
    await t.pumpAndSettle();
    expect(_clip(), findsNothing);
    expect(find.text('next'), findsOneWidget);
  });

  testWidgets('reduced motion fades instead', (t) async {
    await t.pumpWidget(_app(reduced: true));
    await t.tap(find.text('open'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(_clip(), findsNothing);
    await t.pumpAndSettle();
    expect(find.text('next'), findsOneWidget);
  });

  testWidgets('theme switch applies at once with reduced motion', (t) async {
    await t.pumpWidget(_app(reduced: true));
    var applied = false;
    await ThemeReveal.run(() => applied = true);
    expect(applied, isTrue);
  });

  testWidgets('theme switch reveals over the old screen', (t) async {
    await t.pumpWidget(_app());
    final before = find.byType(CustomPaint).evaluate().length;
    var applied = false;
    await t.runAsync(() async {
      ThemeReveal.run(() => applied = true);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await t.pump();
    await t.pump(const Duration(milliseconds: 200));
    expect(applied, isTrue);
    expect(find.byType(CustomPaint).evaluate().length, before + 1);
    await t.pumpAndSettle();
    // The run was started in the real zone; let its ending run there too.
    await t.runAsync(() => Future<void>.delayed(Duration.zero));
    await t.pump();
    expect(find.byType(CustomPaint).evaluate().length, before);
  });
}
