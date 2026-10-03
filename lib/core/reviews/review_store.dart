import 'package:cgpa_calculator/core/cache/cache_first.dart';
import 'package:cgpa_calculator/core/heads/heads.dart';
import 'package:cgpa_calculator/core/heads/paths.dart';
import 'package:cgpa_calculator/core/live/live_heads.dart';
import 'package:cgpa_calculator/core/perf/perf.dart';
import 'package:cgpa_calculator/core/reviews/review.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/timings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_ce/hive.dart';

/// The Hive box caching the person's own reviews.
const reviewsBoxName = 'reviewsBox';

/// Opens the [reviewsBoxName] box.
Future<void> openReviews() => Hive.openBox(reviewsBoxName);

/// Reviews and their counters (ARCHITECTURE.md §10.3). Every write moves the
/// course counter — and the professor's, when there is one — in the same
/// batch; the rules check the delta. Read live, only on the screens that
/// show them, never on app open.
class ReviewStore {
  ReviewStore(this.db, {required this.uid, this.roles});

  /// The Firestore instance read and written.
  final FirebaseFirestore db;

  /// The signed-in uid that salts [hashedId], or `null` when signed out.
  final String? uid;

  /// For moderation: the moderator's name goes on the audit entry.
  final RoleStore? roles;

  /// The review entries collection of [courseId].
  CollectionReference<Map<String, dynamic>> entries(String courseId) =>
      db.collection('reviews').doc(courseId).collection('entries');

  DocumentReference<Map<String, dynamic>> _stats(String courseId, String id) =>
      db.collection('courses').doc(courseId).collection('stats').doc(id);

  DocumentReference<Map<String, dynamic>> _index(String campus) =>
      db.collection('reviewIndex').doc(campus);

  /// Every course's counter on [campus], from one doc (`reviewIndex`),
  /// cached 12 h; [fresh] reads it live.
  Future<Map<String, ReviewStats>> _courseIndex(
    String campus, {
    bool fresh = false,
  }) async {
    Future<Map<String, ReviewStats>> fetch() async {
      final d = await Perf.time('reviews.index', () => _index(campus).get());
      return {
        for (final e in ((d.data()?['c'] as Map?) ?? const {}).entries)
          '${e.key}': ReviewStats.fromMap(Map<String, dynamic>.from(e.value)),
      };
    }

    if (fresh) return fetch();
    return cacheFirst(
      key: 'rix|$campus',
      maxAge: reviewIndexMaxAge,
      version: await markerOf(db, campus, Paths.reviews),
      fetch: fetch,
      encode: (m) => {for (final e in m.entries) e.key: _statsToMap(e.value)},
      decode: _decodeIndex,
    );
  }

  /// Every course's counter on [campus] (the `rix|` cache).
  Future<Map<String, ReviewStats>> index(String campus) => _courseIndex(campus);

  /// The saved [index], read synchronously; null when none is saved.
  Map<String, ReviewStats>? peekIndex(String campus) => _peekIndex(campus);

  /// The signed-in person's review id for [courseId], or `null` when signed
  /// out.
  String? myReviewId(String courseId) =>
      uid == null ? null : hashedId(uid!, courseId);

  /// The course's counter on [campus], or the sum over [professorIds] (a
  /// survivor and everyone merged into it).
  Future<ReviewStats> stats(
    String courseId,
    String campus, {
    List<String>? professorIds,
    bool fresh = false,
  }) async {
    if (professorIds == null) {
      return (await _courseIndex(campus, fresh: fresh))[courseId] ??
          const ReviewStats();
    }
    Future<ReviewStats> fetch() async {
      final ids = [for (final p in professorIds) statsId(campus, p)];
      // Budget: 1 read per professor id, sequentially, per course (P0) — the
      // "Diagnosis" section's reviews_home.dart courses-tab bottleneck.
      var total = const ReviewStats();
      for (final id in ids) {
        final d = await Perf.time(
          'reviews.stats',
          () => _stats(courseId, id).get(),
        );
        total += ReviewStats.fromMap(d.data());
      }
      return total;
    }

    if (fresh) return fetch();
    // The professor counters move in the batch that moves the index.
    return cacheFirst(
      key: _rstKey(courseId, campus, professorIds),
      maxAge: reviewIndexMaxAge,
      version: await markerOf(db, campus, Paths.reviews),
      fetch: fetch,
      encode: _statsToMap,
      decode: (o) => ReviewStats.fromMap(o as Map),
    );
  }

