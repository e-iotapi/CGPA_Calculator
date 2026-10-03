// Builds the per-user seed snapshots in test_env/accounts.json's "dataset"
// column, entirely through the app's own storage functions so the fixtures
// exercise the same code paths a real user does (PERF_TEST_PLAN.md T4a).
//
// Run: POINTER_SEED=1 flutter test tools/test_env/build_snapshots_test.dart
// Writes tools/test_env/out/<dataset>.json (a Sync snapshot, consumed by
// tools/test_env/seed.mjs, T4b) and out/<dataset>.expected.json (the CGPA,
// SGPA per semester and credits the E2E specs in T6 assert against).
import 'dart:convert';
import 'dart:io';

import 'package:cgpa_calculator/core/catalog/catalog_store.dart';
import 'package:cgpa_calculator/core/grading/cgpa.dart';
import 'package:cgpa_calculator/core/grading/grade_scale.dart';
import 'package:cgpa_calculator/core/grading/offshoot.dart';
import 'package:cgpa_calculator/core/models/elective.dart';
import 'package:cgpa_calculator/core/models/marks.dart';
import 'package:cgpa_calculator/core/models/minors.dart';
import 'package:cgpa_calculator/core/models/programmes.dart';
import 'package:cgpa_calculator/core/models/semesters.dart';
import 'package:cgpa_calculator/core/storage/courses.dart';
import 'package:cgpa_calculator/core/storage/marks.dart';
import 'package:cgpa_calculator/core/storage/minor.dart';
import 'package:cgpa_calculator/core/storage/offshoot.dart';
import 'package:cgpa_calculator/core/storage/stats.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/reviews/review_widgets.dart'
    show rememberReview;
import 'package:cgpa_calculator/script.dart' as app;
import 'package:cgpa_calculator/sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

const _seedEnv = 'POINTER_SEED';

void main() {
  final shouldRun = Platform.environment[_seedEnv] == '1';

  test(
    'build test_env seed snapshots',
    () async {
      final outDir = Directory('tools/test_env/out')
        ..createSync(recursive: true);
      await _build(outDir, 'student_full', _seedStudentFull);
      await _build(outDir, 'student_dual', _seedStudentDual);
      await _build(outDir, 'first_login', (_) async {});
      await _build(outDir, 'gate_student', _seedGateStudent);
      await _build(outDir, 'gate_exempt', _seedGateExempt);
    },
    skip: shouldRun
        ? false
        : 'set POINTER_SEED=1 to run (writes tools/test_env/out/*.json)',
  );
}

Future<void> _build(
  Directory outDir,
  String name,
  Future<void> Function(DateTime now) seed,
) async {
  final tempDir = Directory.systemTemp.createTempSync('pointer-seed-$name-');
  try {
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(CourseAdapter());
    registerMarksAdapters();
    await Sync.openBoxes();
    await loadCatalog(asset: () => File('assets/catalog.json').readAsString());

    await seed(DateTime.now());

    final snapshot = Sync.snapshot();
    Sync.validate(snapshot); // fails loudly on a shape that isn't a snapshot
    File('${outDir.path}/$name.json').writeAsStringSync(snapshot);
    File('${outDir.path}/$name.expected.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ')
          .convert(_expected(app.selecteddiscipline)),
    );
  } finally {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  }
}

/// CGPA, per-semester SGPA and credits, computed the same way the app does
/// (core/grading/cgpa.dart), for the E2E specs (T6) to assert against.
Map<String, dynamic> _expected(String discipline) {
  final courses = Hive.box<Course>(coursesBoxName).values.toList();
  if (courses.isEmpty) {
    return {
      'discipline': null,
      'cgpa': 0,
      'creditsShown': 0,
      'creditsGraded': 0,
      'semesters': <Object>[],
    };
  }
  final cum = cumulativeTally(
    courses,
    discipline: discipline,
    profile: Profile.actual,
  );
  final prog = progression(
    courses,
    semesters: semestersFor(discipline),
    discipline: discipline,
    profile: Profile.actual,
  );
  return {
    'discipline': discipline,
    'cgpa': cum.rounded,
    'creditsShown': cum.shownCredits,
    'creditsGraded': cum.gradedCredits,
    'semesters': [
      for (final p in prog)
        {
          'sem': p.sem,
          'sgpa': p.term.rounded,
          'cgpaAfter': p.running.rounded,
          'credits': p.term.shownCredits,
        },
    ],
  };
}

