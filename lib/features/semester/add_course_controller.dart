import 'package:cgpa_calculator/core/grading/cgpa.dart';
import 'package:cgpa_calculator/core/grading/grade_scale.dart';
import 'package:cgpa_calculator/core/models/course_names.dart';
import 'package:cgpa_calculator/core/models/elective.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/mastercourselist.dart';

/// The "counts as" tag for a course that belongs to no category.
const noCategory = 'CDCN';

/// "4 - 1" as shown: "4 − 1".
String semLabel(String sem) => sem.replaceAll('-', '−');

/// A master-list course as a search result.
class CourseHit {
  const CourseHit({
    required this.id,
    required this.title,
    required this.credits,
    required this.category,
    this.heldIn,
  });

  final String id;
  final String title;
  final double credits;

  /// Default elective tag for the discipline.
  final String category;

  /// Semester that already holds this course, if any. Courses are keyed by
  /// id, so adding it again would move it.
  final String? heldIn;
}

/// The legacy electiveSetter, as a function of its inputs.
String categoryFor(String id, String discipline) {
  final dept = id.split(' ').first;
  if (dept == 'HSS' || dept == 'GS' || huel.contains(id)) {
    return Elective.humanity.tag;
  }
  if (del[discipline.substring(2, 4)]?.contains(id) ?? false) {
    return Elective.del2.tag;
  }
  if (del[discipline.substring(0, 2)]?.contains(id) ?? false) {
    return Elective.del1.tag;
  }
  if (nonelist.contains(id)) return noCategory;
  return Elective.open.tag;
}

/// Human label for a tag, for [discipline].
String categoryLabel(String tag, String discipline) {
  final a = discipline.substring(0, 2), b = discipline.substring(2, 4);
  return switch (Elective.fromTag(tag)) {
    Elective.cdc1 => 'CDC ($a)',
    Elective.cdc2 => 'CDC ($b)',
    Elective.del1 => 'Disciplinary Elective ($a)',
    Elective.del2 => 'Disciplinary Elective ($b)',
    Elective.humanity => 'Humanity Elective',
    Elective.open => 'Open Elective',
    null => 'None',
  };
}

/// Tags offered in the "counts as" menu, as the legacy dropdown did.
List<String> categoryOptions(String discipline) {
  final a = discipline.substring(0, 2) != '--';
  final b = discipline.substring(2, 4) != '--';
  return [
    noCategory,
    if (a) Elective.cdc1.tag,
    if (b) Elective.cdc2.tag,
    Elective.open.tag,
    Elective.humanity.tag,
    if (b) Elective.del2.tag,
    if (a && !discipline.startsWith('B')) Elective.del1.tag,
  ];
}

/// Matches on code or name, case- and space-insensitive. Codes that start
/// with the query rank first.
List<CourseHit> searchCourses(
  String query, {
  required Iterable<Course> held,
  required String discipline,
  List<Mastercourselist>? master,
  int limit = 40,
}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  final compact = q.replaceAll(' ', '');
  final byId = {for (final m in master ?? mcourselist) m.id: m};
  bool codeStarts(Mastercourselist m) =>
      m.id.toLowerCase().replaceAll(' ', '').startsWith(compact);
  final found =
      byId.values
          .where(
            (m) =>
                codeStarts(m) ||
                m.title.toLowerCase().contains(q) ||
                m.id.toLowerCase().contains(q),
          )
          .toList()
        ..sort((x, y) {
          final r = (codeStarts(x) ? 0 : 1) - (codeStarts(y) ? 0 : 1);
          return r != 0 ? r : x.id.compareTo(y.id);
        });
  return [
    for (final m in found.take(limit))
      CourseHit(
        id: m.id,
        title: displayTitle(m.id, m.title),
        credits: m.credits,
        category: categoryFor(m.id, discipline),
        heldIn: held.where((c) => sameCourseId(c.id, m.id)).firstOrNull?.sem,
      ),
  ];
}

/// The course as it will be stored.
Course newCourse(
  CourseHit hit, {
  required String sem,
  required String discipline,
  required String category,
  required Profile profile,
  required int grade,
}) => Course(
  title: hit.title,
  id: hit.id,
  credits: hit.credits,
  sem: sem,
  elective: category,
  discipline:
      discipline.substring(0, 2) != '--'
          ? discipline.substring(0, 2)
          : discipline.substring(2, 4),
  grade1: profile == Profile.actual ? grade : GradeCode.clr,
  grade2: profile == Profile.expected ? grade : GradeCode.clr,
);

/// SGPA of [sem] before and after adding [course]; null when nothing counts.
(double?, double?) sgpaChange(
  Iterable<Course> all,
  Course course, {
  required String sem,
  required String discipline,
  required Profile profile,
}) {
  double? g(Iterable<Course> cs) {
    final t = semesterTally(
      cs,
      sem: sem,
      discipline: discipline,
      profile: profile,
    );
    return t.gradedCredits == 0 ? null : t.rounded;
  }

  return (g(all), g([...all, course]));
}
