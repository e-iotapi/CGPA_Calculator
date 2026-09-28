// T7.4: Resources, Report this link and the empty state (UI.md §8.11–§8.13).
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/core/resources/resource.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/features/resources/resources_page.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;

  setUp(() {
    db = FakeFirebaseFirestore();
    roleStore = RoleStore(
      db,
      me: 'f20230001@goa.bits-pilani.ac.in',
      myName: 'S',
    );
  });
  tearDown(() => roleStore = null);

  Widget app(Widget home) => MaterialApp(
    theme: AppPalette.light.materialTheme,
    home: Scaffold(body: home),
  );

  test('eyebrow names only the parts that are known', () {
    expect(resourcesEyebrow('goa', dual: true), 'GOA · DUAL DEGREE');
    expect(resourcesEyebrow(null, dual: true), 'DUAL DEGREE');
    expect(resourcesEyebrow('goa', dual: false), 'GOA');
  });

  testWidgets('report needs a reason', (t) async {
    const r = Resource(
      id: 'r1',
      title: 'Past papers',
      url: 'https://drive.google.com/drive/folders/x',
      campus: 'goa',
      department: 'CS',
    );
    await t.pumpWidget(
      app(
        Builder(
          builder:
              (c) => TextButton(
                onPressed: () => reportLink(c, r),
                child: const Text('open'),
              ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    VoidCallback? send() =>
        t.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed;
    expect(find.text('Report this link'), findsOneWidget);
    expect(send(), isNull);
    await t.tap(find.text('Wrong course'));
    await t.pump();
    expect(send(), isNotNull);
  });

  testWidgets('empty department shows the contact', (t) async {
    await db.collection('config').doc('public').set({
      'contactName': 'Owner',
      'contactMethod': 'whatsapp',
      'contactTarget': '9000000001',
      'contactEnabled': true,
    });
    await t.pumpWidget(app(ResourcesEmpty(onRepresentatives: () {})));
    await t.pumpAndSettle();
    expect(find.text('No resources here yet'), findsOneWidget);
    expect(find.text('Find your representatives'), findsOneWidget);
    expect(find.text('Message Owner'), findsOneWidget);
    expect(find.text('On WhatsApp'), findsOneWidget);
    expect(find.textContaining('9000000001'), findsNothing);
  });

  testWidgets('a switched-off contact is hidden', (t) async {
    await db.collection('config').doc('public').set({
      'contactName': 'Owner',
      'contactMethod': 'whatsapp',
      'contactTarget': '9000000001',
      'contactEnabled': false,
    });
    await t.pumpWidget(app(const ResourcesEmpty()));
    await t.pumpAndSettle();
    expect(find.text('No resources here yet'), findsOneWidget);
    expect(find.text('Find your representatives'), findsNothing);
    expect(find.textContaining('Message'), findsNothing);
  });
}
