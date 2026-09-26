import 'dart:io';

import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/auth_util.dart';
import 'package:cgpa_calculator/core/models/programmes.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/import/erp_import_page.dart';
import 'package:cgpa_calculator/features/setup/degree_setup_page.dart';
import 'package:cgpa_calculator/script.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

Future<void> _pump(
  WidgetTester t,
  Widget child, {
  Size size = const Size(390, 844),
  double scale = 1,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: AppPalette.light.materialTheme,
      builder:
          (c, child) => MediaQuery(
            data: MediaQuery.of(
              c,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
      home: KeyedSubtree(key: UniqueKey(), child: child),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  group('parseBitsAddress', () {
    test('reads level, batch and campus', () {
      final a = parseBitsAddress('f20230123@goa.bits-pilani.ac.in');
      expect(a, (level: DegreeLevel.first, year: 2023, campus: Campus.goa));
      expect(parseBitsAddress('H20240456@Hyderabad.bits-pilani.ac.in'), (
        level: DegreeLevel.higher,
        year: 2024,
        campus: Campus.hyderabad,
      ));
      expect(
        parseBitsAddress('p20210001@pilani.bits-pilani.ac.in').level,
        DegreeLevel.phd,
      );
    });

    test('an unknown subdomain or year is left to ask, never guessed', () {
      final a = parseBitsAddress('f20230123@newcampus.bits-pilani.ac.in');
      expect(a.campus, isNull);
      expect(a.year, 2023);
      expect(parseBitsAddress('f19870123@goa.bits-pilani.ac.in').year, isNull);
      expect(parseBitsAddress('someone@gmail.com'), (
        level: null,
        year: null,
        campus: null,
      ));
      expect(parseBitsAddress(null).campus, isNull);
    });
  });

  test('programmes are filtered by campus', () {
    final goa = programmesAt(Campus.goa).map((p) => p.code);
    final hyd = programmesAt(Campus.hyderabad).map((p) => p.code);
    expect(goa, containsAll(['AC', 'A7', 'B3']));
    expect(goa, isNot(contains('A2')));
    expect(goa, isNot(contains('A5')));
    expect(hyd, containsAll(['A2', 'A5']));
    expect(hyd, isNot(contains('AC')));
    expect(programmeFor('AJ')?.gap, isNotNull);
  });

  group('DegreeSetupPage', () {
    late Directory dir;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('hive_setup');
      Hive.init(dir.path);
      if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(CourseAdapter());
      await Hive.openBox('settingsBox');
      await Hive.openBox<Course>('coursesBox');
    });
    tearDown(() async {
      await Hive.deleteFromDisk();
      await dir.delete(recursive: true);
      app.campus = null;
    });

    testWidgets('prefills from the address; every code has its name', (
      t,
    ) async {
      var done = 0;
      await _pump(
        t,
        DegreeSetupPage(
          email: 'f20230123@goa.bits-pilani.ac.in',
          onDone: () => done++,
        ),
      );
      expect(find.text('Goa'), findsOneWidget);
      expect(find.text('2023 batch'), findsOneWidget);
      expect(find.text('Choose a programme'), findsOneWidget);

      await t.tap(find.text('Dual degree'));
      await t.pumpAndSettle();
      await t.tap(find.bySemanticsLabel(RegExp('^FIRST DEGREE')));
      await t.pumpAndSettle();
      // The pick page: Goa's M.Sc. programmes, by name.
      expect(find.text('FIRST DEGREE · GOA'), findsOneWidget);
      expect(find.text('B.E. Computer Science'), findsNothing);
      await t.tap(find.text('M.Sc. Economics'));
      await t.pumpAndSettle();

      await t.tap(find.bySemanticsLabel(RegExp('^SECOND DEGREE')));
      await t.pumpAndSettle();
      expect(find.text('B.Pharm.'), findsNothing);
      await t.enterText(find.byType(TextField), 'computer sc');
      await t.pump();
      await t.tap(find.text('B.E. Computer Science'));
      await t.pumpAndSettle();

      // Back on setup: codes sit beside their names.
      expect(find.text('B3'), findsOneWidget);
      expect(find.text('M.Sc. Economics'), findsOneWidget);
      expect(find.text('A7'), findsOneWidget);
      expect(find.text('B.E. Computer Science'), findsOneWidget);
      expect(find.textContaining('core courses across'), findsOneWidget);
      expect(find.text('Set up B3 A7'), findsOneWidget);

      await t.ensureVisible(find.text('Set up B3 A7'));
      // Seeding writes to Hive, which needs real time.
      await t.runAsync(() async {
        await t.tap(find.text('Set up B3 A7'));
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await t.pumpAndSettle();
      expect(app.selecteddiscipline, 'B3A7');
      expect(app.batch, 23);
      expect(Hive.box('settingsBox').get('campus'), 'goa');
      expect(Hive.box<Course>('coursesBox').isNotEmpty, isTrue);

      // Step 2: the import, skippable.
      expect(find.byType(ErpImportPage), findsOneWidget);
      expect(find.text('SETUP · 2 OF 2'), findsOneWidget);
      await t.scrollUntilVisible(
        find.text('Skip — I will enter grades myself'),
        200,
      );
      await t.tap(find.text('Skip — I will enter grades myself'));
      await t.pumpAndSettle();
      expect(done, 1);
    });

    testWidgets('an address it cannot read asks, and checks the year', (
      t,
    ) async {
      await _pump(
        t,
        DegreeSetupPage(email: 'someone@gmail.com', onDone: () {}),
      );
      expect(find.text('Change'), findsNothing);
      for (final c in Campus.values) {
        expect(find.text(c.label), findsOneWidget);
      }
      await t.enterText(find.byType(TextField), '19x87');
      await t.pump();
      expect(find.text('1987'), findsOneWidget, reason: 'digits only');
      expect(find.text('Not a batch year'), findsOneWidget);
      await t.enterText(find.byType(TextField), '2024');
      await t.pump();
      expect(find.text('Not a batch year'), findsNothing);
    });

    testWidgets('a higher degree is not asked single or dual', (t) async {
      await _pump(
        t,
        DegreeSetupPage(
          email: 'h20240456@hyderabad.bits-pilani.ac.in',
          onDone: () {},
        ),
      );
      expect(find.text('Dual degree'), findsNothing);
      expect(find.text('Hyderabad'), findsOneWidget);
    });

    testWidgets('2+2 is shown but cannot be picked', (t) async {
      await _pump(
        t,
        DegreeSetupPage(
          email: 'f20230123@goa.bits-pilani.ac.in',
          onDone: () {},
        ),
      );
      expect(find.text('2+2'), findsOneWidget);
      await t.tap(find.text('2+2'));
      await t.pump();
      expect(find.textContaining('still being built'), findsOneWidget);
    });

    testWidgets('setup ends with the install offer, unless installed', (
      t,
    ) async {
      await _pump(t, ErpImportPage(onDone: () {}, installable: true));
      await t.scrollUntilVisible(find.text('Install'), 200);
      expect(find.text('Keep Pointer on your home screen'), findsOneWidget);
      await _pump(t, ErpImportPage(onDone: () {}, installable: false));
      expect(find.text('Keep Pointer on your home screen'), findsNothing);
      // Settings' import is not the end of setup.
      await _pump(t, const ErpImportPage(installable: true));
      expect(find.text('Keep Pointer on your home screen'), findsNothing);
      await _pump(
        t,
        ErpImportPage(onDone: () {}, installable: true),
        size: const Size(320, 640),
        scale: 2,
      );
      expect(t.takeException(), isNull);
    });

    testWidgets('fits 320, 768, 1440 and 200% text', (t) async {
      for (final (size, scale) in const [
        (Size(320, 640), 1.0),
        (Size(768, 1024), 1.0),
        (Size(1440, 900), 1.0),
        (Size(320, 640), 2.0),
      ]) {
        await _pump(
          t,
          DegreeSetupPage(
            email: 'f20230123@goa.bits-pilani.ac.in',
            onDone: () {},
          ),
          size: size,
          scale: scale,
        );
        expect(t.takeException(), isNull, reason: '$size $scale');
        await _pump(t, const ErpImportPage(), size: size, scale: scale);
        expect(t.takeException(), isNull, reason: 'import $size $scale');
        expect(find.text('YOUR DATA'), findsOneWidget);
        expect(find.textContaining('Skip'), findsNothing);
      }
    });
  });
}
