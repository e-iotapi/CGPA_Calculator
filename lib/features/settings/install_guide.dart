import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/platform/browser.dart';
import 'package:cgpa_calculator/shared/widgets/pointer_mark.dart';
import 'package:flutter/material.dart';

/// One step: what to do, and the button to look for on screen.
typedef InstallStep = ({String text, IconData icon, String? mark});

InstallStep _step(String text, IconData icon) => (
  text: text,
  icon: icon,
  mark: null,
);

InstallStep _done(String text, String mark) => (
  text: text,
  icon: Icons.check_rounded,
  mark: mark,
);

const _opensAsApp =
    'Pointer now opens from its own icon, full screen, like any other app.';
const _opensInWindow =
    'Pointer opens in its own window, from your dock, taskbar or start menu.';

/// Where the guide says the app ends up.
String installHeading(InstallTarget t) => switch (t) {
  (device: InstallDevice.desktop, browser: InstallBrowser.safari) =>
    'Add Pointer to your Dock',
  (device: InstallDevice.desktop, browser: _) =>
    'Install Pointer on this computer',
  _ => 'Add Pointer to your home screen',
};

/// The browser and device the steps are for, e.g. "Chrome on Android".
String installLabel(InstallTarget t) {
  final browser = switch (t.browser) {
    InstallBrowser.safari => 'Safari',
    InstallBrowser.chrome => 'Chrome',
    InstallBrowser.edge => 'Edge',
    InstallBrowser.firefox => 'Firefox',
    InstallBrowser.samsung => 'Samsung Internet',
    InstallBrowser.opera => 'Opera',
    InstallBrowser.other => 'this browser',
  };
  final device = switch (t.device) {
    InstallDevice.ios => 'iPhone and iPad',
    InstallDevice.android => 'Android',
    InstallDevice.desktop =>
      t.browser == InstallBrowser.safari ? 'Mac' : 'a computer',
  };
  return 'Steps for $browser on $device';
}

