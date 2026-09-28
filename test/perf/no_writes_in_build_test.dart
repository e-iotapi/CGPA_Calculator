// UI_OPT O3.1: Home's build writes nothing to storage. Each setter is called
// from the handler that changes its value (see home_persist.dart).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The text of the first `Widget build(` method in [src], to its closing brace.
String buildMethod(String src) {
  final start = src.indexOf('Widget build(');
  expect(start, isNonNegative, reason: 'no build method');
  final open = src.indexOf('{', start);
  var depth = 0;
  for (var i = open; i < src.length; i++) {
    if (src[i] == '{') depth++;
    if (src[i] == '}' && --depth == 0) return src.substring(start, i + 1);
  }
  fail('unbalanced braces after build(');
}

void main() {
  test('Home\'s build calls no settings setter', () {
    final build = buildMethod(File('lib/home_page.dart').readAsStringSync());
    expect(build, contains('sgcalc('), reason: 'found the wrong method');
    final writes = RegExp(r'\bset(dis|sort|sem|prof|theme|navcolor)\(\)');
    expect(writes.allMatches(build).map((m) => m[0]), isEmpty);
  });
}
