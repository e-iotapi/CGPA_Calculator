import 'dart:io';

import 'package:cgpa_calculator/core/cache/cache_first.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  group('cacheFirst', () {
    late Directory dir;
    late Box box;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('cache_first');
      Hive.init(dir.path);
      box = await Hive.openBox('t');
    });

    tearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });

    Future<int> fetchWith(
      List<int> calls, {
      String key = 'k',
      Duration maxAge = const Duration(hours: 1),
      DateTime? now,
      Object Function()? failWith,
    }) => cacheFirst<int>(
      key: key,
      maxAge: maxAge,
      box: box,
      now: now == null ? null : () => now,
      fetch: () async {
        calls.add(calls.length);
        if (failWith != null) throw failWith();
        return calls.length;
      },
      encode: (v) => v,
      decode: (v) => v as int,
    );

    test('no cache → fetches', () async {
      final calls = <int>[];
      final v = await fetchWith(calls);
      expect(v, 1);
      expect(calls, hasLength(1));
    });

    test('fresh cache → 0 fetches', () async {
      final calls = <int>[];
      final t0 = DateTime(2026, 1, 1);
      await fetchWith(calls, now: t0);
      final v = await fetchWith(
        calls,
        now: t0.add(const Duration(minutes: 30)),
      );
      expect(v, 1);
      expect(calls, hasLength(1));
    });

    test(
      'stale cache → returns the old value at once and 1 background fetch, '
      'and the next call returns the new value',
      () async {
        final calls = <int>[];
        final t0 = DateTime(2026, 1, 1);
        await fetchWith(calls, now: t0);
        expect(calls, hasLength(1));

        final v = await fetchWith(
          calls,
          now: t0.add(const Duration(hours: 2)),
        );
        // The stale value returns at once; the background fetch is already
        // triggered (fetch() itself runs synchronously here), but its
        // caching write hasn't landed yet.
        expect(v, 1);
        expect(calls, hasLength(2));

        // Let the background refresh's cache write land.
        await Future<void>.delayed(Duration.zero);

        final v2 = await fetchWith(
          calls,
          now: t0.add(const Duration(hours: 2, minutes: 1)),
        );
        expect(v2, 2);
        expect(calls, hasLength(2));
      },
    );

    test('concurrent dedupe: two calls with no cache share one fetch', () async {
      final calls = <int>[];
      final results = await Future.wait([fetchWith(calls), fetchWith(calls)]);
      expect(calls, hasLength(1));
      expect(results, [1, 1]);
    });

    test('forget drops every entry with the prefix', () async {
      final calls = <int>[];
      await fetchWith(calls, key: 'p|a');
      await fetchWith(calls, key: 'p|b');
      await fetchWith(calls, key: 'q|c');
      expect(calls, hasLength(3));

      await forget('p|', box: box);

      await fetchWith(calls, key: 'p|a');
      await fetchWith(calls, key: 'p|b');
      await fetchWith(calls, key: 'q|c');
      expect(calls, hasLength(5)); // p|a and p|b re-fetched; q|c stayed cached
    });

    test('a fetch that throws with a cache present → returns the cache', () async {
      final calls = <int>[];
      final t0 = DateTime(2026, 1, 1);
      await fetchWith(calls, now: t0);
      expect(calls, hasLength(1));

      final v = await fetchWith(
        calls,
        now: t0.add(const Duration(hours: 2)),
        failWith: () => StateError('network is down'),
      );
      expect(v, 1);

      // The background refresh fails and is swallowed; the cache is
      // untouched, so the next call still returns the old value.
      await Future<void>.delayed(Duration.zero);
      final v2 = await fetchWith(
        calls,
        now: t0.add(const Duration(hours: 2, minutes: 1)),
      );
      expect(v2, 1);
    });
  });
}
