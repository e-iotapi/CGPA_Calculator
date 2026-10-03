// U8: the step list is the spec (UI_MAP.md section 8): 40 steps, 7 chapters.
import 'dart:io';

import 'package:cgpa_calculator/features/tour/tour_steps.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('40 steps in 7 chapters with unique ids', () {
    expect(tourSteps, hasLength(40));
    expect(tourChapters, hasLength(7));
    final ids = tourSteps.map((s) => s.id).toList();
    expect(ids.toSet(), hasLength(40), reason: 'ids must be unique');
  });

  test('every chapter has steps and chapters run in order', () {
    for (var c = 0; c < tourChapters.length; c++) {
      expect(tourSteps.where((s) => s.chapter == c), isNotEmpty, reason: '$c');
    }
    final order = tourSteps.map((s) => s.chapter).toList();
    expect(order, [...order]..sort(), reason: 'a chapter is one run of steps');
  });

  test('every step has a target, a title and a line', () {
    for (final s in tourSteps) {
      expect(s.target, isNotEmpty, reason: s.id);
      expect(s.title.trim(), isNotEmpty, reason: s.id);
      expect(s.line.trim(), isNotEmpty, reason: s.id);
      expect(s.profile, inInclusiveRange(1, 4), reason: s.id);
    }
  });

  test('every target is a tour key some screen actually sets', () {
    final src = [
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            !f.path.contains('features/tour/'))
          f.readAsStringSync(),
    ].join('\n');
    for (final t in tourSteps.map((s) => s.target).toSet()) {
      expect(src.contains("'$t'"), isTrue, reason: 'no screen sets "$t"');
    }
  });
}
