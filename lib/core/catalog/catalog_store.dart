/// Where the catalogue comes from: the `catalogBox` cache, the fallback asset,
/// and the published bundle in Firestore (ARCHITECTURE.md §3).
///
/// Firestore layout: `catalog/marker` `{version, schema}` is the one small
/// read an app open makes; `catalog/v{version}` `{version, schema, json}`
/// holds each bundle. Old bundles stay, so a publish is reverted by pointing
/// the marker back. The bundle is a JSON string, not a map: 2,400 nested rows
/// would pass Firestore's index-entry limit for one document.
library;

import 'package:cgpa_calculator/core/cache/cache_first.dart';
import 'package:cgpa_calculator/core/catalog/catalog.dart';
import 'package:cgpa_calculator/core/heads/heads.dart';
import 'package:cgpa_calculator/core/perf/perf.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

const catalogBoxName = 'catalogBox';

/// The published side, behind an interface so tests need no Firestore.
abstract interface class CatalogSource {
  /// The published version and schema; null when nothing is published yet.
  Future<({int version, int schema})?> marker();

  /// The bundle for [version], as JSON.
  Future<String> bundle(int version);
}

class FirestoreCatalogSource implements CatalogSource {
  FirestoreCatalogSource([FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  @override
  Future<({int version, int schema})?> marker() async {
    final d = await Perf.time(
      'catalog.marker',
      () => _db.doc('catalog/marker').get(),
    );
    final m = d.data();
    if (m == null) return null;
    return (version: m['version'] as int, schema: m['schema'] as int);
  }

  @override
  Future<String> bundle(int version) async {
    final d = await Perf.time(
      'catalog.bundle',
      () => _db.doc('catalog/v$version').get(),
    );
    return d.data()!['json'] as String;
  }
}

/// A student's source: the campus head carries the published version, so
/// an app open reads no marker; without a head version the marker is read at
/// most once a day. Budget: ~0 reads/user/day beyond the head.
class HeadCatalogSource implements CatalogSource {
  HeadCatalogSource(this.campus, [FirebaseFirestore? db])
    : _db = db,
      _live = FirestoreCatalogSource(db);
  final String campus;
  final FirebaseFirestore? _db;
  final FirestoreCatalogSource _live;

  @override
  Future<({int version, int schema})?> marker() async {
    final head = await headFor(campus, db: _db);
    if (head?.catalog case final v?) {
      return (version: v, schema: head!.catalogSchema ?? 1);
    }
    return cacheFirst<({int version, int schema})?>(
      key: 'catalog|marker',
      maxAge: const Duration(days: 1),
      fetch: _live.marker,
      encode: (m) => m == null ? null : [m.version, m.schema],
      decode:
          (v) =>
              v == null
                  ? null
                  : (version: (v as List)[0] as int, schema: v[1] as int),
    );
  }

  @override
  Future<String> bundle(int version) => _live.bundle(version);
}

/// Loads the catalogue to boot from: the cached bundle when it is at least as
/// new as the asset, else the asset. Never touches the network.
Future<Catalog> loadCatalog({
  Box? cache,
  Future<String> Function()? asset,
}) async {
  final box = cache ?? await Hive.openBox(catalogBoxName);
  final fallback = Catalog.fromJson(
    await (asset ?? () => rootBundle.loadString(catalogAsset))(),
  );
  var use = fallback;
  final cached = box.get('json');
  if (cached is String) {
    try {
      final c = Catalog.fromJson(cached);
      if (c.version >= fallback.version) use = c;
    } on Object catch (e) {
      // A bundle this build cannot read: keep the asset.
      debugPrint('[Pointer catalogue] cache unreadable: $e');
    }
  }
  useCatalog(use);
  return use;
}

/// Checks the marker and, when a newer bundle this build understands is
/// published, fetches it, caches it and uses it; [beforeUse] runs first, with
/// the old and new catalogues. Returns whether it changed.
/// Failures leave the current catalogue alone.
Future<bool> refreshCatalog(
  CatalogSource source, {
  Box? cache,
  Future<void> Function(Catalog previous, Catalog next)? beforeUse,
}) async {
  try {
    final marker = await source.marker();
    if (marker == null) return false;
    if (marker.schema > catalogSchema) return false;
    if (catalogLoaded && marker.version <= catalog.version) return false;
    final json = await source.bundle(marker.version);
    final next = Catalog.fromJson(json);
    if (catalogLoaded) await beforeUse?.call(catalog, next);
    final box = cache ?? await Hive.openBox(catalogBoxName);
    await box.put('json', json);
    useCatalog(next);
    return true;
  } on Object catch (e) {
    debugPrint('[Pointer catalogue] refresh failed: $e');
    return false;
  }
}
