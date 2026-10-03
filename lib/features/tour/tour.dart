// The guided tour, wired to the app: the router, Home, prefs and who the
// person is. The behaviour itself is in tour_controller.dart.
import 'dart:async';

import 'package:cgpa_calculator/app/router.dart';
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/app/theme/tokens.dart';
import 'package:cgpa_calculator/core/prefs/prefs_store.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/features/semester/widgets/course_row.dart';
import 'package:cgpa_calculator/features/tour/tour_controller.dart';
import 'package:cgpa_calculator/features/tour/tour_steps.dart';
import 'package:cgpa_calculator/script.dart';
import 'package:cgpa_calculator/shared/tour_key.dart';
import 'package:flutter/material.dart';

/// The page on top. `uri` ignores pages pushed over Home, so ask the last
/// match (an imperative push is a match of its own).
String _location() =>
    appRouter.routerDelegate.currentConfiguration.lastOrNull?.matchedLocation ??
    Routes.home;

String _pagePath(TourPage page, String? courseId) => switch (page) {
  TourPage.home => Routes.home,
  TourPage.course => Routes.course(courseId ?? ''),
  TourPage.calendar => Routes.calendar,
  TourPage.stats => Routes.stats,
  TourPage.more => Routes.more,
  TourPage.settings => Routes.settings,
};

/// Home registers this so the tour can switch its grade profile without
/// saving it; null while Home is not on screen.
void Function(int profile)? tourSelectProfile;

bool _wired = false;

/// The one tour. Built on first use so tests that never touch it do not need
/// a router.
final TourController tour = _build();

TourController _build() => TourController(
  TourEnv(
    overlay: () => appRouter.routerDelegate.navigatorKey.currentState?.overlay,
    push: (page, id) => unawaited(appRouter.push(_pagePath(page, id))),
    pop: appRouter.pop,
    onPage: (page, id) => _location() == _pagePath(page, id),
    selectProfile: (p) => tourSelectProfile?.call(p),
    profile: () => selectedprofile,
    firstCourseId:
        () => (tourKey('row', 1).currentWidget as CourseRow?)?.course.id,
    offshootHidden: () => offshootHiddenNow.value,
    seen: () => prefsStore?.tourSeen ?? true,
    markSeen: () async => prefsStore?.setTourSeen(true),
  ),
);

void _wire() {
  if (_wired) return;
  _wired = true;
  appRouter.routerDelegate.addListener(tour.routeChanged);
}

/// Students only: never as an owner, president or CR working in a role, never
/// while looking at someone else's view, never on a role page.
bool tourAllowedHere() => tourAllowedAt(_location());

/// [tourAllowedHere] for a given location.
@visibleForTesting
bool tourAllowedAt(String location) =>
    workingAs.value == null &&
    viewAs.value == null &&
    !onRolePath(location) &&
    location == Routes.home;

/// The first-run tour is due: this account has not seen it and setup is done.
@visibleForTesting
bool firstTourDue() {
  final s = prefsStore;
  return s != null && !s.tourSeen && degree_selected && !tour.active;
}

bool _waiting = false;

/// Home calls this on first sign-in (after setup, never before). Starts the
/// tour when this device's account has not seen it, once the server's prefs
/// have been read: an unset flag before that could just be "not loaded yet".
void maybeStartFirstTour() {
  final s = prefsStore;
  if (s == null || !firstTourDue() || _waiting) return;
  void go() {
    _waiting = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!firstTourDue() || !tourAllowedHere()) return;
      _wire();
      unawaited(tour.start());
    });
  }

  if (s.pulled.value) return go();
  _waiting = true;
  void once() {
    if (!s.pulled.value) return;
    s.pulled.removeListener(once);
    go();
  }

  s.pulled.addListener(once);
}

/// Settings > Replay the tour: whole tour or one chapter. Closes Settings,
/// then runs it from Home.
Future<void> replayTour(BuildContext context) async {
  final p = AppPalette.of(context);
  final picked = await showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    backgroundColor: p.background,
    builder:
        (c) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: Space.lg),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.gutter,
                  0,
                  Space.gutter,
                  Space.sm,
                ),
                child: Text(
                  'Replay the tour',
                  style: TypeScale.title.copyWith(color: p.text),
                ),
              ),
              ListTile(
                title: Text(
                  'Whole tour',
                  style: TypeScale.body.copyWith(color: p.text),
                ),
                onTap: () => Navigator.of(c).pop(-1),
              ),
              for (final (i, name) in tourChapters.indexed)
                ListTile(
                  title: Text(
                    '${i + 1} · $name',
                    style: TypeScale.body.copyWith(color: p.text),
                  ),
                  onTap: () => Navigator.of(c).pop(i),
                ),
            ],
          ),
        ),
  );
  if (picked == null || !context.mounted) return;
  appRouter.pop(); // Settings
  await Future<void>.delayed(const Duration(milliseconds: 400));
  if (!tourAllowedHere()) return;
  _wire();
  await tour.start(chapter: picked < 0 ? null : picked);
}
