// UI_OPT O4.2: cards clip only when asked; the shape still rounds them.
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<Material> card(WidgetTester t, AppCard c) async {
    await t.pumpWidget(
      MaterialApp(theme: AppPalette.light.materialTheme, home: c),
    );
    return t.widget<Material>(
      find
          .descendant(of: find.byType(AppCard), matching: find.byType(Material))
          .first,
    );
  }

  testWidgets('AppCard defaults to Clip.none', (t) async {
    final m = await card(t, const AppCard(child: Text('a')));
    expect(m.clipBehavior, Clip.none);
  });

  testWidgets('a card of edge-to-edge rows clips', (t) async {
    final m = await card(
      t,
      const AppCard(padding: EdgeInsets.zero, child: Text('a')),
    );
    expect(m.clipBehavior, Clip.antiAlias);
  });

  testWidgets('clip: false turns it off', (t) async {
    final m = await card(
      t,
      const AppCard(padding: EdgeInsets.zero, clip: false, child: Text('a')),
    );
    expect(m.clipBehavior, Clip.none);
  });

  testWidgets('clip: true clips to the rounded shape', (t) async {
    final m = await card(t, const AppCard(clip: true, child: Text('a')));
    expect(m.clipBehavior, Clip.antiAlias);
  });
}
