// Add links and Edit link, filled in like their boards.
//
//   SHOTS_DIR=/some/dir flutter test test/ui/uifix_b_add_test.dart
import 'package:cgpa_calculator/features/contribute/add_page.dart';
import 'package:cgpa_calculator/features/contribute/edit_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_data.dart';
import '../helpers/fonts.dart';
import 'uifix_b_screens_test.dart' show seedGrant, seedLinks;

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await seedAll();
    await seedGrant();
    await seedLinks();
  });

  testWidgets('b_contribute_add', (t) async {
    final errors = await renderScreen(
      t,
      'b_contribute_add',
      () => const AddPage(),
      open: (t) async {
        await t.tap(find.text('A course'));
        await t.pump();
        await t.enterText(find.byType(TextField).first, 'CS F211');
        await t.pump();
        await t.tap(find.textContaining('CS F211 ·'));
        await t.pump();
        final f = find.byType(TextField);
        await t.enterText(f.at(0), 'Lecture notes, weeks 1–6');
        await t.enterText(f.at(1), 'https://drive.google.com/…');
        await t.scrollUntilVisible(
          find.text('Another link'),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        await t.drag(find.byType(Scrollable).first, const Offset(0, -150));
        await t.pump();
        await t.tap(find.text('Another link'));
        await t.pump();
        await t.scrollUntilVisible(
          find.text('LINK 2'),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        await t.enterText(find.byType(TextField).at(2), 'Past quizzes');
        await t.enterText(
          find.byType(TextField).at(3),
          'https://drive.google.com/…',
        );
        await t.pump();
      },
    );
    expectRender('b_contribute_add', errors, const {});
  });

  testWidgets('b_contribute_edit', (t) async {
    final errors = await renderScreen(
      t,
      'b_contribute_edit',
      () => const EditPage(id: 'l2'),
    );
    expectRender('b_contribute_edit', errors, const {});
  });
}
