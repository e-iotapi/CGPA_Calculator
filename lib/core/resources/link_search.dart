import 'package:cgpa_calculator/core/resources/resource.dart';
import 'package:cgpa_calculator/core/search/hints.dart';

export 'package:cgpa_calculator/core/search/hints.dart';

/// The links matching [query] or one of [also], the query's own matches
/// first, title matches before the rest.
List<Resource> searchLinks(
  List<Resource> links,
  String query, {
  List<String> also = const [],
  required String Function(String courseId) courseTitle,
  required String Function(String dept) departmentName,
}) {
  final q = normQuery(query);
  if (q.isEmpty) return const [];
  final out = <Resource>[];
  final seen = <String>{};
  for (final phrase in [q, ...also.map(normQuery)]) {
    if (phrase.isEmpty) continue;
    final titled = <Resource>[], rest = <Resource>[];
    for (final r in links) {
      if (seen.contains(r.id)) continue;
      final title = cleanText(r.title);
      final hay = cleanText(
        [
          r.title,
          r.url,
          r.department,
          departmentName(r.department),
          for (final c in r.courseIds) ...[c, courseTitle(c)],
        ].join(' '),
      );
      if (!matchesWords(phrase, hay.split(' '), hay)) continue;
      (matchesWords(phrase, title.split(' '), title) ? titled : rest).add(r);
    }
    for (final r in [...titled, ...rest]) {
      seen.add(r.id);
      out.add(r);
    }
  }
  return out;
}
