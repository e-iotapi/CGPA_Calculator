import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The original lib/constants.dart, verbatim from before the palette existed.
import '../fixtures/legacy_constants.dart' as legacy;

void main() {
  test('named palettes keep every original theme, in order', () {
    expect(
      AppPalette.named.map((p) => p.name),
      legacy.themes.map((c) => c.theme),
    );
  });

  for (final old in legacy.themes) {
    test('${old.theme} keeps all nine colours', () {
      final p = AppPalette.named.firstWhere((p) => p.name == old.theme);
      expect(p.backcolor, old.backcolor);
      expect(p.textcolor, old.textcolor);
      expect(p.sepcolor, old.sepcolor);
      expect(p.highcolor, old.highcolor);
      expect(p.cardcolor, old.cardcolor);
      expect(p.bordcolor, old.bordcolor);
      expect(p.unscolor, old.unscolor);
      expect(p.butcolor, old.butcolor);
      expect(p.iconcolor, old.iconcolor);
    });
  }

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
