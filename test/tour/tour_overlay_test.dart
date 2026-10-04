// U8: the tour overlay and controller against a real GoRouter, with a Home
import 'dart:async';

// stand-in that counts its builds (the real Home needs FirebaseAuth).
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/features/tour/tour_controller.dart';
import 'package:cgpa_calculator/features/tour/tour_steps.dart';
import 'package:cgpa_calculator/shared/tour_key.dart';
import 'package:cgpa_calculator/shared/widgets/pill_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

TourStep _step(
  String id,
  String target, {
  int chapter = 0,
  TourPage page = TourPage.home,
}) => TourStep(id, chapter, page, target, 'Title $id', 'Line $id');

/// 40 steps that all point at `t.a`, spread over the 7 chapters.
List<TourStep> _forty() => [
  for (var i = 0; i < 40; i++) _step('s$i', 't.a', chapter: i * 7 ~/ 40),
];

class _Rig {
  _Rig(this.steps) {
    router = GoRouter(
      navigatorKey: navKey,
      routes: [
        GoRoute(path: '/', builder: (_, _) => _Home(this)),
        GoRoute(path: '/settings', builder: (_, _) => _Settings(this)),
      ],
    );
    controller = TourController(
      TourEnv(
        overlay: () => navKey.currentState?.overlay,
        push: (page, _) => router.push('/settings'),
        pop: router.pop,
        onPage:
            (page, _) =>
                router
                    .routerDelegate
                    .currentConfiguration
                    .last
                    .matchedLocation ==
                (page == TourPage.home ? '/' : '/settings'),
        selectProfile: (_) {},
        profile: () => 1,
        firstCourseId: () => null,
        offshootHidden: () => false,
        seen: () => seen,
        markSeen: () async {
          writes++;
          seen = true;
        },
      ),
      navWait: const Duration(milliseconds: 50),
      steps: steps,
    );
    router.routerDelegate.addListener(controller.routeChanged);
  }

  final List<TourStep> steps;
  final navKey = GlobalKey<NavigatorState>();
  late final GoRouter router;
  late final TourController controller;
  bool seen = false;
  int writes = 0;
  int homeBuilds = 0;
  final taps = <String>[];
}

class _Home extends StatelessWidget {
  const _Home(this.rig);
  final _Rig rig;

