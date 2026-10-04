// Planted bugs: each canary screen breaks exactly one rule, and the clean one
// breaks none. If a check stops catching its canary, or starts flagging the
// clean screen, the checks are broken and no "clean" report can be trusted.
//
//   flutter test agent_toolchains/ui_check/canary_test.dart
//
// ui_check.py runs this with SHOTS_DIR set and reads the .json files back,
// which also proves the write path works.
import 'dart:io';

import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/count_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/helpers/fonts.dart';
import 'ui_checks.dart';

/// name → (what it plants, the kind that must report it; 'error' is a
/// layout error, '' means nothing may be reported).
final canaries = <String, (Widget, String)>{
  'canary_clean': (
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Plain dark text', style: TextStyle(color: Colors.black)),
        // Tightly boxed text, which Flutter's own contrast check misreads.
        const SizedBox(width: 20, height: 20, child: Text('T')),
        // Laid out past the end of a scroll view, where nobody sees it cut
        // short.
        SizedBox(
          height: 60,
          child: ListView(
            children: const [
              SizedBox(height: 100),
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 60,
                  child: Text(
                    'Cut short out of sight',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Text an opaque card covers: hidden, so not an overlap.
        const SizedBox(
          width: 200,
          height: 30,
          child: Stack(
            children: [
              Text('Underneath'),
              ColoredBox(
                color: Colors.white,
                child: SizedBox(width: 200, height: 30, child: Text('On top')),
              ),
            ],
          ),
        ),
        // Scroll content under a fixed bar that it can scroll clear of.
        SizedBox(
          width: 200,
          height: 60,
          child: Stack(
            children: [
              ListView(
                children: const [
                  SizedBox(height: 40),
                  Text('Scrolls clear'),
                  SizedBox(height: 200),
                ],
              ),
              const Positioned(left: 0, top: 40, child: Text('Fixed bar')),
            ],
          ),
        ),
        // A disabled button, faint on purpose: WCAG exempts it.
        const SizedBox(height: 12),
        const SizedBox(
          width: 160,
          child: PrimaryButton(label: 'Not yet', onPressed: null),
        ),
        const SizedBox(height: 12),
        Material(
          color: Colors.black,
          child: InkWell(
            onTap: () {},
            child: const SizedBox(
              width: 160,
              height: 48,
              child: Center(
                child: Text('Tap me', style: TextStyle(color: Colors.white)),
              ),
            ),
          ),
        ),
      ],
    ),
    '',
  ),
  'canary_overflow': (
    const Row(children: [SizedBox(width: 600, height: 10)]),
    'error',
  ),
  'canary_contrast': (
    const Text(
      'Faint text',
      style: TextStyle(color: Color(0xFFE6E6E6), fontSize: 14),
    ),
    'contrast',
  ),
  'canary_tap': (
    InkWell(
      onTap: () {},
      child: const SizedBox(width: 20, height: 20, child: Text('T')),
    ),
    'tap',
  ),
  'canary_unlabeled': (
    GestureDetector(
      onTap: () {},
      child: const SizedBox(width: 48, height: 48, child: Icon(Icons.add)),
    ),
    'unlabeled',
  ),
  'canary_dead': (
    Semantics(
      button: true,
      enabled: true,
      label: 'Dead',
      child: const SizedBox(width: 48, height: 48),
    ),
    'dead',
  ),
  'canary_word_break': (
    const SizedBox(
      width: 40,
      child: Text('Remove', style: TextStyle(fontSize: 20)),
    ),
    'word-break',
  ),
  'canary_overlap': (
    const SizedBox(
      width: 200,
      height: 40,
      child: Stack(children: [Text('Skip this step'), Text('Choose a file')]),
    ),
    'overlap',
  ),
  'canary_truncated': (
    const SizedBox(
      width: 80,
      child: Text(
        'A label that is far too long',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
    'truncated',
  ),
  'canary_off_edge': (
    const SizedBox(
      width: 358,
      height: 40,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [Positioned(left: 300, child: Text('Off the edge'))],
      ),
    ),
    'off-edge',
  ),
  'canary_stretch': (
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [CountPill(label: '3', selected: false, onTap: () {})],
    ),
    'stretch',
  ),
  'canary_stretch_chip': (
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text('2025-26', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
    'stretch',
  ),
  'canary_anim': (
    const SizedBox(width: 40, height: 40, child: CircularProgressIndicator()),
    'anim',
  ),
};

void main() {
  setUpAll(loadAppFonts);

  for (final MapEntry(key: name, value: (screen, kind)) in canaries.entries) {
    testWidgets(name, (t) async {
      final errors = <String>[];
      final old = FlutterError.onError;
      FlutterError.onError =
          (d) => errors.add(d.exceptionAsString().split('\n').first);
      try {
        t.view.physicalSize = const Size(390, 844) * 2;
        t.view.devicePixelRatio = 2;
        addTearDown(t.view.reset);
        await t.pumpWidget(
          RepaintBoundary(
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppPalette.light.materialTheme,
              home: Scaffold(
                body: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Align(alignment: Alignment.topLeft, child: screen),
                  ),
                ),
              ),
            ),
          ),
        );
        for (var i = 0; i < 3; i++) {
          await t.pump(const Duration(milliseconds: 100));
        }
        final issues = await uiIssues(t);
        final out = Platform.environment['SHOTS_DIR'];
        if (out != null) {
          await recordRender(t, out, '${name}_light_390', errors);
        }

        switch (kind) {
          case '':
            expect(issues, isEmpty, reason: 'false alarm');
            expect(errors, isEmpty);
          case 'error':
            expect(errors, isNotEmpty, reason: 'overflow not caught');
          default:
            expect(
              issues.where((i) => i.startsWith('$kind:')),
              isNotEmpty,
              reason: '$kind not caught; got $issues',
            );
        }
      } finally {
        FlutterError.onError = old;
      }
    });
  }
}
