import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    roleStore = null;
    myRoles.value = MyRoles.none;
  });

  test('T3.6: a non-BITS owner still gets their roles', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('owners').doc('x@example.com').set({'active': true});

    startRoles(db, email: 'x@example.com', name: 'X');
    await refreshMyRoles();

    expect(myRoles.value.owner, isTrue);
    expect(roleStore, isNotNull);
    expect((await db.collection('people').get()).docs, isEmpty);
  });
}
