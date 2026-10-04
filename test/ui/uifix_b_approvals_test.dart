// Contributor approvals: applications, links, the reason sheet, the revoke
// dialog.
//
//   SHOTS_DIR=/some/dir flutter test test/ui/uifix_b_approvals_test.dart
import 'package:cgpa_calculator/admin/approvals.dart';
import 'package:cgpa_calculator/core/contrib/contributor_store.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_data.dart';
import '../helpers/fonts.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await seedAll();
    final now = DateTime.now();
    for (final (email, name) in [
      (cr2Email, 'Asha Rao'),
      ('f20230002@goa.bits-pilani.ac.in', 'Dev Shah'),
    ]) {
      await ContributorStore(
        RoleStore(sharedDb, me: email, myName: name),
      ).apply('goa', 'CS');
    }
    await sharedDb.collection('pending').doc('goa|CS').set({
      'batches': {
        'b1': {
          'email': studentEmail,
          'username': 'quietfalcon42',
          'at': now.subtract(const Duration(days: 4)),
          'links': {
            'a': {'title': 'Lecture notes, weeks 1–6', 'url': 'https://x.co/a'},
            'b': {'title': 'Past quizzes', 'url': 'https://x.co/b'},
            'c': {'title': 'Slides 7–12', 'url': 'https://x.co/c'},
          },
        },
        'b2': {
          'email': 'f20230002@goa.bits-pilani.ac.in',
          'username': 'bitsbyte',
          'at': now.subtract(const Duration(days: 13)),
          'links': {
            'd': {'title': 'Old slides', 'url': 'https://x.co/d'},
          },
        },
      },
    });
    await sharedDb
        .collection('grants')
        .doc(grantId(GrantRole.contributor, 'goa', 'CS', 'ramesh@goa.bits-pilani.ac.in'))
        .set(
          Grant(
            role: GrantRole.contributor,
            email: 'ramesh@goa.bits-pilani.ac.in',
            name: 'ramesh_menon',
            campus: 'goa',
            scope: 'CS',
            dept: 'CS',
            active: true,
            expiresAt: now.add(const Duration(days: 300)),
            grantedAt: DateTime(now.year, 8, 3),
          ).toMap(),
        );
  });

  Future<void> tapText(WidgetTester t, String s) async {
    await t.tap(find.textContaining(s).first);
    await t.pump(const Duration(milliseconds: 400));
    await t.pump(const Duration(milliseconds: 400));
  }

  testWidgets('b_approvals', (t) async {
    final errors = await renderScreen(
      t,
      'b_approvals',
      () => const Approvals(campus: 'goa', dept: 'CS'),
      who: As.president2,
    );
    expectRender('b_approvals', errors, const {});
  });

  testWidgets('b_approvals_links', (t) async {
    final errors = await renderScreen(
      t,
      'b_approvals_links',
      () => const Approvals(campus: 'goa', dept: 'CS'),
      who: As.president2,
      open: (t) => tapText(t, 'Links'),
    );
    expectRender('b_approvals_links', errors, const {});
  });

  testWidgets('b_approvals_reason', (t) async {
    final errors = await renderScreen(
      t,
      'b_approvals_reason',
      () => const Approvals(campus: 'goa', dept: 'CS'),
      who: As.president2,
      open: (t) async {
        await tapText(t, 'Links');
        await tapText(t, 'Reject');
      },
    );
    expectRender('b_approvals_reason', errors, const {});
  });

  testWidgets('b_approvals_revoke', (t) async {
    final errors = await renderScreen(
      t,
      'b_approvals_revoke',
      () => const Approvals(campus: 'goa', dept: 'CS'),
      who: As.president2,
      open: (t) => tapText(t, 'Revoke'),
    );
    expectRender('b_approvals_revoke', errors, const {});
  });
}
