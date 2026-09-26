import 'package:cgpa_calculator/core/grading/grade_scale.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/legacy_grading.dart' as legacy;

void main() {
  test('gradecalc matches the original for every stored value', () {
    for (var s = -150; s <= 150; s++) {
      // Ongoing is new; the original had no such grade.
      if (s == GradeCode.ongoing) continue;
      expect(gradecalc(s), legacy.gradecalc(s), reason: '$s');
    }
  });

  test('reversegradecalc matches the original for every input', () {
    final inputs = [
      ...gradeValues.keys.where((k) => k != 'ONG'),
      '',
      '–',
      '?',
      'a',
      'A+',
      'F',
      ' A',
      'NC ',
    ];
    for (final s in inputs) {
      expect(reversegradecalc(s), legacy.reversegradecalc(s), reason: s);
    }
  });

  test('Ongoing is its own grade: no points, distinct from blank', () {
    expect(reversegradecalc('ONG'), GradeCode.ongoing);
    expect(gradecalc(GradeCode.ongoing), 'ONG');
    expect(gradeWords(GradeCode.ongoing), 'Ongoing');
    expect(GradeCode.ongoing, isNot(GradeCode.clr));
    expect(pickerGrades, contains('ONG'));
  });

  test('every letter survives a round trip', () {
    for (final letter in gradeValues.keys) {
      expect(gradecalc(reversegradecalc(letter)), letter);
    }
  });
}
