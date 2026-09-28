// BACKEND SEAM: the scale a course is graded out of ("Graded out of", e.g.
// 200), set by whoever maintains the course's structure. The UI is built and
// wired through this file only; the stored field and the student-side sync
// belong to the logic branch. See UI_REBUILD_HANDOFF.md §3.2 before editing.
import 'package:cgpa_calculator/core/models/offering.dart';

/// False until `Offering` stores the scale. While false, the scheme editor
/// shows the field with a caption that it is not saved yet, and every scale
/// below falls back to the course's own units, so nothing changes.
const outOfStored = false;

/// The manager's scale for [o], or null when none is set.
/// BACKEND: return `o.outOf` once the field exists.
double? offeringOutOf(Offering o) => null;

/// [o] with its scale set to [outOf] (null clears it).
/// BACKEND: return `o.copyWith(outOf: outOf)` once the field exists.
Offering withOutOf(Offering o, double? outOf) => o;

/// The units marks and the stored course average are kept in: percent for a
/// weighted course, marks out of the total otherwise. Mirrors
/// `CourseSummary.courseTotal` in core/grading/marks.dart.
double courseUnits({required bool weighted, required double totalMarks}) =>
    weighted ? 100 : totalMarks;

/// What a manager types the course average out of.
double scaleOf(Offering o) =>
    offeringOutOf(o) ??
    courseUnits(weighted: o.weighted, totalMarks: o.totalMarks);

/// A typed average (0–[scale]) in stored course units.
double toStored(double shown, {required double scale, required double units}) =>
    scale == 0 ? shown : shown * units / scale;

/// A stored average (course units) on the manager's [scale].
double toShown(double stored, {required double scale, required double units}) =>
    units == 0 ? stored : stored * scale / units;
