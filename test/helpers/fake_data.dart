// Fake data for every screen: one Goa campus with an owner, an admin, two
// presidents, two CRs and a student, their grants and contacts, professors,
// a published offering, reviews (reported and hidden), resources (rolled up
// and reported), volunteer offers, a publish draft, audit entries, and a
// student's grades, marks and Offshoot. Screens render from it as they would
// for a real account, so a test sees them full, not empty (UI.md §14).
//
// Everything is written through the app's own stores where one exists, so
// the shapes match what the screens read. No real people: every address is
// made up.
import 'dart:io';

import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import '../../agent_toolchains/ui_check/ui_checks.dart';
export 'fake_seed.dart';
import 'fake_seed.dart';

/// Fills the device and one shared fake Firestore. Call once from
/// `setUpAll`, which runs in real time: seeding inside a widget test's fake
/// clock can stall after a screen has listened to an earlier database.
Future<void> seedAll() async {
  await seedDevice();
  sharedDb = FakeFirebaseFirestore();
  await seedFirestore(sharedDb);
}

/// Opens every Hive box the app uses and fills the student's data.
Future<Directory> seedDevice() async {
  final dir = await Directory.systemTemp.createTemp('pointer_fake');
  Hive.init(dir.path);
  await fillDevice();
  return dir;
}

// ---- Rendering ---------------------------------------------------------------

final shotsOut = Platform.environment['SHOTS_DIR'];

/// One render: a label, a size and a text scale.
typedef Frame = (String label, Size size, double scale);

/// 390 at the board's height, 320 × 640, and 320 at 150% text (light only);
/// 200% is not checked (UI.md §13.2.10).
List<Frame> framesFor(double tall) => [
  ('390', Size(390, tall), 1),
  ('320', const Size(320, 640), 1),
  ('320x1.5', const Size(320, 640), 1.5),
];

/// Renders [screen] as [who] over freshly seeded data, in light and dark at
/// each frame, and returns every error it raised. With SHOTS_DIR set it
/// writes `<name>_<light|dark>_<frame>.png` and a .json of its [uiIssues]. [open] runs after the first
/// frames, for a sheet or dialog opened from a launcher.
Future<List<String>> renderScreen(
  WidgetTester t,
  String name,
  Widget Function() screen, {
  As who = As.student,
  double tall = 844,
  Future<void> Function(WidgetTester t)? open,
}) async {
  final errors = <String>[];
  final old = FlutterError.onError;
  FlutterError.onError =
      (d) => errors.add(d.exceptionAsString().split('\n').first);
  final db = sharedDb;
  try {
    for (final palette in [AppPalette.light, AppPalette.dark]) {
      for (final (label, size, scale) in framesFor(tall)) {
        if (scale != 1 && palette.isDark) continue;
        final before = errors.length;
        roleStore = RoleStore(db, me: who.email, myName: who.name);
        myRoles.value = who.roles;
        myUid = 'u-${who.name.split(' ').first.toLowerCase()}';
        t.view.physicalSize = size * 2;
        t.view.devicePixelRatio = 2;
        await t.pumpWidget(
          RepaintBoundary(
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: palette.materialTheme,
              builder:
                  (c, child) => MediaQuery(
                    data: MediaQuery.of(
                      c,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
              home: screen(),
            ),
          ),
        );
        await settle(t);
        if (open != null) {
          await open(t);
          await settle(t);
        }
        final ex = t.takeException();
        if (ex != null) errors.add('$label: ${'$ex'.split('\n').first}');
        final out = shotsOut;
        if (out != null) {
          final mode = palette.isDark ? 'dark' : 'light';
          await recordRender(
            t,
            out,
            '${name}_${mode}_$label',
            errors.sublist(before),
          );
        }
        await t.pumpWidget(const SizedBox());
      }
    }
  } finally {
    FlutterError.onError = old;
    t.view.reset();
    roleStore = null;
    myRoles.value = MyRoles.none;
    myUid = null;
  }
  return errors.toSet().toList();
}

/// Lets fake Firestore futures finish and frames run, without
/// `pumpAndSettle`: the pulsing Reported tab never settles.
Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump(const Duration(milliseconds: 100));
  }
}

/// A screen that opens a sheet or dialog from its one button, for
/// [renderScreen]'s `open`.
Widget launcher(Future<void> Function(BuildContext c) open) => Scaffold(
  body: Center(
    child: Builder(
      builder:
          (c) => TextButton(
            key: const ValueKey('launch'),
            onPressed: () => open(c),
            child: const Text('open'),
          ),
    ),
  ),
);

/// Taps [launcher]'s button.
Future<void> tapLauncher(WidgetTester t) =>
    t.tap(find.byKey(const ValueKey('launch')));

/// Checks a render against the known issues: a screen listed in [known]
/// must still fail (so the list stays true), and every other must be clean.
void expectRender(String name, List<String> errors, Map<String, String> known) {
  final why = known[name];
  if (why == null) {
    expect(errors, isEmpty, reason: '$name rendered with errors');
  } else {
    expect(
      errors,
      isNotEmpty,
      reason:
          '$name is listed as broken ($why) but renders clean now: '
          'remove it from the known list and log the fix in UI.md §13',
    );
  }
}