/// How to put a web app on the home screen, for this device and browser.
List<InstallStep> installSteps(InstallTarget t) => switch (t) {
  // iOS: every browser is Safari underneath; since iOS 16.4 each can add to
  // the home screen from its own Share sheet.
  (device: InstallDevice.ios, browser: InstallBrowser.safari) => [
    _step(
      'Tap the Share button in the toolbar. On iOS 26, tap ⋯ first, then '
      'Share.',
      Icons.ios_share,
    ),
    _step(
      'Scroll down the share menu and choose “Add to Home Screen”.',
      Icons.add_box_outlined,
    ),
    _done('Tap “Add” in the top-right corner. $_opensAsApp', 'Add'),
  ],
  (device: InstallDevice.ios, browser: InstallBrowser.chrome) => [
    _step(
      'Tap the Share button at the right end of the address bar.',
      Icons.ios_share,
    ),
    _step('Choose “Add to Home Screen”.', Icons.add_box_outlined),
    _done('Tap “Add”. $_opensAsApp', 'Add'),
  ],
  (device: InstallDevice.ios, browser: InstallBrowser.edge) => [
    _step('Tap the ⋯ menu at the bottom, then Share.', Icons.more_horiz),
    _step('Choose “Add to Home Screen”.', Icons.add_box_outlined),
    _done('Tap “Add”. $_opensAsApp', 'Add'),
  ],
  (device: InstallDevice.ios, browser: InstallBrowser.firefox) => [
    _step('Tap the ☰ menu, then Share.', Icons.menu_rounded),
    _step('Choose “Add to Home Screen”.', Icons.add_box_outlined),
    _done('Tap “Add”. $_opensAsApp', 'Add'),
  ],
  (device: InstallDevice.ios, browser: _) => [
    _step(
      'This browser can’t add apps to the home screen. Copy this page’s '
      'address and open it in Safari.',
      Icons.open_in_new_rounded,
    ),
    _step('Tap Share, then choose “Add to Home Screen”.', Icons.ios_share),
    _done('Tap “Add”. $_opensAsApp', 'Add'),
  ],

  (device: InstallDevice.android, browser: InstallBrowser.samsung) => [
    _step('Tap the ☰ menu at the bottom right.', Icons.menu_rounded),
    _step(
      'Choose “Add page to”, then “Home screen”.',
      Icons.add_to_home_screen_rounded,
    ),
    _done('Tap “Add”. $_opensAsApp', 'Add'),
  ],
  (device: InstallDevice.android, browser: InstallBrowser.edge) => [
    _step('Tap the ⋯ menu at the bottom.', Icons.more_horiz),
    _step('Choose “Add to phone”.', Icons.add_to_home_screen_rounded),
    _done('Tap “Install”. $_opensAsApp', 'Install'),
  ],
  (device: InstallDevice.android, browser: InstallBrowser.firefox) => [
    _step('Tap the ⋮ menu.', Icons.more_vert_rounded),
    _step(
      'Choose “Add app to Home screen” (or “Add to Home screen”).',
      Icons.add_to_home_screen_rounded,
    ),
    _done('Tap “Add”. $_opensAsApp', 'Add'),
  ],
  (device: InstallDevice.android, browser: InstallBrowser.opera) => [
    _step('Tap the ⋮ menu in the top-right corner.', Icons.more_vert_rounded),
    _step('Choose “Add to home screen”.', Icons.add_to_home_screen_rounded),
    _done('Tap “Add”. $_opensAsApp', 'Add'),
  ],
  (device: InstallDevice.android, browser: InstallBrowser.chrome) => [
    _step('Tap the ⋮ menu in the top-right corner.', Icons.more_vert_rounded),
    _step(
      'Choose “Add to Home screen” or “Install app”.',
      Icons.add_to_home_screen_rounded,
    ),
    _done('Tap “Install”. $_opensAsApp', 'Install'),
  ],
  (device: InstallDevice.android, browser: _) => [
    _step('Open the browser’s menu.', Icons.more_vert_rounded),
    _step(
      'Choose “Add to Home screen” or “Install app”. Not there? Open this '
      'page in Chrome instead.',
      Icons.add_to_home_screen_rounded,
    ),
    _done('Confirm with “Add” or “Install”. $_opensAsApp', 'Add'),
  ],

  (device: InstallDevice.desktop, browser: InstallBrowser.safari) => [
    _step('In the menu bar, open File.', Icons.menu_rounded),
    _step(
      'Choose “Add to Dock…”. It is also in the Share button’s menu.',
      Icons.ios_share,
    ),
    _done('Click “Add”. $_opensInWindow', 'Add'),
  ],
  (device: InstallDevice.desktop, browser: InstallBrowser.edge) => [
    _step(
      'Click the install icon at the right end of the address bar.',
      Icons.install_desktop_rounded,
    ),
    _step(
      'No icon? Open the ⋯ menu → Apps → “Install this site as an app”.',
      Icons.more_horiz,
    ),
    _done('Click “Install”. $_opensInWindow', 'Install'),
  ],
  (device: InstallDevice.desktop, browser: InstallBrowser.firefox) => [
    _step(
      'Firefox can’t install web apps on a computer. Copy this page’s '
      'address.',
      Icons.link_rounded,
    ),
    _step(
      'Open it in Chrome or Edge, or in Safari on a Mac.',
      Icons.open_in_new_rounded,
    ),
    _done(
      'Use that browser’s install icon in the address bar, then '
          '“Install”. $_opensInWindow',
      'Install',
    ),
  ],
  (device: InstallDevice.desktop, browser: InstallBrowser.chrome) => [
    _step(
      'Click the install icon at the right end of the address bar.',
      Icons.install_desktop_rounded,
    ),
    _step(
      'No icon? Open the ⋮ menu → “Cast, save and share” → “Install page '
      'as app”.',
      Icons.more_vert_rounded,
    ),
    _done('Click “Install”. $_opensInWindow', 'Install'),
  ],
  (device: InstallDevice.desktop, browser: _) => [
    _step(
      'Look for an install icon at the right end of the address bar.',
      Icons.install_desktop_rounded,
    ),
    _step(
      'No icon? Open the browser’s menu and look for “Install”. Not '
      'there? Open this page in Chrome or Edge.',
      Icons.more_vert_rounded,
    ),
    _done('Click “Install”. $_opensInWindow', 'Install'),
  ],
};

/// The home-screen tutorial, as a sheet.
Future<void> showInstallGuide(BuildContext context, InstallTarget target) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppPalette.of(context).background,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => InstallGuide(target: target),
  );
}

class InstallGuide extends StatelessWidget {
  const InstallGuide({super.key, required this.target});

  final InstallTarget target;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final steps = installSteps(target);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          Space.gutter,
          0,
          Space.gutter,
          Space.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p.inverse,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: PointerMark(color: p.onInverse, size: 30),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        installHeading(target),
                        style: TypeScale.title.copyWith(color: p.text),
                      ),
                      Text(
                        'It opens like an app and works offline.',
                        style: TypeScale.caption.copyWith(color: p.textMuted),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        installLabel(target),
                        style: TypeScale.caption.copyWith(
                          color: p.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.lg),
            for (final (i, s) in steps.indexed) ...[
              _Step(number: i + 1, step: s),
              if (i < steps.length - 1) const SizedBox(height: Space.sm),
            ],
            const SizedBox(height: Space.lg),
            SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: p.inverse,
                  foregroundColor: p.onInverse,
                  textStyle: TypeScale.button,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(19),
                  ),
                ),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.step});

  final int number;
  final InstallStep step;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(Radii.row),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: p.inverse,
            child: Text(
              '$number',
              style: TypeScale.caption.copyWith(
                color: p.onInverse,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Text(
              step.text,
              style: TypeScale.body.copyWith(color: p.text),
            ),
          ),
          const SizedBox(width: Space.sm),
          // What the button looks like, so it is easy to find.
          Container(
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.surfaceSunken,
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                step.mark != null
                    ? Text(
                      step.mark!,
                      style: TypeScale.caption.copyWith(
                        color: p.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                    : Icon(step.icon, size: 20, color: p.accent),
          ),
        ],
      ),
    );
  }
}
