// Renders the shell at phone, tablet and desktop widths with the real fonts
// and writes PNGs, for eyeballing layout without a browser.
//
//   SHOTS_DIR=/some/dir flutter test test/shared/nav_screenshots_test.dart
//
// Skipped when SHOTS_DIR is unset.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/shared/layout/responsive.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/app_nav.dart';
import 'package:cgpa_calculator/shared/widgets/grade_chip.dart';
import 'package:cgpa_calculator/shared/widgets/pill_button.dart';
import 'package:cgpa_calculator/shared/widgets/stat_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fonts.dart';

final _out = Platform.environment['SHOTS_DIR'];

class _SampleBody extends StatelessWidget {
  const _SampleBody();

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return ListView(
      padding: const EdgeInsets.all(Space.gutter),
      children: [
        Text(
          'Good evening',
          style: TypeScale.caption.copyWith(color: p.textMuted),
        ),
        Text('Siddharth', style: TypeScale.title.copyWith(color: p.text)),
        const SizedBox(height: Space.md),
        const Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'SGPA',
                value: '9.17',
                caption: '24 credits · 4-1',
                hero: true,
              ),
            ),
            SizedBox(width: 11),
            Expanded(
              child: StatCard(
                label: 'CGPA',
                value: '7.71',
                caption: '158 credits',
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.md),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            PillButton(label: '4 - 1', selected: true, onPressed: () {}),
            PillButton(label: '3 - 2', onPressed: () {}),
            PillButton(label: '3 - 1', onPressed: () {}),
            PillButton.icon(
              icon: Icons.download_rounded,
              semanticLabel: 'Export',
              onPressed: () {},
            ),
          ],
        ),
        const SizedBox(height: Space.md),
        for (final (title, grade) in const [
          (
            'Principles of Programming Languages and Compiler Construction',
            'B-',
          ),
          ('Business Analysis and Valuation', 'A'),
          ('Theory of Computation', 'B'),
          ('Operating Systems', 'A-'),
        ]) ...[
          AppCard(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TypeScale.body.copyWith(color: p.text),
                  ),
                ),
                const SizedBox(width: Space.md),
                GradeChip(grade),
              ],
            ),
          ),
          const SizedBox(height: 9),
        ],
      ],
    );
  }
}

void main() {
  setUpAll(() async {
    if (_out != null) await loadAppFonts();
  });

  const shots = {
    'phone_320': Size(320, 640),
    'phone_390': Size(390, 844),
    'tablet_768': Size(768, 1024),
    'desktop_1440': Size(1440, 900),
  };

  for (final palette in [
    AppPalette.light,
    AppPalette.dark,
    AppPalette.named.first,
  ]) {
    for (final MapEntry(key: name, value: size) in shots.entries) {
      testWidgets('${palette.name} $name', skip: _out == null, (t) async {
        t.view.physicalSize = size * 2;
        t.view.devicePixelRatio = 2;
        addTearDown(t.view.reset);
        await t.pumpWidget(
          RepaintBoundary(
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: palette.materialTheme,
              home: ResponsiveScaffold(
                destinations: const [
                  NavDestination(icon: Icons.home_outlined, label: 'Actual'),
                  NavDestination(
                    icon: Icons.bar_chart_rounded,
                    label: 'Expected',
                  ),
                  NavDestination(
                    icon: Icons.compare_arrows_rounded,
                    label: 'Compare',
                  ),
                  NavDestination(
                    icon: Icons.workspace_premium_outlined,
                    label: 'Offshoot',
                  ),
                ],
                selectedIndex: 0,
                onSelected: (_) {},
                body: const _SampleBody(),
              ),
            ),
          ),
        );
        expect(t.takeException(), isNull);
        await t.runAsync(() async {
          final image = await captureImage(
            t.element(find.byType(RepaintBoundary).first),
          );
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          File(
            '$_out/${palette.name.toLowerCase()}_$name.png',
          ).writeAsBytesSync(png!.buffer.asUint8List());
        });
      });
    }
  }
}
