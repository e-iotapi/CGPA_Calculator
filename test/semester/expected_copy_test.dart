// The Expected profile's round copy button (board `Expected`).
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/features/semester/widgets/copy_profile_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final button = find.byIcon(Icons.copy_rounded);

  Future<List<int>> pump(WidgetTester t) async {
    final copies = <int>[];
    await t.pumpWidget(
      MaterialApp(
        theme: AppPalette.light.materialTheme,
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
    expect(button, findsOneWidget);
    await t.pump(const Duration(seconds: 5));
    expect(button, findsOneWidget);
  });

  testWidgets('an icon only, named by its tooltip', (t) async {
    await pump(t);
    expect(find.textContaining('Copy from'), findsNothing);
    expect(
      find.byTooltip('Copy every Actual grade into Expected'),
      findsOneWidget,
    );
  });

  testWidgets('asks first; Cancel copies nothing', (t) async {
    final copies = await pump(t);
    await t.tap(button);
    await t.pumpAndSettle();
    expect(find.text('Import from Actual?'), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(copies, isEmpty);
  });

  testWidgets('Import copies once', (t) async {
    final copies = await pump(t);
    await t.tap(button);
    await t.pumpAndSettle();
    await t.tap(find.text('Import'));
    await t.pumpAndSettle();
    expect(copies, [1]);
  });

  testWidgets('ink, round, and at least a 44 px target', (t) async {
    await pump(t);
    final fab = t.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(fab.backgroundColor, AppPalette.light.inverse);
    expect(fab.shape, isA<CircleBorder>());
    final size = t.getSize(find.byType(FloatingActionButton));
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
  });
}
