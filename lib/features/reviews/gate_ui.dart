/// The compulsory-reviews gate as the student's screens see it (feature 2).
library;

import 'package:cgpa_calculator/core/grading/grade_scale.dart';
import 'package:cgpa_calculator/core/reviews/gate.dart';
import 'package:cgpa_calculator/core/reviews/gate_store.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/core/storage/courses.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/reviews/mine_filter.dart';
import 'package:cgpa_calculator/features/reviews/review_widgets.dart';
import 'package:cgpa_calculator/script.dart'
    show currentsem, selecteddiscipline;

/// The signed-in person's gate store, or `null` before sign-in.
GateStore? get gateStore => switch (roleStore) {
  final r? => GateStore(r),
  null => null,
};

/// The electives (HEL/DEL/OPEL, never CDCs: [electiveIds], the category the
/// requirement cards use) the student has a result for. One still in progress
/// or left blank is not taken yet.
List<Course> electivesTaken() {
  final ids = electiveIds(allCourses(), selecteddiscipline);
  return [
    for (final c in allCourses())
      if (ids.contains(c.id) &&
          c.grade1 != GradeCode.ongoing &&
          c.grade1 != GradeCode.clr &&
          c.grade1 != GradeCode.dash &&
          c.grade1 != GradeCode.w)
        c,
  ];
}

/// The student's own reviews, from the saved "mine" copies. Their own are
/// never imported and always carry stars and a would-take answer; one whose
/// copy is not saved yet was posted from here, so it counts.
int myReviewCount() {
  final store = reviewStore;
  if (store == null) return 0;
  var n = 0;
  for (final id in myReviewedCourses()) {
    final r = store.peekMine(id);
    if (r == null || r.stars > 0) n++;
  }
  return n;
}

/// Where the student stands now, read from saved copies only: a gate never
/// loaded is off, so nothing is locked and nothing spins.
GateState myGate(String campus) => gateState(
  on: gateStore?.peekOf(campus) ?? false,
  currentsem: currentsem,
  electivesTaken: electivesTaken().length,
  myReviewCount: myReviewCount(),
);

/// Loads the gate into its saved copy; a failure keeps the one saved.
Future<void> refreshGate(String campus) async {
  try {
    await gateStore?.of(campus);
  } catch (_) {
    // The saved gate stands.
  }
}
