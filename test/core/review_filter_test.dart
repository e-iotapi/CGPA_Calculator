import 'package:cgpa_calculator/core/reviews/review.dart';
import 'package:cgpa_calculator/core/reviews/review_filter.dart';
import 'package:flutter_test/flutter_test.dart';

Review r(String id, String term, {String? text, String? prof, int stars = 4}) =>
    Review(
      id: id,
      courseId: 'CS F111',
      stars: stars,
      recommend: stars >= 3,
      campus: 'goa',
      term: term,
      text: text,
      professorId: prof,
    );

void main() {
  final all = [
    r('a', '2025-26-1', text: 'Great labs', prof: 'p1'),
    r('b', '2025-26-2', text: 'Heavy quizzes', stars: 2),
    r('c', '2024-25-S', text: 'Summer rush'),
    r('d', '', text: 'Old review'),
  ];

  test('terms split into year and semester; odd ones do not', () {
    expect(termParts('2024-25-S'), ('2024-25', 'S'));
    expect(termParts(''), isNull);
    expect(termParts('2024-1'), isNull);
  });

  test('year and semester narrow; an empty term shows under All only', () {
    ids(ReviewFilter f) => [for (final x in f.apply(all)) x.id];
    expect(ids(const ReviewFilter()), ['a', 'b', 'c', 'd']);
    expect(ids(const ReviewFilter(year: '2025-26')), ['a', 'b']);
    expect(ids(const ReviewFilter(sem: 'S')), ['c']);
    expect(ids(const ReviewFilter(year: '2025-26', sem: '2')), ['b']);
  });

  test('search matches text and professor name, any case', () {
    expect(const ReviewFilter(query: 'QUIZ').apply(all).single.id, 'b');
    expect(
      const ReviewFilter(
        query: 'menon',
      ).apply(all, {'p1': 'R Menon'}).single.id,
      'a',
    );
  });

  test('years newest first; stats follow the filter', () {
    expect(ReviewFilter.yearsIn(all), ['2025-26', '2024-25']);
    final s = ReviewFilter.statsOf(
      const ReviewFilter(year: '2025-26').apply(all),
    );
    expect((s.count, s.starSum, s.recommendCount), (2, 6, 1));
  });
}
