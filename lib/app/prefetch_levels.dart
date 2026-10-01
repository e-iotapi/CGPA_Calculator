import 'package:cgpa_calculator/app/router.dart';
import 'package:cgpa_calculator/core/analytics/analytics_store.dart';
import 'package:cgpa_calculator/core/prefetch/prefetch.dart';
import 'package:cgpa_calculator/core/professors/professor_store.dart';
import 'package:cgpa_calculator/core/roles/maintain_store.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/core/storage/offerings.dart';
import 'package:cgpa_calculator/features/marks/official.dart';
import 'package:cgpa_calculator/features/resources/resources_page.dart';
import 'package:cgpa_calculator/features/reviews/review_widgets.dart';
import 'package:cgpa_calculator/features/roles/rep_profile.dart';
import 'package:cgpa_calculator/features/setup/campus_pick_page.dart';
import 'package:cgpa_calculator/script.dart';

Future<void> Function() _job(Future<Object?> Function() call) =>
    () => call().then((_) {});

/// Levels 2-4 for the signed-in user (level 1 is already local). Built when
/// the run starts, so it reads the roles and campus as they are then.
List<PrefetchLevel> prefetchLevels() {
  final campus = viewCampus(), roles = roleStore;
  if (campus == null || roles == null) return const [];
  final reviews = reviewStore!, contacts = contactStore!;
  final taking = takingNow().toList()..sort();
  final term = currentTerm(DateTime.now());
  final me = myRoles.value;
  final l2 = <PrefetchLevel>[[]], l3 = <PrefetchLevel>[[]];
  final two = l2.first, three = l3.first;

  two.add(_job(() => reviews.mostReviewed(campus)));
  for (final c in taking) {
    two.add(_job(() => reviews.stats(c, campus)));
  }
  for (final c in myReviewedCourses()) {
    two.add(_job(() => reviews.mine(c)));
  }
  two.add(_job(() => contacts.directory(campus)));
  for (final c in taking) {
    two.add(
      _job(() async {
        // A course with a CR needs no volunteer offer.
        final people = await contacts.directory(campus);
        final now = DateTime.now();
        final hasCr = people.any(
          (p) => p
              .liveAt(now)
              .any((r) => r.role == GrantRole.course && r.scope == c),
        );
        return hasCr ? null : contacts.myOffer(campus, c);
      }),
    );
  }
  final store = resourceStore;
  if (store != null) {
    for (final code in programmesOf(selecteddiscipline)) {
      if (departmentOfProgramme(code) case final dept?) {
        two.add(_job(() => store.department(campus, dept)));
      }
    }
  }
  two.add(_job(() => roles.publicContact()));

  for (final c in taking) {
    three.add(_job(() => reviews.page(c, campus)));
    three.add(_job(() => reviews.byProfessor(c, campus)));
    final off = cachedOffering(c, campus, term);
    for (final id in off?.professors ?? const <String>[]) {
      three.add(_job(() => ProfessorStore(roles.db).get(id)));
    }
  }

  final four = <Future<void> Function()>[_job(prefetchPresidentPages)];
  final maintain = MaintainStore(roles);
  for (final g in me.courses) {
    four.add(_job(() => maintain.offering(g.scope, campus, term)));
  }
  if (me.reachesAdmin) {
    final analytics = AnalyticsStore(roles.db);
    four
      ..add(_job(() => roles.roster()))
      ..add(_job(() => roles.owners()))
      ..add(_job(() => roles.terms()))
      ..add(_job(() => analytics.counts()))
      ..add(_job(() => analytics.days(30)));
  }
  return [two, three, four];
}
