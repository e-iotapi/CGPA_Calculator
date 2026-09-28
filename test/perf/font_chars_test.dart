import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// UI_OPT O7.1: every character a string literal in lib/ can show must be in
/// the subset fonts carry (tools/font_chars.txt), or it falls back to a
/// downloaded Noto font and looks different.
void main() {
  test('every string literal in lib/ is inside the font subset', () {
    final subsetLine = File('tools/font_chars.txt').readAsStringSync().trim();
    final allowed =
        subsetLine
            .split(',')
            .map((u) => int.parse(u.substring(2), radix: 16))
            .toSet();
    // The scanner's own literal quoting always fits ASCII; keep the guard
    // honest by also allowing newline/tab, which are stripped before render.
    allowed.addAll([0x0A, 0x09, 0x0D]);

    final quoted = RegExp(r'''(['"])((?:\\.|(?!\1).)*)\1''');
    final missing = <String, Set<int>>{};
    for (final entity in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!entity.path.endsWith('.dart')) continue;
      final src = entity.readAsStringSync();
      for (final m in quoted.allMatches(src)) {
        final s = m
            .group(2)!
            .replaceAll(r'\n', '\n')
            .replaceAll(r'\t', '\t');
        for (final rune in s.runes) {
          if (!allowed.contains(rune)) {
            (missing[entity.path] ??= {}).add(rune);
          }
        }
      }
    }
    expect(
      missing,
      isEmpty,
      reason:
          'Characters outside tools/font_chars.txt: ${missing.entries.map((e) => '${e.key}: ${e.value.map((c) => String.fromCharCode(c)).join()}').join('; ')}. '
          'Add them to the scanner and re-run tools/subset_fonts.sh.',
    );
  });
}