/// Adds 4 evaluatives (Quiz 1, Quiz 2, Midsem, Compre) plus a config to
/// [courseId], dated from 30 days ago to 45 days ahead of [now] so the
/// Calendar has both past and upcoming items.
Future<void> _addMarks(String courseId, DateTime now) async {
  await saveConfig(CourseConfig(courseId: courseId));
  const plan = [
    ('Quiz 1', 10.0, 20.0, -30),
    ('Quiz 2', 10.0, 20.0, -10),
    ('Midsem', 30.0, 60.0, 5),
    ('Compre', 40.0, 80.0, 45),
  ];
  for (final (name, weight, outOf, offsetDays) in plan) {
    final date = now.add(Duration(days: offsetDays));
    final happened = offsetDays <= 0;
    await saveEvaluative(
      Evaluative(
        courseId: courseId,
        name: name,
        weight: weight,
        parts: [
          EvalPart(
            name: '',
            outOf: outOf,
            marks: happened ? outOf * 0.75 : null,
            date: date.toIso8601String().split('T').first,
          ),
        ],
      ),
    );
  }
}

/// `--A3` (EEE), batch 24, 3rd year: 1-1 through PS 1 graded with every
/// grade code at least once, 3-1 (current) ongoing with marks, electives
/// included, plus a minor and offshoot with partial progress.
Future<void> _seedStudentFull(DateTime now) async {
  app.selecteddiscipline = '--A3';
  app.batch = 24;
  app.campus = Campus.goa;
  app.erase = 1;
  await app.setdis();
  await app.initializeCourses();
  app.erase = 0;
  app.currentsem = '3 - 1';
  await app.setsem();

  final box = Hive.box<Course>(coursesBoxName);
  const gradedPastSems = {'1 - 1', '1 - 2', '2 - 1', '2 - 2', 'PS 1'};
  // Every grade code the picker offers, at least once.
  const gradeCycle = [
    'A', 'A-', 'B', 'B-', 'C', 'C-', 'D', 'E', 'NC', 'GD', 'RC', 'W', 'CLR',
  ];
  final past = box.values.where((c) => gradedPastSems.contains(c.sem)).toList();
  for (final (i, c) in past.indexed) {
    final grade = reversegradecalc(gradeCycle[i % gradeCycle.length]);
    await saveCourse(c.withGrade(1, grade).withGrade(2, grade));
  }
  // A compare-only profile grade, so Compare has data for profile 3.
  if (past.isNotEmpty) {
    final c = box.values.firstWhere((c) => c.id == past.first.id);
    await saveCourse(c.withGrade(3, gradeValues['A']!));
  }

  // Current semester: taking now, half marked ongoing and half CLR.
  final current = box.values.where((c) => c.sem == '3 - 1').toList();
  for (final (i, c) in current.indexed) {
    await saveCourse(
      c.withGrade(1, i.isEven ? GradeCode.ongoing : GradeCode.clr),
    );
  }
  for (final c in current) {
    await _addMarks(c.id, now);
  }

  // Electives: a Humanity and Open elective already graded, a current
  // Disciplinary elective (DEl1) ongoing. Representative course names, not
  // verified against the live catalogue (that lookup is T4b's job).
  await saveCourse(Course(
    title: 'Ethics and Self Awareness',
    id: 'HSS F219',
    discipline: '--',
    sem: '2 - 2',
    elective: Elective.humanity.tag,
    credits: 2,
    grade1: gradeValues['B']!,
    grade2: gradeValues['B']!,
  ));
  final openElective = offshootCourses[0]; // a real, cross-listed course id
  await saveCourse(Course(
    title: openElective.title,
    id: openElective.id,
    discipline: '--',
    sem: '2 - 1',
    elective: Elective.open.tag,
    credits: 3,
    grade1: gradeValues['A-']!,
    grade2: gradeValues['A-']!,
  ));
  await saveCourse(Course(
    title: 'Embedded Systems',
    id: 'EEE F332',
    discipline: '--',
    sem: '3 - 1',
    elective: Elective.del1.tag,
    credits: 3,
    grade1: GradeCode.ongoing,
    grade2: GradeCode.clr,
  ));
  await _addMarks('EEE F332', now);

  // Offshoot: two of the six finance courses, one graded and counted, one
  // still ongoing and excluded until it is.
  final second = offshootCourses[1];
  await saveCourse(Course(
    title: second.title,
    id: second.id,
    discipline: '--',
    sem: '3 - 1',
    elective: Elective.open.tag,
    credits: 3,
    grade1: GradeCode.ongoing,
    grade2: GradeCode.clr,
  ));
  await setOffshootOutOf(50);
  await toggleOffshootExcluded(second.id);

  // Minor: Data Science, with one core course already done — partial
  // progress, not complete.
  await setChosenMinor(minorNamed('Data Science'));

  await setStatsTarget(8.5);
  await setStatsPlan({'3 - 2': 8.0, '4 - 1': 8.0});
  // Matches the review tools/test_env/seed.mjs writes for this account, so
  // "Your reviews" (backed by the local myReviews list) finds it.
  await pinCategory('EEE F311');
  await rememberReview('EEE F311');
}

