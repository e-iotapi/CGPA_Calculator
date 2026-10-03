import 'dart:io';

import 'package:cgpa_calculator/core/cache/cache_first.dart';
import 'package:cgpa_calculator/core/reviews/gate.dart';
import 'package:cgpa_calculator/core/reviews/gate_store.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:hive_ce/hive.dart';
import 'package:flutter_test/flutter_test.dart';

GateState s(String? sem, int electives, int reviews, {bool on = true}) =>
    gateState(
      on: on,
      currentsem: sem,
      electivesTaken: electives,
      myReviewCount: reviews,
    );

void main() {
  test('pastTwoOne: only after 2 - 1', () {
    for (final x in ['1 - 1', '1 - 2', '2 - 1', null, 'bogus']) {
      expect(pastTwoOne(x), isFalse, reason: '$x');
    }
    for (final x in [
      '2 - 2',
      'PS 1',
      '3 - 1',
      'ST 1',
      '4 - 2',
      'ST 2',
      '5 - 1',
    ]) {
      expect(pastTwoOne(x), isTrue, reason: x);
    }
  });

  test('required caps at 5', () {
    expect([required(0), required(3), required(5), required(9)], [0, 3, 5, 5]);
  });

  test(
    'gate off is open',
    () => expect(s('3 - 1', 4, 0, on: false), GateState.open),
  );

  test('1-1, 1-2, 2-1 are exempt', () {
    for (final x in ['1 - 1', '1 - 2', '2 - 1']) {
      expect(s(x, 4, 0), GateState.exempt);
    }
  });

  test(
    'no electives never locks',
    () => expect(s('3 - 1', 0, 0), GateState.exempt),
  );

  test('2-2 and later lock until enough reviews', () {
    expect(s('2 - 2', 3, 2), GateState.locked);
    expect(s('2 - 2', 3, 3), GateState.unlocked);
    expect(s('ST 2', 1, 0), GateState.locked);
  });

  test('cap of 5', () {
    expect(s('4 - 1', 9, 4), GateState.locked);
    expect(s('4 - 1', 9, 5), GateState.unlocked);
  });

  test(
    'GateStore: missing doc is off; set writes doc, audit and marker',
    () async {
      final dir = await Directory.systemTemp.createTemp('gate');
      Hive.init(dir.path);
      await openSharedCache();
      final db = FakeFirebaseFirestore();
      final store = GateStore(
        RoleStore(db, me: 'p@goa.bits-pilani.ac.in', myName: 'P'),
      );
      expect(await store.of('goa'), isFalse);
      await store.set('goa', true);
      expect(await store.of('goa'), isTrue);
      expect(store.peekOf('goa'), isTrue);
      final d = (await db.doc('reviewGate/goa').get()).data()!;
      expect(d['on'], isTrue);
      final a = await db.doc('audit/${d['auditId']}').get();
      expect(a.data()!['path'], 'reviewGate/goa');
      expect((await db.doc('heads/goa').get()).data()!['v']['reviewGate'], 1);
      await Hive.close();
      await dir.delete(recursive: true);
    },
  );
}
