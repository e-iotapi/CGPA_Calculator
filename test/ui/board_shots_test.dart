// Renders the student screens at the boards' sizes, light and dark, and fails
// on any overflow. With SHOTS_DIR set it also writes PNGs to compare against
// the UI Directions boards:
//
//   SHOTS_DIR=/some/dir flutter test test/ui/board_shots_test.dart
import 'package:cgpa_calculator/features/settings/settings_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fonts.dart';
import '../helpers/shots.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('Settings', (t) async {
    await shoot(
      t,
      'settings',
      () => SettingsView(
        name: 'Siddharth Mishra',
        email: 'f20220000@goa.bits-pilani.ac.in',
        discipline: 'B3A7',
        batch: 24,
        isDark: false,
        campus: 'Goa',
        profiles: const [
          'Actual',
          'Expected',
          'Profile 3',
          'Profile 4',
          'Profile 5',
        ],
        workingAs: 'Student',
        onWorkingAs: () {},
        contactSummary: 'Email, WhatsApp',
        onContact: () {},
        onClose: () {},
        onPickDiscipline: (_) {},
        onTheme: (_) {},
        onRenameProfile: (_) {},
        onExport: () {},
        onImportBackup: () {},
        onImportOld: () {},
        onReport: () {},
        onReset: () {},
        onSignOut: () {},
      ),
      sizes: const [('390', Size(390, 1100)), ('320', Size(320, 640))],
    );
  });
}
