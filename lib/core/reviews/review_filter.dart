/// Search and year/semester filtering over reviews already loaded: the
/// course's campus doc holds them all, so filtering costs no reads.
library;

import 'package:cgpa_calculator/core/reviews/review.dart';

/// `'2025-26-1'` → `('2025-26', '1')`; null for a missing or odd term.
(String year, String sem)? termParts(String term) {
  final m = RegExp(r'^(\d{4}-\d{2})-(1|2|S)$').firstMatch(term);
  return m == null ? null : (m[1]!, m[2]!);
}

const semesterLabels = {'1': 'Sem 1', '2': 'Sem 2', 'S': 'Summer'};

class ReviewFilter {
  const ReviewFilter({this.year, this.sem, this.query = ''});

  final String? year, sem;
  final String query;

  bool get active => year != null || sem != null || query.trim().isNotEmpty;

  /// [names] maps professor ids to names, so a search finds them too.
  List<Review> apply(
    Iterable<Review> reviews, [
    Map<String, String> names = const {},
  ]) {
    final q = query.trim().toLowerCase();
    return [
      for (final r in reviews)
        if (_term(r) && (q.isEmpty || _text(r, names).contains(q))) r,
    ];
  }

  bool _term(Review r) {
    if (year == null && sem == null) return true;
    final t = termParts(r.term);
    return t != null &&
        (year == null || t.$1 == year) &&
        (sem == null || t.$2 == sem);
  }

  static String _text(Review r, Map<String, String> names) =>
      '${r.text ?? ''} ${names[r.professorId] ?? ''}'.toLowerCase();

  /// The academic years present, newest first.
  static List<String> yearsIn(Iterable<Review> reviews) =>
      {
          for (final r in reviews)
            if (termParts(r.term) case (final y, _)) y,
        }.toList()
        ..sort((a, b) => b.compareTo(a));

  /// Counters for [reviews], so the summary card follows the filter.
  static ReviewStats statsOf(Iterable<Review> reviews) => ReviewStats(
    count: reviews.length,
    starSum: reviews.fold(0, (s, r) => s + r.stars),
    recommendCount: reviews.where((r) => r.recommend).length,
  );
}
