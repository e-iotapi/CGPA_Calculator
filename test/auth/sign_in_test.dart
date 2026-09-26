import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/features/auth/sign_in_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fonts.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('sign-in says Pointer and fits 320, 768, 1440 and 200% text', (
    t,
  ) async {
    var taps = 0;
    for (final (size, scale) in const [
      (Size(320, 640), 1.0),
      (Size(768, 1024), 1.0),
      (Size(1440, 900), 1.0),
      (Size(320, 640), 2.0),
    ]) {
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
          home: SignInView(busy: false, onSignIn: () => taps++),
        ),
      );
      expect(t.takeException(), isNull, reason: '$size $scale');
    }
    expect(find.text('Pointer'), findsOneWidget);
    expect(
      find.text('Import every past semester from your ERP sheet'),
      findsOneWidget,
    );
    expect(find.textContaining('never uploaded'), findsOneWidget);
    await t.ensureVisible(find.bySemanticsLabel('Continue with Google'));
    await t.tap(find.bySemanticsLabel('Continue with Google'));
    expect(taps, 1);
  });
}
