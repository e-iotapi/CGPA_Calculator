import 'dart:async';

import 'package:cgpa_calculator/core/prefetch/prefetch.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(resetPrefetch);

  test('levels run in order after the delay, failures dropped', () {
    fakeAsync((f) {
      final log = <String>[];
      runPrefetch(
        [
          [() async => log.add('2a'), () async => throw 'x'],
          [() async => log.add('3')],
        ],
        delay: const Duration(seconds: 2),
        online: () => true,
      );
      f.elapse(const Duration(seconds: 1));
      expect(log, isEmpty);
      f.elapse(const Duration(seconds: 2));
      expect(log, ['2a', '3']);
    });
  });

  test('waits while offline', () {
    fakeAsync((f) {
      final log = <String>[];
      final net = StreamController<bool>();
      runPrefetch(
        [
          [() async => log.add('a')],
        ],
        delay: const Duration(seconds: 2),
        online: () => false,
        onlineChanges: net.stream,
      );
      f.elapse(const Duration(seconds: 10));
      expect(log, isEmpty);
      net.add(true);
      f.elapse(const Duration(seconds: 3));
      expect(log, ['a']);
    });
  });

  test('last level jobs run one after another with a gap', () {
    fakeAsync((f) {
      final log = <String>[];
      runPrefetch(
        [
          [() async => log.add('x')],
          [() async => log.add('a1'), () async => log.add('a2')],
        ],
        delay: Duration.zero,
        gap: const Duration(milliseconds: 400),
        online: () => true,
      );
      f.elapse(const Duration(milliseconds: 100));
      expect(log, ['x', 'a1']);
      f.elapse(const Duration(milliseconds: 500));
      expect(log, ['x', 'a1', 'a2']);
    });
  });

  test('runs once per session', () {
    fakeAsync((f) {
      var n = 0;
      final jobs = [
        [() async => n++],
      ];
      final a = runPrefetch(jobs, delay: Duration.zero, online: () => true);
      final b = runPrefetch(jobs, delay: Duration.zero, online: () => true);
      expect(identical(a, b), isTrue);
      f.flushMicrotasks();
      f.elapse(const Duration(seconds: 1));
      expect(n, 1);
    });
  });
}
