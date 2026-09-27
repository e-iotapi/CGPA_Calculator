import 'dart:convert';

import 'package:cgpa_calculator/core/reviews/review.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

const reviewsBoxName = 'reviewsBox';

Future<void> openReviews() => Hive.openBox(reviewsBoxName);

Box? get _cache =>
    Hive.isBoxOpen(reviewsBoxName) ? Hive.box(reviewsBoxName) : null;

/// Reviews and their counters (ARCHITECTURE.md §10.3). Every write moves the
/// course counter — and the professor's, when there is one — in the same
/// batch; the rules check the delta. Read live, only on the screens that
/// show them, never on app open.
class ReviewStore {
  ReviewStore(this.db, {required this.uid, this.roles});

  final FirebaseFirestore db;
  final String? uid;

  /// For moderation: the moderator's name goes on the audit entry.
  final RoleStore? roles;

  CollectionReference<Map<String, dynamic>> entries(String courseId) =>
      db.collection('reviews').doc(courseId).collection('entries');

  DocumentReference<Map<String, dynamic>> _stats(String courseId, String id) =>
      db.collection('courses').doc(courseId).collection('stats').doc(id);

  String? myReviewId(String courseId) =>
      uid == null ? null : hashedId(uid!, courseId);

  /// The course's counter on [campus], or the sum over [professorIds] (a
  /// survivor and everyone merged into it).
  Future<ReviewStats> stats(
    String courseId,
    String campus, {
    List<String>? professorIds,
  }) async {
    final ids =
        professorIds == null
            ? [statsId(campus)]
            : [for (final p in professorIds) statsId(campus, p)];
    var total = const ReviewStats();
    for (final id in ids) {
      total += ReviewStats.fromMap((await _stats(courseId, id).get()).data());
    }
    return total;
  }

  /// Every professor with reviews of [courseId] on [campus], and their
  /// counters: the Reviews screen's "Taught by" pills.
  Future<Map<String, ReviewStats>> byProfessor(
    String courseId,
    String campus,
  ) async {
    final q =
        await db
            .collection('courses')
            .doc(courseId)
            .collection('stats')
            .where('campus', isEqualTo: campus)
            .where('scope', isEqualTo: 'professor')
            .get();
    return {
      for (final d in q.docs)
        if (d.data()['professorId'] case final String id)
          id: ReviewStats.fromMap(d.data()),
    };
  }

  /// The most reviewed courses on [campus] (§16.3 fix 14's index).
  Future<List<({String courseId, ReviewStats stats})>> mostReviewed(
    String campus, {
    int limit = 10,
  }) async {
    final q =
        await db
            .collectionGroup('stats')
            .where('campus', isEqualTo: campus)
            .where('scope', isEqualTo: 'course')
            .orderBy('count', descending: true)
            .limit(limit)
            .get();
    return [
      for (final d in q.docs)
        (
          courseId: d.data()['courseId'] as String? ?? '',
          stats: ReviewStats.fromMap(d.data()),
        ),
    ];
  }

  /// One page of visible reviews on [campus], newest page after [after].
  Future<({List<Review> reviews, DocumentSnapshot? last})> page(
    String courseId,
    String campus, {
    List<String>? professorIds,
    ReviewOrder order = ReviewOrder.helpful,
    DocumentSnapshot? after,
    int limit = 10,
    Duration fresh = const Duration(minutes: 10),
    DateTime? now,
  }) async {
    // The first page of each view is cached (§10.3).
    final key = [courseId, campus, ...?professorIds, order.name].join('|');
    final at = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final raw = after == null ? _cache?.get(key) : null;
    if (raw is String) {
      final m = jsonDecode(raw) as Map;
      if (at - (m['at'] as int) < fresh.inMilliseconds) {
        return (
          reviews: [
            for (final e in (m['rows'] as Map).entries)
              Review.fromMap(e.key as String, courseId, e.value as Map),
          ],
          last: null,
        );
      }
    }
    Query<Map<String, dynamic>> q = entries(
      courseId,
    ).where('campus', isEqualTo: campus).where('hidden', isEqualTo: false);
    if (professorIds != null) {
      q = q.where('professorId', whereIn: professorIds.take(10).toList());
    }
    q = q.orderBy(order.field, descending: order.descending).limit(limit);
    if (after != null) q = q.startAfterDocument(after);
    final r = await q.get();
    final reviews = [
      for (final d in r.docs) Review.fromMap(d.id, courseId, d.data()),
    ];
    if (after == null) {
      await _cache?.put(
        key,
        jsonEncode({
          'at': at,
          'rows': {for (final x in reviews) x.id: x.toMap()},
        }),
      );
    }
    return (reviews: reviews, last: r.docs.lastOrNull);
  }

  Future<Review?> mine(String courseId) async {
    final id = myReviewId(courseId);
    if (id == null) return null;
    final d = await entries(courseId).doc(id).get();
    final m = d.data();
    return m == null ? null : Review.fromMap(id, courseId, m);
  }

  /// Moves the course counter, and the professor's, by the given amounts.
  void _count(
    WriteBatch b,
    String courseId,
    String campus,
    String? professorId,
    String reviewId, {
    required int count,
    required int stars,
    required int recommend,
  }) {
    for (final p in [null, if (professorId != null) professorId]) {
      b.set(_stats(courseId, statsId(campus, p)), {
        'count': FieldValue.increment(count),
        'starSum': FieldValue.increment(stars),
        'recommendCount': FieldValue.increment(recommend),
        'campus': campus,
        'courseId': courseId,
        'scope': p == null ? 'course' : 'professor',
        'professorId': p,
        'touchedBy': reviewId,
      }, SetOptions(merge: true));
    }
  }

