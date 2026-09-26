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

  group('needs from a performance sheet', () {
    AuditCategory card(DegreeAudit a, String label) =>
        a.categories.singleWhere((c) => c.label == label);

    test('set HEL and EL, and a single degree\'s DEL', () {
      const needs = DegreeNeeds(
        degree: '--A7',
        hel: (courses: 2, units: 6),
        del: (courses: 5, units: 15),
        el: (courses: 0, units: 0),
      );
      final a = degreeAudit([], '--A7', needs: needs);
      expect(card(a, 'Humanity Electives').requiredCredits, 6);
      expect(card(a, 'Disciplinary Electives (A7)').requiredCourses, 5);
      // Nothing required: totals only.
      expect(card(a, 'Open Electives').requiredCredits, isNull);
    });

    test('are ignored under another degree', () {
      const needs = DegreeNeeds(degree: 'B3A7', hel: (courses: 2, units: 6));
      final a = degreeAudit([], '--A7', needs: needs);
      expect(card(a, 'Humanity Electives').requiredCredits, 8);
      expect(card(a, 'Open Electives').requiredCredits, 15);
    });

    test('a dual keeps a card per half, with the table\'s share', () {
      const needs = DegreeNeeds(degree: 'B3A7', del: (courses: 9, units: 27));
      final a = degreeAudit([], 'B3A7', needs: needs);
      expect(card(a, 'Disciplinary Electives (B3)').requiredCredits, 18);
      expect(card(a, 'Disciplinary Electives (A7)').requiredCredits, 12);
    });

    test('bring one core card, counting every core course', () {
      const needs = DegreeNeeds(
        degree: 'B3A7',
        cdc: (courses: 4, units: 12),
        hel: (courses: 1, units: 3),
      );
      final a = degreeAudit(
        [
          _c('CDC1', 3, 8),
          _c('CDC2', 3, 8, 'A7'),
          _c('CDCN', 3, 9),
          _c('Humanity Elective', 3, 9),
        ],
        'B3A7',
        needs: needs,
      );
      final core = card(a, 'Core courses (CDC)');
      expect((core.courses, core.credits), (3, 9));
      expect(a.categories.where((c) => c.label.startsWith('CDC')), isEmpty);
      // 3 core credits and both DELs' 30 still to go; HEL is met.
      expect(a.creditsLeft, 33);
    });

    test('survive a JSON round trip', () {
      const needs = DegreeNeeds(
        degree: 'B3A7',
        cdc: (courses: 40, units: 150),
        hel: (courses: 3, units: 8),
        el: (courses: 0, units: 0),
      );
      expect(DegreeNeeds.fromJson(needs.toJson()), needs);
    });
  });

  group('electives are placed by their code', () {
    Course el(String id, String tag, [String d = 'B3']) => Course(
      title: '',
      id: id,
      credits: 3,
      grade1: 9,
      grade2: GradeCode.clr,
      discipline: d,
      sem: '3 - 1',
      elective: tag,
    );
    Elective? of(Course c, [String d = 'B3A7']) => auditCategory(c, d);

    test('a DEL belongs to the half whose department offers it', () {
      expect(of(el('CS F266', 'Disciplinary Elective1')), Elective.del2);
      expect(of(el('ECON F355', 'Disciplinary Elective2')), Elective.del1);
      // Not ECON, but on B3's list.
      expect(of(el('FIN F414', 'Disciplinary Elective2')), Elective.del1);
    });

    test('an elective from another department is an open elective', () {
      expect(
        of(el('EEE F241', 'Disciplinary Elective2'), '--A7'),
        Elective.open,
      );
      expect(of(el('BITS F382', 'Open Elective')), Elective.open);
    });

    test('GS and HSS are humanities', () {
      expect(of(el('GS F211', 'Open Elective')), Elective.humanity);
      expect(of(el('HSS F334', 'Disciplinary Elective1')), Elective.humanity);
    });

    test('ECOM is a DEL for every electronics programme', () {
      for (final d in ['--A3', '--A8', '--AA', '--AC', 'B3A3', 'B5AA']) {
        expect(
          of(el('ECOM F343', 'Disciplinary Elective2'), d),
          Elective.del2,
          reason: d,
        );
      }
      // Not for the others: another department's DEL is an open elective.
      expect(
        of(el('ECOM F343', 'Disciplinary Elective2'), '--A7'),
        Elective.open,
      );
    });

    test('core courses are left alone', () {
      expect(of(el('EEE F111', 'CDC2')), Elective.cdc2);
      expect(of(el('XYZ F101', 'CDCN')), isNull);
    });

    test('common courses are the first degree\'s core', () {
      expect(of(el('HSS F101', 'CDCN')), Elective.cdc1);
      expect(of(el('MATH F111', 'CDCN')), Elective.cdc1);
      expect(of(el('MATH F111', 'CDCN'), '--A7'), Elective.cdc2);
    });

    test('a category set by hand is never moved', () {
      final eee = el('EEE F311', 'Disciplinary Elective2');
      expect(of(eee), Elective.open);
      pinnedCategories = {'EEE F311'};
      addTearDown(() => pinnedCategories = {});
      expect(of(eee), Elective.del2);
    });

    test('and count where they are placed', () {
      final a = degreeAudit([el('CS F266', 'Disciplinary Elective1')], 'B3A7');
      int del(String half) =>
          a.categories
              .singleWhere((c) => c.label == 'Disciplinary Electives ($half)')
              .courses;
      expect((del('A7'), del('B3')), (1, 0));
    });
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
