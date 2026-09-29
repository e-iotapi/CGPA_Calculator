// Writes assets/catalog.json, the fallback catalogue that ships with each
// release (ARCHITECTURE.md §3), from a published bundle: download
// catalog/v{n}.json from /admin and pass it here, so the asset is the live
// bundle, at most one release behind.
//
//   dart run tools/export_catalog.dart bundle.json
import 'dart:io';

import 'package:cgpa_calculator/core/catalog/catalog.dart';

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('usage: dart run tools/export_catalog.dart bundle.json');
    exit(64);
  }
  final out = File(catalogAsset);
  final json = Catalog.fromJson(File(args.first).readAsStringSync()).toJson();
  out.parent.createSync(recursive: true);
  out.writeAsStringSync('$json\n');
  stdout.writeln('${out.path}: ${out.lengthSync()} bytes');
}
