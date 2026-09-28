import 'dart:io';

import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../agent_toolchains/ui_check/ui_checks.dart';

/// Where screenshot tests write PNGs; null skips them.
final shotsDir = Platform.environment['SHOTS_DIR'];

/// Board sizes: the boards are drawn at 390 wide; 320 is the narrowest
/// phone §15 checks.
const boardSizes = [('390', Size(390, 844)), ('320', Size(320, 640))];

/// Pumps [screen] in light and dark at each of [sizes] and writes
/// `$SHOTS_DIR/<name>_<light|dark>_<width>.png`, with a .json of its
/// [uiIssues] beside it. Fails on any overflow.
/// Pass a taller size to see the whole of a board drawn full length.
Future<void> shoot(
  WidgetTester t,
  String name,
  Widget Function() screen, {
  List<(String, Size)> sizes = boardSizes,
  double textScale = 1,
  Future<void> Function(WidgetTester t)? after,
}) async {
  for (final palette in [AppPalette.light, AppPalette.dark]) {
    for (final (label, size) in sizes) {
      t.view.physicalSize = size * 2;
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        RepaintBoundary(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: palette.materialTheme,
            builder:
                (c, child) => MediaQuery(
                  data: MediaQuery.of(
                    c,
                  ).copyWith(textScaler: TextScaler.linear(textScale)),
                  child: child!,
                ),
            home: screen(),
          ),
        ),
      );
      await t.pumpAndSettle();
      if (after != null) await after(t);
      expect(t.takeException(), isNull, reason: '$name $label');
      final out = shotsDir;
      if (out == null) continue;
      final mode = palette.isDark ? 'dark' : 'light';
      await recordRender(t, out, '${name}_${mode}_$label', const []);
    }
  }
}
