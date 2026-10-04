// heads/{campus} (PERF_TEST_PLAN.md §A): scheme saves move a course's
// version; a publish and the contact land on every campus.
import 'dart:convert';
import 'dart:io';

import 'package:cgpa_calculator/core/cache/cache_first.dart';
import 'package:cgpa_calculator/core/heads/heads.dart';
import 'package:cgpa_calculator/core/heads/heads_client.dart';
import 'package:cgpa_calculator/core/heads/paths.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  late Directory dir;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('hive_heads');
    Hive.init(dir.path);
    await openSharedCache();
  });
  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test(
    'a scheme save moves only its course; publishes reach every campus',
    () async {
      final db = FakeFirebaseFirestore();
      var b = db.batch();
      bumpOfferings(b, db, 'goa', '2026-27-1', ['CS F372', 'EEE F211']);
      setOnAllHeads(b, db, {'catalog': 7, 'catalogSchema': 1});
      await b.commit();
      b = db.batch();
      bumpOfferings(b, db, 'goa', '2026-27-1', ['CS F372']);
      await b.commit();
      final goa = (await headFor('goa', db: db))!;
      expect(goa.offering('CS F372', '2026-27-1'), 2);
      expect(goa.offering('EEE F211', '2026-27-1'), 1);
      expect(goa.offering('CS F372', '2025-26-2'), isNull);
      expect(goa.catalog, 7);
      expect((await headFor('hyderabad', db: db))!.catalog, 7);
      expect((await headFor('hyderabad', db: db))!.offerings, isEmpty);
    },
  );

  test('a head is read once, then served from the cache', () async {
    final db = FakeFirebaseFirestore();
    await db.doc('heads/goa').set({'catalog': 3});
    expect((await headFor('goa', db: db))!.catalog, 3);
    await db.doc('heads/goa').set({'catalog': 4});
    expect((await headFor('goa', db: db))!.catalog, 3);
  });

  test('markers: read from v, bumped per campus or on every head', () async {
    expect(
      Head.fromMap({
        'v': {'reps': 3},
      }).version('reps'),
      3,
    );
    expect(Head.fromMap({}).version('reps'), isNull);
    final h = Head.fromMap({
      'v': {'reps': 3},
    });
    expect(Head.fromMap(h.toMap()).version('reps'), 3);

    final db = FakeFirebaseFirestore();
    var b = db.batch();
    bumpPath(b, db, 'goa', Paths.reps);
    bumpPath(b, db, 'goa', Paths.reviewsOf('CS F372'));
    bumpPathOnAllHeads(b, db, Paths.owners);
    await b.commit();
    b = db.batch();
    bumpPath(b, db, 'goa', Paths.reps);
    await b.commit();
    final goa = (await headFor('goa', db: db))!;
    expect(goa.version(Paths.reps), 2);
    expect(goa.version('reviews/CS F372'), 1);
    expect(goa.version(Paths.owners), 1);
    expect((await headFor('dubai', db: db))!.version(Paths.owners), 1);
    expect((await headFor('dubai', db: db))!.version(Paths.reps), isNull);
  });

  test('fromMap skips values that are not numbers', () {
    final h = Head.fromMap({
      'v': {'a': 2, 'b': 'x'},
      'offerings': {'c|T': 1, 'd|T': 'y'},
    });
    expect(h.v, {'a': 2});
    expect(h.offerings, {'c|T': 1});
  });

  group('Worker heads', () {
    tearDown(() => skipWorkerUntil = null);

    test('a fetch replaces the saved markers, even with a lower one', () async {
      final db = FakeFirebaseFirestore();
      await sharedCacheBox!.put(
        'head|goa',
        jsonEncode({
          'at': 0,
          'v': const Head(v: {'reps': 5}).toMap(),
          'ver': null,
        }),
      );
      final h = await headFor(
        'goa',
        db: db,
        awaitStale: true,
        worker: (c) async => {'v': {'reps': 3, 'staff': 1}},
      );
      expect(h!.v, {'reps': 3, 'staff': 1});
    });

    test('skipWorkerUntil sends the read to Firestore', () async {
      final db = FakeFirebaseFirestore();
      await db.doc('heads/goa').set({
        'v': {'reps': 9},
      });
      skipWorkerUntil = DateTime.now().add(const Duration(minutes: 2));
      final h = await headFor(
        'goa',
        db: db,
        worker: (c) async => {'v': {'reps': 2}},
      );
      expect(h!.version('reps'), 9);
      await forget('head|');
      skipWorkerUntil = DateTime.now().subtract(const Duration(seconds: 1));
      expect((await headFor('goa', db: db, worker: (c) async => {'v': {'reps': 2}}))!
          .version('reps'), 2);
    });

    test('headFor reads the Worker first', () async {
      final db = FakeFirebaseFirestore();
      await db.doc('heads/goa').set({
        'v': {'reps': 9},
      });
      final h = await headFor(
        'goa',
        db: db,
        worker:
            (c) async => {
              'v': {'reps': 2},
            },
      );
      expect(h!.version('reps'), 2);
    });

    test(
      'a Worker that throws or has no head gives the Firestore head',
      () async {
        final db = FakeFirebaseFirestore();
        await db.doc('heads/goa').set({
          'v': {'reps': 9},
        });
        final h = await headFor(
          'goa',
          db: db,
          worker: (c) async => throw Exception('down'),
        );
        expect(h!.version('reps'), 9);
        await sharedCacheBox!.clear();
        final h2 = await headFor('goa', db: db, worker: (c) async => {});
        expect(h2!.version('reps'), 9);
      },
    );

    test('workerHead: 200 gives the doc, anything else null', () async {
      String? asked;
      Future<({int status, String body})> ok(String u) async {
        asked = u;
        return (status: 200, body: '{"v":{"reps":2}}');
      }

      expect(await workerHead('goa', url: 'https://w.dev/', fetch: ok), {
        'v': {'reps': 2},
      });
      expect(asked, 'https://w.dev/heads/goa');
      expect(
        await workerHead(
          'goa',
          url: 'https://w.dev',
          fetch: (u) async => (status: 502, body: ''),
        ),
        isNull,
      );
      expect(
        await workerHead(
          'goa',
          url: 'https://w.dev',
          fetch: (u) async => throw Exception('x'),
        ),
        isNull,
      );
      expect(
        await workerHead(
          'goa',
          url: 'https://w.dev',
          fetch: (u) async => (status: 200, body: 'nope'),
        ),
        isNull,
      );
      expect(await workerHead('goa', url: '', fetch: ok), isNull);
    });
  });
}
