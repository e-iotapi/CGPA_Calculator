// U1: star ratings in the Add course rows, from the saved review index.
import 'dart:convert';
import 'dart:io';

import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/core/cache/cache_first.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/reviews/review_widgets.dart';
import 'package:cgpa_calculator/features/semester/add_course_sheet.dart';
import 'package:cgpa_calculator/mastercourselist.dart';
import 'package:cgpa_calculator/core/grading/cgpa.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

/// A Firestore that is unreachable.
class _Down implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw FirebaseException(plugin: 'firestore', code: 'unavailable');
}

const _me = 'f20230456@goa.bits-pilani.ac.in';

final _master = [
  Mastercourselist(title: 'Aerodynamics', id: 'AN F311', credits: 3),
  Mastercourselist(title: 'Aerodynamics Lab', id: 'AN F312', credits: 1),
  Mastercourselist(title: 'Aerospace Propulsion', id: 'AN F341', credits: 3),
];

final _held = [
  Course(
    title: 'AN F341',
    id: 'AN F341',
    credits: 3,
    grade1: 9,
    grade2: -2,
    discipline: 'A7',
    sem: '3 - 2',
    elective: 'CDCN',
  ),
];

Widget _sheet() => MaterialApp(
  theme: AppPalette.light.materialTheme,
  home: Scaffold(
    body: AddCourseSheet(
      held: _held,
      sem: '4 - 1',
      discipline: 'A7--',
      profile: Profile.actual,
      master: _master,
    ),
  ),
);

Map<String, dynamic> _index = {
  'AN F311': {'count': 12, 'starSum': 48, 'recommendCount': 9},
  'AN F312': {'count': 0, 'starSum': 0, 'recommendCount': 0},
  'AN F341': {'count': 5, 'starSum': 25, 'recommendCount': 5},
};

void main() {
  tearDown(() {
    roleStore = null;
  });

  Future<void> search(WidgetTester t) async {
    await t.enterText(find.byType(TextField), 'aero');
    await t.pump(const Duration(milliseconds: 200));
  }

  testWidgets('rows show stars and count; none yet; held row unchanged', (
    t,
  ) async {
    final db = FakeFirebaseFirestore();
    await db.doc('reviewIndex/goa').set({'c': _index});
    roleStore = RoleStore(db, me: _me, myName: 'S');
    await t.pumpWidget(_sheet());
    await t.pump();
    await search(t);
    expect(find.text('4.0 · 12 reviews'), findsOneWidget);
    expect(t.widget<Stars>(find.byType(Stars)).value, 4);
    expect(find.text('No ratings yet'), findsOneWidget);
    // The held course is "ADDED" with no rating, whatever the index says.
    expect(find.text('ADDED'), findsOneWidget);
    expect(find.text('5.0 · 5 reviews'), findsNothing);
    expect(find.text('Ratings did not load'), findsNothing);
  });

  testWidgets('a failed load: notice, rows without stars, still tappable', (
    t,
  ) async {
    roleStore = RoleStore(_Down(), me: _me, myName: 'S');
    await t.pumpWidget(_sheet());
    await t.pump();
    await search(t);
    expect(find.text('Ratings did not load'), findsOneWidget);
    expect(find.textContaining('review'), findsNothing);
    expect(find.text('No ratings yet'), findsNothing);
    await t.tap(find.text('Aerodynamics').first);
    await t.pump();
    expect(find.textContaining('Add to 4', findRichText: true), findsOneWidget);
  });

  testWidgets('the button reads Add to <semester>, no SGPA preview', (t) async {
    roleStore = null;
    await t.pumpWidget(_sheet());
    await search(t);
    await t.tap(find.text('Aerodynamics').first);
    await t.pump();
    final texts = [
      for (final w in t.widgetList<RichText>(find.byType(RichText)))
        w.text.toPlainText(),
    ];
    expect(texts.where((x) => x.startsWith('Add to ')), ['Add to 4 − 1']);
    expect(texts.any((x) => x.contains('SGPA')), isFalse);
  });

  testWidgets('nospin: the saved index draws at once, even offline', (t) async {
    await t.runAsync(() async {
      Hive.init((await Directory.systemTemp.createTemp('rix_peek')).path);
      await openSharedCache();
      await sharedCacheBox!.put('rix|goa', jsonEncode({'at': 0, 'v': _index}));
    });
    addTearDown(() => t.runAsync(Hive.close));
    roleStore = RoleStore(_Down(), me: _me, myName: 'S');
    await t.pumpWidget(_sheet());
    // First frame, before any load settles.
    await search(t);
    expect(find.text('4.0 · 12 reviews'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await t.pump();
    // The failed refresh keeps the saved copy and shows no notice.
    expect(find.text('Ratings did not load'), findsNothing);
    expect(find.text('4.0 · 12 reviews'), findsOneWidget);
  });
}
