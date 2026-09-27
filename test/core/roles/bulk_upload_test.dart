import 'dart:convert';

import 'package:cgpa_calculator/admin/bulk_upload.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;

  setUp(() {
    db = FakeFirebaseFirestore();
    roleStore = RoleStore(db, me: 'owner@gmail.com', myName: 'Owner');
    myRoles.value = const MyRoles(email: 'owner@gmail.com', owner: true);
  });

  tearDown(() {
    roleStore = null;
    myRoles.value = MyRoles.none;
  });

  Widget page(String source) => MaterialApp(
    theme: AppPalette.light.materialTheme,
    home: BulkUploadPage(campus: 'goa', source: source),
  );

  String file(List<Map<String, Object?>> courses) => jsonEncode({
    'schema': 'pointer.eval.v1',
    'campus': 'Goa',
    'term': '2026-27-1',
    'courses': courses,
  });

  testWidgets('a bad file is refused whole, naming the row', (t) async {
    await t.pumpWidget(
      page(
        file([
          {
            'code': 'CS F211',
            'components': [
              {'name': 'Quiz', 'outOf': 10},
            ],
          },
        ]),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('This file cannot be used'), findsOneWidget);
    expect(find.textContaining('courses[0] (CS F211)'), findsOneWidget);
  });

  testWidgets('previews, confirms, then writes with an audit entry', (t) async {
    await t.pumpWidget(
      page(
        file([
          {
            'code': 'CS F211',
            'weighted': true,
            'components': [
              {'name': 'Quiz', 'weight': 20, 'outOf': 10},
              {'name': 'Compre', 'weight': 80, 'outOf': 100},
            ],
          },
        ]),
      ),
    );
    await t.pumpAndSettle();
    expect(
      find.textContaining(RegExp('creates', caseSensitive: false)),
      findsOneWidget,
    );
    expect((await db.collectionGroup('offerings').get()).docs, isEmpty);

    await t.tap(find.text('Write 1 schemes'));
    await t.pumpAndSettle();
    await t.tap(find.text('Write'));
    await t.pumpAndSettle();

    final written =
        await db.doc('courses/CS F211/offerings/goa_2026-27-1').get();
    expect(written.data()!['components'], hasLength(2));
    final audit = (await db.collection('audit').get()).docs.single.data();
    expect(audit['uploadId'], written.data()!['uploadId']);
    expect(find.textContaining('Done'), findsOneWidget);
  });
}
