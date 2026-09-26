import 'package:cgpa_calculator/core/grading/cgpa.dart';
import 'package:cgpa_calculator/core/storage/course_order.dart';
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
  gradesDesc('Sort by Grades(Des)', 'Grade ↓'),

  /// The order the student dragged the rows into. Once a row is dragged the
  /// other sorts stop applying until one is picked again.
  custom(customSortKey, 'Custom');

  const CourseSort(this.key, this.label);
  final String key;
  final String label;

  static CourseSort fromKey(String key) =>
      values.firstWhere((s) => s.key == key, orElse: () => creditsAsc);
}

/// GPA figures for one profile.
class ProfileFigures {
  const ProfileFigures({
    required this.term,
    required this.overall,
    this.previous,
  });
  final GpaTally term;
  final GpaTally overall;

  /// The CGPA at the end of the last graded semester before this one; null
  /// when there is none.
  final GpaTally? previous;
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
    required this.compared,
    required this.comparedFigures,
  });

  factory SemesterData.from({
    required Iterable<Course> allCourses,
    required List<Course> visible,
    required String sem,
    required List<String> semesters,
    required String discipline,
    required SemesterMode mode,
    required CourseSort sort,
    required List<String> profileNames,
    (int, int) compared = (1, 2),
  }) {
    // Every semester ordered before this one, for "last semester's" CGPA:
    // the same progression the Stats page draws.
    final before = semesters.takeWhile((s) => s != sem).toList();
    ProfileFigures figures(Profile p) => ProfileFigures(
      term: semesterTally(
        allCourses,
        sem: sem,
        discipline: discipline,
        profile: p,
      ),
      overall: cumulativeTally(allCourses, discipline: discipline, profile: p),
      previous:
          progression(
            allCourses,
            semesters: before.length == semesters.length ? const [] : before,
            discipline: discipline,
            profile: p,
          ).lastOrNull?.running,
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
      compared: compared,
      comparedFigures: (
        figures(Profile.fromId(compared.$1)!),
        figures(Profile.fromId(compared.$2)!),
      ),
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

  /// Every profile's name, profile 1 first.
  final List<String> profileNames;

  /// The two profile ids Compare shows, and their figures.
  final (int, int) compared;
  final (ProfileFigures, ProfileFigures) comparedFigures;

  /// Figures for the tab being shown; Actual's for compare and offshoot.
  ProfileFigures get current =>
      mode == SemesterMode.expected ? expected : actual;

  String nameOf(int profile) => profileNames[profile - 1];

  /// The sentence under the greeting.
  String get editorial {
    if (mode == SemesterMode.compare) {
      return 'Comparing ${nameOf(compared.$1)} and ${nameOf(compared.$2)} '
          'grades';
    }
    if (mode == SemesterMode.offshoot) return 'Your offshoot, scored.';
    final f = current;
    if (f.overall.gradedCredits == 0) {
      return 'Add your courses and grades to see your CGPA.';
    }
    if (f.term.gradedCredits == 0) return 'Nothing graded in $sem yet.';
    final prev = f.previous;
    // No last semester, no comparison with one.
    if (prev == null) return 'Nothing graded before $sem to compare with.';
    final yours =
        mode == SemesterMode.expected ? 'Your expected CGPA' : 'Your CGPA';
    final diff = f.overall.rounded - prev.rounded;
    if (diff.abs() < 0.005) return '$yours is the same as last semester\'s.';
    final by = diff.abs().toStringAsFixed(2);
    return '$yours is $by ${diff > 0 ? 'above' : 'below'} last semester\'s.';
  }

  /// The bold part of [editorial], if any.
  String? get editorialEmphasis {
    final m = RegExp(
      r'\d+\.\d\d (above|below)|the same as',
    ).firstMatch(editorial);
    return m?.group(0);
  }
}

/// "24", "0.5", "3.5" — credits without a trailing ".0".
String formatCredits(double c) =>
    c == c.roundToDouble() ? c.toInt().toString() : c.toString();

/// A GPA for display: "–" when nothing is graded.
String formatGpa(GpaTally t) => t.gradedCredits == 0 ? '–' : t.fixed;
