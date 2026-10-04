// U8: Settings > "Replay the tour" shows for students only.
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/features/settings/settings_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _view({VoidCallback? onReplayTour}) => MaterialApp(
  theme: AppPalette.light.materialTheme,
  home: SettingsView(
    name: 'Sid',
    email: 'f20220000@goa.bits-pilani.ac.in',
    discipline: 'B3A7',
    batch: 24,
    isDark: false,
    profiles: const ['Actual', 'Expected', 'Profile 3'],
    onClose: () {},
    onPickDiscipline: (_) {},
    onTheme: (_) {},
    onRenameProfile: (_) {},
    onExport: () {},
    onImportOld: () {},
    onReport: () {},
    onReset: () {},
    onSignOut: () {},
    onReplayTour: onReplayTour,
  ),
);

void main() {
  testWidgets('the row is there for a student and runs the callback', (
    t,
  ) async {
    var n = 0;
    await t.pumpWidget(_view(onReplayTour: () => n++));
    await t.scrollUntilVisible(find.text('Replay the tour'), 200);
    await t.tap(find.text('Replay the tour'));
    expect(n, 1);
    expect(find.text('APP'), findsOneWidget);
  });

  testWidgets('no row, and no APP section, for a role', (t) async {
    await t.pumpWidget(_view());
    await t.scrollUntilVisible(find.text('Export grades'), 200);
    expect(find.text('Replay the tour'), findsNothing);
    expect(find.text('APP'), findsNothing);
  });
}
