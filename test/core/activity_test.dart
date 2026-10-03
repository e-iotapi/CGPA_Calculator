import 'package:cgpa_calculator/core/roles/activity_store.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

int ms(int y, int m, [int d = 15]) => DateTime(y, m, d).millisecondsSinceEpoch;

void main() {
  final now = DateTime(2026, 10, 3); // semester 1 of 2026-27

  test('semestersAgo counts academic semester boundaries', () {
    expect(semestersAgo(ms(2026, 8), now), 0);
    expect(semestersAgo(ms(2026, 7), now), 1); // summer
    expect(semestersAgo(ms(2026, 3), now), 2); // semester 2 of 2025-26
    expect(semestersAgo(ms(2025, 9), now), 3);
    expect(semestersAgo(ms(2027, 1), now), 0); // future clamps
  });

  test('labels and staleness', () {
    expect(updatedLabel(null, now), 'Not updated yet');
    expect(updatedLabel(ms(2026, 8), now), 'Updated Aug 2026');
    expect(updatedLabel(ms(2026, 7), now), 'Updated Jul 2026');
    expect(updatedLabel(ms(2026, 3), now), '2 semesters ago');
    expect(isStale(null, now), isTrue);
    expect(isStale(ms(2026, 7), now), isFalse);
    expect(isStale(ms(2026, 3), now), isTrue);
  });

  test('touch stamps the course and department with hints', () async {
    final db = FakeFirebaseFirestore();
    final b = db.batch();
    ActivityStore.touch(b, db, 'goa', courseId: 'CS F211', dept: 'CS');
    await b.commit();
    final m = (await db.collection('activity').doc('goa').get()).data()!;
    expect(m['c'], 'CS F211');
    expect(m['d'], 'CS');
    final a = Activity.fromMap(m);
    expect(a.ofCourse('CS F211'), isNotNull);
    expect(a.ofDept('CS'), isNotNull);
    expect(a.ofDept('EEE'), isNull);
  });

  test('a department-only touch leaves the course hint empty', () async {
    final db = FakeFirebaseFirestore();
    final b = db.batch();
    ActivityStore.touch(b, db, 'goa', dept: 'ECON');
    await b.commit();
    final m = (await db.collection('activity').doc('goa').get()).data()!;
    expect(m['c'], '');
    expect(m.containsKey('course'), isFalse);
  });
}
