// Renders the student screens at the boards' sizes, light and dark, and fails
// on any overflow. With SHOTS_DIR set it also writes PNGs to compare against
// the UI Directions boards:
//
//   SHOTS_DIR=/some/dir flutter test test/ui/board_shots_test.dart
import 'package:cgpa_calculator/features/settings/settings_view.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/bottom_action.dart';
import 'package:cgpa_calculator/shared/widgets/card_row.dart';
import 'package:cgpa_calculator/shared/widgets/code_badge.dart';
import 'package:cgpa_calculator/shared/widgets/notice.dart';
import 'package:cgpa_calculator/shared/widgets/outlined_pill.dart';
import 'package:cgpa_calculator/shared/widgets/search_box.dart';
import 'package:cgpa_calculator/shared/widgets/segmented.dart';
import 'package:cgpa_calculator/shared/widgets/tag_badge.dart';
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

  testWidgets('T3.10: SegmentedPair', (t) async {
    await shoot(
      t,
      'segmented_pair',
      () => Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: SegmentedPair<int>(
            a: (0, 'One mark'),
            b: (1, 'Several parts'),
            value: 0,
            onChanged: (_) {},
          ),
        ),
      ),
      sizes: const [('demo', Size(340, 100))],
    );
  });

  testWidgets('T3.10: SegmentedTrack', (t) async {
    await shoot(
      t,
      'segmented_track',
      () => Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: SegmentedTrack<String>(
            tabs: const [('all', 'All'), ('mine', 'Mine')],
            value: 'all',
            onChanged: (_) {},
          ),
        ),
      ),
      sizes: const [('demo', Size(340, 100))],
    );
  });

  testWidgets('T3.10: TagBadge', (t) async {
    await shoot(
      t,
      'tag_badge',
      () => const Scaffold(
        body: Center(child: TagBadge('Official', tone: TagTone.official)),
      ),
      sizes: const [('demo', Size(200, 100))],
    );
  });

  testWidgets('T3.10: Notice', (t) async {
    await shoot(
      t,
      'notice',
      () => const Scaffold(
        body: Padding(
          padding: EdgeInsets.all(16),
          child: Notice(text: TextSpan(text: 'Backed up just now.')),
        ),
      ),
      sizes: const [('demo', Size(340, 100))],
    );
  });

  testWidgets('T3.10: CardRow', (t) async {
    await shoot(
      t,
      'card_row',
      () => Scaffold(
        body: Column(
          children: [
            CardRow(title: 'Grading scheme', onTap: () {}),
            const CardDivider(),
            const CardRow(title: 'Credits', trailing: Text('4')),
          ],
        ),
      ),
      sizes: const [('demo', Size(340, 140))],
    );
  });

  testWidgets('T3.10: CodeBadge', (t) async {
    await shoot(
      t,
      'code_badge',
      () => const Scaffold(
        body: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CodeBadge('A7', tone: CodeTone.first),
              SizedBox(width: 8),
              CodeBadge('', tone: CodeTone.empty),
            ],
          ),
        ),
      ),
      sizes: const [('demo', Size(200, 100))],
    );
  });

  testWidgets('T3.10: SearchBox', (t) async {
    await shoot(
      t,
      'search_box',
      () => Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: SearchBox(
            controller: TextEditingController(),
            hint: 'Search courses',
          ),
        ),
      ),
      sizes: const [('demo', Size(340, 100))],
    );
  });

  testWidgets('T3.10: BottomAction', (t) async {
    await shoot(
      t,
      'bottom_action',
      () => Scaffold(
        body: Stack(
          children: [
            BottomAction(
              child: PrimaryButton(label: 'Save evaluative', onPressed: () {}),
            ),
          ],
        ),
      ),
      sizes: const [('demo', Size(340, 220))],
    );
  });

  testWidgets('T3.10: CompactField', (t) async {
    await shoot(
      t,
      'compact_field',
      () => Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: CompactField(
                  c: TextEditingController(text: '9.2'),
                  official: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CompactField(c: TextEditingController(text: '8.5')),
              ),
            ],
          ),
        ),
      ),
      sizes: const [('demo', Size(300, 100))],
    );
  });

  testWidgets('T3.10: AppTextField labelAbove', (t) async {
    await shoot(
      t,
      'app_text_field_label_above',
      () => Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: AppTextField(
            controller: TextEditingController(),
            label: 'course code',
            labelAbove: true,
          ),
        ),
      ),
      sizes: const [('demo', Size(300, 120))],
    );
  });

  testWidgets('T3.10: PrimaryButton tall', (t) async {
    await shoot(
      t,
      'primary_button_tall',
      () => Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: PrimaryButton(
            label: 'Save evaluative',
            onPressed: () {},
            tall: true,
          ),
        ),
      ),
      sizes: const [('demo', Size(300, 100))],
    );
  });

  testWidgets('T3.10: OutlinedPill', (t) async {
    await shoot(
      t,
      'outlined_pill',
      () => const Scaffold(
        body: Center(
          child: OutlinedPill(
            label: 'Filter',
            trailing: Icons.tune_rounded,
            onPressed: null,
          ),
        ),
      ),
      sizes: const [('demo', Size(200, 100))],
    );
  });
}
