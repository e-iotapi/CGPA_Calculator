import 'package:cgpa_calculator/core/reviews/review.dart';
import 'package:cgpa_calculator/core/reviews/review_stats.dart';
import 'package:flutter_test/flutter_test.dart';

Review r(
  String id, {
  int stars = 3,
  bool rec = true,
  String? grade,
  num? marks,
  String? prof,
  String term = '2025-26-1',
  int helpful = 0,
  int at = 0,
  String? text,
}) => Review(
  id: id,
  courseId: 'c',
  stars: stars,
  recommend: rec,
  campus: 'goa',
  term: term,
  professorId: prof,
  grade: grade,
  marks: marks,
  helpful: helpful,
  createdAt: at,
  text: text,
);

List<String> ids(Iterable<Review> rs) => [for (final x in rs) x.id];

void main() {
  group('statsOf', () {
    test('imported class averages win over reviewers\' own grades', () {
      const classes = [
        ClassAverage(
          term: '2024-25-1',
          grade: 8,
          gradeN: 3,
          marks: 60,
          outOf: 100,
          marksN: 1,
        ),
        ClassAverage(
          term: '2025-26-1',
          grade: 7,
          gradeN: 1,
          marks: 70,
          outOf: 100,
          marksN: 3,
        ),
      ];
      final s = statsOf([r('a', grade: 'A', marks: 95)], classes: classes);
      expect(s.avgGradePoints, 7.75);
      expect(s.avgGradeLetter, 'B');
      expect(s.avgMarks, 67.5);
      expect(s.marksOutOf, 100);
      expect(s.gradeCount, 4);
      // Different totals across terms: a percentage.
      final mixed = statsOf(
        const [],
        classes: [
          classes.first,
          const ClassAverage(
            term: '2025-26-1',
            marks: 150,
            outOf: 200,
            marksN: 1,
          ),
        ],
      );
      expect(mixed.avgMarks, 67.5);
      expect(mixed.marksOutOf, 100);
      // None: the reviewers' own, with no total.
      final own = statsOf([r('a', grade: 'A', marks: 95)]);
      expect(own.avgGradeLetter, 'A');
      expect(own.marksOutOf, isNull);
      expect(classes.first.matches('2024-25', '1'), isTrue);
      expect(classes.first.matches('2024-25', '2'), isFalse);
      expect(classes.first.matches(null, null), isTrue);
    });

    test('empty says nothing', () {
      final s = statsOf(const []);
      expect(s.count, 0);
      expect(s.avgStars, isNull);
      expect(s.recommendPct, isNull);
      expect(s.avgGradeLetter, isNull);
      expect(s.avgMarks, isNull);
    });

    test('ND, W, NC, RC and missing grades stay out of the grade average', () {
      final s = statsOf([
        r('1', grade: 'A'),
        r('2', grade: 'B'),
        r('3', grade: 'ND'),
        r('4', grade: 'W'),
        r('5', grade: 'NC'),
        r('6', grade: 'RC'),
        r('7'),
      ]);
      expect(s.count, 7);
      expect(s.gradeCount, 2);
      expect(s.avgGradePoints, 9);
      expect(s.avgGradeLetter, 'A-');
    });

    test('no gradable letters: no average', () {
      final s = statsOf([r('1', grade: 'ND')]);
      expect(s.avgGradePoints, isNull);
      expect(s.avgGradeLetter, isNull);
    });

    test('marks average only over those given', () {
      final s = statsOf([r('1', marks: 80), r('2', marks: 61), r('3')]);
      expect(s.avgMarks, 70.5);
      expect(s.marksCount, 2);
      expect(statsOf([r('1')]).avgMarks, isNull);
    });

    test('stars and recommend as ReviewStats', () {
      final s = statsOf([r('1', stars: 5), r('2', stars: 2, rec: false)]);
      expect(s.avgStars, 3.5);
      expect(s.recommendPct, 50);
    });
  });

  group('applyQuery', () {
    final rs = [
      r('a', stars: 5, prof: 'p1', helpful: 1, at: 1, term: '2024-25-1'),
      r('b', stars: 1, prof: 'p2', helpful: 9, at: 3, term: '2025-26-2'),
      r('c', stars: 5, prof: 'p1', helpful: 4, at: 2, term: '2025-26-1'),
      r('d', stars: 3, prof: 'p3', helpful: 4, at: 4, text: 'tough exams'),
    ];
    const names = {'p3': 'Rao'};
    List<String> q(ReviewQuery x) => ids(applyQuery(rs, x, names));

    test('sorts', () {
      expect(q(const ReviewQuery()), ['b', 'd', 'c', 'a']);
      expect(q(const ReviewQuery(sort: ReviewSort.recent)), [
        'd',
        'b',
        'c',
        'a',
      ]);
      expect(q(const ReviewQuery(sort: ReviewSort.highest)), [
        'c',
        'a',
        'd',
        'b',
      ]);
      expect(q(const ReviewQuery(sort: ReviewSort.lowest)), [
        'b',
        'd',
        'c',
        'a',
      ]);
    });

    test('filters combine', () {
      expect(q(const ReviewQuery(professorIds: {'p1', 'p2'})), ['b', 'c', 'a']);
      expect(q(const ReviewQuery(professorIds: {'p1'}, year: '2025-26')), [
        'c',
      ]);
      expect(q(const ReviewQuery(year: '2025-26', sem: '2')), ['b']);
      expect(q(const ReviewQuery(sem: '1', professorIds: {'p1'})), ['c', 'a']);
      expect(q(const ReviewQuery(text: 'rao')), ['d']);
      expect(
        q(const ReviewQuery(text: 'tough', professorIds: {'p1'})),
        isEmpty,
      );
    });
  });

  test('validYear', () {
    final now = DateTime(2026, 10);
    expect(validYear('2023-24', now: now), '2023-24');
    expect(validYear('2023', now: now), '2023-24');
    expect(validYear('1999', now: now), isNull);
    expect(validYear('2023-25', now: now), isNull);
    expect(validYear('2028', now: now), isNull);
    expect(validYear('2027', now: now), '2027-28');
    expect(validYear('abc', now: now), isNull);
  });
}
