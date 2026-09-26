import 'package:cgpa_calculator/core/models/marks.dart';

/// Parts that count toward [e]: every graded part, or the best
/// [Evaluative.countBest] by marks/outOf. Ungraded parts never count.
List<EvalPart> countedParts(Evaluative e) {
  final graded = e.parts.where((p) => p.marks != null && p.outOf > 0).toList();
  if (e.countBest <= 0 || e.countBest >= graded.length) return graded;
  final ranked = [...graded]
    ..sort((a, b) => (b.marks! / b.outOf).compareTo(a.marks! / a.outOf));
  return ranked.take(e.countBest).toList();
}

/// Graded but outside the best N. Still shown, marked dropped.
List<EvalPart> droppedParts(Evaluative e) {
  final counted = countedParts(e).toSet();
  return e.parts.where((p) => p.marks != null && !counted.contains(p)).toList();
}

/// What [e] contributes: counted marks over counted maximums, times the
/// weight. Derived from the parts — never a hard-coded divisor. Null when
/// nothing counted yet.
double? contribution(Evaluative e) {
  final c = countedParts(e);
  if (c.isEmpty) return null;
  final marks = c.fold(0.0, (s, p) => s + p.marks!);
  final outOf = c.fold(0.0, (s, p) => s + p.outOf);
  return marks / outOf * e.weight;
}

/// A course's running total.
class MarksSummary {
  MarksSummary(this.evaluatives, CourseConfig? config)
    : config = config ?? CourseConfig(courseId: '');

  final List<Evaluative> evaluatives;
  final CourseConfig config;

  /// Σ contributions, in course units (percent when weighted).
  double get secured =>
      evaluatives.fold(0.0, (s, e) => s + (contribution(e) ?? 0));

  /// Weight of the evaluatives with anything counted.
  double get gradedWeight => evaluatives
      .where((e) => contribution(e) != null)
      .fold(0.0, (s, e) => s + e.weight);

  double get assignedWeight => evaluatives.fold(0.0, (s, e) => s + e.weight);

  double get courseTotal =>
      config.weighted
          ? 100
          : (config.courseTotal > 0 ? config.courseTotal : assignedWeight);

  /// Display rescale; marks stay stored as entered.
  double get factor => courseTotal == 0 ? 1 : config.displayOutOf / courseTotal;

  double get shownSecured => secured * factor;
  double get shownGraded => gradedWeight * factor;

  /// Share of the course graded, 0–1.
  double get gradedShare => courseTotal == 0 ? 0 : gradedWeight / courseTotal;

  /// secured − class average; null when no average is set or nothing is
  /// graded — never invented.
  double? get classDelta {
    final avg = config.classAverage;
    if (avg == null || gradedWeight == 0) return null;
    return secured - avg;
  }
}
