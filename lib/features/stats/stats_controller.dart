import 'dart:math' as math;

import 'package:cgpa_calculator/core/models/semester_kind.dart';
import 'package:cgpa_calculator/core/grading/cgpa.dart';
import 'package:cgpa_calculator/core/grading/forecast.dart';
import 'package:cgpa_calculator/core/grading/requirements.dart';
import 'package:cgpa_calculator/core/models/semesters.dart';
import 'package:cgpa_calculator/course.dart';

/// A point on the chart.
typedef CgpaPoint = ({String sem, double cgpa});

/// One future semester the user can plan. One left out of the forecast
/// (`included` false) keeps its SGPA but moves nothing.
typedef PlannedSemester =
    ({
      String sem,
      double credits,
      double sgpa,
      double cgpaAfter,
      bool included,
    });

/// Everything the Stats screen shows. Pure; built from the stored courses.
class StatsData {
  StatsData._({
    required this.discipline,
    required this.done,
    required this.actual,
    required this.target,
    required this.remaining,
    required this.required,
    required this.planned,
    required this.audit,
    required this.note,
    this.totalSet,
  });

  factory StatsData.from({
    required Iterable<Course> all,
    required String discipline,
    double? target,
    Map<String, double> plan = const {},
    Set<String> skipped = const {},
    DegreeNeeds? needs,
    int? totalSet,
  }) {
    final order = semestersFor(discipline);
    final done = cumulativeTally(
      all,
      discipline: discipline,
      profile: Profile.actual,
    );
    final prog = progression(
      all,
      semesters: order,
      discipline: discipline,
      profile: Profile.actual,
    );
    final tgt = target ?? defaultTarget(done.gpa);
    final remaining = remainingCredits(all, discipline);
    final req = requiredAverage(
      target: tgt,
      done: done,
      futureCredits: remaining,
    );

    var running = done;
    final planned = <PlannedSemester>[];
    for (final f in futureSemesters(all, discipline, order)) {
      final sgpa = plan[f.sem] ?? _snap(done.gpa);
      final included = !skipped.contains(f.sem);
      if (included) running = withPlanned(running, f.credits, sgpa);
      planned.add((
        sem: f.sem,
        credits: f.credits,
        sgpa: sgpa,
        cgpaAfter: running.gpa,
        included: included,
      ));
    }

    return StatsData._(
      discipline: discipline,
      done: done,
      actual: [for (final p in prog) (sem: p.sem, cgpa: p.running.gpa)],
      target: tgt,
      remaining: remaining,
      required: req,
      planned: planned,
      audit: degreeAudit(all, discipline, needs: needs),
      totalSet: totalSet,
      // Summer and Practice School terms are not semesters to repeat.
      note: _note([
        for (final p in prog)
          if (semesterKind(p.sem, all.where((c) => c.sem == p.sem)) ==
              SemesterKind.regular)
            (sem: p.sem, sgpa: p.term.gpa),
      ], req),
    );
  }

  final String discipline;
  final GpaTally done;

  /// Running CGPA after each graded semester. The last equals [done].
  final List<CgpaPoint> actual;
  final double target;

  /// Credits still to earn, including NCs to repeat.
  final double remaining;

  /// Average needed over [remaining] to hit [target]; null if none remain.
  final double? required;
  final List<PlannedSemester> planned;
  final DegreeAudit audit;

  /// One sentence on whether [required] is realistic.
  final String note;

  /// The degree's total credits, as the student set it.
  final int? totalSet;

  /// The CGPA today, over graded courses.
  double get cgpa => done.gpa;

  /// The CGPA after the last planned semester, or [cgpa] with none planned.
  double get finish => planned.isEmpty ? cgpa : planned.last.cgpaAfter;

  /// The chart's dashed line: only the semesters in the forecast.
  List<PlannedSemester> get _forecasted => [
    for (final p in planned)
      if (p.included) p,
  ];

  /// From the same two rounded figures the footer shows ("YOU FINISH AT
  /// x.x5 CGPA"), not the raw ones (BUG-52) — otherwise a real 0.01 rise
  /// between the *displayed* numbers can round to "0.00 up" when the
  /// unrounded gap happens to sit under 0.005.
  double get delta =>
      double.parse(finish.toStringAsFixed(2)) -
      double.parse(cgpa.toStringAsFixed(2));

  /// The dashed forecast line: today's point, then each included plan.
  List<CgpaPoint> get forecast => [
    if (actual.isNotEmpty) actual.last,
    for (final p in _forecasted) (sem: p.sem, cgpa: p.cgpaAfter),
  ];

  /// Credits the degree still needs: from the sheet's requirements when
  /// imported, else the ungraded courses held.
  /// A total the student set wins.
  double get degreeLeft => switch (totalSet) {
    final t? => math.max(0, t - audit.totalCredits),
    // Ongoing courses are counted as done, so not as still to come.
    null => audit.creditsLeft ?? math.max(0, remaining - audit.ongoingCredits),
  };

  /// Credits earned (as the home screen counts them) over earned + left.
  double get degreeShare {
    final total = audit.totalCredits + degreeLeft;
    return total == 0 ? 0 : audit.totalCredits / total;
  }

  /// A new user (no CGPA yet, [cgpa] 0) gets a plain, reachable-looking
  /// default rather than a "0.50" derived from a CGPA that doesn't exist
  /// (BUG-07) — one that also sits inside the target step buttons' 4–10
  /// range, so Raise/Lower work immediately.
  static double defaultTarget(double cgpa) =>
      cgpa <= 0 ? 7.5 : math.min(10, (cgpa * 2).floor() / 2 + 0.5);

  /// Nearest 0.05, clamped to the slider's range.
  static double _snap(double v) => ((v * 20).round() / 20).clamp(4.0, 10.0);

  static String _note(
    Iterable<({String sem, double sgpa})> terms,
    double? req,
  ) {
    if (req == null) return 'Every course is graded.';
    if (req <= 0) return 'You are there already, whatever comes next.';
    if (req > 10) return 'Out of reach: even straight 10s fall short.';
    final sorted = terms.toList()..sort((a, b) => b.sgpa.compareTo(a.sgpa));
    if (sorted.isEmpty) return '';
    final best = sorted.take(3).toList();
    final avg = best.fold(0.0, (s, t) => s + t.sgpa) / best.length;
    final worst = sorted.last;
    final n = best.length == 3 ? 'three semesters' : 'semesters';
    final reachable = avg >= req;
    final base =
        'Your best $n averaged ${avg.toStringAsFixed(2)}, so this is '
        '${reachable ? 'reachable' : 'a stretch'}';
    // The "but not with a repeat of X" caveat only makes sense once the
    // verdict above is "reachable" — warning that the *worst* semester
    // specifically falls short (BUG-23). Appending it to "a stretch" is
    // self-contradicting: the sentence already said even the best average
    // doesn't clear the bar, so singling out the worst one adds nothing and
    // reads as if some other repeat *would* work.
    return reachable && worst.sgpa < req
        ? '$base — but not with a repeat of ${worst.sem}.'
        : '$base.';
  }
}
