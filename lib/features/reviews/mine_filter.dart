/// The Your reviews tab's filter pills (board PfYourReviewsAll).
library;

import 'package:cgpa_calculator/core/grading/requirements.dart';
import 'package:cgpa_calculator/core/models/elective.dart';
import 'package:cgpa_calculator/core/reviews/review.dart';
import 'package:cgpa_calculator/course.dart';

/// Which of the student's own reviews to show.
enum MineFilter {
  all('All'),
  thisSemester('This semester'),
  electives('Electives');

  const MineFilter(this.label);
  final String label;
}

/// The ids of [courses] that count as an elective in the audit (the same
/// category the requirement cards use, not a second rule).
Set<String> electiveIds(Iterable<Course> courses, String discipline) => {
  for (final c in courses)
    if (auditCategory(c, discipline) case final e?
        when e != Elective.cdc1 && e != Elective.cdc2)
      c.id,
};

/// [reviews] narrowed by [f]: [taking] is `takingNow()`, [electives] is
/// [electiveIds].
List<Review> filterMine(
  Iterable<Review> reviews,
  MineFilter f, {
  required Set<String> taking,
  required Set<String> electives,
}) => [
  for (final r in reviews)
    if (switch (f) {
      MineFilter.all => true,
      MineFilter.thisSemester => taking.contains(r.courseId),
      MineFilter.electives => electives.contains(r.courseId),
    })
      r,
];
