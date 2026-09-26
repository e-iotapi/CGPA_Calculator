import 'dart:io';
import 'dart:math';

import 'package:cgpa_calculator/core/grading/cgpa.dart';
import 'package:cgpa_calculator/core/grading/grade_scale.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/legacy_grading.dart' as legacy;

// Chronological, as the `sems` list in script.dart.
const _sems = [
  '1 - 1',
  '1 - 2',
  '2 - 1',
  '2 - 2',
  'PS 1',
  '3 - 1',
  '3 - 2',
  'ST 1',
  '4 - 1',
  '4 - 2',
];

Course _course(String sem, double credits, int g1, int g2, [String d = 'B3']) =>
    Course(
      title: '',
      id: '',
      credits: credits,
      grade1: g1,
      grade2: g2,
      discipline: d,
      sem: sem,
      elective: 'CDC',
    );

/// Anonymised real transcript. Kept out of git; see .gitignore.
final _transcript = File('test/fixtures/transcript.csv');

List<Course> _loadTranscript() {
  final lines = _transcript.readAsLinesSync().skip(1);
  return [
    for (final l in lines.where((l) => l.trim().isNotEmpty))
      () {
        final f = l.split(',');
        return Course(
          title: '',
          id: f[0],
          sem: f[1],
          credits: double.parse(f[2]),
          discipline: f[3],
          elective: f[4],
          grade1: int.parse(f[5]),
          grade2: int.parse(f[6]),
        );
      }(),
  ];
}

void main() {
  group('matches the original implementation', () {
    // Every stored value a course can hold, weighted towards the awkward ones.
    const values = [10, 9, 8, 7, 6, 5, 4, 2, -1, -2, -3, -3, -3, -5, -6, -7];
    const credits = [0.0, 0.5, 1, 1.5, 2, 3, 4, 5, 6, 20];

    test('on 2,000 random course sets, both profiles', () {
      final rng = Random(42);
      for (var run = 0; run < 2000; run++) {
        final n = rng.nextInt(30);
        final courses = [
          for (var i = 0; i < n; i++)
            _course(
              _sems[rng.nextInt(_sems.length)],
              credits[rng.nextInt(credits.length)].toDouble(),
              values[rng.nextInt(values.length)],
              values[rng.nextInt(values.length)],
              ['B3', 'A7', 'AA', 'B1'][rng.nextInt(4)],
            ),
        ];
        const d = 'B3A7';
        // The original knew only Actual and Expected.
        for (final p in [Profile.actual, Profile.expected]) {
          final inD = courses.where((c) => inDiscipline(c, d));
          expect(
            cumulativeTally(courses, discipline: d, profile: p).rounded,
            legacy.cgcalc(courses, d, p.id),
          );
          expect(
            cumulativeTally(courses, discipline: d, profile: p).shownCredits,
            legacy.shownCredits(inD, p.id),
          );
          // sgcalc was cgcalc's loop over one semester.
          for (final s in _sems) {
            expect(
              semesterTally(courses, sem: s, discipline: d, profile: p).rounded,
              legacy.cgcalc(courses.where((c) => c.sem == s), d, p.id),
            );
          }
        }
        expect(
          '${cumulativeTally(courses, discipline: d, profile: Profile.actual).fixed} '
          '${cumulativeTally(courses, discipline: d, profile: Profile.expected).fixed}',
          legacy.cgcomp(courses, d),
        );
      }
    });

    test('an unknown profile still yields -3.0', () {
      expect(Profile.fromId(0), isNull);
      expect(legacy.cgcalc(const [], 'B3A7', 0), -3.0);
    });
  });

  test('GD passes but carries no weight; NC, RC and W are not shown', () {
    final t = tally([
      _course('1 - 1', 4, 10, 0), // A: 40 points
      _course('1 - 1', 3, GradeCode.gd, 0), // shown, not weighted
      _course('1 - 1', 2, GradeCode.nc, 0),
      _course('1 - 1', 2, GradeCode.rc, 0),
      _course('1 - 1', 2, GradeCode.w, 0),
    ], Profile.actual);
    expect(t.points, 40);
    expect(t.gradedCredits, 4);
    expect(t.shownCredits, 7);
    expect(t.rounded, 10);
  });

  test('nothing graded reads as 0 and "0"', () {
    expect(GpaTally.empty.rounded, 0);
    expect(GpaTally.empty.fixed, '0');
  });

  group(
    'real transcript, B3A7, Actual',
    skip:
        _transcript.existsSync()
            ? null
            : 'test/fixtures/transcript.csv not present',
    () {
      late List<Course> courses;
      setUpAll(() => courses = _loadTranscript());

      test('CGPA after 4-1 is 7.71: 1195 points / 155, 158 shown', () {
        final t = cumulativeTally(
          courses,
          discipline: 'B3A7',
          profile: Profile.actual,
        );
        expect(t.points, 1195);
        expect(t.gradedCredits, 155);
        expect(t.shownCredits, 158);
        expect(t.rounded, 7.71);
        // The naive rule the app does not use — why §2.1 exists.
        expect((t.points / t.shownCredits).toStringAsFixed(2), '7.56');
      });

      test('4-1 SGPA is 9.17', () {
        final t = semesterTally(
          courses,
          sem: '4 - 1',
          discipline: 'B3A7',
          profile: Profile.actual,
        );
        expect(t.rounded, 9.17);
      });

      test('SGPA and running CGPA, semester by semester', () {
        final rows = progression(
          courses,
          semesters: _sems,
          discipline: 'B3A7',
          profile: Profile.actual,
        );
        expect(rows.map((r) => r.sem), [
          '1 - 1',
          '1 - 2',
          '2 - 1',
          '2 - 2',
          'PS 1',
          '3 - 1',
          '3 - 2',
          'ST 1',
          '4 - 1',
        ]);
        expect(rows.map((r) => r.term.fixed), [
          '8.76',
          '7.55',
          '6.60',
          '7.71',
          '10.00',
          '7.17',
          '5.33',
          '9.67',
          '9.17',
        ]);
        expect(rows.map((r) => r.running.fixed), [
          '8.76',
          '8.11',
          '7.67',
          '7.68',
          '7.83',
          '7.68',
          '7.28',
          '7.44',
          '7.71',
        ]);
      });
    },
  );
}
