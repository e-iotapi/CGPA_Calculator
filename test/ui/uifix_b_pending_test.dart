// "Application sent" for a student whose application is waiting.
//
//   SHOTS_DIR=/some/dir flutter test test/ui/uifix_b_pending_test.dart
import 'package:cgpa_calculator/core/contrib/contributor_store.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cgpa_calculator/features/contribute/contribute_page.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_data.dart';
import '../helpers/fonts.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await seedAll();
    final s = ContributorStore(
      RoleStore(sharedDb, me: studentEmail, myName: 'Owl'),
    );
    await s.claimUsername('goa', 'quietfalcon42');
    await s.apply('goa', 'CS');
  });

  testWidgets('b_pending', (t) async {
    final errors = await renderScreen(
      t,
      'b_pending',
      () => const ContributePage(),
    );
    expectRender('b_pending', errors, const {});
  });
}
