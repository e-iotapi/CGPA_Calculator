// Writes assets/catalog.json, the fallback catalogue that ships with each
// release (ARCHITECTURE.md §3).
//
//   dart run tools/export_catalog.dart                 from the lists in lib/
//   dart run tools/export_catalog.dart bundle.json     from a published bundle
//
// Until the first publish, lib/course.dart and lib/mastercourselist.dart are
// the source. After it, download catalog/v{n}.json from /admin and pass it
// here, so the asset is the live bundle, at most one release behind.
import 'dart:io';

import 'package:cgpa_calculator/core/catalog/catalog.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/mastercourselist.dart';

void main(List<String> args) {
  final out = File(catalogAsset);
  final json =
      args.isEmpty
          ? Catalog(
            version: 1,
            chartOld: hydCourseList,
            chartNew: hydCourseListNew,
            master: mcourselist,
            retired: {},
          ).toJson()
          : Catalog.fromJson(File(args.first).readAsStringSync()).toJson();
  out.parent.createSync(recursive: true);
  out.writeAsStringSync('$json\n');
  stdout.writeln('${out.path}: ${out.lengthSync()} bytes');
}
