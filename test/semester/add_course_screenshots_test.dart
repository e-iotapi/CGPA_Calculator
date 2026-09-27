// SHOTS_DIR=/some/dir flutter test test/semester/add_course_screenshots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/core/grading/cgpa.dart';
import 'package:cgpa_calculator/features/semester/add_course_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fonts.dart';

final _shots = Platform.environment['SHOTS_DIR'];

void main() {
  setUpAll(() async {
    if (_shots != null) await loadAppFonts();
  });

  for (final palette in [AppPalette.light, AppPalette.dark]) {
    for (final (name, size) in const [
      ('320', Size(320, 640)),
      ('390', Size(390, 844)),
    ]) {
      testWidgets('selected card, ${palette.name} $name', (t) async {
        t.view.physicalSize = size * 2;
        t.view.devicePixelRatio = 2;
        addTearDown(t.view.reset);
        await t.pumpWidget(
          RepaintBoundary(
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: palette.materialTheme,
              home: Scaffold(
                backgroundColor: palette.background,
                body: Builder(
                  builder:
                      (c) => Center(
                        child: TextButton(
                          onPressed:
                              () => showAddCourseSheet(
                                c,
                                held: const [],
                                sem: '1 - 1',
                                discipline: 'B3A7',
                                profile: Profile.actual,
                              ),
                          child: const Text('open'),
                        ),
                      ),
                ),
              ),
            ),
          ),
        );
        await t.tap(find.text('open'));
        await t.pumpAndSettle();
        await t.enterText(find.byType(TextField), 'BITS F101');
        await t.pumpAndSettle();
        await t.tap(find.textContaining('Navigating Campus').last);
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);

        if (_shots != null) {
          await t.runAsync(() async {
            final img = await captureImage(
              t.element(find.byType(RepaintBoundary).first),
            );
            final png = await img.toByteData(format: ui.ImageByteFormat.png);
            File(
              '$_shots/add_course_${palette.name.toLowerCase()}_$name.png',
            ).writeAsBytesSync(png!.buffer.asUint8List());
          });
        }
        // The card sits above the action bar without scrolling to it.
        final submit = find.textContaining('Add to', findRichText: true);
        expect(submit, findsOneWidget);
        final notYet = t.getBottomLeft(find.text('Not yet')).dy;
        expect(notYet, lessThan(t.getTopLeft(submit).dy), reason: name);
        expect(t.getBottomLeft(submit).dy, lessThanOrEqualTo(size.height));
      });
    }
  }
}
