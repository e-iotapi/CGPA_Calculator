import 'package:cgpa_calculator/core/contrib/contributor_store.dart';
import 'package:cgpa_calculator/core/contrib/leaderboard_store.dart';
import 'package:cgpa_calculator/core/resources/resource.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/features/resources/resources_page.dart';
import 'package:cgpa_calculator/features/setup/campus_pick_page.dart';
import 'package:cgpa_calculator/script.dart';
import 'package:flutter/foundation.dart';

/// The signed-in user's contributor store, or `null` before sign-in.
ContributorStore? get contributorStore => switch (roleStore) {
  final r? => ContributorStore(r),
  null => null,
};

/// The campus leaderboard store, or `null` before sign-in.
LeaderboardStore? get leaderboardStore => switch (roleStore) {
  final r? => LeaderboardStore(r.db),
  null => null,
};

/// Where the student stands as a contributor (what Settings, More and the
/// Resources prompt follow): none yet, applied (waiting), approved, or
/// declined (may apply again).
enum ContribState { none, applied, approved, declined }

/// What the stores hold about me, for one screen.
typedef MyContrib = ({MyContributor me, ContributorRequest? request});

/// [ContribState] from the saved copies, refreshed by [refreshContribState].
final contribState = ValueNotifier<ContribState>(ContribState.none);

/// Whether the Resources prompt was already shown this session.
bool contributePromptShown = false;

/// The department a student applies for: their main degree's.
String? myContribDept() {
  for (final code in programmesOf(selecteddiscipline).reversed) {
    if (departmentOfProgramme(code) case final d?) return d;
  }
  return null;
}

/// [ContribState] of [v]; a held grant wins (it is read at sign-in).
ContribState contribStateOf(MyContrib? v) {
  if (myRoles.value.contributor || v?.me.isContributor == true) {
    return ContribState.approved;
  }
  return switch (v?.request?.status) {
    RequestStatus.pending => ContribState.applied,
    RequestStatus.declined => ContribState.declined,
    _ => ContribState.none,
  };
}

/// [loadMyContrib] from the saved copies; null when there are none.
MyContrib? peekMyContrib() {
  final s = contributorStore;
  if (s == null) return null;
  final me = s.peekMe(s.roles.me), r = s.peekMyRequest(s.roles.me);
  if (me == null && r == null) return null;
  return (me: me ?? const MyContributor(isContributor: false), request: r);
}

/// My grant, username, points and latest request.
Future<MyContrib> loadMyContrib() async {
  final s = contributorStore, campus = viewCampus();
  if (s == null || campus == null) {
    return (me: const MyContributor(isContributor: false), request: null);
  }
  final me = await s.me(campus);
  final dept = myContribDept();
  final r = dept == null ? null : await s.myRequest(campus, dept);
  final v = (me: me, request: r);
  contribState.value = contribStateOf(v);
  return v;
}

/// Reads [contribState] from the saved copies at once, then the stores. A
/// failed refresh keeps what is shown.
Future<void> refreshContribState() async {
  if (contributorStore == null) {
    contribState.value = ContribState.none;
    return;
  }
  contribState.value = contribStateOf(peekMyContrib());
  try {
    await loadMyContrib();
  } catch (e) {
    debugPrint('[Pointer] contributor state: $e');
  }
}

/// The state of one of my links.
enum LinkState { awaiting, approved, rejected, expired }

/// [r]'s state, or null for a link a president removed (no reason given).
LinkState? linkStateOf(Resource r, DateTime now) {
  if (r.removed) return r.rejectedReason.isEmpty ? null : LinkState.rejected;
  if (r.approved) return LinkState.approved;
  return r.hiddenAt(now) ? LinkState.expired : LinkState.awaiting;
}

/// Whether the student may add links (a grant), or is staff (who publish
/// at once).
bool get contributesDirectly => myRoles.value.privileged;
