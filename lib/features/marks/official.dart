/// The student's side of published offerings: which one applies to a course
/// they hold, and keeping those fresh.
library;

import 'package:cgpa_calculator/core/grading/grade_scale.dart';
import 'package:cgpa_calculator/core/heads/heads.dart';
import 'package:cgpa_calculator/core/models/offering.dart';
import 'package:cgpa_calculator/core/storage/courses.dart';
import 'package:cgpa_calculator/core/storage/offerings.dart';
import 'package:cgpa_calculator/core/timings.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/script.dart' as app;

/// Set at startup (main.dart); null reads nothing, as in widget tests.
OfferingSource? offeringSource;

/// [c]'s term for this student, or null when there is no campus yet or the
/// semester has no year ("PS 1" has one; a custom label may not).
String? termFor(Course c) =>
    app.campus == null ? null : termOf(app.batch, c.sem);

/// The cached offering for [c], if any.
Offering? offeringFor(Course c) {
  final term = termFor(c);
  if (term == null) return null;
  return cachedOffering(c.id, app.campus!.name, term);
}

/// Reads [c]'s offering again when its version on the campus head moved, or
/// — before any head names it — when the copy is older than [maxAge].
Future<Offering?> refreshOfferingFor(
  Course c, {
  Duration maxAge = offeringMaxAge,
}) async {
  final term = termFor(c), source = offeringSource;
  if (term == null || source == null) return offeringFor(c);
  final campus = app.campus!.name;
  final head = await headFor(campus);
  return refreshOffering(
    source,
    c.id,
    campus,
    term,
    maxAge: maxAge,
    version: head?.offering(c.id, term),
  );
}

/// The term running on [now]: August–December is semester 1, January–May
/// semester 2, June–July the summer term.
String currentTerm(DateTime now) {
  final start = now.month >= 8 ? now.year : now.year - 1;
  final k =
      now.month >= 8
          ? '1'
          : now.month <= 5
          ? '2'
          : 'S';
  return '$start-${((start + 1) % 100).toString().padLeft(2, '0')}-$k';
}

/// On app open: refresh the offerings of courses being taken this term, at
/// most twice a day each. Never on the first paint's path.
Future<void> refreshCurrentOfferings({DateTime? now}) async {
  if (app.campus == null) return;
  final term = currentTerm(now ?? DateTime.now());
  for (final c in allCourses().toList()) {
    final taking = c.grade1 == GradeCode.ongoing || c.grade1 == GradeCode.clr;
    if (!taking || termFor(c) != term) continue;
    await refreshOfferingFor(c);
  }
}
