import 'dart:io';

import 'package:cgpa_calculator/app/router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  final sources = [
    for (final line in File('landing/_redirects').readAsLinesSync())
      if (line.trim().isNotEmpty && !line.startsWith('#'))
        line.trim().split(RegExp(r'\s+')).first,
  ];

  // Top-level segments under Home: 'stats', 'course' (from 'course/:id')…
  final home = appRoutes.single as GoRoute;
  final segments = [
    for (final r in home.routes.whereType<GoRoute>()) r.path.split('/').first,
  ];

  test('every top-level route segment has a _redirects line', () {
    expect(segments, isNotEmpty);
    for (final s in segments) {
      final hasChildren = home.routes.whereType<GoRoute>().any(
        (r) => r.path.startsWith('$s/'),
      );
      final route = home.routes.whereType<GoRoute>().firstWhere(
        (r) => r.path.split('/').first == s,
      );
      final nested = route.routes.isNotEmpty;
      expect(
        sources,
        contains(hasChildren || nested ? '/calculator/$s/*' : '/calculator/$s'),
        reason:
            'deep links to /calculator/$s need a line in landing/_redirects',
      );
      // A page with pages beneath it needs its own line as well: `/x/*`
      // does not match `/x`.
      if (nested) expect(sources, contains('/calculator/$s'));
    }
  });

  test('no catch-all rule rewrites the app\'s own files', () {
    expect(sources, isNot(contains('/calculator/*')));
    expect(sources.where((s) => s.startsWith('/calculator/:')), isEmpty);
  });
}
