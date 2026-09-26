import 'package:cgpa_calculator/core/grading/grade_scale.dart';
import 'package:cgpa_calculator/core/grading/requirements.dart';
import 'package:cgpa_calculator/core/models/course_graph.dart';
import 'package:cgpa_calculator/core/models/course_names.dart';
import 'package:cgpa_calculator/core/models/elective.dart';
import 'package:cgpa_calculator/core/models/minors.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/mastercourselist.dart';

/// Where a minor's course stands, on the Actual profile.
enum MinorState {
  /// Passed: a letter grade or GD.
  done,

  /// In the course list, not graded yet.
  planned,

  /// Not in the list, or not passed.
  missing,
}

/// One place in a minor and the course, if any, that fills it.
class MinorSlotStatus {
  const MinorSlotStatus(
    this.slot,
    this.course,
    this.state, {
    this.overlap = false,
  });

  final MinorSlot slot;
  final Course? course;
  final MinorState state;

  /// Also mandatory for the student's own degree.
  final bool overlap;

  /// The id shown: the course taken, else the slot's first.
  String get id => course?.id ?? slot.first;

  String get title =>
      course?.title ??
      mcourselist
          .where((m) => sameCourseId(m.id, slot.first))
          .firstOrNull
          ?.title ??
      '';

  double get units =>
      course?.credits ??
      mcourselist
          .where((m) => sameCourseId(m.id, slot.first))
          .firstOrNull
          ?.credits ??
      3;
}

class MinorProgress {
  const MinorProgress({
    required this.minor,
    required this.core,
    required this.pools,
    required this.courses,
    required this.units,
    required this.overlapDropped,
    required this.projectsDropped,
    required this.gpa,
  });

  final Minor minor;
  final List<MinorSlotStatus> core;

  /// Per pool, in [Minor.pools] order.
  final List<List<MinorSlotStatus>> pools;

  /// Passed courses and units that count, after the overlap and project caps.
  final int courses;
  final double units;

  /// Passed courses left out: past the overlap cap, or a second project.
  final int overlapDropped;
  final int projectsDropped;

  /// GPA over the counted courses with a letter grade; null before any.
  final double? gpa;

  int get coreDone => core.where((s) => s.state == MinorState.done).length;
  int doneIn(int pool) =>
      pools[pool].where((s) => s.state == MinorState.done).length;
  int get electivesDone => [
    for (var i = 0; i < pools.length; i++) doneIn(i),
  ].fold(0, (a, b) => a + b);

  bool get complete =>
      coreDone == core.length &&
      electivesDone >= minor.electives &&
      [
        for (var i = 0; i < pools.length; i++) doneIn(i) >= minor.pools[i].min,
      ].every((ok) => ok) &&
      courses >= minor.courses &&
      units >= minor.units &&
      (gpa ?? 0) >= minorMinGpa;
}

/// How far [all] goes towards [minor] under [discipline].
MinorProgress minorProgress(
  Minor minor,
  Iterable<Course> all,
  String discipline,
) {
  final used = <Course>{};
  bool passed(Course c) => c.grade1 > 0 || c.grade1 == GradeCode.gd;
  bool core(Course c) => switch (auditCategory(c, discipline)) {
    null || Elective.cdc1 || Elective.cdc2 => true,
    _ => false,
  };

  MinorSlotStatus fill(MinorSlot slot) {
    final found = [
      for (final c in all)
        if (!used.contains(c) && slot.any((id) => courseGraph.same(c.id, id)))
          c,
    ];
    final best =
        found.where(passed).firstOrNull ??
        found
            .where(
              (c) => c.grade1 == GradeCode.clr || c.grade1 == GradeCode.ongoing,
            )
            .firstOrNull;
    if (best == null) return MinorSlotStatus(slot, null, MinorState.missing);
    used.add(best);
    return MinorSlotStatus(
      slot,
      best,
      passed(best) ? MinorState.done : MinorState.planned,
      overlap: core(best),
    );
  }

  final coreSlots = minor.core.map(fill).toList();
  final poolSlots = [for (final p in minor.pools) p.courses.map(fill).toList()];

  // Core first, then electives: the core has to count.
  var courses = 0, overlapCourses = 0, overlapDropped = 0, projects = 0;
  var projectsDropped = 0;
  var units = 0.0, overlapUnits = 0.0, points = 0.0, graded = 0.0;
  for (final s in [...coreSlots, ...poolSlots.expand((p) => p)]) {
    final c = s.course;
    if (c == null || s.state != MinorState.done) continue;
    if (minor.projects.contains(c.id)) {
      if (projects == 1) {
        projectsDropped++;
        continue;
      }
      projects++;
    }
    if (s.overlap) {
      if (overlapCourses == minorOverlapCourses ||
          overlapUnits + c.credits > minorOverlapUnits) {
        overlapDropped++;
        continue;
      }
      overlapCourses++;
      overlapUnits += c.credits;
    }
    courses++;
    units += c.credits;
    if (c.grade1 > 0) {
      points += c.grade1 * c.credits;
      graded += c.credits;
    }
  }
  return MinorProgress(
    minor: minor,
    core: coreSlots,
    pools: poolSlots,
    courses: courses,
    units: units,
    overlapDropped: overlapDropped,
    projectsDropped: projectsDropped,
    gpa: graded == 0 ? null : points / graded,
  );
}
