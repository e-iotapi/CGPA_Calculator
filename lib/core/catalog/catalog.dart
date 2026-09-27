/// The course catalogue, read from a published bundle instead of compiled in
/// (ARCHITECTURE.md §1–§3). The app boots from the cached bundle in
/// `catalogBox`, else the fallback asset, and checks for a newer one in the
/// background; nothing waits on the network.
library;

import 'dart:convert';

import 'package:cgpa_calculator/core/models/course_names.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/mastercourselist.dart';

/// The newest bundle shape this build understands. A cached client that meets
/// a higher one keeps its previous copy instead of misreading it (§2).
const catalogSchema = 1;

/// The fallback bundle, written by tools/export_catalog.dart.
const catalogAsset = 'assets/catalog.json';

class Catalog {
  Catalog({
    required this.version,
    required this.chartOld,
    required this.chartNew,
    required this.master,
    required this.retired,
    this.schema = catalogSchema,
  });

  final int schema;
  final int version;

  /// Chart rows for batches before 2025, and from 2025 on.
  final List<Course> chartOld, chartNew;

  /// Every course on offer, for Add course search.
  final List<Mastercourselist> master;

  /// Ids hidden from Add a course; they still resolve and count (§2).
  final Set<String> retired;

  /// The chart rows for a batch (two-digit year).
  List<Course> chart(int batch) => batch < 25 ? chartOld : chartNew;

  /// Parses a bundle. Throws [FormatException] on a shape this build cannot
  /// read, including a newer schema.
  factory Catalog.fromJson(String source) {
    final m = jsonDecode(source);
    if (m is! Map) throw const FormatException('not an object');
    final schema = m['schema'];
    if (schema is! int || schema > catalogSchema) {
      throw FormatException('schema $schema is newer than $catalogSchema');
    }
    List<Course> rows(Object? list) => [
      for (final r in list as List)
        Course(
          id: r[0] as String,
          title: r[1] as String,
          credits: (r[2] as num).toDouble(),
          sem: r[3] as String,
          discipline: r[4] as String,
          elective: r[5] as String,
          grade1: -2,
          grade2: -2,
        ),
    ];
    return Catalog(
      schema: schema,
      version: m['version'] as int,
      chartOld: rows(m['chartOld']),
      chartNew: rows(m['chartNew']),
      master: [
        for (final r in m['master'] as List)
          Mastercourselist(
            id: r[0] as String,
            title: r[1] as String,
            credits: (r[2] as num).toDouble(),
          ),
      ],
      retired: {for (final id in m['retired'] as List) id as String},
    );
  }

  /// Rows as arrays: the bundle is one Firestore string field, and keys
  /// repeated 2,400 times would be most of it.
  String toJson() {
    List row(Course c) => [
      c.id,
      c.title,
      _num(c.credits),
      c.sem,
      c.discipline,
      c.elective,
    ];
    return jsonEncode({
      'schema': schema,
      'version': version,
      'chartOld': [for (final c in chartOld) row(c)],
      'chartNew': [for (final c in chartNew) row(c)],
      'master': [
        for (final m in master) [m.id, m.title, _num(m.credits)],
      ],
      'retired': retired.toList()..sort(),
    });
  }

  static num _num(double d) => d == d.roundToDouble() ? d.toInt() : d;
}

Catalog? _current;

/// The catalogue in use. Loaded before the app starts (catalog_store.dart);
/// tests load the asset in test/flutter_test_config.dart.
Catalog get catalog =>
    _current ?? (throw StateError('the catalogue is not loaded'));

bool get catalogLoaded => _current != null;

/// Makes [c] the catalogue in use, and its retired ids the ones every row
/// marks.
void useCatalog(Catalog c) {
  _current = c;
  retiredCourses
    ..clear()
    ..addAll(c.retired);
}

/// A value derived from the catalogue, recomputed when a newer one is used.
class PerCatalog<T> {
  PerCatalog(this._build);
  final T Function(Catalog) _build;
  Catalog? _for;
  late T _value;

  T of(Catalog c) {
    if (!identical(c, _for)) {
      _value = _build(c);
      _for = c;
    }
    return _value;
  }
}
