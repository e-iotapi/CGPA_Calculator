/// The compulsory-reviews gate as the student's screens see it (feature 2).
library;

import 'package:cgpa_calculator/app/routes.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/cache/cache_first.dart';
import 'package:cgpa_calculator/core/grading/grade_scale.dart';
import 'package:cgpa_calculator/core/heads/paths.dart';
import 'package:cgpa_calculator/core/reviews/gate.dart';
import 'package:cgpa_calculator/core/reviews/gate_store.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart' show markerOf;
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/core/storage/courses.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/reviews/mine_filter.dart';
import 'package:cgpa_calculator/features/reviews/review_widgets.dart';
import 'package:cgpa_calculator/features/reviews/compulsory_pick.dart';
import 'package:cgpa_calculator/script.dart'
    show currentsem, selecteddiscipline;
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/shared/widgets/notice.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/material.dart';

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

/// Board `ReviewsLocked`: the banner (no count) and the way out, drawn in
/// place of every list of reviews while the gate is [GateState.locked].
/// [onBack] runs when the student returns from the electives page.
class LockedReviews extends StatelessWidget {
  const LockedReviews({super.key, required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Notice(
        icon: Icons.lock_outline_rounded,
        text: TextSpan(
          text:
              'Reviews are locked. Review the electives you have taken to '
              'open them: it takes a minute, and stays anonymous.',
        ),
      ),
      const SizedBox(height: Space.sm),
      PrimaryButton(
        label: 'Review your electives',
        tall: true,
        onPressed: () async {
          await openRoute(
            context,
            Routes.compulsoryReviews,
            () => const CompulsoryPickPage(),
          );
          onBack();
        },
      ),
    ],
  );
}

/// The switch as the staff rows show it: on or off, who turned it on, when
/// (ms since epoch).
typedef GateInfo = ({bool on, String? by, int? at});

GateInfo _decodeInfo(Object? o) {
  final m = o as Map;
  return (
    on: m['on'] == true,
    by: m['by'] as String?,
    at: (m['at'] as num?)?.toInt(),
  );
}

/// The saved [gateInfo] for [campus], or null.
GateInfo? peekGateInfo(String campus) =>
    peekCache<GateInfo>('gateinfo|$campus', _decodeInfo);

/// `reviewGate/<campus>` with its audit fields, cached under the gate's
/// marker. A GateStore.set forgets `gate|`, and the marker it moves retires
/// this copy.
Future<GateInfo> gateInfo(String campus) async {
  final db = roleStore!.db;
  return cacheFirst<GateInfo>(
    key: 'gateinfo|$campus',
    maxAge: const Duration(hours: 1),
    version: await markerOf(db, campus, Paths.reviewGate),
    fetch: () async {
      final m = (await db.collection('reviewGate').doc(campus).get()).data();
      return (
        on: m?['on'] == true,
        by: (m?['by'] as Map?)?['name'] as String?,
        at: (m?['at'] as Timestamp?)?.millisecondsSinceEpoch,
      );
    },
    encode: (v) => {'on': v.on, 'by': v.by, 'at': v.at},
    decode: _decodeInfo,
  );
}
