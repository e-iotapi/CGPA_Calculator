/// Grades are stored on a course as ints: the grade point for letter grades,
/// and a negative code for everything that carries no points.
abstract final class GradeCode {
  static const nc = -1;
  static const clr = -2;

  /// Graded-and-passed with no points. Counted in credits shown, never in
  /// the GPA denominator.
  static const gd = -3;

  /// Rendered as a dash.
  static const dash = -5;
  static const rc = -6;
  static const w = -7;

  /// What [reversegradecalc] returns for an unknown letter.
  static const unknown = -100;
}

/// Letter → stored value, for every grade the app accepts.
const gradeValues = <String, int>{
  'A': 10,
  'A-': 9,
  'B': 8,
  'B-': 7,
  'C': 6,
  'C-': 5,
  'D': 4,
  'E': 2,
  'NC': GradeCode.nc,
  'CLR': GradeCode.clr,
  'GD': GradeCode.gd,
  'RC': GradeCode.rc,
  'W': GradeCode.w,
};

final _letters = {
  for (final e in gradeValues.entries) e.value: e.key,
  GradeCode.dash: '–',
};

/// Stored value → letter. Unknown values show as "?".
String gradecalc(int s) => _letters[s] ?? '?';

/// Letter → stored value. An empty string means cleared.
int reversegradecalc(String s) =>
    s == '' ? GradeCode.clr : gradeValues[s] ?? GradeCode.unknown;

/// Order of the grade picker. "" is how a cleared grade is picked.
const pickerGrades = [
  'A',
  'A-',
  'B',
  'B-',
  'C',
  'C-',
  'D',
  'E',
  'NC',
  'RC',
  'W',
  'CLR',
  'GD',
  '',
];