  @override
  Widget build(BuildContext context) {
    rig.homeBuilds++;
    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            left: 20,
            top: 100,
            child: KeyedSubtree(
              key: tourKey('t.a'),
              child: ElevatedButton(
                onPressed: () => rig.taps.add('a'),
                child: const Text('Button A'),
              ),
            ),
          ),
          Positioned(
            left: 20,
            top: 300,
            child: KeyedSubtree(
              key: tourKey('t.b'),
              child: ElevatedButton(
                onPressed: () => rig.taps.add('b'),
                child: const Text('Button B'),
              ),
            ),
          ),
          Positioned(
            left: 20,
            top: 500,
            child: ElevatedButton(
              onPressed: () => rig.taps.add('c'),
              child: const Text('Button C'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Settings extends StatelessWidget {
  const _Settings(this.rig);
  final _Rig rig;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 20, top: 100),
        child: KeyedSubtree(
          key: tourKey('t.s'),
          child: ElevatedButton(
            onPressed: () => rig.taps.add('s'),
            child: const Text('Settings button'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _pump(WidgetTester t, _Rig rig) => t.pumpWidget(
  MaterialApp.router(
    routerConfig: rig.router,
    theme: ThemeData(extensions: [AppPalette.light]),
  ),
);

/// Lets navigation waits, frames and scrolling finish.
Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 40; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

Finder _label(String s) => find.text(s);
Finder _btn(String s) => find.widgetWithText(PillButton, s);

void main() {
  late _Rig rig;

  Future<void> begin(
    WidgetTester t,
    List<TourStep> steps, {
    int? chapter,
  }) async {
    rig = _Rig(steps);
    await _pump(t, rig);
    unawaited(rig.controller.start(chapter: chapter));
    await _settle(t);
  }

  testWidgets('shows "Step n of 40 · chapter" and moves with Next and Back', (
    t,
  ) async {
    await begin(t, _forty());
    expect(_label('Step 1 of 40 · Home basics'), findsOneWidget);
    expect(_label('Title s0'), findsOneWidget);
    await t.tap(_btn('Next'));
    await _settle(t);
    expect(_label('Step 2 of 40 · Home basics'), findsOneWidget);
    await t.tap(_btn('Back'));
    await _settle(t);
    expect(_label('Step 1 of 40 · Home basics'), findsOneWidget);
    // Skip, Next and Back are all there on a step.
    expect(find.text('Skip'), findsOneWidget);
    expect(_btn('Next'), findsOneWidget);
    expect(_btn('Back'), findsOneWidget);
    await t.tap(find.text('Skip'));
    await _settle(t);
  });

  testWidgets('Back does nothing on the first step', (t) async {
    await begin(t, _forty());
    await t.tap(_btn('Back'), warnIfMissed: false);
    await _settle(t);
    expect(_label('Step 1 of 40 · Home basics'), findsOneWidget);
    expect(t.widget<PillButton>(_btn('Back')).onPressed, isNull);
    await t.tap(find.text('Skip'));
    await _settle(t);
  });

  testWidgets('chapter label follows the step', (t) async {
    await begin(t, _forty());
    for (var i = 0; i < 6; i++) {
      await t.tap(_btn('Next'));
      await _settle(t);
    }
    // Step 7 is index 6: 6 * 7 ~/ 40 == 1.
    expect(_label('Step 7 of 40 · Grade profiles'), findsOneWidget);
    await t.tap(find.text('Skip'));
    await _settle(t);
  });

  testWidgets('Skip ends the tour and writes seen exactly once', (t) async {
    await begin(t, _forty());
    expect(rig.controller.active, isTrue);
    await t.tap(find.text('Skip'));
    await _settle(t);
    expect(rig.controller.active, isFalse);
    expect(find.textContaining('Step 1 of'), findsNothing);
    expect(rig.writes, 1);
    // Replaying and skipping again does not write a second time.
    unawaited(rig.controller.start());
    await _settle(t);
    await t.tap(find.text('Skip'));
    await _settle(t);
    expect(rig.writes, 1);
  });

  testWidgets('finishing writes seen once; the last step says Done', (t) async {
    final steps = [_step('a', 't.a'), _step('b', 't.b')];
    await begin(t, steps);
    expect(_btn('Next'), findsOneWidget);
    await t.tap(_btn('Next'));
    await _settle(t);
    expect(_btn('Done'), findsOneWidget);
    expect(rig.writes, 0, reason: 'not written before it ends');
    await t.tap(_btn('Done'));
    await _settle(t);
    expect(rig.controller.active, isFalse);
    expect(rig.writes, 1);
  });

  testWidgets('taps outside, and on the highlighted control, are blocked', (
    t,
  ) async {
    await begin(t, [_step('a', 't.a')]);
    await t.tapAt(const Offset(40, 320)); // Button B, outside the hole
    await t.tapAt(const Offset(40, 520)); // Button C, outside the hole
    await t.tapAt(t.getCenter(find.text('Button A'))); // inside the hole
    await t.drag(
      find.text('Button B'),
      const Offset(0, -50),
      warnIfMissed: false,
    );
    expect(rig.taps, isEmpty);
    await t.tap(find.text('Skip'));
    await _settle(t);
    await t.tap(find.text('Button B'));
    expect(rig.taps, ['b'], reason: 'works again once the tour is over');
  });

  testWidgets('a step whose control is absent is skipped, both ways', (
    t,
  ) async {
    final steps = [
      _step('a', 't.a'),
      _step('gone', 't.missing'),
      _step('b', 't.b'),
    ];
    await begin(t, steps);
    await t.tap(_btn('Next'));
    await _settle(t);
    expect(_label('Step 3 of 3 · Home basics'), findsOneWidget);
    await t.tap(_btn('Back'));
    await _settle(t);
    expect(_label('Step 1 of 3 · Home basics'), findsOneWidget);
    await t.tap(find.text('Skip'));
    await _settle(t);
  });

  testWidgets('running out of present steps ends the tour', (t) async {
    await begin(t, [_step('a', 't.a'), _step('gone', 't.missing')]);
    await t.tap(_btn('Next'));
    await _settle(t);
    expect(rig.controller.active, isFalse);
    expect(rig.writes, 1);
  });

  testWidgets('one chapter replays on its own', (t) async {
    final steps = [
      _step('a', 't.a'),
      _step('b', 't.b', chapter: 1),
      _step('c', 't.a', chapter: 1),
      _step('d', 't.b', chapter: 2),
    ];
    await begin(t, steps, chapter: 1);
    expect(_label('Step 2 of 4 · Grade profiles'), findsOneWidget);
    expect(t.widget<PillButton>(_btn('Back')).onPressed, isNull);
    await t.tap(_btn('Next'));
    await _settle(t);
    expect(_btn('Done'), findsOneWidget);
    await t.tap(_btn('Done'));
    await _settle(t);
    expect(rig.controller.active, isFalse);
  });

  testWidgets('the overlay stays above a page the tour opens', (t) async {
    final steps = [
      _step('a', 't.a'),
      _step('s', 't.s', page: TourPage.settings),
    ];
    await begin(t, steps);
    await t.tap(_btn('Next'));
    await _settle(t);
    expect(
      rig.router.routerDelegate.currentConfiguration.last.matchedLocation,
      '/settings',
    );
    expect(_label('Step 2 of 2 · Home basics'), findsOneWidget);
    await t.tapAt(t.getCenter(find.text('Settings button')));
    expect(rig.taps, isEmpty, reason: 'the page under the scrim is blocked');
    await t.tap(_btn('Back'));
    await _settle(t);
    expect(
      rig.router.routerDelegate.currentConfiguration.last.matchedLocation,
      '/',
    );
    expect(_label('Step 1 of 2 · Home basics'), findsOneWidget);
    await t.tap(_btn('Next'));
    await _settle(t);
    await t.tap(_btn('Done'));
    await _settle(t);
    expect(
      rig.router.routerDelegate.currentConfiguration.last.matchedLocation,
      '/',
    );
    expect(rig.controller.active, isFalse);
    expect(rig.writes, 1);
  });

  testWidgets('system Back while on another page ends the tour', (t) async {
    final steps = [
      _step('a', 't.a'),
      _step('s', 't.s', page: TourPage.settings),
    ];
    await begin(t, steps);
    await t.tap(_btn('Next'));
    await _settle(t);
    rig.router.pop();
    await _settle(t);
    expect(rig.controller.active, isFalse);
    expect(rig.writes, 1);
  });

  testWidgets('running the tour never rebuilds Home', (t) async {
    final steps = [_step('a', 't.a'), _step('b', 't.b'), _step('c', 't.a')];
    rig = _Rig(steps);
    await _pump(t, rig);
    final before = rig.homeBuilds;
    unawaited(rig.controller.start());
    await _settle(t);
    await t.tap(_btn('Next'));
    await _settle(t);
    await t.tap(_btn('Back'));
    await _settle(t);
    await t.tap(find.text('Skip'));
    await _settle(t);
    expect(rig.homeBuilds, before);
  });

  testWidgets('Esc skips and the arrow keys step', (t) async {
    await begin(t, _forty());
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await _settle(t);
    expect(_label('Step 2 of 40 · Home basics'), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await _settle(t);
    expect(_label('Step 1 of 40 · Home basics'), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await _settle(t);
    expect(rig.controller.active, isFalse);
    expect(rig.writes, 1);
  });
}
