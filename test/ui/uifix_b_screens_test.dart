// Lane B screens that match the UI Directions boards: the leaderboard (full),
// then, as they are added, the review gate, contributors, GEN claim and the
// "last updated" rows.
//
//   SHOTS_DIR=/some/dir flutter test test/ui/uifix_b_screens_test.dart
import 'package:cgpa_calculator/features/contribute/leaderboard_page.dart';
import 'package:cgpa_calculator/features/more/more_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_data.dart';
import '../helpers/fonts.dart';

/// A campus board with eight names, and the student on it at 7th.
Future<void> seedBoard() async {
  await sharedDb.collection('leaderboard').doc('goa').set({
    'p': {
      'ece_sage': 212,
      'bitsbyte': 180,
      'ramesh_menon': 144,
      'nightowl': 96,
      'chalkdust': 81,
      'merry_mole': 63,
      'quietfalcon42': 28,
      'owl_7': 12,
    },
    'tags': {
      'ece_sage': 'B3',
      'bitsbyte': 'A3',
      'ramesh_menon': 'A7',
      'nightowl': 'A4',
      'chalkdust': 'B2',
      'merry_mole': 'A7',
      'quietfalcon42': 'A7',
    },
  });
  await sharedDb.collection('contributors').doc(studentEmail).set({
    'username': 'quietfalcon42',
  });
}

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await seedAll();
    await seedBoard();
  });

  final screens = <(String, Widget Function(), double)>[
    ('b_leaderboard', () => const LeaderboardPage(), 844),
    ('b_more_board', () => const MorePage(), 844),
  ];
  for (final (name, screen, tall) in screens) {
    testWidgets(name, (t) async {
      final errors = await renderScreen(t, name, screen, tall: tall);
      expectRender(name, errors, const {});
    });
  }
}
