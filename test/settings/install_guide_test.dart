import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/features/settings/install_guide.dart';
import 'package:cgpa_calculator/core/platform/browser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _ua = {
  'iphone safari':
      'Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Mobile/15E148 Safari/604.1',
  'iphone chrome':
      'Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/138.0.7204.119 Mobile/15E148 Safari/604.1',
  'iphone edge':
      'Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 EdgiOS/138.3351.83 Mobile/15E148 Safari/605.1.15',
  'iphone firefox':
      'Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) FxiOS/141.0 Mobile/15E148 Safari/605.1.15',
  'iphone instagram':
      'Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Instagram 390.0.0.28.85',
  'android chrome':
      'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 Mobile Safari/537.36',
  'android samsung':
      'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) SamsungBrowser/28.0 Chrome/130.0.0.0 Mobile Safari/537.36',
  'android edge':
      'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 Mobile Safari/537.36 EdgA/139.0.0.0',
  'android firefox':
      'Mozilla/5.0 (Android 14; Mobile; rv:142.0) Gecko/142.0 Firefox/142.0',
  'android opera':
      'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 Mobile Safari/537.36 OPR/90.0.0.0',
  'windows chrome':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 Safari/537.36',
  'windows edge':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 Safari/537.36 Edg/139.0.0.0',
  'linux firefox':
      'Mozilla/5.0 (X11; Linux x86_64; rv:142.0) Gecko/20100101 Firefox/142.0',
  'mac safari':
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Safari/605.1.15',
};

void main() {
  test('the user agent picks the device and browser', () {
    const ios = InstallDevice.ios, and = InstallDevice.android;
    const pc = InstallDevice.desktop;
    final want = {
      'iphone safari': (ios, InstallBrowser.safari),
      'iphone chrome': (ios, InstallBrowser.chrome),
      'iphone edge': (ios, InstallBrowser.edge),
      'iphone firefox': (ios, InstallBrowser.firefox),
      'iphone instagram': (ios, InstallBrowser.other),
      'android chrome': (and, InstallBrowser.chrome),
      'android samsung': (and, InstallBrowser.samsung),
      'android edge': (and, InstallBrowser.edge),
      'android firefox': (and, InstallBrowser.firefox),
      'android opera': (and, InstallBrowser.opera),
      'windows chrome': (pc, InstallBrowser.chrome),
      'windows edge': (pc, InstallBrowser.edge),
      'linux firefox': (pc, InstallBrowser.firefox),
      'mac safari': (pc, InstallBrowser.safari),
    };
    for (final MapEntry(:key, value: (d, b)) in want.entries) {
      expect(parseInstallTarget(_ua[key]!), (
        device: d,
        browser: b,
      ), reason: key);
    }
    // An iPad asks for the desktop site, so only touch tells it from a Mac.
    expect(parseInstallTarget(_ua['mac safari']!, touch: true), (
      device: ios,
      browser: InstallBrowser.safari,
    ));
  });

  final targets = [
    for (final device in InstallDevice.values)
      for (final browser in InstallBrowser.values)
        (device: device, browser: browser),
  ];

  test('every target has three steps ending in the confirm button', () {
    for (final t in targets) {
      final s = installSteps(t);
      expect(s, hasLength(3), reason: '$t');
      expect(s.last.mark, isNotNull, reason: '$t');
    }
    expect(
      installSteps((
        device: InstallDevice.ios,
        browser: InstallBrowser.safari,
      )).first.text,
      contains('Share'),
    );
    expect(
      installSteps((
        device: InstallDevice.desktop,
        browser: InstallBrowser.safari,
      ))[1].text,
      contains('Add to Dock'),
    );
    expect(
      installLabel((
        device: InstallDevice.android,
        browser: InstallBrowser.chrome,
      )),
      'Steps for Chrome on Android',
    );
  });

  for (final target in [
    (device: InstallDevice.ios, browser: InstallBrowser.safari),
    (device: InstallDevice.android, browser: InstallBrowser.samsung),
    (device: InstallDevice.desktop, browser: InstallBrowser.firefox),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('$target guide at 320px, text ×$scale', (t) async {
        t.view.physicalSize = const Size(320, 640);
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
            home: Builder(
              builder:
                  (c) => Scaffold(
                    body: TextButton(
                      onPressed: () => showInstallGuide(c, target),
                      child: const Text('open'),
                    ),
                  ),
            ),
          ),
        );
        await t.tap(find.text('open'));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        expect(find.text(installHeading(target)), findsOneWidget);
        expect(find.text(installLabel(target)), findsOneWidget);
        await t.scrollUntilVisible(
          find.text('Got it'),
          100,
          scrollable: find.byType(Scrollable).last,
        );
        await t.tap(find.text('Got it'));
        await t.pumpAndSettle();
        expect(find.text(installHeading(target)), findsNothing);
      });
    }
  }
}
