import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/shared/layout/responsive.dart';
import 'package:cgpa_calculator/shared/widgets/app_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fonts.dart';

const _destinations = [
  NavDestination(icon: Icons.home_outlined, label: 'Actual'),
  NavDestination(icon: Icons.bar_chart_rounded, label: 'Expected'),
  NavDestination(icon: Icons.compare_arrows_rounded, label: 'Compare'),
  NavDestination(icon: Icons.workspace_premium_outlined, label: 'Offshoot'),
];

Future<void> _pump(
  WidgetTester t,
  Size size, {
  List<NavDestination> destinations = _destinations,
  int selected = 0,
  ValueChanged<int>? onSelected,
  double textScale = 1,
  AppPalette palette = AppPalette.light,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: palette.materialTheme,
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
      home: ResponsiveScaffold(
        destinations: destinations,
        selectedIndex: selected,
        onSelected: onSelected ?? (_) {},
        body: const Placeholder(key: Key('body')),
      ),
    ),
  ); // MaterialApp animates between themes; let it land.
  await t.pumpAndSettle();
}

/// Every label is on screen, not clipped to nothing, and not squashed.
void _expectLabelsLegible(WidgetTester t, List<String> labels) {
  final screen = Offset.zero & t.view.physicalSize;
  for (final l in labels) {
    final f = find.text(l);
    expect(f, findsOneWidget, reason: l);
    final r = t.getRect(f);
    expect(
      screen.contains(r.topLeft) && screen.contains(r.bottomRight),
      true,
      reason: '$l at $r is off screen',
    );
    expect(r.width, greaterThan(20), reason: '$l is squashed to ${r.width}');
    expect(r.height, greaterThanOrEqualTo(10), reason: l);
  }
}

void main() {
  setUpAll(loadAppFonts);

  final labels = _destinations.map((d) => d.label).toList();

  testWidgets('320px: bottom pill, four legible labels, no overflow', (
    t,
  ) async {
    await _pump(t, const Size(320, 640));
    expect(t.takeException(), isNull);
    expect(find.byType(BottomNavigationBar), findsNothing);
    final nav = t.getRect(find.byType(AppNav));
    expect(
      nav.bottom,
      greaterThan(560),
      reason: 'nav should sit at the bottom',
    );
    expect(nav.left, greaterThanOrEqualTo(0));
    expect(nav.right, lessThanOrEqualTo(320));
    _expectLabelsLegible(t, labels);
    // No label was ellipsized at this width.
    for (final l in labels) {
      final p = t.renderObject<RenderParagraph>(find.text(l));
      expect(p.didExceedMaxLines, isFalse, reason: '$l was truncated');
    }
  });

  testWidgets('768px: pill centres at its max width instead of stretching', (
    t,
  ) async {
    await _pump(t, const Size(768, 1024));
    expect(t.takeException(), isNull);
    final nav = t.getRect(find.byType(AppNav));
    expect(nav.width, AppNav.pillMaxWidth);
    expect(nav.center.dx, closeTo(384, 0.5));
    _expectLabelsLegible(t, labels);
  });

  testWidgets('1099px is still the pill; 1100px is the rail', (t) async {
    await _pump(t, const Size(1099, 800));
    expect(t.getRect(find.byType(AppNav)).bottom, greaterThan(700));

    await _pump(t, const Size(1100, 800));
    final rail = t.getRect(find.byType(AppNav));
    expect(rail.left, lessThan(20));
    expect(rail.width, AppNav.railWidth);
  });

  testWidgets('1440px desktop: left rail, labels legible, body beside it', (
    t,
  ) async {
    await _pump(t, const Size(1440, 900));
    expect(t.takeException(), isNull);
    final rail = t.getRect(find.byType(AppNav));
    final body = t.getRect(find.byKey(const Key('body')));
    expect(rail.top, lessThan(20));
    expect(body.left, greaterThanOrEqualTo(rail.right));
    expect(body.width, lessThanOrEqualTo(1180));
    _expectLabelsLegible(t, labels);
  });

  testWidgets('long custom profile names ellipsize instead of overflowing', (
    t,
  ) async {
    const long = [
      NavDestination(icon: Icons.home_outlined, label: 'My actual grades 2026'),
      NavDestination(icon: Icons.bar_chart_rounded, label: 'Optimistic plan B'),
      NavDestination(icon: Icons.compare_arrows_rounded, label: 'Compare'),
      NavDestination(icon: Icons.workspace_premium_outlined, label: 'Offshoot'),
    ];
    for (final size in const [Size(320, 640), Size(1440, 900)]) {
      await _pump(t, size, destinations: long);
      expect(t.takeException(), isNull, reason: '$size');
    }
  });

  testWidgets('survives 200% text at 320px and on the rail', (t) async {
    for (final size in const [Size(320, 640), Size(1440, 900)]) {
      await _pump(t, size, textScale: 2);
      expect(t.takeException(), isNull, reason: '$size');
    }
  });

  testWidgets('tapping a destination reports its index', (t) async {
    final taps = <int>[];
    await _pump(t, const Size(320, 640), onSelected: taps.add);
    await t.tap(find.text('Offshoot'));
    await t.tap(find.text('Expected'));
    expect(taps, [3, 1]);
  });

  testWidgets('renders under every palette, including the legacy themes', (
    t,
  ) async {
    for (final p in [AppPalette.light, AppPalette.dark, ...AppPalette.named]) {
      await _pump(t, const Size(320, 640), palette: p, selected: 2);
      expect(t.takeException(), isNull, reason: p.name);
      final bg = t.widget<Scaffold>(find.byType(Scaffold)).backgroundColor;
      expect(bg, p.background, reason: p.name);
    }
  });
}
