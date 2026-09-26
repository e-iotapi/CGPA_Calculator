import 'dart:io';
import 'dart:ui' as ui;

import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/features/settings/settings_controller.dart';
import 'package:cgpa_calculator/features/settings/settings_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fonts.dart';

void main() {
  group('rules carried over from the old screen', () {
    test('changing the MSc half always clears', () {
      final c = changeDiscipline('B3A7', dual: true, value: 'B4', erase: 0);
      expect(c, (discipline: 'B4A7', erase: 1));
    });

    test('changing the B.E. half of a dual degree keeps the MSc grades', () {
      expect(changeDiscipline('B3A7', dual: false, value: 'A3', erase: 0), (
        discipline: 'B3A3',
        erase: 2,
      ));
      expect(changeDiscipline('--A7', dual: false, value: 'A3', erase: 0), (
        discipline: '--A3',
        erase: 1,
      ));
      // A full clear already pending is never weakened.
      expect(
        changeDiscipline('B3A7', dual: false, value: 'A3', erase: 1).erase,
        1,
      );
    });

    test('picking the same value changes nothing', () {
      expect(changeDiscipline('B3A7', dual: false, value: 'A7', erase: 0), (
        discipline: 'B3A7',
        erase: 0,
      ));
    });

    test('batch clears only across 2025', () {
      expect(batchErase(24, 25, 0), 1);
      expect(batchErase(22, 24, 0), 0);
      expect(batchErase(26, 25, 0), 0);
    });

    test('profile names: empty falls back, nine letters at most', () {
      expect(profileName('  ', 'Profile 1'), 'Profile 1');
      expect(profileName('Optimistic', 'Profile 1'), 'Optimisti');
      expect(profileName('Actual', 'Profile 1'), 'Actual');
    });

    test('labels', () {
      expect(disciplineLabel('--', dual: true), 'None');
      expect(disciplineLabel('B-', dual: true), 'Other');
      expect(disciplineLabel('--', dual: false), 'Other');
      expect(disciplineOptions(dual: false).first, ('A1', 'A1'));
    });
  });

  testWidgets('lays out at 320, 768, 1440 and 200% text', (t) async {
    await loadAppFonts();
    final taps = <String>[];
    Widget view(bool dark) => SettingsView(
      name: 'Siddharth Mishra With A Very Long Name Indeed',
      email: 'f20220000000000000@goa.bits-pilani.ac.in',
      discipline: 'B3A7',
      batch: 24,
      isDark: dark,
      profile1: 'Actual',
      profile2: 'Expected',
      onClose: () => taps.add('close'),
      onPickDiscipline: (d) => taps.add(d ? 'dual' : 'discipline'),
      onPickBatch: () => taps.add('batch'),
      onTheme: (d) => taps.add('theme $d'),
      onRenameProfile: (i) => taps.add('profile $i'),
      onExport: () => taps.add('export'),
      onImportBackup: () => taps.add('backup'),
      onImportOld: () => taps.add('old'),
      onReport: () => taps.add('report'),
      onReset: () => taps.add('reset'),
      onSignOut: () => taps.add('signout'),
      onEmail: () => taps.add('email'),
      onGithub: () => taps.add('github'),
      onInstall: () => taps.add('install'),
    );

    Future<void> pump(Size size, {double scale = 1, bool dark = false}) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      await t.pumpWidget(
        MaterialApp(
          theme: (dark ? AppPalette.dark : AppPalette.light).materialTheme,
          builder:
              (c, child) => MediaQuery(
                data: MediaQuery.of(
                  c,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
          home: KeyedSubtree(key: UniqueKey(), child: view(dark)),
        ),
      );
      await t.pumpAndSettle();
    }

    addTearDown(t.view.reset);
    for (final size in const [
      Size(320, 640),
      Size(768, 1024),
      Size(1440, 900),
    ]) {
      await pump(size);
      expect(t.takeException(), isNull, reason: '$size');
    }
    await pump(const Size(320, 640), scale: 2);
    expect(t.takeException(), isNull, reason: '200%');

    await pump(const Size(390, 844));
    expect(find.text('A7'), findsOneWidget);
    expect(find.text('B3'), findsOneWidget);
    expect(find.text('2024'), findsOneWidget);
    await t.tap(find.text('Discipline'));
    await t.tap(find.text('Dark'));
    await t.tap(find.text('Profile 2'));
    await t.scrollUntilVisible(find.text('Install app'), 200);
    await t.tap(find.text('Install app'));
    await t.scrollUntilVisible(find.text('Reset courses'), 200);
    await t.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await t.pumpAndSettle();
    await t.tap(find.text('Reset courses'));
    expect(taps, ['discipline', 'theme true', 'profile 2', 'install', 'reset']);

    final shots = Platform.environment['SHOTS_DIR'];
    if (shots != null) {
      for (final dark in [false, true]) {
        await pump(const Size(390, 844), dark: dark);
        await t.runAsync(() async {
          final img = await captureImage(
            t.element(find.byType(RepaintBoundary).first),
          );
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          File(
            '$shots/settings_${dark ? 'dark' : 'light'}.png',
          ).writeAsBytesSync(png!.buffer.asUint8List());
        });
      }
    }
  });
}
