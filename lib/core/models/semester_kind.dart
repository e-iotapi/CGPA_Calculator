import 'package:cgpa_calculator/course.dart';

/// What kind of semester a label is (ARCHITECTURE.md §16.3 fix 10). Summer
/// terms and Practice School are left out of "your best three semesters".
enum SemesterKind { regular, summer, practiceSchool }

final _ps2 = RegExp(
  r'practice\s*school\s*[-–]?\s*(ii|2)\b',
  caseSensitive: false,
);

/// "ST n" is a summer term and "PS 1" Practice School I; any semester that
/// holds Practice School-II ([courses] are the ones in it) is Practice
/// School too.
SemesterKind semesterKind(String label, Iterable<Course> courses) {
  final l = label.trim().toUpperCase();
  if (l.startsWith('ST')) return SemesterKind.summer;
  if (l.startsWith('PS')) return SemesterKind.practiceSchool;
  final ps2 = courses.any(
    (c) => c.id.trim().toUpperCase() == 'BITS F412' || _ps2.hasMatch(c.title),
  );
  return ps2 ? SemesterKind.practiceSchool : SemesterKind.regular;
}
