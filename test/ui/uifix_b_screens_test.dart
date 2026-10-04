// Lane B screens that match the UI Directions boards: the leaderboard (full),
// then, as they are added, the review gate, contributors, GEN claim and the
// "last updated" rows.
//
//   SHOTS_DIR=/some/dir flutter test test/ui/uifix_b_screens_test.dart
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/features/contribute/contribute_page.dart';
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
    'points': 28,
  });
  await seedGrant();
}

/// The student holds a contributor grant on Goa.
Future<void> seedGrant() async {
  await sharedDb
      .collection('grants')
      .doc(grantId(GrantRole.contributor, 'goa', 'goa', studentEmail))
      .set(
        Grant(
          role: GrantRole.contributor,
          email: studentEmail,
          name: 'Owl',
          campus: 'goa',
          scope: 'goa',
          active: true,
          expiresAt: DateTime.now().add(const Duration(days: 300)),
        ).toMap(),
      );
}

/// My four links, one of each state.
Future<void> seedLinks() async {
  final now = DateTime.now();
  int ago(int days) => now.subtract(Duration(days: days)).millisecondsSinceEpoch;
  Future<void> add(
    String id,
    String title,
    int days, {
    String scope = 'department',
    String dept = 'CS',
    List<String> courses = const [],
    bool approved = true,
    bool removed = false,
    String reason = '',
    int? published,
  }) => sharedDb.collection('resources').doc(id).set({
    'title': title,
    'url': 'https://drive.google.com/$id',
    'host': 'drive.google.com',
    'campus': 'goa',
    'department': dept,
    'scope': scope,
    'courseIds': courses,
    'addedBy': {'name': 'Owl', 'email': studentEmail},
    'addedAt': ago(days),
    'removed': removed,
    'approved': approved,
    if (published != null) 'publishedAt': published,
    if (reason.isNotEmpty) 'rejectedReason': reason,
  });
  await add('l1', 'CS F301 lecture notes', 10, scope: 'course', courses: ['CS F301']);
  await add('l2', 'Mid-sem papers 2024-25', 5, approved: false, published: ago(4));
  await add('l3', 'Old slides', 14, scope: 'course', courses: ['CS F111'], approved: false, removed: true, reason: 'the link needs access');
  await add('l4', 'Quiz answers', 22, dept: 'ECE', approved: false, published: ago(20));
}

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await seedAll();
    await seedBoard();
    await seedLinks();
  });

  final screens = <(String, Widget Function(), double)>[
    ('b_leaderboard', () => const LeaderboardPage(), 844),
    ('b_more_board', () => const MorePage(), 844),
    ('b_contribute_home', () => const ContributePage(), 844),
  ];
  for (final (name, screen, tall) in screens) {
    testWidgets(name, (t) async {
      final errors = await renderScreen(t, name, screen, tall: tall);
      expectRender(name, errors, const {});
    });
  }
}
