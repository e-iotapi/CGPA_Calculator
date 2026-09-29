import 'dart:io';

import 'package:cgpa_calculator/core/catalog/catalog.dart';
import 'package:cgpa_calculator/core/catalog/catalog_store.dart';
import 'package:cgpa_calculator/core/models/course_names.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/mastercourselist.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

String _asset() => File(catalogAsset).readAsStringSync();

List _row(Course c) => [
  c.id,
  c.title,
  c.credits,
  c.sem,
  c.discipline,
  c.elective,
  c.grade1,
  c.grade2,
];

class _Source implements CatalogSource {
  _Source(this.published, this.bundles);
  ({int version, int schema})? published;
  final Map<int, String> bundles;
  int bundleReads = 0;

  @override
  Future<({int version, int schema})?> marker() async => published;

  @override
  Future<String> bundle(int version) async {
    bundleReads++;
    return bundles[version]!;
  }
}

String _bundle(int version, {Set<String> retired = const {}, int? schema}) {
  final c = Catalog.fromJson(_asset());
  final json =
      Catalog(
        version: version,
        chartOld: c.chartOld,
        chartNew: c.chartNew,
        master: c.master,
        retired: retired,
      ).toJson();
  return schema == null
      ? json
      : json.replaceFirst('"schema":1', '"schema":$schema');
}

void main() {
  late Catalog shipped;
  setUp(() => shipped = Catalog.fromJson(_asset()));
  tearDown(() => useCatalog(shipped));

  test('the shipped asset is exactly the compiled-in catalogue', () {
    // Step 2 of ARCHITECTURE.md §9: same data, new source.
    expect(shipped.chartOld.map(_row), hydCourseList.map(_row));
    expect(shipped.chartNew.map(_row), hydCourseListNew.map(_row));
    expect(
      shipped.master.map((m) => [m.id, m.title, m.credits]),
      mcourselist.map((m) => [m.id, m.title, m.credits]),
    );
    expect(shipped.chart(24), same(shipped.chartOld));
    expect(shipped.chart(25), same(shipped.chartNew));
  });

  test('a bundle round-trips, and a newer schema is refused', () {
    expect(Catalog.fromJson(shipped.toJson()).toJson(), shipped.toJson());
    expect(
      () => Catalog.fromJson(_bundle(2, schema: catalogSchema + 1)),
      throwsFormatException,
    );
  });

  group('loading and refreshing', () {
    late Directory dir;
    late Box box;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('catalog');
      Hive.init(dir.path);
      box = await Hive.openBox('catalogTest');
    });
    tearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });

    Future<Catalog> load() =>
        loadCatalog(cache: box, asset: () async => _asset());

    test('boots from the asset when nothing is cached', () async {
      expect((await load()).version, shipped.version);
    });

    test(
      'boots from a newer cached bundle, and marks its retired ids',
      () async {
        await box.put('json', _bundle(5, retired: {'CS F372'}));
        expect((await load()).version, 5);
        expect(isRetired('CS F372'), isTrue);
      },
    );

    test(
      'ignores a cached bundle older than the asset, or unreadable',
      () async {
        await box.put('json', _bundle(0));
        expect((await load()).version, shipped.version);
        await box.put('json', _bundle(9, schema: catalogSchema + 1));
        expect((await load()).version, shipped.version);
      },
    );

    test('fetches only a newer bundle, caches it and uses it', () async {
      await load();
      final source = _Source((version: 1, schema: 1), {3: _bundle(3)});
      expect(await refreshCatalog(source, cache: box), isFalse);
      expect(source.bundleReads, 0, reason: 'same version: marker read only');

      source.published = (version: 3, schema: 1);
      expect(await refreshCatalog(source, cache: box), isTrue);
      expect(catalog.version, 3);
      expect(Catalog.fromJson(box.get('json') as String).version, 3);
    });

    test(
      'keeps what it has when the marker names a newer schema, or fails',
      () async {
        await load();
        final newer = _Source((version: 4, schema: catalogSchema + 1), {});
        expect(await refreshCatalog(newer, cache: box), isFalse);
        final broken = _Source((version: 4, schema: 1), {4: '{'});
        expect(await refreshCatalog(broken, cache: box), isFalse);
        expect(catalog.version, shipped.version);
        expect(box.get('json'), isNull);
      },
    );
  });
}
