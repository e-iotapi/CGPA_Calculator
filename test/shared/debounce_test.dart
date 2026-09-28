// UI_OPT O5.2: a search runs once typing pauses.
import 'package:cgpa_calculator/features/setup/programme_pick_page.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/core/models/programmes.dart';
import 'package:cgpa_calculator/shared/debounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('search waits for a pause', (t) async {
    final typed = Debouncer();
    addTearDown(typed.dispose);
    var runs = 0;
    for (var i = 0; i < 5; i++) {
      typed(() => runs++);
      await t.pump(const Duration(milliseconds: 50));
    }
    expect(runs, 0);
    await t.pump(const Duration(milliseconds: 150));
    expect(runs, 1);
  });

  testWidgets('the programme list follows the search after a pause', (t) async {
    final all = programmesAt(Campus.goa);
    await t.pumpWidget(
      MaterialApp(
        theme: AppPalette.light.materialTheme,
        home: ProgrammePickPage(heading: 'Pick a programme', options: all),
      ),
    );
    final other = all.firstWhere((p) => p.code != 'A7');
    expect(find.text(other.name), findsOneWidget);
    await t.enterText(find.byType(TextField), 'A7');
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text(other.name), findsOneWidget);
    await t.pump(const Duration(milliseconds: 150));
    expect(find.text(other.name), findsNothing);
  });
}
