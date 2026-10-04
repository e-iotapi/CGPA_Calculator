// A fake Firestore that can be taken offline: every read and write throws the
// `unavailable` error the SDK gives, for U15's failing-store widget tests.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

class FlakyFirestore extends FakeFirebaseFirestore {
  bool down = false;

  Never _fail() =>
      throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      down ? _fail() : super.collection(path);

  @override
  DocumentReference<Map<String, dynamic>> doc(String path) =>
      down ? _fail() : super.doc(path);

  @override
  WriteBatch batch() => down ? _fail() : super.batch();
}
