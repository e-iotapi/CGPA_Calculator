import 'package:cgpa_calculator/core/grading/grade_scale.dart';
import 'package:cgpa_calculator/core/grading/requirements.dart';
import 'package:cgpa_calculator/core/models/elective.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/transcript.dart';

// The old analytics page's own table and rule, verbatim, as the reference.
const _legacyTable = {
  'AD': [15, 48, 4, 12],
  'AA': [14, 48, 4, 12],
  'AB': [15, 48, 4, 12],
  'AC': [14, 48, 4, 12],
  'AJ': [14, 48, 4, 12],
  'A1': [15, 45, 5, 15],
  'A2': [17, 57, 4, 12],
  'A3': [15, 49, 4, 12],
  'A4': [16, 56, 4, 12],
  'A5': [16, 48, 4, 12],
  'A7': [14, 48, 4, 12],
  'A8': [14, 48, 4, 12],
  'A9': [13, 43, 5, 15],
  'B1': [14, 44, 5, 15],
  'B2': [12, 37, 5, 15],
  'B3': [14, 42, 6, 18],
  'B4': [14, 42, 5, 15],
  'B5': [15, 45, 4, 15],
  'B7': [15, 45, 5, 15],
  'B-': [0, 0, 0, 0],
};

double _legacyCreds(String s, List<Course> si) {
  double sum = 0;
  for (int i = 0; i < si.length; i++) {
    if (si[i].elective == s && (si[i].grade1 > 0 || si[i].grade1 == -3)) {
      sum += si[i].credits;
    }
  }
  return sum;
}

int _legacyCount(String s, List<Course> si) =>
    si.where((c) => c.elective == s && (c.grade1 > 0 || c.grade1 == -3)).length;

String _fmt(num v) => v.toString().replaceAll('.0', '');

/// "x/y" strings as the new audit would print them.
Map<String, (String, String)> _shown(DegreeAudit a) => {
  for (final c in a.categories)
    c.category.tag: (
      '${c.courses}${c.requiredCourses == null ? '' : '/${c.requiredCourses}'}',
      '${_fmt(c.credits)}'
          '${c.requiredCredits == null ? '' : '/${c.requiredCredits}'}',
    ),
};

var _n = 0;
Course _c(String el, double cr, int g, [String d = 'B3']) => Course(
  title: '',
  id: 'X ${_n++}',
  credits: cr,
  grade1: g,
  grade2: GradeCode.clr,
  discipline: d,
  sem: '1 - 1',
  elective: el,
);

void main() {
  test('table matches the old page', () {
    for (final e in _legacyTable.entries) {
      final r = requirements[e.key]!;
      expect([r.cdcCourses, r.cdcCredits, r.delCourses, r.delCredits], e.value);
    }
    expect(requirements.length, _legacyTable.length);
  });

  test('tags round-trip', () {
    for (final e in Elective.values) {
      expect(Elective.fromTag(e.tag), e);
    }
  });

  test('GD counts, NC/CLR/RC/W do not, grade1 only', () {
    final cs = [
      _c('CDC1', 3, 10),
      _c('CDC1', 4, GradeCode.gd),
      _c('CDC1', 3, GradeCode.nc),
      _c('CDC1', 3, GradeCode.clr),
      _c('CDC1', 3, GradeCode.rc),
    ];
    expect(earnedCredits(Elective.cdc1, cs), 7);
    expect(earnedCourses(Elective.cdc1, cs), 2);
  });

  test('cards per discipline shape', () {
    List<String> labels(String d) =>
        degreeAudit([], d).categories.map((c) => c.label).toList();
    expect(labels('----'), isEmpty);
    expect(labels('--A7'), [
      'CDC (A7)',
      'Disciplinary Electives (A7)',
      'Humanity Electives',
      'Open Electives',
    ]);
    expect(labels('B3A7').length, 6);
    expect(labels('B3--').first, 'CDC (B3)');
    final bMinus = degreeAudit([], 'B-A7').categories;
    expect(bMinus[2].requiredCredits, isNull); // CDC1 on a B- shows no target
  });

  test(
    'real transcript, B3A7: every "x / y" matches the old page',
    skip: transcriptSkip,
    () {
      final all = loadTranscript();
      final mine =
          all
              .where((c) => c.discipline == 'B3' || c.discipline == 'A7')
              .toList();
      String cnt(String t, [int? req]) =>
          '${_legacyCount(t, mine)}${req == null ? '' : '/$req'}';
      String cr(String t, [int? req]) =>
          '${_fmt(_legacyCreds(t, mine))}${req == null ? '' : '/$req'}';
      final a7 = _legacyTable['A7']!, b3 = _legacyTable['B3']!;
      final expected = {
        'CDC2': (cnt('CDC2', a7[0]), cr('CDC2', a7[1])),
        'Disciplinary Elective2': (
          cnt('Disciplinary Elective2', a7[2]),
          cr('Disciplinary Elective2', a7[3]),
        ),
        'CDC1': (cnt('CDC1', b3[0]), cr('CDC1', b3[1])),
        'Disciplinary Elective1': (
          cnt('Disciplinary Elective1', b3[2]),
          cr('Disciplinary Elective1', b3[3]),
        ),
        'Humanity Elective': (
          cnt('Humanity Elective', 3),
          cr('Humanity Elective', 8),
        ),
        'Open Elective': (cnt('Open Elective'), cr('Open Elective')),
      };
      final audit = degreeAudit(all, 'B3A7');
      expect(_shown(audit), expected);
      expect(audit.totalCredits, 158); // "158 / 144", as the home screen
      // ignore: avoid_print
      print(expected);
    },
  );
}
