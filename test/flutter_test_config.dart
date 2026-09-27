import 'dart:async';
import 'dart:io';

import 'package:cgpa_calculator/core/catalog/catalog.dart';

/// Every test sees the catalogue the app boots from: the shipped asset.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  useCatalog(Catalog.fromJson(File(catalogAsset).readAsStringSync()));
  await testMain();
}
