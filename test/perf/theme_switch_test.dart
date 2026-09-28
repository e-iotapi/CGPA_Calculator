import 'package:cgpa_calculator/app/theme/circle_reveal.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'perf_helpers.dart';

Widget _screen() => Container(width: 200, height: 200, color: Colors.red);

class _ThemeToggleHost extends StatefulWidget {
  const _ThemeToggleHost({required this.zeroDuration, required this.child});

  final bool zeroDuration;
  final Widget child;

  @override
  State<_ThemeToggleHost> createState() => _ThemeToggleHostState();
}

class _ThemeToggleHostState extends State<_ThemeToggleHost> {
  var _dark = false;

  void toggle() => setState(() => _dark = true);

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: (_dark ? AppPalette.dark : AppPalette.light).materialTheme,
    themeAnimationDuration:
        widget.zeroDuration ? Duration.zero : kThemeAnimationDuration,
    home: widget.child,
  );
}

void main() {
  group('O1.1: no theme lerp', () {
    Widget app(bool zeroDuration) => _ThemeToggleHost(
      zeroDuration: zeroDuration,
      child: const BuildCounter(child: SizedBox()),
    );

    testWidgets('theme change rebuilds the app once', (t) async {
      await t.pumpWidget(app(true));
      t.state<_ThemeToggleHostState>(find.byType(_ThemeToggleHost)).toggle();
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      await t.pump(const Duration(milliseconds: 100));
      final counter = t.state<BuildCounterState>(find.byType(BuildCounter));
      expect(counter.builds, 2);
    });

    testWidgets('without themeAnimationDuration it rebuilds across the lerp', (
      t,
    ) async {
      await t.pumpWidget(app(false));
      t.state<_ThemeToggleHostState>(find.byType(_ThemeToggleHost)).toggle();
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      await t.pump(const Duration(milliseconds: 100));
      final counter = t.state<BuildCounterState>(find.byType(BuildCounter));
      expect(counter.builds, greaterThan(2));
    });
  });

  group('O1.3: a cheaper snapshot', () {
    setUp(() => ThemeReveal.captures = 0);

    testWidgets('prepare then run uses the prepared snapshot', (t) async {
      await t.pumpWidget(MaterialApp(home: ThemeReveal.root(_screen())));
      ThemeReveal.prepare();
      await t.pump();
      await t.pump();
      expect(ThemeReveal.captures, 1);
      final done = ThemeReveal.run(() {});
      await t.pumpAndSettle();
      await done;
      expect(ThemeReveal.captures, 1);
    });

    testWidgets('a prepared snapshot expires', (t) async {
      await t.pumpWidget(MaterialApp(home: ThemeReveal.root(_screen())));
      ThemeReveal.prepare();
      await t.pump();
      await t.pump();
      expect(ThemeReveal.debugPreparedImage, isNotNull);
      await t.pump(const Duration(seconds: 3));
      expect(ThemeReveal.debugPreparedImage, isNull);
    });
  });

  testWidgets('O1.4: the theme applies before the circle moves', (t) async {
    await t.pumpWidget(MaterialApp(home: ThemeReveal.root(_screen())));
    double? valueAtApply;
    final done = ThemeReveal.run(() {
      valueAtApply = ThemeReveal.debugAnimValue;
    });
    await t.pumpAndSettle();
    await done;
    expect(valueAtApply, 0);
  });

  testWidgets('O1.6: the reveal overlay has its own repaint boundary', (
    t,
  ) async {
    await t.pumpWidget(MaterialApp(home: ThemeReveal.root(_screen())));
    final done = ThemeReveal.run(() {});
    await t.pump();
    final hole = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter.runtimeType.toString() == '_HolePainter',
    );
    expect(hole, findsOneWidget);
    expect(repaintBoundaryAround(hole), findsWidgets);
    await t.pumpAndSettle();
    await done;
  });
}
