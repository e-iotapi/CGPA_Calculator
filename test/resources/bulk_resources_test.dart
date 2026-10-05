import 'package:cgpa_calculator/admin/bulk_resources.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps until [f] shows: a spinner never settles.
Future<void> until(WidgetTester t, Finder f) async {
  for (var i = 0; i < 100 && f.evaluate().isEmpty; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  late FakeFirebaseFirestore db;

  setUp(() {
    db = FakeFirebaseFirestore();
    roleStore = RoleStore(
      db,
      me: 'f20230802@goa.bits-pilani.ac.in',
      myName: 'P',
    );
  });
  tearDown(() => roleStore = null);

  testWidgets(
    'paste, preview with guessed titles, add, and skip what is there',
    (t) async {
      t.view.physicalSize = const Size(390, 1600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.runAsync(
        () => db.collection('resources').add({
          'title': 'Old',
          'url': 'https://a.com/old',
          'campus': 'goa',
          'department': 'ELEC',
          'scope': 'department',
          'courseIds': <String>[],
          'pinnedToDepartment': false,
          'removed': false,
        }),
      );
      await t.pumpWidget(
        MaterialApp(
          theme: AppPalette.light.materialTheme,
          home: const BulkResourcesPage(campus: 'goa', dept: 'ELEC'),
        ),
      );
      await t.tap(find.text('Paste'));
      await t.pumpAndSettle();
      await t.enterText(
        find.byType(TextField),
        '{"schema":"pointer.resources.v1","links":['
        '{"url":"https://a.com/notes/Midsem_2023.pdf"},'
        '{"url":"https://drive.google.com/drive/folders/1a","title":"PYQs"},'
        '{"url":"https://a.com/old"}]}',
      );
      await t.tap(find.text('Preview'));
      await until(t, find.text('2 new · 1 already there'));
      expect(find.text('2 new · 1 already there'), findsOneWidget);
      expect(find.text('Midsem 2023'), findsOneWidget);
      expect(find.text('GUESSED'), findsOneWidget);
      await t.tap(find.text('Add 2 links'));
      await t.pumpAndSettle();
      await t.tap(find.text('Add').last);
      await until(t, find.text('Done. Every link is added and logged.'));
      expect(
        find.text('Done. Every link is added and logged.'),
        findsOneWidget,
      );
      final saved = await t.runAsync(
        () =>
            db.collection('resources').where('removed', isEqualTo: false).get(),
      );
      expect(
        saved!.docs.map((d) => d['title']),
        containsAll(['Midsem 2023', 'PYQs']),
      );
      expect(saved.docs, hasLength(3));
    },
  );

  testWidgets('a bad row names itself and adds nothing', (t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: AppPalette.light.materialTheme,
        home: const BulkResourcesPage(campus: 'goa', dept: 'ELEC'),
      ),
    );
    await t.tap(find.text('Paste'));
    await t.pumpAndSettle();
    await t.enterText(
      find.byType(TextField),
      '{"schema":"pointer.resources.v1","links":[{"url":"https://a.com/x"},{"url":"nope"}]}',
    );
    await t.tap(find.text('Preview'));
    await until(t, find.text('This file cannot be used'));
    expect(find.textContaining('Link 2'), findsOneWidget);
    expect(find.text('This file cannot be used'), findsOneWidget);
  });
}