  String _rstKey(String courseId, String campus, List<String> ids) =>
      'rst|$campus|$courseId|${ids.join(',')}';

  static Map<String, int> _statsToMap(ReviewStats s) => {
    'count': s.count,
    'starSum': s.starSum,
    'recommendCount': s.recommendCount,
  };

  /// The saved [stats], read synchronously; null when none is saved.
  ReviewStats? peekStats(
    String courseId,
    String campus, {
    List<String>? professorIds,
  }) {
    if (professorIds != null) {
      return peekCache(
        _rstKey(courseId, campus, professorIds),
        (o) => ReviewStats.fromMap(o as Map),
      );
    }
    final i = _peekIndex(campus);
    return i == null ? null : i[courseId] ?? const ReviewStats();
  }

  Map<String, ReviewStats>? _peekIndex(String campus) =>
      peekCache('rix|$campus', _decodeIndex);

  static Map<String, ReviewStats> _decodeIndex(Object? o) => {
    for (final e in (o as Map).entries)
      '${e.key}': ReviewStats.fromMap(Map<String, dynamic>.from(e.value)),
  };

  /// Every professor with reviews of [courseId] on [campus], and their
  /// counters: the Reviews screen's "Taught by" pills.
  Future<Map<String, ReviewStats>> byProfessor(
    String courseId,
    String campus,
  ) async => cacheFirst(
    key: 'rbp|$campus|$courseId',
    maxAge: reviewIndexMaxAge,
    version: await markerOf(db, campus, Paths.reviews),
    fetch: () async {
      final q = await Perf.time(
        'reviews.byProfessor',
        () =>
            db
                .collection('courses')
                .doc(courseId)
                .collection('stats')
                .where('campus', isEqualTo: campus)
                .where('scope', isEqualTo: 'professor')
                .get(),
      );
      return {
        for (final d in q.docs)
          if (d.data()['professorId'] case final String id)
            id: ReviewStats.fromMap(d.data()),
      };
    },
    encode: (m) => {for (final e in m.entries) e.key: _statsToMap(e.value)},
    decode: _decodeIndex,
  );

  /// The saved [byProfessor], read synchronously; null when none is saved.
  Map<String, ReviewStats>? peekByProfessor(String courseId, String campus) =>
      peekCache('rbp|$campus|$courseId', _decodeIndex);

  /// The most reviewed courses on [campus] (§16.3 fix 14's index).
  Future<List<({String courseId, ReviewStats stats})>> mostReviewed(
    String campus, {
    int limit = 10,
    bool fresh = false,
  }) async {
    return _top(await _courseIndex(campus, fresh: fresh), limit);
  }

  static List<({String courseId, ReviewStats stats})> _top(
    Map<String, ReviewStats> index,
    int limit,
  ) {
    final all = [
      for (final e in index.entries)
        if (e.value.count > 0) (courseId: e.key, stats: e.value),
    ]..sort((a, b) => b.stats.count.compareTo(a.stats.count));
    return all.take(limit).toList();
  }

  /// The saved [mostReviewed], read synchronously; null when none is saved.
  List<({String courseId, ReviewStats stats})>? peekMostReviewed(
    String campus, {
    int limit = 10,
  }) => switch (_peekIndex(campus)) {
    final i? => _top(i, limit),
    _ => null,
  };

  DocumentReference<Map<String, dynamic>> _mirror(
    String courseId,
    String campus,
  ) => db.collection('reviews').doc(courseId).collection('campus').doc(campus);

