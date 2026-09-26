import 'package:cgpa_calculator/core/grading/cgpa.dart';
import 'package:cgpa_calculator/course.dart';

/// What the nav's four tabs show. Matches `selectedprofile` 1–4.
enum SemesterMode {
  actual,
  expected,
  compare,
  offshoot;

  static SemesterMode fromProfileId(int id) => values[(id - 1).clamp(0, 3)];

  Profile? get profile => switch (this) {
    actual => Profile.actual,
    expected => Profile.expected,
    _ => null,
  };
}

/// Sort options. [key] is the string stored in `currentsort`.
enum CourseSort {
  creditsAsc('Sort by Credits(Asc)', 'Credits ↑'),
  creditsDesc('Sort by Credits(Des)', 'Credits ↓'),
  gradesAsc('Sort by Grades(Asc)', 'Grade ↑'),
  gradesDesc('Sort by Grades(Des)', 'Grade ↓');

  const CourseSort(this.key, this.label);
  final String key;
  final String label;

  static CourseSort fromKey(String key) =>
      values.firstWhere((s) => s.key == key, orElse: () => creditsAsc);
}

/// GPA figures for one profile.
class ProfileFigures {
  const ProfileFigures({required this.term, required this.overall});
  final GpaTally term;
  final GpaTally overall;
}

/// Everything the semester screen displays, computed once per build from the
/// store. Holds no state and never touches Hive.
class SemesterData {
  SemesterData({
    required this.sem,
    required this.semesters,
    required this.courses,
    required this.mode,
    required this.sort,
    required this.actual,
    required this.expected,
    required this.profileNames,
  });

  factory SemesterData.from({
    required Iterable<Course> allCourses,
    required List<Course> visible,
    required String sem,
    required List<String> semesters,
    required String discipline,
    required SemesterMode mode,
    required CourseSort sort,
    required (String, String) profileNames,
  }) {
    ProfileFigures figures(Profile p) => ProfileFigures(
      term: semesterTally(
        allCourses,
        sem: sem,
        discipline: discipline,
        profile: p,
      ),
      overall: cumulativeTally(allCourses, discipline: discipline, profile: p),
    );
    return SemesterData(
      sem: sem,
      semesters: semesters,
      courses: visible,
      mode: mode,
      sort: sort,
      actual: figures(Profile.actual),
      expected: figures(Profile.expected),
      profileNames: profileNames,
    );
  }

  final String sem;
  final List<String> semesters;

  /// This semester's courses, already filtered and sorted.
  final List<Course> courses;
  final SemesterMode mode;
  final CourseSort sort;
  final ProfileFigures actual;
  final ProfileFigures expected;
  final (String, String) profileNames;

  /// Figures for the tab being shown; Actual's for compare and offshoot.
  ProfileFigures get current =>
      mode == SemesterMode.expected ? expected : actual;

  String nameOf(Profile p) =>
      p == Profile.actual ? profileNames.$1 : profileNames.$2;

  /// The sentence under the greeting.
  String get editorial {
    if (mode == SemesterMode.compare) {
      return 'Comparing ${profileNames.$1} and ${profileNames.$2} grades';
    }
    if (mode == SemesterMode.offshoot) return 'Your offshoot, scored.';
    final f = current;
    if (f.overall.gradedCredits == 0) {
      return 'Add your courses and grades to see your CGPA.';
    }
    if (f.term.gradedCredits == 0) return 'Nothing graded in $sem yet.';
    final diff = f.term.rounded - f.overall.rounded;
    if (diff.abs() < 0.005) {
      return 'This semester you are level with your running CGPA.';
    }
    final by = diff.abs().toStringAsFixed(2);
    return 'This semester you are $by ${diff > 0 ? 'above' : 'below'} '
        'your running CGPA.';
  }

  /// The bold part of [editorial], if any.
  String? get editorialEmphasis {
    final m = RegExp(
      r'\d+\.\d\d (above|below)|level with',
    ).firstMatch(editorial);
    return m?.group(0);
  }
}

/// "24", "0.5", "3.5" — credits without a trailing ".0".
String formatCredits(double c) =>
    c == c.roundToDouble() ? c.toInt().toString() : c.toString();

/// A GPA for display: "–" when nothing is graded.
String formatGpa(GpaTally t) => t.gradedCredits == 0 ? '–' : t.fixed;
