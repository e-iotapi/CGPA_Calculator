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
    // Every stored value a course can hold, weighted towards the awkward
    // ones. GD (-3) is excluded: the original dropped GD credits from the
    // denominator entirely (BUG-06), which this implementation no longer
    // does — see the GD-specific tests below.
    const values = [10, 9, 8, 7, 6, 5, 4, 2, -1, -2, -5, -6, -7];
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

  test(
    'GD keeps its credits in the GPA denominator but earns no points '
    '(BUG-06); NC, RC and W drop out of both credits and the denominator',
    () {
      final courses = [
        _course('1 - 1', 4, 10, 0), // A: 40 points, 4 credits
        _course('1 - 1', 3, GradeCode.gd, 0), // GD: 0 points, 3 credits kept
        _course('1 - 1', 2, GradeCode.nc, 0),
        _course('1 - 1', 2, GradeCode.rc, 0),
        _course('1 - 1', 2, GradeCode.w, 0),
        _course('1 - 1', 5, 0, 0), // ungraded: not in denominator or shown
      ];
      final t = tally(courses, Profile.actual);
      expect(t.points, 40);
      expect(t.gradedCredits, 7); // A's 4 + GD's 3
      // Shown: everything except a non-GD negative code — the ungraded
      // course's 5 credits still show (it just isn't in the GPA yet).
      expect(t.shownCredits, 12); // A's 4 + GD's 3 + ungraded's 5
      expect(t.rounded, closeTo(40 / 7, 0.005));

      // SGPA must equal the sum over the visible, graded courses: same
      // course set, same discipline filter, as semesterTally uses.
      const d = 'B3A7';
      final visible = courses.where((c) => inDiscipline(c, d));
      expect(
        semesterTally(
          courses,
          sem: '1 - 1',
          discipline: d,
          profile: Profile.actual,
        ).rounded,
        tally(visible, Profile.actual).rounded,
      );
    },
  );

  test('a course counted in SGPA/CGPA is never hidden from the visible list '
      '(BUG-40): inDiscipline matches "--" the same way regardless of which '
      'half of the discipline code holds it', () {
    final open = _course('2 - 1', 3, 9, 9, '--'); // catalogue open elective
    final real = _course('2 - 1', 3, 10, 10, 'A7');
    final courses = [open, real];

    // Single degree stored either as "A7--" or "--A7" must treat "--"
    // identically: both halves are checked, in either order.
    for (final discipline in ['A7--', '--A7']) {
      final visible = courses.where((c) => inDiscipline(c, discipline));
      expect(
        visible,
        containsAll([open, real]),
        reason: 'discipline "$discipline" hid a course it still counts',
      );
      final gpa = semesterTally(
        courses,
        sem: '2 - 1',
        discipline: discipline,
        profile: Profile.actual,
      );
      // Every course the GPA counts must be in the visible set.
      expect(gpa.gradedCredits, tally(visible, Profile.actual).gradedCredits);
    }
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
