import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/features/contribute/contribute_data.dart';
import 'package:cgpa_calculator/features/resources/bookmarks.dart';
import 'package:cgpa_calculator/features/resources/bookmarks_page.dart';
import 'package:cgpa_calculator/features/resources/resource_course_page.dart';
import 'package:cgpa_calculator/features/resources/resources_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_data.dart';

// Apart from resources_screens_test: a head fetch an earlier test there
// leaves pending would hold this one's campus load.
void main() {
  setUpAll(seedAll);

  Future<void> open(WidgetTester t, As who, Widget page) async {
    contributePromptShown = true;
    roleStore = RoleStore(sharedDb, me: who.email, myName: who.name);
    myRoles.value = who.roles;
    myUid = 'u-test';
    addTearDown(() => myRoles.value = MyRoles.none);
    await t.pumpWidget(
      MaterialApp(theme: AppPalette.light.materialTheme, home: page),
    );
    await settle(t);
  }

  // Search covers every link on campus, and a search that found nothing
  // followed by an opened link teaches the pair (owner, 2026-10-06).
  testWidgets('hub search finds links and learns a retry', (t) async {
    await open(t, As.student, const ResourcesPage());
    await t.enterText(find.byType(TextField), 'zzqq');
    await settle(t);
    expect(find.textContaining('No links match'), findsOneWidget);
    await t.pump(const Duration(seconds: 1));
    await t.enterText(find.byType(TextField), 'lab sheets');
    await settle(t);
    expect(find.text('OS lab sheets'), findsOneWidget);
    await t.tap(find.text('OS lab sheets'));
    await settle(t);
    final q =
        (await sharedDb.collection('searchHints').doc('goa').get()).data()?['q']
            as Map?;
    expect(q?['zzqq'], {'lab sheets': 1});
    await t.enterText(find.byType(TextField), '');
    await settle(t);
    expect(find.text('Course resources'), findsOneWidget);
  });

  // Bookmarks from any link row land on the Bookmarked page (owner,
  // 2026-10-06).
  testWidgets('a bookmarked link shows on Bookmarked', (t) async {
    bookmarks.value = {};
    await open(t, As.student, const ResourceCoursePage(courseId: takingId));
    await t.tap(find.byTooltip('Bookmark').first);
    await t.pump();
    expect(bookmarks.value.values.map((r) => r.title), ['OS lab sheets']);
    expect(find.byTooltip('Remove bookmark'), findsOneWidget);
    await open(t, As.student, const BookmarksPage());
    expect(find.text('OS lab sheets'), findsOneWidget);
    await t.tap(find.byTooltip('Remove bookmark'));
    await t.pump();
    expect(find.text('OS lab sheets'), findsNothing);
  });
}
