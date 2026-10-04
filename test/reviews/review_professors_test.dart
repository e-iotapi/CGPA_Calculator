import 'dart:io';

import 'package:cgpa_calculator/core/cache/cache_first.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/features/reviews/review_form.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  setUpAll(() async {
    Hive.init((await Directory.systemTemp.createTemp('review_profs')).path);
    await openSharedCache();
  });

  tearDown(() => roleStore = null);

  // An SOP under CS taught from Economics: the student can still name her.
  test('a professor reviewed on the course is offered, whatever the '
      'department', () async {
    final db = FakeFirebaseFirestore();
    roleStore = RoleStore(
      db,
      me: 'f20230456@goa.bits-pilani.ac.in',
      myName: 'Student',
    );
    Map<String, Object?> prof(String name, String dept) => {
      'name': name,
      'campus': 'goa',
      'department': dept,
      'aliases': <String>[],
      'nameTokens': <String>[],
      'mergedIds': <String>[],
      'active': true,
    };
    await db.doc('professors/cs1').set(prof('Cee Ess', 'CS'));
    await db.doc('professors/ec1').set(prof('Eko Nomist', 'ECON'));
    await db.doc('courses/CS F266/stats/goa_ec1').set({
      'count': 2,
      'starSum': 8,
      'recommendCount': 2,
      'campus': 'goa',
      'courseId': 'CS F266',
      'scope': 'professor',
      'professorId': 'ec1',
    });

    final r = await reviewProfessors('CS F266', 'goa', '2024-25-1');
    expect([for (final p in r.list) p.id], ['ec1', 'cs1']);
    expect(r.taught, isNull);
    final peek = peekReviewProfessors('CS F266', 'goa', '2024-25-1');
    expect([for (final p in peek!.list) p.id], ['ec1', 'cs1']);
  });
}
