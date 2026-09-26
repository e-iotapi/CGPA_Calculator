import 'package:cgpa_calculator/core/models/marks.dart';

/// Whether any part of [e] carries a mark. One that does not is ungraded
/// and stays out of the course total; once one does, every blank part in it
/// scores zero.
bool isGraded(Evaluative e) => e.parts.any((p) => p.marks != null);

/// Parts that count toward [e]: every part with an out-of, or the best
/// [Evaluative.countBest] by marks/outOf. A blank part scores zero, so it is
/// the first dropped. None while [e] is ungraded.
List<EvalPart> countedParts(Evaluative e) {
  if (!isGraded(e)) return const [];
  final scored = e.parts.where((p) => p.outOf > 0).toList();
  if (e.countBest <= 0 || e.countBest >= scored.length) return scored;
  double share(EvalPart p) => (p.marks ?? 0) / p.outOf;
  final ranked = [...scored]..sort((a, b) => share(b).compareTo(share(a)));
  return ranked.take(e.countBest).toList();
}

/// Scored but outside the best N. Still shown, marked dropped.
List<EvalPart> droppedParts(Evaluative e) {
  if (!isGraded(e)) return const [];
  final counted = countedParts(e).toSet();
  return e.parts.where((p) => p.outOf > 0 && !counted.contains(p)).toList();
}

/// What [e] contributes: counted marks over counted maximums, times the
/// weight. Derived from the parts — never a hard-coded divisor. Null while
/// [e] is ungraded.
double? contribution(Evaluative e) {
  final c = countedParts(e);
  if (c.isEmpty) return null;
  final marks = c.fold(0.0, (s, p) => s + (p.marks ?? 0));
  final outOf = c.fold(0.0, (s, p) => s + p.outOf);
  return outOf == 0 ? null : marks / outOf * e.weight;
}

/// A figure and whether the app worked it out rather than being told it.
typedef Resolved = ({double value, bool derived});

/// A value the user typed beats one the app worked out (ARCHITECTURE §5):
/// [typed] when set, else [derive]'s, else null. The one resolver for
/// every average.
Resolved? resolve(double? typed, double? Function() derive) {
  if (typed != null) return (value: typed, derived: false);
  final d = derive();
  return d == null ? null : (value: d, derived: true);
}

/// [e]'s class average: the typed component average, else the sum of its
/// part averages, marked derived. On the component's raw scale.
Resolved? componentAverage(Evaluative e) => resolve(e.average, () {
  final given = e.parts.where((p) => p.average != null);
  return given.isEmpty ? null : given.fold<double>(0, (s, p) => s + p.average!);
});

/// Your raw marks against [componentAverage], over the same parts: all of
/// them for a typed average, those with an average for a derived one. Null
/// while [e] is ungraded or has no average.
double? componentDelta(Evaluative e) {
  final avg = componentAverage(e);
  if (avg == null || !isGraded(e)) return null;
  final parts = avg.derived ? e.parts.where((p) => p.average != null) : e.parts;
  return parts.fold(0.0, (s, p) => s + (p.marks ?? 0)) - avg.value;
}

/// "Quiz 1" → "Quiz 2", "Lab" → "Lab 2": the name for a copy.
String nextName(String name) {
  final m = RegExp(r'^(.*?)(\d+)$').firstMatch(name.trim());
  if (m == null) return name.trim().isEmpty ? '' : '${name.trim()} 2';
  return '${m.group(1)}${int.parse(m.group(2)!) + 1}';
}

/// A copy of [e] to fill in: structure, weight and out-of, never the marks,
/// averages or dates; the name's number bumped.
Evaluative duplicateEvaluative(Evaluative e) => Evaluative(
  courseId: e.courseId,
  name: nextName(e.name),
  weight: e.weight,
  parts: [for (final p in e.parts) p.blank()],
  countBest: e.countBest,
);

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