  /// Posts, or edits, this person's review of [courseId]. An edit keeps its
  /// votes and moves the counters by the difference.
  Future<void> save({
    required String courseId,
    required String campus,
    required String term,
    required String? professorId,
    required int stars,
    required bool recommend,
    String? text,
    Review? before,
  }) async {
    final id = myReviewId(courseId)!;
    final ref = entries(courseId).doc(id);
    final t = text?.trim();
    final b = db.batch();
    if (before == null) {
      b.set(ref, {
        'courseId': courseId,
        'department': deptOf(courseId),
        'stars': stars,
        'recommend': recommend,
        if (t != null && t.isNotEmpty) 'text': t,
        'campus': campus,
        'term': term,
        'professorId': professorId,
        'hidden': false,
        'helpful': 0,
        'reports': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _count(
        b,
        courseId,
        campus,
        professorId,
        id,
        count: 1,
        stars: stars,
        recommend: recommend ? 1 : 0,
      );
    } else {
      b.update(ref, {
        'stars': stars,
        'recommend': recommend,
        'text': t == null || t.isEmpty ? FieldValue.delete() : t,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!before.hidden) {
        _count(
          b,
          courseId,
          before.campus,
          before.professorId,
          id,
          count: 0,
          stars: stars - before.stars,
          recommend: (recommend ? 1 : 0) - (before.recommend ? 1 : 0),
        );
      }
    }
    await b.commit();
    await _forget(courseId);
  }

  /// Drops [courseId]'s cached pages after a write, so the change shows.
  Future<void> _forget(String courseId) async {
    final c = _cache;
    if (c == null) return;
    await c.deleteAll(
      c.keys.where((k) => '$k'.startsWith('$courseId|')).toList(),
    );
  }

  /// A student deletes their own review; the counters go back (fix 6).
  Future<void> delete(Review r) async {
    final b = db.batch()..delete(entries(r.courseId).doc(r.id));
    if (!r.hidden) {
      _count(
        b,
        r.courseId,
        r.campus,
        r.professorId,
        r.id,
        count: -1,
        stars: -r.stars,
        recommend: r.recommend ? -1 : 0,
      );
    }
    await b.commit();
    await _forget(r.courseId);
  }

  /// Marks [r] helpful, once per person. False when already voted.
  Future<bool> vote(Review r) => _once(r, 'votes', 'helpful', const {});

  /// Reports [r] to its moderators, once per person.
  Future<bool> report(Review r) => _once(r, 'reports', 'reports', const {});

  Future<bool> _once(
    Review r,
    String sub,
    String counter,
    Map<String, Object> extra,
  ) async {
    final u = uid;
    if (u == null) return false;
    final ref = entries(r.courseId).doc(r.id);
    final b =
        db.batch()
          ..set(ref.collection(sub).doc(hashedId(u, r.id)), {
            'createdAt': FieldValue.serverTimestamp(),
            ...extra,
          })
          ..update(ref, {counter: FieldValue.increment(1)});
    try {
      await b.commit();
      return true;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return false;
      rethrow;
    }
  }

  // ---- Moderation: hide-only, logged (§10.3) --------------------------------

  /// Reviews in [department] on [campus] for a moderator: reported, hidden,
  /// or all of them, newest first.
  Future<List<Review>> moderation(
    String campus,
    String department, {
    bool? hidden,
    bool reportedOnly = false,
    int limit = 50,
  }) async {
    Query<Map<String, dynamic>> q = db
        .collectionGroup('entries')
        .where('campus', isEqualTo: campus)
        .where('department', isEqualTo: department);
    if (hidden != null) q = q.where('hidden', isEqualTo: hidden);
    if (reportedOnly) q = q.where('reports', isGreaterThan: 0);
    q =
        reportedOnly
            ? q.orderBy('reports', descending: true)
            : q.orderBy('createdAt', descending: true);
    final r = await q.limit(limit).get();
    return [
      for (final d in r.docs)
        Review.fromMap(d.id, d.data()['courseId'] as String? ?? '', d.data()),
    ];
  }

  Future<void> _moderate(
    Review r,
    Map<String, Object?> change,
    String summary, {
    int? countSign,
  }) async {
    final roles = this.roles!;
    final b = db.batch();
    final path = 'reviews/${r.courseId}/entries/${r.id}';
    final audit = roles.logInto(
      b,
      path: path,
      summary: summary,
      campus: r.campus,
      course: r.courseId,
    );
    b.update(entries(r.courseId).doc(r.id), {
      ...change,
      'auditId': audit,
      'moderatedAt': FieldValue.serverTimestamp(),
    });
    if (countSign != null) {
      _count(
        b,
        r.courseId,
        r.campus,
        r.professorId,
        r.id,
        count: countSign,
        stars: countSign * r.stars,
        recommend: r.recommend ? countSign : 0,
      );
    }
    await b.commit();
  }

  /// Hides [r] with a reason; its counters come off (§10.3).
  Future<void> hide(Review r, String reason) => _moderate(
    r,
    {
      'hidden': true,
      'reason': reason,
      'hiddenBy': {'email': roles!.me, 'name': roles!.myName},
    },
    'Hid a ${r.courseId} review: $reason',
    countSign: -1,
  );

  /// Unhides [r]; its counters come back.
  Future<void> unhide(Review r) => _moderate(
    r,
    {'hidden': false},
    'Unhid a ${r.courseId} review',
    countSign: 1,
  );

  /// Keep: the reports were looked at and the review stays.
  Future<void> keep(Review r) =>
      _moderate(r, {'reports': 0}, 'Kept a reported ${r.courseId} review');
}
