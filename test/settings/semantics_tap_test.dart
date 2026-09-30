import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/features/settings/settings_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// BUG-47: activating a row through the accessibility tree runs that row's
/// action, also after the list has scrolled.
void main() {
  testWidgets('semantics tap on a scrolled Settings row runs its action', (
    t,
  ) async {
    final h = t.ensureSemantics();
    final taps = <String>[];
    t.view.physicalSize = const Size(390, 700);
    t.view.devicePixelRatio = 1;
    await t.pumpWidget(
      MaterialApp(
        theme: AppPalette.light.materialTheme,
        home: SettingsView(
          name: 'Sid',
          email: 'f20220000@goa.bits-pilani.ac.in',
          discipline: 'B3A7',
          batch: 24,
          isDark: false,
          profiles: const ['Actual', 'Expected', 'P3', 'P4', 'P5'],
          onClose: () {},
          onPickDiscipline: (_) {},
          onTheme: (_) {},
          onRenameProfile: (i) => taps.add('profile $i'),
          onExport: () => taps.add('export'),
          onImportBackup: () => taps.add('backup'),
          onImportOld: () => taps.add('old'),
          onReport: () {},
          onReset: () {},
          onSignOut: () {},
          campus: 'Goa',
        ),
      ),
    );
    await t.drag(find.byType(ListView), const Offset(0, -300));
    await t.pumpAndSettle();
    await t.tap(find.bySemanticsLabel(RegExp('Import from old site')));
    await t.pumpAndSettle();
    expect(taps, ['old']);
    h.dispose();
  });
}
