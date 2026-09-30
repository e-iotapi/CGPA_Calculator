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

/// The longest review text, in characters.
const reviewTextLimit = 600;

/// One review of a course offering, keyed by [hashedId].
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

  /// The pseudonymous review id, and the course, campus key and term it
  /// concerns.
  final String id, courseId, campus, term;

  /// The rating, 1 to 5.
  final int stars;

  /// Whether the reviewer recommends the course.
  final bool recommend;

  /// Null when the offering recorded no professor: it counts toward the
  /// course and no professor (fix 5).
  final String? professorId;
  /// The written review, if any.
  final String? text;

  /// Whether a moderator hid the review.
  final bool hidden;

  /// The moderator's reason and name, when [hidden].
  final String? reason, hiddenByName;

  /// The helpful-vote and report counters.
  final int helpful, reports;

  /// Milliseconds since the epoch.
  final int createdAt, updatedAt;

  /// Whether the review was changed after it was posted.
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

  /// Reads a review from Firestore or the Hive cache.
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

  /// The number of reviews, the sum of their stars and how many recommend.
  final int count, starSum, recommendCount;

  /// The mean star rating, or `null` with no reviews.
  double? get average => count == 0 ? null : starSum / count;

  /// The rounded percentage recommending, or `null` with no reviews.
  int? get recommendPercent =>
      count == 0 ? null : (100 * recommendCount / count).round();

  /// The combined counters of this and [o].
  ReviewStats operator +(ReviewStats o) => ReviewStats(
    count: count + o.count,
    starSum: starSum + o.starSum,
    recommendCount: recommendCount + o.recommendCount,
  );

  /// Reads a stats document; a missing one reads as zeros.
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
  /// The chip label and the Firestore field ordered by.
  final String label, field;

  /// Whether larger values come first.
  final bool descending;
}
