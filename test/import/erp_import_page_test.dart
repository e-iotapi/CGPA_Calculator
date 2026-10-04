import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/features/import/erp_import_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester t, Widget child, {bool still = false}) async {
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: AppPalette.light.materialTheme,
      builder:
          (c, child) => MediaQuery(
            data: MediaQuery.of(c).copyWith(disableAnimations: still),
            child: child!,
          ),
      home: child,
    ),
  );
  await t.pump();
}

/// The nudge: a scale transition over the strip (UI_OPT O6.2).
final _nudge = find.ancestor(
  of: find.text('Install Pointer'),
  matching: find.byType(ScaleTransition),
);

void main() {
  testWidgets('no nudge under reduced motion', (t) async {
    await _pump(
      t,
      ErpImportPage(onDone: () {}, installable: true),
      still: true,
    );
    await t.scrollUntilVisible(find.text('Install Pointer'), 200);
    await t.pump();
    expect(t.binding.transientCallbackCount, 0);
    await _pump(t, ErpImportPage(onDone: () {}, installable: true));
    await t.scrollUntilVisible(find.text('Install Pointer'), 200);
    await t.pump();
    expect(t.binding.transientCallbackCount, greaterThan(0));
  });

  testWidgets('the nudge moves a layer, not widgets', (t) async {
    await _pump(t, ErpImportPage(onDone: () {}, installable: true));
    await t.scrollUntilVisible(find.text('Install Pointer'), 200);
    expect(_nudge, findsOneWidget);
    expect(
      find.ancestor(of: _nudge, matching: find.byType(RepaintBoundary)),
      findsWidgets,
    );
    final label = t.widget(find.text('Install Pointer'));
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 450));
    }
    expect(identical(t.widget(find.text('Install Pointer')), label), isTrue);
  });

  testWidgets('Skip calls onDone', (t) async {
    var done = 0;
    await _pump(t, ErpImportPage(onDone: () => done++, installable: false));
    await t.tap(find.text('Skip — I will enter grades myself'));
    expect(done, 1);
  });

  testWidgets('Settings mode has no Skip', (t) async {
    await _pump(t, const ErpImportPage());
    expect(find.textContaining('Skip'), findsNothing);
  });
}
