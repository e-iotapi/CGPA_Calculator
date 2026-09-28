import 'package:cgpa_calculator/core/perf/perf.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

// perfEnabled is const-folded from --dart-define=POINTER_PERF/POINTER_ENV
// (P0), so it's false under a plain `flutter test` and these are no-ops by
// design (T1's tree-shaking, same as build_snapshots_test.dart's
// POINTER_SEED gate). Run with:
//   flutter test --dart-define=POINTER_PERF=true test/core/perf/perf_test.dart
const _skip = perfEnabled ? false : 'set --dart-define=POINTER_PERF=true to run';

void main() {
  setUp(Perf.reset);

  test('time() counts a QuerySnapshot by its document count', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('c').add({'a': 1});
    await db.collection('c').add({'a': 2});
    final snap = await Perf.time('q', () => db.collection('c').get());
    expect(snap.docs.length, 2);
    expect(Perf.reads('q'), 2);
  }, skip: _skip);

  test('time() counts an empty QuerySnapshot as 1, matching billing', () async {
    final db = FakeFirebaseFirestore();
    await Perf.time('empty', () => db.collection('nothing').get());
    expect(Perf.reads('empty'), 1);
  }, skip: _skip);

  test('time() counts a DocumentSnapshot as 1', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('c').doc('d').set({'a': 1});
    await Perf.time('doc', () => db.collection('c').doc('d').get());
    expect(Perf.reads('doc'), 1);
  }, skip: _skip);

  test('time() counts a non-snapshot result as 0 reads (a cache hit)', () async {
    await Perf.time('cache', () async => 'not a snapshot');
    expect(Perf.reads('cache'), 0);
  }, skip: _skip);

  test('mark accumulates reads under its name', () {
    Perf.mark('m');
    Perf.mark('m', 2);
    expect(Perf.reads('m'), 3);
  }, skip: _skip);

  test('markWrite accumulates under its name', () {
    Perf.markWrite('w');
    Perf.markWrite('w', 3);
    expect(Perf.writes('w'), 4);
  }, skip: _skip);

  test('reset clears every counter', () async {
    Perf.markWrite('w');
    await Perf.time('r', () async => 1);
    Perf.reset();
    expect(Perf.writes('w'), 0);
    expect(Perf.totalReads, 0);
    expect(Perf.totalWrites, 0);
  }, skip: _skip);

  test('totals sum every name', () {
    Perf.markWrite('a');
    Perf.markWrite('b', 2);
    expect(Perf.totalWrites, 3);
  }, skip: _skip);

  test('time() and markWrite are no-ops when perfEnabled is false', () async {
    if (perfEnabled) return; // covered by the tests above instead
    await Perf.time('x', () async => 1);
    Perf.markWrite('x');
    expect(Perf.reads('x'), 0);
    expect(Perf.writes('x'), 0);
  });
}
