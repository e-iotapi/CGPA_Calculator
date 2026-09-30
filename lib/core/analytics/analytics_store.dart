/// Site analytics on the Spark plan (PERF_TEST_PLAN.md §D): a stable 1 in
/// [analyticsSampleEvery] of users, re-drawn each day, pings `analytics/{IST day}`
/// once a day and once an hour; owners read the day docs and free
/// `count()` aggregates over `people`. No third party, no Functions.
library;

import 'dart:convert';

import 'package:cgpa_calculator/core/timings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:hive_ce/hive.dart';

const campuses = ['goa', 'hyderabad', 'pilani', 'dubai'];

/// India time, whatever the device's zone.
DateTime ist(DateTime t) =>
    t.toUtc().add(const Duration(hours: 5, minutes: 30));

/// "2026-09-29", the IST day.
String istDay(DateTime t) => ist(t).toIso8601String().substring(0, 10);

/// Whether [uid] reports on [day]: stable within a day, re-drawn daily so
/// everyone is sampled over time.
bool sampled(String uid, String day) =>
    int.parse(
          sha256.convert(utf8.encode(uid + day)).toString().substring(0, 8),
          radix: 16,
        ) %
        analyticsSampleEvery ==
    0;

/// One campus on one day, scaled up from the sample.
class DayCounts {
  const DayCounts({required this.day, this.dau = 0, this.hours = const {}});
  final String day;

  /// Estimated active users, and by IST hour ("00".."23").
  final int dau;
  final Map<String, int> hours;

  static DayCounts of(String day, Map<String, dynamic>? m, String? campus) {
    var dau = 0;
    final hours = <String, int>{};
    for (final c in campus == null ? campuses : [campus]) {
      final x = m?[c] as Map?;
      if (x == null) continue;
      dau += ((x['dau'] as num?) ?? 0).toInt();
      for (final e in ((x['h'] as Map?) ?? const {}).entries) {
        hours['${e.key}'] = (hours['${e.key}'] ?? 0) + (e.value as num).toInt();
      }
    }
    final k = ((m?['sample'] as num?) ?? analyticsSampleEvery).toInt();
    return DayCounts(
      day: day,
      dau: dau * k,
      hours: {for (final e in hours.entries) e.key: e.value * k},
    );
  }

  /// The busiest hour, or null on a quiet day.
  MapEntry<String, int>? get peak => hours.entries.fold<MapEntry<String, int>?>(
    null,
    (b, e) => b == null || e.value > b.value ? e : b,
  );
}

/// Exact totals from `count()`: 1 read per 1,000 people counted.
typedef PeopleCounts =
    ({int users, int newWeek, int newToday, int week, int month});

class AnalyticsStore {
  AnalyticsStore(this.db);
  final FirebaseFirestore db;

  /// Called once the app has opened. No-op unless [uid] is sampled today,
  /// and at most one write per IST hour per device ([device] remembers).
  Future<void> recordOpen({
    required String uid,
    required String campus,
    required Box? device,
    DateTime? now,
  }) async {
    final t = now ?? DateTime.now();
    final day = istDay(t);
    if (!campuses.contains(campus) || !sampled(uid, day)) return;
    final hour = ist(t).hour.toString().padLeft(2, '0');
    final firstToday = device?.get('anaDay') != day;
    if (!firstToday && device?.get('anaHour') == hour) return;
    await db.collection('analytics').doc(day).set({
      'sample': analyticsSampleEvery,
      campus: {
        if (firstToday) 'dau': FieldValue.increment(1),
        'h': {hour: FieldValue.increment(1)},
        'at': hour, // names the hour moved, for the rules
      },
    }, SetOptions(merge: true));
    await device?.putAll({'anaDay': day, 'anaHour': hour});
  }

  /// The last [n] IST days, newest first; [campus] null is every campus.
  Future<List<DayCounts>> days(int n, {String? campus, DateTime? now}) async {
    final t = now ?? DateTime.now();
    final from = istDay(t.subtract(Duration(days: n - 1)));
    final q =
        await db
            .collection('analytics')
            .where(FieldPath.documentId, isGreaterThanOrEqualTo: from)
            .get();
    final by = {for (final d in q.docs) d.id: d.data()};
    return [
      for (final day in [
        for (var i = 0; i < n; i++) istDay(t.subtract(Duration(days: i))),
      ])
        DayCounts.of(day, by[day], campus),
    ];
  }

  /// Users, new this week and today, active this week and month.
  Future<PeopleCounts> counts({String? campus, DateTime? now}) async {
    final t = (now ?? DateTime.now()).millisecondsSinceEpoch;
    const day = 86400000;
    final startToday =
        DateTime.parse(
          '${istDay(DateTime.fromMillisecondsSinceEpoch(t))}T00:00:00+05:30',
        ).millisecondsSinceEpoch;
    Query<Map<String, dynamic>> people() {
      final q = db.collection('people');
      return campus == null ? q : q.where('campus', isEqualTo: campus);
    }

    Future<int> n(Query<Map<String, dynamic>> q) async =>
        (await q.count().get()).count ?? 0;
    final r = await Future.wait([
      n(people()),
      n(people().where('firstSignIn', isGreaterThanOrEqualTo: t - 7 * day)),
      n(people().where('firstSignIn', isGreaterThanOrEqualTo: startToday)),
      n(people().where('lastSeen', isGreaterThanOrEqualTo: t - 7 * day)),
      n(people().where('lastSeen', isGreaterThanOrEqualTo: t - 30 * day)),
    ]);
    return (
      users: r[0],
      newWeek: r[1],
      newToday: r[2],
      week: r[3],
      month: r[4],
    );
  }
}
