import 'dart:async';
import 'dart:io';

import 'package:cgpa_calculator/core/catalog/catalog.dart';
import 'package:cgpa_calculator/core/search/hints.dart';
import 'package:cgpa_calculator/features/contribute/leaderboard_page.dart';

/// Every test sees the catalogue the app boots from: the shipped asset.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  useCatalog(Catalog.fromJson(File(catalogAsset).readAsStringSync()));
  sparklesFly = false;
  loadSearchHints = false;
  await testMain();
}
