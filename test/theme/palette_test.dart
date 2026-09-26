import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The original lib/constants.dart, verbatim from before the palette existed.
import '../fixtures/legacy_constants.dart' as legacy;

void main() {
  test('only White and Black are offered', () {
    expect(AppPalette.named.map((p) => p.name), ['White', 'Black']);
    expect(AppPalette.named[0].background, AppPalette.light.background);
    expect(AppPalette.named[1].background, AppPalette.dark.background);
  });

  // Every theme a user could have saved before, taken from the original list.
  for (final old in legacy.themes) {
    test('saved "${old.theme}" falls back to the mode it resembled', () {
      final wasDark =
          ThemeData.estimateBrightnessForColor(old.backcolor) ==
          Brightness.dark;
      final now = AppPalette.named.firstWhere(
        (p) => p.name == AppPalette.resolveName(old.theme),
      );
      expect(now.isDark, wasDark);
    });
  }

  test('an unknown saved name falls back to White', () {
    expect(AppPalette.resolveName('Sunset'), 'White');
  });

  test('materialTheme seeds from the accent, as MyApp did before', () {
    for (final p in AppPalette.named) {
      expect(
        p.materialTheme.colorScheme,
        ColorScheme.fromSeed(seedColor: p.highcolor),
      );
      expect(p.materialTheme.extension<AppPalette>(), same(p));
    }
  });

  test('every grade has a tone, and unknown grades fall back to neutral', () {
    for (final p in [AppPalette.light, AppPalette.dark, ...AppPalette.named]) {
      for (final g in ['A', 'A-', 'B', 'B-', 'C', 'C-', 'D', 'E', 'NC']) {
        expect(p.gradeTone(g), isNot(same(p.mutedTone)), reason: g);
      }
      for (final g in ['GD', 'RC', 'W', 'CLR', '–', '?']) {
        expect(p.gradeTone(g), same(p.mutedTone), reason: g);
      }
    }
  });
}
