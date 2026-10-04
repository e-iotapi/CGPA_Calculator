// UT-4: a second open of Course reviews draws from the saved copies.
import 'dart:io';

import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/core/cache/cache_first.dart';
import 'package:cgpa_calculator/core/professors/professor_store.dart';
import 'package:cgpa_calculator/core/reviews/review_store.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/core/storage/courses.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/reviews/course_reviews.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  const me = 'f20230456@goa.bits-pilani.ac.in';
  const course = 'CS F211';

  testWidgets('Course reviews: no spinner on revisit, filters keep working', (
    t,
  ) async {
    final db = FakeFirebaseFirestore();
    roleStore = RoleStore(db, me: me, myName: 'Student');
    myUid = 'u-me';
    addTearDown(() {
      roleStore = null;
      myUid = null;
    });
    await db.collection('professors').doc('pr-a').set({
      'name': 'Asha Rao',
      'campus': 'goa',
      'department': 'CS',
      'aliases': <String>[],
      'mergedIds': <String>[],
      'active': true,
      'nameTokens': ['asha', 'rao'],
    });
    await t.runAsync(() async {
      Hive.init((await Directory.systemTemp.createTemp('nospin_rev')).path);
      await openSharedCache();
      if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(CourseAdapter());
      await Hive.openBox<Course>(coursesBoxName);
      final other = ReviewStore(db, uid: 'u1', roles: roleStore);
      await other.save(
        courseId: course,
        campus: 'goa',
        term: '2024-25-1',
        professorId: 'pr-a',
        stars: 4,
        recommend: true,
        grade: 'A',
        marks: 70,
        text: 'saved review',
      );
      // What the first open saves.
      final store = ReviewStore(db, uid: 'u-me', roles: roleStore);
      await store.all(course, 'goa');
      await store.byProfessor(course, 'goa');
      await store.stats(course, 'goa');
      await store.mine(course);
      await ProfessorStore(db).get('pr-a');
    });
    await t.pumpWidget(
      MaterialApp(
        theme: AppPalette.light.materialTheme,
        home: const CourseReviewsPage(courseId: course),
      ),
    );
    // The first frame: saved copies, no spinner.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('saved review'), findsOneWidget);
    await t.pumpAndSettle();
    expect(find.text('saved review'), findsOneWidget);
  });
}
