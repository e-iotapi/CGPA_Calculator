import 'dart:convert';
import 'dart:io';

import 'package:cgpa_calculator/admin/config_pages.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/core/cache/cache_first.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  const me = 'owner@example.com';

  testWidgets(
    'public contact draws its last copy at once; Save waits for the fresh load',
    (t) async {
      await t.runAsync(() async {
        Hive.init((await Directory.systemTemp.createTemp('nospin_ui')).path);
        await openSharedCache();
        // What the last successful load saved (unawaited: Hive memory is
        // updated at once).
        await sharedCacheBox!.put(
          'last|public-contact|$me',
          jsonEncode({
            'at': 0,
            'v': {
              'c': {
                'name': 'Saved Name',
                'method': 'whatsapp',
                'target': '9000000001',
                'enabled': true,
              },
              'by': null,
            },
          }),
        );
      });
      final db = FakeFirebaseFirestore();
      await db.doc('config/public').set({
        'contactName': 'Fresh Name',
        'contactMethod': 'whatsapp',
        'contactTarget': '9000000002',
        'contactEnabled': true,
      });
      roleStore = RoleStore(db, me: me, myName: 'Owner');
      myRoles.value = const MyRoles(email: me, owner: true);

      VoidCallback? save() =>
          t
              .widget<PrimaryButton>(find.widgetWithText(PrimaryButton, 'Save'))
              .onPressed;

      await t.pumpWidget(
        MaterialApp(
          theme: AppPalette.light.materialTheme,
          home: const PublicContactPage(),
        ),
      );
      // First frame: the saved copy, no spinner, Save disabled.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.widgetWithText(TextField, 'Saved Name'), findsOneWidget);
      expect(save(), isNull);

      await t.pumpAndSettle();
      // The fresh load landed: its values replace the untouched form.
      expect(find.widgetWithText(TextField, 'Fresh Name'), findsOneWidget);
      expect(save(), isNotNull);
      // Hive stays open: the save the load started is a pending write that
      // cannot finish under fake time, and this file's isolate ends here.
    },
  );
}
