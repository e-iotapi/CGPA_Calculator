// UI_OPT O4.1: no `Opacity` widget over a subtree. Animated fades use
// FadeTransition; static ones use colour alpha.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Files allowed one `Opacity(`, each with its reason.
const _allowed = {
  // A row that isn't open yet dims whole: CardRow owns its text colours.
  // Static, one short row.
  'lib/admin/admin_home.dart': 'closed admin row',
  // A dropped part's live text fields dim with it; static, one small part.
  'lib/features/marks/add_evaluative_page.dart':
      'dropped part holds text fields',
};

void main() {
  test('lib has no Opacity widget outside the allow-list', () {
    final hits = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final path = f.path.replaceAll(r'\', '/');
      final n =
          RegExp(
            r'(?<![A-Za-z])Opacity\(',
          ).allMatches(f.readAsStringSync()).length;
      if (n > (_allowed.containsKey(path) ? 1 : 0)) hits.add('$path ($n)');
    }
    expect(hits, isEmpty);
  });
}
