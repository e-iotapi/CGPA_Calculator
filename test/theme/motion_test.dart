import 'package:cgpa_calculator/app/theme/circle_reveal.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/core/perf/device_tier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _CountingPage extends StatefulWidget {
  const _CountingPage();

  static int inits = 0;

  @override
  State<_CountingPage> createState() => _CountingPageState();
}

class _CountingPageState extends State<_CountingPage> {
  @override
  void initState() {
    super.initState();
    _CountingPage.inits++;
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('next'));
}

Widget _app({bool reduced = false}) => MaterialApp(
  theme: AppPalette.light.materialTheme,
  builder:
      (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(disableAnimations: reduced),
        child: ThemeReveal.root(TapOriginTracker(child: child!)),
      ),
  home: Builder(
    builder:
        (c) => Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: TextButton(
              onPressed:
                  () => Navigator.of(c).push(
                    MaterialPageRoute(builder: (_) => const _CountingPage()),
                  ),
              child: const Text('open'),
            ),
          ),
        ),
  ),
);

Finder _clip() =>
    find.ancestor(of: find.text('next'), matching: find.byType(ClipPath));

void main() {
  testWidgets('pages open as a circle from the tap', (t) async {
    await t.pumpWidget(_app());
    final tap = t.getCenter(find.text('open'));
    await t.tap(find.text('open'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 200));
    expect(TapOrigin.last, tap);
    expect(_clip(), findsOneWidget);
    await t.pumpAndSettle();
    // O2.1: the same ClipPath stays mounted at rest, just with no clip.
    expect(_clip(), findsOneWidget);
    expect(t.widget<ClipPath>(_clip()).clipBehavior, Clip.none);
    expect(find.text('next'), findsOneWidget);
  });

  testWidgets('no remount at the end of a push', (t) async {
    await t.pumpWidget(_app());
    _CountingPage.inits = 0;
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(_CountingPage.inits, 1);
  });

  testWidgets('low tier clips with a hard edge', (t) async {
    deviceTier = DeviceTier.low;
    addTearDown(() => deviceTier = DeviceTier.normal);
    await t.pumpWidget(_app());
    await t.tap(find.text('open'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 200));
    expect(t.widget<ClipPath>(_clip()).clipBehavior, Clip.hardEdge);
    await t.pumpAndSettle();
  });

  testWidgets('one curve per route', (t) async {
    final before = CircleRevealTransitionsBuilder.debugCurvesCreated;
    await t.pumpWidget(_app());
    await t.tap(find.text('open'));
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 20));
    }
    expect(CircleRevealTransitionsBuilder.debugCurvesCreated - before, 1);
    await t.pumpAndSettle();
  });

  testWidgets('reduced motion fades instead', (t) async {
    await t.pumpWidget(_app(reduced: true));
    await t.tap(find.text('open'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(_clip(), findsNothing);
    await t.pumpAndSettle();
    expect(find.text('next'), findsOneWidget);
  });

  testWidgets('theme switch applies at once with reduced motion', (t) async {
    await t.pumpWidget(_app(reduced: true));
    var applied = false;
    await ThemeReveal.run(() => applied = true);
    expect(applied, isTrue);
  });

  testWidgets('theme switch reveals over the old screen', (t) async {
    await t.pumpWidget(_app());
    final before = find.byType(CustomPaint).evaluate().length;
    var applied = false;
    await t.runAsync(() async {
      ThemeReveal.run(() => applied = true);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await t.pump();
    await t.pump(const Duration(milliseconds: 200));
    expect(applied, isTrue);
    expect(find.byType(CustomPaint).evaluate().length, before + 1);
    await t.pumpAndSettle();
    // The run was started in the real zone; let its ending run there too.
    await t.runAsync(() => Future<void>.delayed(Duration.zero));
    await t.pump();
    expect(find.byType(CustomPaint).evaluate().length, before);
  });

  test('the theme switch fades on screens bigger than a phone', () {
    expect(fadesTheme(const Size(1080, 2400), 3), isFalse); // phone
    expect(fadesTheme(const Size(2400, 1080), 3), isFalse); // phone, sideways
    expect(fadesTheme(const Size(2048, 2732), 2), isTrue); // iPad
    expect(fadesTheme(const Size(1920, 1080), 1), isTrue); // laptop
    expect(fadesTheme(const Size(1920, 1080), 1, fx: 'circle'), isFalse);
    expect(fadesTheme(const Size(1080, 2400), 3, fx: 'fade'), isTrue);
  });

  test('Firefox switches through a veil, no pictures; fx overrides', () {
    expect(veilsTheme(firefox: true), isTrue);
    expect(veilsTheme(firefox: false), isFalse);
    expect(veilsTheme(firefox: true, fx: 'fade'), isFalse);
    expect(veilsTheme(firefox: true, fx: 'circle'), isFalse);
    expect(veilsTheme(firefox: false, fx: 'veil'), isTrue);
  });
}
