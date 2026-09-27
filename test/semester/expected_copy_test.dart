// The Expected profile's "Copy from Actual" button (board `Expected`).
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/features/semester/widgets/copy_profile_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<List<int>> pump(
    WidgetTester t, {
    AppPalette p = AppPalette.light,
  }) async {
    final copies = <int>[];
    await t.pumpWidget(
      MaterialApp(
        theme: p.materialTheme,
        home: Scaffold(
          floatingActionButton: CopyProfileButton(
            from: 'Actual',
            to: 'Expected',
            onCopy: () async => copies.add(1),
          ),
        ),
      ),
    );
    return copies;
  }

  testWidgets('stays up: no timer hides it', (t) async {
    await pump(t);
    expect(find.text('Copy from Actual'), findsOneWidget);
    await t.pump(const Duration(seconds: 5));
    expect(find.text('Copy from Actual'), findsOneWidget);
  });

  testWidgets('asks first; Cancel copies nothing', (t) async {
    final copies = await pump(t);
    await t.tap(find.text('Copy from Actual'));
    await t.pumpAndSettle();
    expect(find.text('Import from Actual?'), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(copies, isEmpty);
  });

  testWidgets('Import copies once', (t) async {
    final copies = await pump(t);
    await t.tap(find.text('Copy from Actual'));
    await t.pumpAndSettle();
    await t.tap(find.text('Import'));
    await t.pumpAndSettle();
    expect(copies, [1]);
  });

  testWidgets('ink in light, and fits a 44 px touch target', (t) async {
    await pump(t);
    final fab = t.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(fab.backgroundColor, AppPalette.light.inverse);
    expect(
      t.getSize(find.byType(FloatingActionButton)).height,
      greaterThanOrEqualTo(44),
    );
  });

  testWidgets('a long profile name is cut, not overflowed, at 320', (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: AppPalette.dark.materialTheme,
        home: Scaffold(
          floatingActionButton: CopyProfileButton(
            from: 'My very long renamed profile',
            to: 'Expected',
            onCopy: () async {},
          ),
        ),
      ),
    );
    expect(t.takeException(), isNull);
  });
}
