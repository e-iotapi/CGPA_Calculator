/// Read/write counters and timings for the More pages and startup
/// (PERF_TEST_PLAN.md P0). Counts documents the way Firestore bills them:
/// one per document a query returns, at least 1 even when it returns
/// nothing (§0.5). Compiled in only for a perf build or the test
/// environment; [perfEnabled] is `const`-foldable, so dart2js drops every
/// call site from a plain production build.
library;

import 'package:cgpa_calculator/core/env/app_env.dart';
import 'package:cgpa_calculator/core/perf/perf_stub.dart'
    if (dart.library.js_interop) 'package:cgpa_calculator/core/perf/perf_web.dart'
    as platform;
import 'package:cloud_firestore/cloud_firestore.dart';

/// Whether the build counts reads, writes and timings.
const bool perfEnabled =
    bool.fromEnvironment('POINTER_PERF') || isTestEnv;

/// Counters of Firestore reads and writes and of timings, by operation name.
abstract final class Perf {
  static final Map<String, int> _reads = {};
  static final Map<String, int> _writes = {};
  static final Map<String, List<int>> _millis = {};
  static bool _published = false;

  static void _ensurePublished() {
    if (_published || !perfEnabled) return;
    _published = true;
    platform.publishPerf(
      reads: reads,
      writes: writes,
      summary: () => {'reads': totalReads, 'writes': totalWrites},
    );
  }

  /// Records [count] reads under [name] — for a read with no single future
  /// to hand [time] (inside a transaction, a manual count).
  static void mark(String name, [int count = 1]) {
    if (!perfEnabled) return;
    _ensurePublished();
    _reads[name] = (_reads[name] ?? 0) + count;
  }

  /// Records [count] writes under [name] — a `.set()`/`.update()` is 1, a
  /// batch or transaction is however many documents it touched.
  static void markWrite(String name, [int count = 1]) {
    if (!perfEnabled) return;
    _ensurePublished();
    _writes[name] = (_writes[name] ?? 0) + count;
  }

  /// Times [body] and records its result as a read under [name]: a
  /// [QuerySnapshot] counts its documents (at least 1, matching billing), a
  /// [DocumentSnapshot] counts 1; anything else (a cache hit that never
  /// reached Firestore, a derived value) counts 0.
  static Future<T> time<T>(String name, Future<T> Function() body) async {
    if (!perfEnabled) return body();
    _ensurePublished();
    final sw = Stopwatch()..start();
    try {
      final result = await body();
      final count = _docCount(result);
      if (count > 0) mark(name, count);
      return result;
    } finally {
      sw.stop();
      (_millis[name] ??= []).add(sw.elapsedMilliseconds);
    }
  }

  static int _docCount(Object? result) => switch (result) {
    QuerySnapshot q => q.docs.isEmpty ? 1 : q.docs.length,
    DocumentSnapshot _ => 1,
    _ => 0,
  };

  /// The documents read under [name].
  static int reads(String name) => _reads[name] ?? 0;

  /// The documents written under [name].
  static int writes(String name) => _writes[name] ?? 0;

  /// The recorded durations under [name], in milliseconds.
  static List<int> millis(String name) => List.unmodifiable(_millis[name] ?? const []);

  /// The documents read across every name.
  static int get totalReads => _reads.values.fold(0, (a, b) => a + b);

  /// The documents written across every name.
  static int get totalWrites => _writes.values.fold(0, (a, b) => a + b);

  /// Clears every counter; the quota spec calls this before each simulated
  /// day so counts aren't carried over from a previous one.
  static void reset() {
    _reads.clear();
    _writes.clear();
    _millis.clear();
  }
}
