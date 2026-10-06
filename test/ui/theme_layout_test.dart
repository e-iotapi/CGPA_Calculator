// Light and dark lay every text and icon out in the same place: a border
// only one theme drew padded the nav by 1 px (owner, 2026-10-06).
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/features/more/more_page.dart';
import 'package:cgpa_calculator/shared/layout/responsive.dart';
import 'package:cgpa_calculator/shared/widgets/app_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<Map<String, Rect>> layout(
    WidgetTester t,
    AppPalette p,
    double w,
  ) async {
    t.view.physicalSize = Size(w, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: p.materialTheme,
        home: ResponsiveScaffold(
          destinations: const [
            NavDestination(icon: Icons.home_outlined, label: 'Home'),
            NavDestination(icon: Icons.bar_chart, label: 'Stats'),
            NavDestination(icon: Icons.apps, label: 'More'),
          ],
          selectedIndex: 2,
          onSelected: (_) {},
          body: const MorePage(),
        ),
      ),
    );
    await t.pump(const Duration(seconds: 1));
    final out = <String, Rect>{};
    var n = 0;
    void visit(Element e) {
      final r = e.renderObject;
      if (e.widget is Text || e.widget is Icon || e.widget is RichText) {
        if (r is RenderBox && r.hasSize && r.attached) {
          final o = r.localToGlobal(Offset.zero);
          out['${n++} ${e.widget.runtimeType} ${e.widget is Text
                  ? (e.widget as Text).data
                  : e.widget is Icon
                  ? (e.widget as Icon).icon?.codePoint
                  : ''}'] =
              o & r.size;
        }
      }
      e.visitChildren(visit);
    }

    t.binding.rootElement!.visitChildren(visit);
    return out;
  }

  for (final w in [390.0, 1280.0]) {
    testWidgets('light and dark match at $w px', (t) async {
      final light = await layout(t, AppPalette.light, w);
      await t.pumpWidget(const SizedBox());
      final dark = await layout(t, AppPalette.dark, w);
      expect(dark, light);
    });
  }
}
