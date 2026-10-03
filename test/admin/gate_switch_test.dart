// U10: the staff compulsory-reviews switch (prefetch: gate_prefetch_test.dart).
import 'dart:io';

import 'package:cgpa_calculator/admin/gate_switch.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/core/cache/cache_first.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/core/storage/courses.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/reviews/gate_ui.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  late FakeFirebaseFirestore db;

  setUpAll(() async {
    Hive.init((await Directory.systemTemp.createTemp('gate_switch')).path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(CourseAdapter());
    await Hive.openBox<Course>(coursesBoxName);
    await openSharedCache();
    await Hive.openBox('settingsBox');
  });

  setUp(() async {
    db = FakeFirebaseFirestore();
    roleStore = RoleStore(
      db,
      me: 'f20230456@goa.bits-pilani.ac.in',
      myName: 'Student',
    );
    myUid = 'u-me';
    await sharedCacheBox!.clear();
  });

  tearDown(() {
    roleStore = null;
    myUid = null;
  });

  Widget app(Widget home) =>
      MaterialApp(theme: AppPalette.light.materialTheme, home: home);

  /// Pumps on real time until [f] shows (writes finish outside fake time).
  Future<void> until(WidgetTester t, Finder f) async {
    for (var i = 0; i < 25 && f.evaluate().isEmpty; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await t.pump();
    }
  }

  testWidgets('staff row: switching on asks, off does not', (t) async {
    await t.runAsync(
      () => db.collection('reviewGate').doc('goa').set({'on': false}),
    );
    roleStore = RoleStore(db, me: 'owner@x.com', myName: 'Owner');
    await t.pumpWidget(app(const Scaffold(body: GateSwitchRow(campus: 'goa'))));
    await t.pumpAndSettle();
    expect(find.textContaining('Off'), findsOneWidget);
    await t.tap(find.byType(Switch));
    await t.pumpAndSettle();
    expect(find.text('Switch on compulsory reviews?'), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect((await db.collection('reviewGate').doc('goa').get())['on'], isFalse);
    await t.tap(find.byType(Switch));
    await t.pumpAndSettle();
    await t.tap(find.text('Switch on'));
    await until(t, find.textContaining('turned on by Owner'));
    expect((await db.collection('reviewGate').doc('goa').get())['on'], isTrue);
    expect(find.textContaining('turned on by Owner'), findsOneWidget);
    // Off: no question.
    await t.tap(find.byType(Switch));
    await until(t, find.textContaining('Off'));
    expect(find.byType(AlertDialog), findsNothing);
    expect((await db.collection('reviewGate').doc('goa').get())['on'], isFalse);
  });
}
