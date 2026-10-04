import 'dart:io';

import 'package:cgpa_calculator/core/analytics/analytics_store.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

/// The first of name(0), name(1), … that [ok] accepts.
String first(String Function(int) name, bool Function(String) ok) {
  for (var i = 0; ; i++) {
    if (ok(name(i))) return name(i);
  }
}

void main() {
  test('about 1 in 20 is sampled, the same all day, a new draw each day', () {
    final hits = [
      for (var i = 0; i < 10000; i++)
        if (sampled('u$i', '2026-09-29')) i,
    ];
    expect(hits.length, inInclusiveRange(420, 580));
    expect(sampled('u${hits.first}', '2026-09-29'), isTrue);
    final tomorrow = hits.where((i) => sampled('u$i', '2026-09-30')).length;
    expect(tomorrow, lessThan(hits.length ~/ 5));
  });

  test('IST day and hour, whatever the device zone', () {
    final t = DateTime.utc(2026, 9, 29, 19, 0); // 00:30 IST on the 30th
    expect(istDay(t), '2026-09-30');
    expect(ist(t).hour, 0);
  });

  test('a sampled open counts once a day and once an hour, scaled', () async {
    Hive.init(Directory.systemTemp.createTempSync('ana').path);
    final device = await Hive.openBox('deviceBox');
    final db = FakeFirebaseFirestore();
    final store = AnalyticsStore(db);
    final t = DateTime.utc(2026, 9, 29, 6); // 11:30 IST
    final uid = first((i) => 'u$i', (u) => sampled(u, istDay(t)));
    Future<void> open(DateTime at) =>
        store.recordOpen(uid: uid, campus: 'goa', device: device, now: at);
    await open(t);
    await open(t.add(const Duration(minutes: 10))); // same hour: nothing
    await open(t.add(const Duration(hours: 2)));
    final day = (await store.days(1, now: t)).single;
    expect(day.dau, 20); // one sampled user ≈ 20
    expect(day.hours, {'11': 20, '13': 20});
    expect(day.peak!.value, 20);
    // An unsampled user writes nothing.
    await store.recordOpen(
      uid: first((i) => 'x$i', (u) => !sampled(u, istDay(t))),
      campus: 'goa',
      device: null,
      now: t,
    );
    expect((await store.days(1, now: t)).single.dau, 20);
    await Hive.close();
  });

  test('people counts: users, new and active', () async {
    final db = FakeFirebaseFirestore();
    final now = DateTime.utc(2026, 9, 29, 6);
    final ms = now.millisecondsSinceEpoch;
    const d = 86400000;
    for (final (i, first, seen) in [
      (1, ms - 40 * d, ms - 20 * d),
      (2, ms - 3 * d, ms - d),
      (3, ms - 60, ms),
    ]) {
      await db.collection('people').doc('p$i').set({
        'campus': 'goa',
        'firstSignIn': first,
        'lastSeen': seen,
      });
    }
    final c = await AnalyticsStore(db).counts(now: now);
    expect((c.users, c.newWeek, c.newToday, c.week, c.month), (3, 2, 1, 2, 3));
  });
}
