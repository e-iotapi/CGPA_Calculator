/// The compulsory-reviews gate as the student's screens see it (feature 2).
library;

import 'package:cgpa_calculator/admin/widgets.dart' show Note, shortDay;
import 'package:cgpa_calculator/app/routes.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/cache/cache_first.dart';
import 'package:cgpa_calculator/core/grading/grade_scale.dart';
import 'package:cgpa_calculator/core/heads/paths.dart';
import 'package:cgpa_calculator/core/models/elective.dart';
import 'package:cgpa_calculator/core/reviews/gate.dart';
import 'package:cgpa_calculator/core/reviews/gate.dart' as gate show required;
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
import 'package:cgpa_calculator/shared/widgets/app_card.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
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
  final remembered = myReviewedCourses().toSet();
  var n = 0;
  for (final id in remembered) {
    final r = store.peekMine(id);
    if (r == null || r.stars > 0) n++;
  }
  // Reviews this device does not remember (posted on another device, or the
  // list replaced by a sync): their saved copies, read by [refreshGate].
  for (final c in electivesTaken()) {
    if (remembered.contains(c.id)) continue;
    final r = store.peekMine(c.id);
    if (r != null && r.stars > 0) n++;
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

/// Still locked: the reviews themselves decide, not this device's list of
/// them (another device posted them, or a sync replaced the list). Reads each
/// elective taken and not remembered (one cached read each, only while
/// locked) and remembers the ones reviewed. A prefetch job, never the UI's.
Future<void> recoverMyReviews(String campus) async {
  final store = reviewStore;
  if (store == null || myGate(campus) != GateState.locked) return;
  final known = myReviewedCourses().toSet();
  for (final c in electivesTaken()) {
    if (known.contains(c.id)) continue;
    try {
      if (await store.mine(c.id) != null) await rememberReview(c.id);
    } catch (_) {
      // Offline: the saved state stands.
    }
  }
}

/// The short code the boards print for an elective's stored tag.
String electiveCode(String tag) => switch (Elective.fromTag(tag)) {
  Elective.humanity => 'HEL',
  Elective.open => 'OPEL',
  Elective.del1 || Elective.del2 => 'DEL',
  _ => tag,
};

/// The board's 22-square tick: ink with a check when [on], a ring when not.
class ReviewTick extends StatelessWidget {
  const ReviewTick({super.key, required this.on});
  final bool on;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: on ? p.inverse : p.surface,
        borderRadius: BorderRadius.circular(7),
        border: on ? null : Border.all(color: p.outline, width: 1.5),
      ),
      child: on ? Icon(Icons.check_rounded, size: 16, color: p.onInverse) : null,
    );
  }
}

/// Board `PfForcedLocked`: the mint banner with the progress bar (no count)
/// and the way out, then the reviews that count so far. Drawn in place of
/// every list of reviews while the gate is [GateState.locked]. [onBack] runs
/// when the student returns from the electives page.
class LockedReviews extends StatelessWidget {
  const LockedReviews({super.key, required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final taken = electivesTaken();
    final need = gate.required(taken.length);
    final done = myReviewCount();
    final remembered = myReviewedCourses().toSet();
    final counted = [
      for (final c in taken)
        if (remembered.contains(c.id)) c,
    ];
    final share = need == 0 ? 0.0 : (done / need).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          decoration: BoxDecoration(
            color: p.hero,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10,
            children: [
              Row(
                spacing: 12,
                children: [
                  SizedBox.square(
                    dimension: 44,
                    child: Icon(
                      Icons.lock_outline_rounded,
                      size: 20,
                      color: p.onHero,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 2,
                      children: [
                        Text(
                          'Reviews are locked',
                          style: TypeScale.body.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: p.onHero,
                          ),
                        ),
                        Text(
                          'Review your electives to read every course’s '
                          'reviews.',
                          style: TypeScale.caption.copyWith(
                            fontSize: 10.5,
                            color: p.onHeroMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Text(
                'YOUR REVIEWS',
                style: TypeScale.label.copyWith(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: p.onHeroMuted,
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: share,
                  minHeight: 8,
                  backgroundColor: p.chipFill,
                  color: p.inverse,
                ),
              ),
              PrimaryButton(
                label: 'Review my electives',
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
          ),
        ),
        if (counted.isNotEmpty) ...[
          const SizedBox(height: Space.sm),
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 6),
            child: Text(
              'COUNTED SO FAR',
              style: TypeScale.label.copyWith(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: p.textMuted,
              ),
            ),
          ),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final (i, c) in counted.indexed) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      indent: 15,
                      endIndent: 15,
                      color: p.divider,
                    ),
                  Opacity(
                    opacity: 0.5,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 8,
                      ),
                      child: Row(
                        spacing: 10,
                        children: [
                          const ReviewTick(on: true),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: 2,
                              children: [
                                Text(
                                  c.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TypeScale.body.copyWith(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  _posted(c),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TypeScale.caption.copyWith(
                                    fontSize: 10.5,
                                    color: p.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: Space.xs),
        const Note(
          'Only electives count (HEL, DEL, OPEL). Compulsory courses and '
          'imported historical reviews never do. Stars and Will I take it are '
          'required; the written part is optional.',
        ),
      ],
    );
  }

  String _posted(Course c) {
    final at = reviewStore?.peekMine(c.id)?.createdAt ?? 0;
    return [
      c.id,
      electiveCode(c.elective),
      if (at > 0)
        'posted ${shortDay(DateTime.fromMillisecondsSinceEpoch(at))}',
    ].join(' · ');
  }
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