  /// Every visible review of [courseId] on [campus], from one doc
  /// (`reviews/{c}/campus/{campus}`), sorted by [order]; [professorIds]
  /// narrows it. One page holds them all, so `last` is always null.
  // ponytail: one doc caps near 1,000 reviews per course and campus; shard
  // by year past that.
  Future<({List<Review> reviews, DocumentSnapshot? last})> page(
    String courseId,
    String campus, {
    List<String>? professorIds,
    ReviewOrder order = ReviewOrder.helpful,
    DocumentSnapshot? after,
    int limit = 10,
    Duration fresh = reviewPageMaxAge,
    DateTime? now,
  }) async {
    if (after != null) return (reviews: const <Review>[], last: null);
    final all = await cacheFirst<List<Review>>(
      key: _rcdKey(courseId, campus),
      maxAge: fresh,
      version: await markerOf(db, campus, Paths.reviewsOf(courseId)),
      now: now == null ? null : () => now,
      fetch: () async {
        final d = await Perf.time(
          'reviews.page',
          () => _mirror(courseId, campus).get(),
        );
        return [
          for (final e in ((d.data()?['r'] as Map?) ?? const {}).entries)
            Review.fromMap('${e.key}', courseId, {
              ...e.value as Map,
              'campus': campus,
            }),
        ];
      },
      encode: (rs) => {for (final r in rs) r.id: r.toMap()},
      decode: (o) => _decodePage(o, courseId),
    );
    return (reviews: _shown(all, professorIds, order), last: null);
  }

  /// Every review of [courseId] on [campus], unordered, from the same
  /// cached campus doc as [page].
  Future<List<Review>> all(String courseId, String campus) async =>
      (await page(courseId, campus)).reviews;

  /// The saved [all], read synchronously; null when none is saved.
  List<Review>? peekAll(String courseId, String campus) =>
      peekCache(_rcdKey(courseId, campus), (o) => _decodePage(o, courseId));

  String _rcdKey(String courseId, String campus) => 'rcd|$courseId|$campus';

  static List<Review> _decodePage(Object? o, String courseId) => [
    for (final e in (o as Map).entries)
      Review.fromMap('${e.key}', courseId, e.value as Map),
  ];

  /// The saved [page], read synchronously; null when none is saved.
  ({List<Review> reviews, DocumentSnapshot? last})? peekPage(
    String courseId,
    String campus, {
    List<String>? professorIds,
    ReviewOrder order = ReviewOrder.helpful,
  }) => switch (peekCache(
    _rcdKey(courseId, campus),
    (o) => _decodePage(o, courseId),
  )) {
    final all? => (reviews: _shown(all, professorIds, order), last: null),
    _ => null,
  };

  static List<Review> _shown(
    List<Review> all,
    List<String>? professorIds,
    ReviewOrder order,
  ) {
    int key(Review r) => switch (order) {
      ReviewOrder.helpful => r.helpful,
      ReviewOrder.recent => r.createdAt,
      ReviewOrder.highest || ReviewOrder.lowest => r.stars,
    };
    return [
      for (final r in all)
        if (professorIds == null || professorIds.contains(r.professorId)) r,
    ]..sort(
      (a, b) =>
          order.descending
              ? key(b).compareTo(key(a))
              : key(a).compareTo(key(b)),
    );
  }

  /// The student-visible copy of a review in its campus doc, in [b].
  void _mirrorSet(
    WriteBatch b,
    String courseId,
    String campus,
    String reviewId,
    Object entry,
  ) {
    b.set(_mirror(courseId, campus), {
      'k': reviewId,
      'r': {reviewId: entry},
    }, SetOptions(merge: true));
    bumpPath(b, db, campus, Paths.reviewsOf(courseId));
  }

