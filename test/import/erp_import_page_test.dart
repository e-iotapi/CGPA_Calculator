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

final _nudge = find.byWidgetPredicate(
  (w) =>
      w is AnimatedBuilder &&
      w.animation is AnimationController &&
      (w.animation as AnimationController).duration ==
          const Duration(milliseconds: 4500),
);

void main() {
  testWidgets('no nudge under reduced motion', (t) async {
    await _pump(
      t,
      ErpImportPage(onDone: () {}, installable: true),
      still: true,
    );
    await t.scrollUntilVisible(find.text('Install Pointer'), 200);
    expect(
      find.ancestor(of: find.text('Install Pointer'), matching: _nudge),
      findsNothing,
    );
    await _pump(t, ErpImportPage(onDone: () {}, installable: true));
    await t.scrollUntilVisible(find.text('Install Pointer'), 200);
    expect(
      find.ancestor(of: find.text('Install Pointer'), matching: _nudge),
      findsWidgets,
    );
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
