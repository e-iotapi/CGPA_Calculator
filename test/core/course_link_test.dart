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

/// lib/sync.dart's `_course` on master, verbatim: the app still open on
/// some devices when this version ships.
Course _oldCourse(Map m) => Course(
  title: m['title'],
  id: m['id'],
  credits: (m['credits'] as num).toDouble(),
  grade1: (m['grade1'] as num).toInt(),
  grade2: (m['grade2'] as num).toInt(),
  discipline: m['discipline'],
  sem: m['sem'],
  elective: m['elective'] ?? 'CDC',
);

void main() {
  final dsa = catalogIdentity('CS F211')!;

  test('a catalogue course is marked linked, and still carries its title', () {
    final m = encodeCourse(_c('CS F211', dsa.title, dsa.credits));
    expect(m['linked'], isTrue);
    // An older app, still open somewhere, reads every entry whole.
    expect(m['title'], dsa.title);
    expect(m['credits'], dsa.credits);
    expect(m['grade1'], 10);
    expect(_all(decodeCourse(m)), _all(_c('CS F211', dsa.title, dsa.credits)));
  });

  test('a linked course follows the catalogue over what it carries', () {
    final m = {
      ...encodeCourse(_c('CS F211', dsa.title, dsa.credits)),
      'title': 'Stale Name',
      'credits': 1,
    };
    final c = decodeCourse(m);
    expect([c.title, c.credits], [dsa.title, dsa.credits]);
  });

  test('entries written without title or credits still read', () {
    final m =
        encodeCourse(_c('CS F211', dsa.title, dsa.credits))
          ..remove('title')
          ..remove('credits')
          ..remove('linked');
    final c = decodeCourse(m);
    expect([c.title, c.credits], [dsa.title, dsa.credits]);
  });

  test('a custom course, or one with its own credits, stays whole', () {
    final custom = _c('XYZ F999', 'Something Else', 2);
    final own = _c('CS F211', dsa.title, dsa.credits + 1);
    for (final c in [custom, own]) {
      final m = encodeCourse(c);
      expect(m.containsKey('linked'), isFalse);
      expect(_all(decodeCourse(m)), _all(c));
    }
  });

  test('the older app reads every entry', () {
    for (final c in [
      _c('CS F211', dsa.title, dsa.credits),
      _c('XYZ F999', 'Something Else', 2),
    ]) {
      final old = _oldCourse(encodeCourse(c));
      expect(
        [old.id, old.title, old.credits, old.grade1],
        [c.id, c.title, c.credits, c.grade1],
      );
    }
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
