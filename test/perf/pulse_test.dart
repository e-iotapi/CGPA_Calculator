// UI_OPT O6.1: the Reported pulse moves layers, not widgets, and stops when
// its page is covered.
import 'package:cgpa_calculator/admin/dept_resources.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _label = '2 LINKS REPORTED';

Future<GlobalKey<NavigatorState>> _pump(
  WidgetTester t, {
  bool still = false,
}) async {
  final nav = GlobalKey<NavigatorState>();
  await t.pumpWidget(
    MaterialApp(
      navigatorKey: nav,
      theme: AppPalette.light.materialTheme,
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: still),
            child: child!,
          ),
      home: const Scaffold(
        body: Center(child: PulsingTab(label: _label, active: true)),
      ),
    ),
  );
  return nav;
}

void main() {
  testWidgets('the pulse rebuilds nothing per tick', (t) async {
    await _pump(t);
    final label = t.widget(find.text(_label));
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    expect(t.binding.transientCallbackCount, greaterThan(0));
    expect(identical(t.widget(find.text(_label)), label), isTrue);
  });

  testWidgets('the pulse stops under a pushed page', (t) async {
    final nav = await _pump(t);
    nav.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Scaffold()),
    );
    // Settles only if the covered pulse has stopped.
    await t.pumpAndSettle();
    expect(t.binding.transientCallbackCount, 0);
    nav.currentState!.pop();
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    expect(t.binding.transientCallbackCount, greaterThan(0));
  });

  testWidgets('reduced motion keeps a slower dot, no ring', (t) async {
    await _pump(t, still: true);
    await t.pump(const Duration(milliseconds: 100));
    expect(t.binding.transientCallbackCount, greaterThan(0));
    expect(
      find.descendant(
        of: find.byType(PulsingTab),
        matching: find.byType(Transform),
      ),
      findsNothing,
    );
  });
}
