import 'package:cgpa_calculator/auth_util.dart';
import 'package:cgpa_calculator/main.dart' show refusal;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

class _User implements User {
  _User(this.email);
  @override
  final String? email;
  @override
  bool get emailVerified => true;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  test(
    'students and owners get in; faculty are refused (BUG-33, 43)',
    () async {
      final db = FakeFirebaseFirestore();
      await db.doc('owners/owner@pointer.test').set({'active': true});
      Future<bool?> may(String e) => mayUseApp(_User(e), db: db);
      expect(await may('f20239992@goa.bits-pilani.ac.in'), isTrue);
      expect(await may('owner@pointer.test'), isTrue);
      expect(await may('testfaculty@goa.bits-pilani.ac.in'), isFalse);
      expect(
        refusal(_User('testfaculty@goa.bits-pilani.ac.in'), false),
        contains('Faculty and staff'),
      );
    },
  );
}
