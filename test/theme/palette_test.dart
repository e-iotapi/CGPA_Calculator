import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  test('materialTheme seeds from the accent, painted over with the palette', () {
    for (final p in AppPalette.named) {
      final scheme = p.materialTheme.colorScheme;
      expect(scheme.brightness, p.isDark ? Brightness.dark : Brightness.light);
      expect(scheme.primary, p.inverse);
      expect(scheme.surface, p.surface);
      expect(p.materialTheme.extension<AppPalette>(), same(p));
    }
  });

  group('T3.1: one Material theme per palette (G1)', () {
    test('brightness follows the palette', () {
      expect(AppPalette.dark.materialTheme.brightness, Brightness.dark);
      expect(AppPalette.light.materialTheme.brightness, Brightness.light);
    });

    test('body text is readable and in the app font', () {
      for (final p in [AppPalette.light, AppPalette.dark]) {
        final body = p.materialTheme.textTheme.bodyMedium!;
        expect(body.color, p.text);
        expect(body.fontFamily, TypeScale.family);
      }
    });

    testWidgets('a TextButton renders in the app font under the dark theme', (
      t,
    ) async {
      await t.pumpWidget(
        MaterialApp(
          theme: AppPalette.dark.materialTheme,
          home: const TextButton(onPressed: null, child: Text('x')),
        ),
      );
      final rp = t.renderObject<RenderParagraph>(find.text('x'));
      expect(rp.text.style!.fontFamily, TypeScale.family);
    });
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
