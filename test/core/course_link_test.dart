import 'package:cgpa_calculator/core/catalog/catalog.dart';
import 'package:cgpa_calculator/core/storage/course_link.dart';
import 'package:cgpa_calculator/core/storage/seed.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/mastercourselist.dart';
import 'package:flutter_test/flutter_test.dart';

Course _c(String id, String title, double credits, {int grade = 10}) => Course(
  title: title,
  id: id,
  credits: credits,
  grade1: grade,
  grade2: -2,
  discipline: 'A7',
  sem: '2 - 1',
  elective: 'CDC',
  more: {3: 8},
);

List _all(Course c) => [
  c.id,
  c.title,
  c.credits,
  c.grade1,
  c.grade2,
  c.discipline,
  c.sem,
  c.elective,
  c.more,
];

/// The shipped catalogue with CS F211's credits changed to [credits].
Catalog _withCredits(double credits) {
  final c = catalog;
  List<Course> rows(List<Course> l) => [
    for (final r in l) r.id == 'CS F211' ? r.copyWith(credits: credits) : r,
  ];
  return Catalog(
    version: c.version + 1,
    chartOld: rows(c.chartOld),
    chartNew: rows(c.chartNew),
    master: [
      for (final m in c.master)
        m.id == 'CS F211'
            ? Mastercourselist(title: m.title, id: m.id, credits: credits)
            : m,
    ],
    retired: c.retired,
  );
}

void main() {
  final dsa = catalogIdentity('CS F211')!;

  test('a catalogue course is stored by id, without title or credits', () {
    final m = encodeCourse(_c('CS F211', dsa.title, dsa.credits));
    expect(m.containsKey('title'), isFalse);
    expect(m.containsKey('credits'), isFalse);
    expect(m['grade1'], 10);
    expect(_all(decodeCourse(m)), _all(_c('CS F211', dsa.title, dsa.credits)));
  });

  test('a custom course, or one with its own credits, stays whole', () {
    final custom = _c('XYZ F999', 'Something Else', 2);
    final own = _c('CS F211', dsa.title, dsa.credits + 1);
    for (final c in [custom, own]) {
      final m = encodeCourse(c);
      expect(m.containsKey('credits'), isTrue);
      expect(_all(decodeCourse(m)), _all(c));
    }
    expect(encodeCourse(custom).containsKey('title'), isTrue);
    expect(encodeCourse(own).containsKey('title'), isFalse);
  });

  test('entries written before the split still read back whole', () {
    final old = {
      'title': 'Old Name',
      'id': 'CS F211',
      'credits': 4,
      'grade1': 9,
      'grade2': 8,
      'discipline': 'A7',
      'sem': '2 - 1',
      'elective': 'CDC',
    };
    final c = decodeCourse(old);
    expect([c.title, c.credits, c.grade1, c.grade2], ['Old Name', 4.0, 9, 8]);
  });

  test('every seeded course round-trips through the linked form', () {
    for (final d in ['A7', 'B3A7', 'A3', 'B5AA']) {
      for (final c in seedCourses(d, chartRows(25))) {
        expect(_all(decodeCourse(encodeCourse(c))), _all(c), reason: c.id);
      }
    }
  });

  test('a published credit correction reaches a linked course only', () {
    final next = _withCredits(dsa.credits + 1);
    final linked = _c('CS F211', dsa.title, dsa.credits);
    expect(relink(linked, catalog, next)!.credits, dsa.credits + 1);
    expect(relink(linked, catalog, next)!.grade1, 10);

    final own = _c('CS F211', dsa.title, 5);
    expect(relink(own, catalog, next), isNull);
    expect(relink(_c('XYZ F999', 'X', 3), catalog, next), isNull);
  });
}
