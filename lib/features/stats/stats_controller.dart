import 'dart:math' as math;

import 'package:cgpa_calculator/core/grading/cgpa.dart';
import 'package:cgpa_calculator/core/grading/forecast.dart';
import 'package:cgpa_calculator/core/grading/requirements.dart';
import 'package:cgpa_calculator/core/models/semesters.dart';
import 'package:cgpa_calculator/course.dart';

/// A point on the chart.
typedef CgpaPoint = ({String sem, double cgpa});

/// One future semester the user can plan.
typedef PlannedSemester =
    ({String sem, double credits, double sgpa, double cgpaAfter});

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
  });

  factory StatsData.from({
    required Iterable<Course> all,
    required String discipline,
    double? target,
    Map<String, double> plan = const {},
    DegreeNeeds? needs,
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
      running = withPlanned(running, f.credits, sgpa);
      planned.add((
        sem: f.sem,
        credits: f.credits,
        sgpa: sgpa,
        cgpaAfter: running.gpa,
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
      note: _note(prog.map((p) => (sem: p.sem, sgpa: p.term.gpa)), req),
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

  double get cgpa => done.gpa;
  double get finish => planned.isEmpty ? cgpa : planned.last.cgpaAfter;
  double get delta => finish - cgpa;

  List<CgpaPoint> get forecast => [
    if (actual.isNotEmpty) actual.last,
    for (final p in planned) (sem: p.sem, cgpa: p.cgpaAfter),
  ];

  /// Credits the degree still needs: from the sheet's requirements when
  /// imported, else the ungraded courses held.
  double get degreeLeft => audit.creditsLeft ?? remaining;

  /// Credits earned (as the home screen counts them) over earned + left.
  double get degreeShare {
    final total = audit.totalCredits + degreeLeft;
    return total == 0 ? 0 : audit.totalCredits / total;
  }

  static double defaultTarget(double cgpa) =>
      math.min(10, (cgpa * 2).floor() / 2 + 0.5);

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
    final base =
        'Your best $n averaged ${avg.toStringAsFixed(2)}, so this is '
        '${avg >= req ? 'reachable' : 'a stretch'}';
    return worst.sgpa < req
        ? '$base — but not with a repeat of ${worst.sem}.'
        : '$base.';
  }
}