/// `B3A7` (Economics/CS dual), batch 22, currently in Practice School-II at
/// 5-1 with the second PS II scheduled at 5-2 — the shape D3 gives every
/// dual student once it lands. Placed by hand here (D3 itself isn't built
/// yet); D3's migration treats two existing rows as a no-op, so this stays
/// correct once it does.
Future<void> _seedStudentDual(DateTime now) async {
  app.selecteddiscipline = 'B3A7';
  app.batch = 22;
  app.campus = Campus.goa;
  app.erase = 1;
  await app.setdis();
  await app.initializeCourses();
  app.erase = 0;
  app.currentsem = '5 - 1';
  await app.setsem();

  final box = Hive.box<Course>(coursesBoxName);
  for (final c in box.values.toList()) {
    if (c.id == 'BITS F412') continue; // Practice School-II, handled below
    await saveCourse(
      c.withGrade(1, gradeValues['A-']!).withGrade(2, gradeValues['A-']!),
    );
  }

  final ps2 = box.values.firstWhere((c) => c.id == 'BITS F412');
  await saveCourse(ps2.copyWith(sem: '5 - 1', grade1: GradeCode.ongoing));
  await box.put('BITS F412#2', ps2.copyWith(sem: '5 - 2'));

  await setChosenMinor(minorNamed('Data Science'));
  final offshootCourse = offshootCourses[2];
  await saveCourse(Course(
    title: offshootCourse.title,
    id: offshootCourse.id,
    discipline: '--',
    sem: '3 - 1',
    elective: Elective.open.tag,
    credits: 3,
    grade1: gradeValues['B']!,
    grade2: gradeValues['B']!,
  ));
  await setOffshootOutOf(60);
}

/// `--A3`, batch 24, at 3-1 with three electives already graded and no
/// reviews: the review gate locks this student when it is on (B9).
Future<void> _seedGateStudent(DateTime now) async {
  await _startAt('3 - 1', 24);
  final open = offshootCourses[0];
  final picks = [
    ('Ethics and Self Awareness', 'HSS F219', '2 - 2', Elective.humanity),
    (open.title, open.id, '2 - 1', Elective.open),
    ('Embedded Systems', 'EEE F332', '2 - 2', Elective.del1),
  ];
  for (final (title, id, sem, tag) in picks) {
    await saveCourse(Course(
      title: title,
      id: id,
      discipline: '--',
      sem: sem,
      elective: tag.tag,
      credits: 3,
      grade1: gradeValues['B']!,
      grade2: gradeValues['B']!,
    ));
  }
}

/// `--A3`, batch 25, still at 1-2: before the gate's semester, so exempt.
Future<void> _seedGateExempt(DateTime now) => _startAt('1 - 2', 25);

Future<void> _startAt(String sem, int batch) async {
  app.selecteddiscipline = '--A3';
  app.batch = batch;
  app.campus = Campus.goa;
  app.erase = 1;
  await app.setdis();
  await app.initializeCourses();
  app.erase = 0;
  app.currentsem = sem;
  await app.setsem();
}
