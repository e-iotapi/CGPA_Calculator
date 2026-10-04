/// Per-filter review summary and the combined filter and sort the review
/// list applies to the loaded reviews (R-B: computed in the app, no counters).
library;

import 'package:cgpa_calculator/core/grading/grade_scale.dart';
import 'package:cgpa_calculator/core/reviews/review.dart';
import 'package:cgpa_calculator/core/reviews/review_filter.dart';

/// What the summary card shows for the reviews passed to [statsOf].
class ReviewSummary {
  const ReviewSummary({
    required this.count,
    this.avgStars,
    this.recommendPct,
    this.avgGradePoints,
    this.avgGradeLetter,
    this.avgMarks,
    this.marksCount = 0,
    this.gradeCount = 0,
    this.marksOutOf,
  });

  /// Reviews counted, and how many carried marks or a gradable letter.
  final int count, marksCount, gradeCount;

  /// Mean stars, mean grade points and mean marks: each null when there is
  /// nothing to average.
  final double? avgStars, avgGradePoints, avgMarks;

  /// The rounded percentage recommending.
  final int? recommendPct;

  /// The letter nearest [avgGradePoints].
  final String? avgGradeLetter;

  /// What [avgMarks] is out of, when the class averages give it.
  final double? marksOutOf;
}

/// One term's class average, imported once with the old reviews: grade
/// points and marks out of [outOf], each over the reviews that reported it.
class ClassAverage {
  const ClassAverage({
    required this.term,
    this.grade,
    this.gradeN = 0,
    this.marks,
    this.outOf,
    this.marksN = 0,
  });

  factory ClassAverage.fromMap(String term, Map m) => ClassAverage(
    term: term,
    grade: (m['g'] as num?)?.toDouble(),
    gradeN: (m['gn'] as num?)?.toInt() ?? 0,
    marks: (m['m'] as num?)?.toDouble(),
    outOf: (m['t'] as num?)?.toDouble(),
    marksN: (m['mn'] as num?)?.toInt() ?? 0,
  );

  /// `'2024-25-1'`.
  final String term;
  final double? grade, marks, outOf;
  final int gradeN, marksN;

  /// Whether the year (`'2024-25'`) and semester (`'1'`) filters keep it.
  bool matches(String? year, String? sem) =>
      (year == null || term.startsWith('$year-')) &&
      (sem == null || term.endsWith('-$sem'));
}

/// Summarises [rs], which the caller has already filtered (and from which
/// it has removed hidden reviews). `ND`, `W`, `NC`, `RC` and missing grades
/// stay out of the grade average; marks average over those given.
///
/// [classes], the imported class averages the same filters keep, win over
/// the reviewers' own grades and marks, which run high: the grade from
/// them when any gives one, and likewise the marks.
ReviewSummary statsOf(
  Iterable<Review> rs, {
  List<ClassAverage> classes = const [],
}) {
  final base = ReviewFilter.statsOf(rs);
  final pts = [
    for (final r in rs)
      if (gradeValues[r.grade] case final p? when p > 0) p,
  ];
  final marks = [
    for (final r in rs)
      if (r.marks != null) r.marks!.toDouble(),
  ];
  double? mean(Iterable<(double, int)> xs) {
    final n = xs.fold(0, (s, x) => s + x.$2);
    return n == 0 ? null : xs.fold(0.0, (s, x) => s + x.$1 * x.$2) / n;
  }

  final cg = [
    for (final c in classes)
      if (c.grade != null && c.gradeN > 0) (c.grade!, c.gradeN),
  ];
  final cm = [
    for (final c in classes)
      if (c.marks != null && c.outOf != null && c.marksN > 0) c,
  ];
  // One course total across the terms: marks as they are; else percent.
  final sameTotal = cm.map((c) => c.outOf).toSet().length == 1;
  final classMarks = mean([
    for (final c in cm)
      (sameTotal ? c.marks! : 100 * c.marks! / c.outOf!, c.marksN),
  ]);
  final avgPts =
      cg.isNotEmpty
          ? mean(cg)
          : pts.isEmpty
          ? null
          : pts.reduce((a, b) => a + b) / pts.length;
  return ReviewSummary(
    count: base.count,
    avgStars: base.average,
    recommendPct: base.recommendPercent,
    avgGradePoints: avgPts,
    avgGradeLetter: avgPts == null ? null : gradecalc(avgPts.round()),
    avgMarks:
        classMarks ??
        (marks.isEmpty ? null : marks.reduce((a, b) => a + b) / marks.length),
    marksCount:
        classMarks != null ? cm.fold(0, (s, c) => s + c.marksN) : marks.length,
    gradeCount: cg.isNotEmpty ? cg.fold(0, (s, x) => s + x.$2) : pts.length,
    marksOutOf: classMarks == null ? null : (sameTotal ? cm.first.outOf : 100),
  );
}

enum ReviewSort { helpful, recent, highest, lowest }

/// The review list's filters and sort; they AND-combine.
class ReviewQuery {
  const ReviewQuery({
    this.professorIds = const {},
    this.year,
    this.sem,
    this.text = '',
    this.sort = ReviewSort.helpful,
  });

  /// Empty means every professor. The caller expands merged ids.
  final Set<String> professorIds;

  /// `'2023-24'` (see [validYear]) and `'1'`, `'2'` or `'S'`.
  final String? year, sem;

  /// Free text, matched in review text and professor names.
  final String text;
  final ReviewSort sort;
}

/// [rs] matching [q], ordered by [ReviewQuery.sort]; ties by newest.
List<Review> applyQuery(
  Iterable<Review> rs,
  ReviewQuery q,
  Map<String, String> professorNames,
) {
  final kept = [
    for (final r in ReviewFilter(
      year: q.year,
      sem: q.sem,
      query: q.text,
    ).apply(rs, professorNames))
      if (q.professorIds.isEmpty || q.professorIds.contains(r.professorId)) r,
  ];
  int by(Review a, Review b) {
    final h = b.helpful.compareTo(a.helpful);
    return switch (q.sort) {
      ReviewSort.helpful => h,
      ReviewSort.recent => 0,
      ReviewSort.highest => a.stars != b.stars ? b.stars - a.stars : h,
      ReviewSort.lowest => a.stars != b.stars ? a.stars - b.stars : h,
    };
  }

  return kept..sort((a, b) {
    final c = by(a, b);
    return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
  });
}

/// `'2023-24'` or `'2023'` as `'2023-24'`; null when odd, before 2000 or
/// after next year.
String? validYear(String input, {DateTime? now}) {
  final m = RegExp(r'^(\d{4})(?:-(\d{2}))?$').firstMatch(input.trim());
  if (m == null) return null;
  final y = int.parse(m[1]!);
  final next = ((y + 1) % 100).toString().padLeft(2, '0');
  if (y < 2000 || y > (now ?? DateTime.now()).year + 1) return null;
  if (m[2] != null && m[2] != next) return null;
  return '$y-$next';
}
