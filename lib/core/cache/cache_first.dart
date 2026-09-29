/// A cache-first helper (PERF_TEST_PLAN.md P1): the stores that read shared
/// Firestore data (contacts, resources, reviews, professors, roles) wrap
/// their network calls with this instead of hand-rolling a `Box` cache each
/// time. `sharedCacheBox` (ARCHITECTURE.md §16.3) never syncs to the user
/// document, so this is only for data everyone reads the same way.
library;

import 'dart:async';
import 'dart:convert';

import 'package:cgpa_calculator/core/storage/cache_boxes.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

Future<void> openSharedCache() => Hive.openBox(sharedCacheBoxName);

Box? get sharedCacheBox =>
    Hive.isBoxOpen(sharedCacheBoxName) ? Hive.box(sharedCacheBoxName) : null;

/// Fetches in flight, keyed the same as the cache, so concurrent callers for
/// one key share one fetch instead of each starting their own.
final _inFlight = <String, Future<Object?>>{};

/// Returns the cached value at once when there is one, refreshing it in the
/// background when older than [maxAge]; fetches (and caches) only when
/// nothing is cached. Concurrent calls for one key share one fetch.
Future<T> cacheFirst<T>({
  required String key,
  required Duration maxAge,
  required Future<T> Function() fetch,
  required Object? Function(T) encode, // JSON-safe
  required T Function(Object?) decode,
  Box? box,
  DateTime Function()? now,
}) async {
  final b = box ?? sharedCacheBox;
  final at = (now ?? DateTime.now)().millisecondsSinceEpoch;
  final raw = b?.get(key);
  if (raw is String) {
    try {
      final m = jsonDecode(raw) as Map;
      final value = decode(m['v']);
      if (at - (m['at'] as int) < maxAge.inMilliseconds) return value;
      unawaited(
        _fetchAndCache(key, fetch, encode, b, at).catchError((Object e) {
          debugPrint('[Pointer cache] $key: background refresh failed: $e');
          return value;
        }),
      );
      return value;
    } on Object catch (e) {
      debugPrint('[Pointer cache] $key: dropping bad cache entry: $e');
      await b?.delete(key);
    }
  }
  return _fetchAndCache(key, fetch, encode, b, at);
}

Future<T> _fetchAndCache<T>(
  String key,
  Future<T> Function() fetch,
  Object? Function(T) encode,
  Box? box,
  int at,
) {
  final existing = _inFlight[key];
  if (existing != null) return existing.then((v) => v as T);
  final future = _run(key, fetch, encode, box, at);
  _inFlight[key] = future;
  return future;
}

Future<T> _run<T>(
  String key,
  Future<T> Function() fetch,
  Object? Function(T) encode,
  Box? box,
  int at,
) async {
  try {
    final value = await fetch();
    // Hive updates memory at once; the disk write need not hold the caller.
    unawaited(
      box
          ?.put(key, jsonEncode({'at': at, 'v': encode(value)}))
          .catchError((Object e) => debugPrint('[Pointer cache] $key: $e')),
    );
    return value;
  } finally {
    _inFlight.remove(key);
  }
}

/// Drops every cached entry whose key starts with [keyPrefix], e.g. after a
/// write that only that prefix's reads should now see.
Future<void> forget(String keyPrefix, {Box? box}) async {
  final b = box ?? sharedCacheBox;
  if (b == null) return;
  final keys = b.keys.where((k) => k is String && k.startsWith(keyPrefix));
  await b.deleteAll(keys);
}