  // Budget: 1 read per reviewed course, sequentially ("Your reviews" tab, P0).
  /// Reads the signed-in person's review of [courseId], or `null` if none.
  Future<Review?> mine(String courseId) async {
    final id = myReviewId(courseId);
    if (id == null) return null;
    return cacheFirst<Review?>(
      key: 'rmine|$courseId|$id',
      maxAge: reviewPageMaxAge,
      fetch: () async {
        final d = await Perf.time(
          'reviews.mine',
          () => entries(courseId).doc(id).get(),
        );
        final m = d.data();
        return m == null ? null : Review.fromMap(id, courseId, m);
      },
      encode: (r) => r?.toMap(),
      decode: (o) => o == null ? null : Review.fromMap(id, courseId, o as Map),
    );
  }

  /// The saved [mine], read synchronously; null when none is saved (or the
  /// person has not reviewed it).
  Review? peekMine(String courseId) {
    final id = myReviewId(courseId);
    if (id == null) return null;
    return peekCache<Review?>(
      'rmine|$courseId|$id',
      (o) => o == null ? null : Review.fromMap(id, courseId, o as Map),
    );
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
    bumpPath(b, db, campus, Paths.reviews);
    // ponytail: old app versions skip this, so the index can lag their
    // reviews; backfill from stats if the drift shows.
    b.set(_index(campus), {
      'k': courseId,
      'c': {
        courseId: {
          'count': FieldValue.increment(count),
          'starSum': FieldValue.increment(stars),
          'recommendCount': FieldValue.increment(recommend),
        },
      },
    }, SetOptions(merge: true));
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
    required String grade,
    num? marks,
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
        'grade': grade,
        if (marks != null) 'marks': marks,
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
      _mirrorSet(b, courseId, campus, id, {
        'stars': stars,
        'recommend': recommend,
        if (t != null && t.isNotEmpty) 'text': t,
        'grade': grade,
        if (marks != null) 'marks': marks,
        'term': term,
        'professorId': professorId,
        'helpful': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      b.update(ref, {
        'stars': stars,
        'recommend': recommend,
        'text': t == null || t.isEmpty ? FieldValue.delete() : t,
        'grade': grade,
        'marks': marks ?? FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!before.hidden) {
        _mirrorSet(b, courseId, before.campus, id, {
          'stars': stars,
          'recommend': recommend,
          'text': t == null || t.isEmpty ? FieldValue.delete() : t,
          'grade': grade,
          'marks': marks ?? FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
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
    if (before == null || !before.hidden) _poke(courseId, index: true);
    await _forget(courseId, campus);
  }

  /// After a commit that moved [courseId]'s review marker (and the index's,
  /// when a counter moved): tells the live server.
  void _poke(String courseId, {required bool index}) {
    LiveHeads.poke(Paths.reviewsOf(courseId));
    if (index) LiveHeads.poke(Paths.reviews);
  }

  /// Drops [courseId]'s cached pages after a write, so the change shows.
  Future<void> _forget(String courseId, String campus) async {
    final c = sharedCacheBox;
    if (c == null) return;
    await forget('rmine|$courseId|');
    await forget('rbp|$campus|$courseId');
    await forget('rst|$campus|$courseId|');
    await c.deleteAll(
      c.keys
          .where(
            (k) => '$k'.startsWith('rix|') || '$k'.startsWith('rcd|$courseId|'),
          )
          .toList(),
    );
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
    if (counter == 'helpful') {
      _mirrorSet(b, r.courseId, r.campus, r.id, {
        'helpful': FieldValue.increment(1),
      });
    }
    try {
      await b.commit();
      if (counter == 'helpful') _poke(r.courseId, index: false);
      await _forget(r.courseId, r.campus);
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
      _mirrorSet(
        b,
        r.courseId,
        r.campus,
        r.id,
        countSign < 0
            ? FieldValue.delete()
            : {
              'stars': r.stars,
              'recommend': r.recommend,
              if (r.text != null) 'text': r.text,
              'term': r.term,
              'professorId': r.professorId,
              'helpful': r.helpful,
              'createdAt': Timestamp.fromMillisecondsSinceEpoch(r.createdAt),
              'updatedAt': Timestamp.fromMillisecondsSinceEpoch(r.updatedAt),
            },
      );
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
    if (countSign != null) _poke(r.courseId, index: true);
    await _forget(r.courseId, r.campus);
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
