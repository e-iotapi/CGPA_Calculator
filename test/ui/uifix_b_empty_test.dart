// Lane B screens drawn with nothing yet (no one on the board, ...), on a
// database without the data uifix_b_screens_test.dart seeds.
//
//   SHOTS_DIR=/some/dir flutter test test/ui/uifix_b_empty_test.dart
import 'package:cgpa_calculator/features/contribute/contribute_page.dart';
import 'package:cgpa_calculator/features/contribute/leaderboard_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_data.dart';
import '../helpers/fonts.dart';
import 'uifix_b_screens_test.dart' show seedGrant;

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await seedAll();
    await seedGrant();
    await sharedDb.collection('contributors').doc(studentEmail).set({
      'username': 'quietfalcon42',
    });
  });

  final screens = <(String, Widget Function(), double)>[
    ('b_leaderboard_empty', () => const LeaderboardPage(), 844),
    ('b_contribute_empty', () => const ContributePage(), 844),
  ];
  for (final (name, screen, tall) in screens) {
    testWidgets(name, (t) async {
      final errors = await renderScreen(t, name, screen, tall: tall);
      expectRender(name, errors, const {});
    });
  }
}
