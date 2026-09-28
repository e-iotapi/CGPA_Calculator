// The scale a course is graded out of ("Graded out of", e.g. 200), set by
// whoever maintains the course's structure. Every offering save and scale
// read in the UI goes through this file; `Offering.outOf` stores it and
// core/grading/official_scheme.dart carries it to students
// (UI_REBUILD_HANDOFF.md §3.2).
import 'package:cgpa_calculator/core/models/offering.dart';

/// True: `Offering` stores the scale, so the scheme editor saves it.
const outOfStored = true;

/// The manager's scale for [o], or null when none is set.
double? offeringOutOf(Offering o) => o.outOf;

/// [o] with its scale set to [outOf] (null clears it).
Offering withOutOf(Offering o, double? outOf) => o.copyWith(outOf: outOf);

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
