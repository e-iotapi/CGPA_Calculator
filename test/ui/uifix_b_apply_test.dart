// Contributor screens for a student who has not applied: Apply, and the
// first-open prompt.
//
//   SHOTS_DIR=/some/dir flutter test test/ui/uifix_b_apply_test.dart
import 'package:cgpa_calculator/features/contribute/apply_page.dart';
import 'package:cgpa_calculator/features/contribute/contribute_data.dart';
import 'package:cgpa_calculator/features/contribute/contribute_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_data.dart';
import '../helpers/fonts.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await seedAll();
  });

  testWidgets('b_apply', (t) async {
    final errors = await renderScreen(t, 'b_apply', () => const ApplyPage());
    expectRender('b_apply', errors, const {});
  });

  testWidgets('b_contribute_prompt', (t) async {
    final errors = await renderScreen(
      t,
      'b_contribute_prompt',
      () => launcher((c) => maybeShowContributePrompt(c)),
      open: (t) async {
        contributePromptShown = false;
        await tapLauncher(t);
      },
    );
    expectRender('b_contribute_prompt', errors, const {});
  });
}
