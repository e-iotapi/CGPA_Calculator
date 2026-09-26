import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/pwa_helper/pwa_helper.dart';
import 'package:cgpa_calculator/shared/widgets/pointer_mark.dart';
import 'package:flutter/material.dart';

/// One step: what to do, and the button to look for on screen.
typedef InstallStep = ({String text, IconData icon, String? mark});

/// How to put a web app on the home screen, per browser.
List<InstallStep> installSteps(InstallPlatform platform) => switch (platform) {
  InstallPlatform.ios => const [
    (
      text:
          'Open this page in Safari, then tap the Share button in the '
          'toolbar.',
      icon: Icons.ios_share,
      mark: null,
    ),
    (
      text: 'Scroll down the share menu and choose “Add to Home Screen”.',
      icon: Icons.add_box_outlined,
      mark: null,
    ),
    (
      text:
          'Tap “Add” in the top-right corner. Pointer now opens from its '
          'own icon, full screen, like any other app.',
      icon: Icons.check_rounded,
      mark: 'Add',
    ),
  ],
  InstallPlatform.android => const [
    (
      text:
          'Open this page in Chrome, then tap the ⋮ menu in the top-right '
          'corner.',
      icon: Icons.more_vert_rounded,
      mark: null,
    ),
    (
      text: 'Choose “Add to Home screen” or “Install app”.',
      icon: Icons.add_to_home_screen_rounded,
      mark: null,
    ),
    (
      text:
          'Tap “Install” to confirm. Pointer now opens from its own icon, '
          'full screen, like any other app.',
      icon: Icons.check_rounded,
      mark: 'Install',
    ),
  ],
  InstallPlatform.desktop => const [
    (
      text:
          'In Chrome or Edge, click the install icon at the right end of '
          'the address bar.',
      icon: Icons.install_desktop_rounded,
      mark: null,
    ),
    (
      text:
          'No icon? Open the browser menu and choose “Cast, save and share” '
          '→ “Install page as app”.',
      icon: Icons.more_vert_rounded,
      mark: null,
    ),
    (
      text:
          'Click “Install”. Pointer opens in its own window and from your '
          'dock, taskbar or start menu.',
      icon: Icons.check_rounded,
      mark: 'Install',
    ),
  ],
};

/// The home-screen tutorial, as a sheet.
Future<void> showInstallGuide(BuildContext context, InstallPlatform platform) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppPalette.of(context).background,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => InstallGuide(platform: platform),
  );
}

class InstallGuide extends StatelessWidget {
  const InstallGuide({super.key, required this.platform});

  final InstallPlatform platform;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final steps = installSteps(platform);
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
                        'Add Pointer to your home screen',
                        style: TypeScale.title.copyWith(color: p.text),
                      ),
                      Text(
                        'It opens like an app, full screen, and works '
                        'offline.',
                        style: TypeScale.caption.copyWith(color: p.textMuted),
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
