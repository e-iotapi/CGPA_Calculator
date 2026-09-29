/// Reviews (ARCHITECTURE.md §10.3, §16.3 fixes 4–6): per professor and per
/// term, pseudonymous by construction, counted by counters rather than
/// queries.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

/// `sha256(uid + key)` as lowercase hex. Reviews use the course id, votes
/// and reports the review id: one per person, and nothing that links one
/// person's entries together.
String hashedId(String uid, String key) =>
    sha256.convert(utf8.encode(uid + key)).toString();

const reviewTextLimit = 600;

class Review {
  const Review({
    required this.id,
    required this.courseId,
    required this.stars,
    required this.recommend,
    required this.campus,
    required this.term,
    this.professorId,
    this.text,
    this.hidden = false,
    this.reason,
    this.hiddenByName,
    this.helpful = 0,
    this.reports = 0,
    this.createdAt = 0,
    this.updatedAt = 0,
  });

  final String id, courseId, campus, term;
  final int stars;
  final bool recommend;

  /// Null when the offering recorded no professor: it counts toward the
  /// course and no professor (fix 5).
  final String? professorId;
  final String? text;
  final bool hidden;
  final String? reason, hiddenByName;
  final int helpful, reports;

  /// Milliseconds since the epoch.
  final int createdAt, updatedAt;

  bool get edited => updatedAt > createdAt + 1000;

  /// After a successful vote: the server write already moved the counter,
  /// this just keeps the on-screen tile from lagging behind it (fix for a
  /// helpful count that only updates on reload).
  Review withHelpful(int n) => Review(
    id: id,
    courseId: courseId,
    stars: stars,
    recommend: recommend,
    campus: campus,
    term: term,
    professorId: professorId,
    text: text,
    hidden: hidden,
    reason: reason,
    hiddenByName: hiddenByName,
    helpful: n,
    reports: reports,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  /// The shape cached in Hive.
  Map<String, dynamic> toMap() => {
    'stars': stars,
    'recommend': recommend,
    'campus': campus,
    'term': term,
    'professorId': professorId,
    if (text != null) 'text': text,
    'hidden': hidden,
    'helpful': helpful,
    'reports': reports,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  static int _ms(Object? at) =>
      at is int
          ? at
          : at is num
          ? at.toInt()
          : (at as dynamic)?.millisecondsSinceEpoch as int? ?? 0;

  static Review fromMap(String id, String courseId, Map m) => Review(
    id: id,
    courseId: courseId,
    stars: (m['stars'] as num?)?.toInt() ?? 0,
    recommend: m['recommend'] as bool? ?? false,
    campus: m['campus'] as String? ?? '',
    term: m['term'] as String? ?? '',
    professorId: m['professorId'] as String?,
    text: m['text'] as String?,
    hidden: m['hidden'] as bool? ?? false,
    reason: m['reason'] as String?,
    hiddenByName: (m['hiddenBy'] as Map?)?['name'] as String?,
    helpful: (m['helpful'] as num?)?.toInt() ?? 0,
    reports: (m['reports'] as num?)?.toInt() ?? 0,
    createdAt: _ms(m['createdAt']),
    updatedAt: _ms(m['updatedAt']),
  );
}

/// `courses/{id}/stats/{campus}` or `…/{campus}_{profId}`.
class ReviewStats {
  const ReviewStats({
    this.count = 0,
    this.starSum = 0,
    this.recommendCount = 0,
  });

  final int count, starSum, recommendCount;

  double? get average => count == 0 ? null : starSum / count;
  int? get recommendPercent =>
      count == 0 ? null : (100 * recommendCount / count).round();

  ReviewStats operator +(ReviewStats o) => ReviewStats(
    count: count + o.count,
    starSum: starSum + o.starSum,
    recommendCount: recommendCount + o.recommendCount,
  );

  static ReviewStats fromMap(Map? m) => ReviewStats(
    count: (m?['count'] as num?)?.toInt() ?? 0,
    starSum: (m?['starSum'] as num?)?.toInt() ?? 0,
    recommendCount: (m?['recommendCount'] as num?)?.toInt() ?? 0,
  );
}

/// The stats document id for [campus], or one professor on it.
String statsId(String campus, [String? professorId]) =>
    professorId == null ? campus : '${campus}_$professorId';

/// Orderings, each with its composite index (§10.3).
enum ReviewOrder {
  helpful('Helpful', 'helpful', true),
  recent('Recent', 'createdAt', true),
  highest('Highest', 'stars', true),
  lowest('Lowest', 'stars', false);

  const ReviewOrder(this.label, this.field, this.descending);
  final String label, field;
  final bool descending;
}
