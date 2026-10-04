// The compulsory-reviews gate: the locked banner, Pick electives, the
// unlocked dialog and the staff switch, drawn like their boards.
//
//   SHOTS_DIR=/some/dir flutter test test/ui/uifix_b_gate_test.dart
import 'package:cgpa_calculator/admin/gate_switch.dart';
import 'package:cgpa_calculator/core/reviews/gate_store.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/features/reviews/compulsory_pick.dart';
import 'package:cgpa_calculator/features/reviews/reviews_home.dart';
import 'package:cgpa_calculator/script.dart' as script;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_data.dart';
import '../helpers/fonts.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await seedAll();
    script.currentsem = '3 - 1';
    roleStore = RoleStore(sharedDb, me: studentEmail, myName: 'Owl');
    myUid = 'u-owl';
    await sharedDb.collection('reviewGate').doc('goa').set({'on': true});
    await GateStore(roleStore!).of('goa');
  });

  testWidgets('b_gate_locked', (t) async {
    final errors = await renderScreen(t, 'b_gate_locked', () => const ReviewsHome());
    expectRender('b_gate_locked', errors, const {});
  });

  testWidgets('b_gate_pick', (t) async {
    final errors = await renderScreen(t, 'b_gate_pick', () => const CompulsoryPickPage());
    expectRender('b_gate_pick', errors, const {});
  });

  testWidgets('b_gate_switch_confirm', (t) async {
    await sharedDb.collection('reviewGate').doc('goa').set({'on': false});
    final errors = await renderScreen(
      t,
      'b_gate_switch_confirm',
      () => const Scaffold(body: GateSwitchRow(campus: 'goa')),
      who: As.owner,
      open: (t) async {
        await t.tap(find.byType(Switch));
        await t.pump(const Duration(milliseconds: 300));
      },
    );
    await sharedDb.collection('reviewGate').doc('goa').set({'on': true});
    expectRender('b_gate_switch_confirm', errors, const {});
  });
}
