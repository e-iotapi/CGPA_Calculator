# UI_OPT.md — making Pointer smooth on older phones, with the same UI

A step-by-step guide. It is written for an implementing agent that builds it card by card.
Every card lists its files, its steps (with code where the step is easy to get wrong), the tests
to write, how to measure it, and when it counts as done. **Nothing in this guide changes what
the app looks like.** It changes only how much work each frame costs.

- Part 1 (§1–§3): the rules, the targets and how to measure.
- Part 2 (§4–§11): the phases O1–O8, in build order.
- Part 3 (§12–§14): the per-screen checklist, merging with `pointer-refactor`, and done.

---

## 1 · Read first

### 1.1 What is wrong today (found in the code, 27 Sep 2026, branch `pointer-rebuild`)
The app runs on Flutter web with the **CanvasKit** renderer (WebGL). `deploy.yml` builds with
plain `flutter build web --release`. CanvasKit redraws the layer tree each frame, so the cost
of a frame is what gets rebuilt, laid out and painted in it. On a 2018–2020 budget phone
(Redmi 7, Galaxy A10) or an iPhone 7/8, anything beyond one screen of work per frame drops
frames.

The worst offenders, by severity:

| # | Where | What happens | Severity |
|---|---|---|---|
| 1 | Dark/light switch: `lib/app/theme/circle_reveal.dart` `ThemeReveal`, `lib/script.dart:320` `switchTheme`, `lib/main.dart:269` `MyApp` | Four problems, detailed in §4. It snapshots the whole screen before anything moves (`toImage`, a GPU read-back). It rebuilds the whole app about 12 times while the circle runs (`MaterialApp`'s default 200 ms `AnimatedTheme` lerp). It recomputes `ColorScheme.fromSeed`. It draws a full-screen image each frame. | **High**: this is the "doesn't work or lags" report |
| 2 | Home profile switch: `semester_page.dart:145` `AnimatedSwitcher` | Two full pages fade across each other for 380 ms, and the new one is built in the first frame | High |
| 3 | Home rebuild: `home_page.dart:68-182` | Every `setState` re-filters and sorts the box, fires about 12 IndexedDB writes (`setdis`…`settheme`) and re-runs the tallies | High |
| 4 | Stats slider: `stats_page.dart:112-115` | Every slider tick (120 steps) rebuilds all of `StatsData` and writes the plan to IndexedDB | High |
| 5 | Page transitions: `CircleRevealTransitionsBuilder` | An anti-aliased full-screen `ClipPath` each frame. A remount hitch on the last frame (the widget type changes from `ClipPath` to the page). A `CurvedAnimation` leak. | Medium |
| 6 | Long lists built at once | `RowGroup` (`lib/admin/widgets.dart:26`) puts about 130 course rows in one `Column` (DeptCourses), re-laid out on every keystroke. The same happens in programme pick, add-course search (no debounce), roster, professors and resources. | Medium–High (admin) |
| 7 | Looping and one-off animations | `PulsingTab` animates a `BoxShadow` forever. The sign-in entrance animates `Opacity` widgets. `Opacity` wraps search hits in the add-course sheet. | Medium |
| 8 | Web load | About 2.1 MB of full Montserrat TTFs (the SemiBold file twice). No asset caching (the service worker unregisters itself). A `MutationObserver` in `web/index.html` walks the whole DOM on every mutation. | Medium (start-up) |

### 1.2 Targets (the user's choice)
- **Low-end Android on Chrome**: 2–3 GB RAM, Snapdragon 450 / Helio P22 class (Redmi 6/7,
  Galaxy A10/A12).
- **Old iPhones on Safari**: iPhone 7/8/SE 2nd gen on iOS 15–16.
- **Budget per frame**: 16.7 ms. **A transition may drop at most 2 frames** (theme switch,
  page push or pop, profile switch). A tap must show its first change within **100 ms**.

### 1.3 Rules that bind every card
1. **Same UI.** Never change a layout, colour, size, copy, icon, route or animation shape.
   - The **circle reveal stays on every device**, for the theme switch and for pages (the
     user's decision).
   - What may change: how the same picture is produced. That covers caching, clip modes,
     filter quality, when work runs, and which widgets rebuild.
   - Durations stay the same: the reveal 560 ms, page push 420 ms, pop 380 ms, profile
     switch 380 ms.
2. **Reduced motion** keeps working exactly as today (`MediaQuery.disableAnimationsOf`): the
   theme applies at once, and pages fade.
3. **Don't touch `pointer-refactor`'s ground** (PERF_TEST_PLAN.md Phase P on that branch):
   - `startApp()` in `main.dart` (P3 owns it)
   - the stores in `lib/core/**` (P1–P2)
   - `sync.dart` (P3, P4)
   - the tally functions `sgcalc` / `cgcalc` / `creditTotals` in `script.dart` (P4.3)
   - `StatsData.cached` (P4.4)
   - deferred libraries and `--wasm` (P7)

   Where a card depends on one of these, it says "**after refactor P…**" and gives a
   UI-only step for now.
4. The repo rules from UI.md §1.3 and §20.0 all apply:
   - Dart 3.7, with no null-aware elements.
   - `dart format` only on new or already-formatted files. `main.dart`, `home_page.dart` and
     `script.dart` are legacy: edit them by hand.
   - No Hive writes from UI tests.
   - No real emails.
   - Stage named files only.
   - Commit per phase with the trailer. The user pushes.
5. Every card leaves `flutter analyze` at the baseline and `flutter test` green, including
   the render tests in `test/ui/*_screens_test.dart` (UI.md §14.1). Those catch any visual
   regression as a layout error.

### 1.4 Order (and the answer to "does doing this early break the UI rebuild?")
It doesn't, **as long as the same agent does it on `pointer-rebuild`, in sequence, never in
parallel on another branch**.

O1 and O2 touch:
- `circle_reveal.dart`
- the two `MaterialApp`s in `main.dart` (the `SignInApp` and `MyApp` widgets only, not
  `startApp`)
- `switchTheme` in `script.dart`
- `materialTheme` in `palette.dart`

UI.md T3.1 rewrites that same getter. Run them one after another and nothing conflicts.

The order:
1. UI.md Group 2
2. UI.md **T3.1** (the Material theme)
3. **UI_OPT O0, O1, O2, O7**
4. the rest of UI.md Group 3
5. UI.md Groups 4–8, each card also passing the per-screen checklist (§12)
6. **UI_OPT O3–O6, O8** as one sweep
7. UI.md Group 9 (the last pass), which re-measures with §3.

If refactor's P5.0 merge (it merges `pointer-rebuild` into `pointer-refactor`) happens midway,
nothing here blocks it. §13 lists the files both branches touch.

---

## 2 · The files this guide touches

| File | Phases | Shared with |
|---|---|---|
| `lib/app/theme/circle_reveal.dart` | O1, O2 | — |
| `lib/app/theme/palette.dart` (`materialTheme`) | O1.2 | UI.md T3.1: do T3.1 first |
| `lib/main.dart` (`SignInApp`, `MyApp` build only) | O1.1, O4.2 | refactor P3 (`startApp`): don't touch it |
| `lib/script.dart` (`switchTheme` only) | O1.5 | refactor P4.3 (the tallies): don't touch them |
| `lib/home_page.dart` | O3.1–O3.3 | refactor P4.2 hooks `setdis` / `setprof`: keep their names |
| `lib/features/semester/semester_page.dart` | O3.4 | — |
| `lib/features/stats/stats_page.dart`, `widgets/progression_view.dart`, `widgets/cgpa_chart.dart` | O3.5, O4.3 | refactor P5 (`StatsData.cached` one-liner) |
| `lib/admin/widgets.dart` (`RowGroup`), `admin/maintain.dart`, `admin/professors.dart`, `admin/people.dart`, `features/setup/programme_pick_page.dart`, `features/semester/add_course_sheet.dart` | O5 | UI.md Groups 4–8 (restyle): do O5 inside those cards or after |
| `lib/admin/dept_resources.dart` (`PulsingTab`) | O6.1 | UI.md T8.13 |
| `pubspec.yaml`, `fonts/`, `web/index.html`, `landing/_headers` | O7 | refactor P7 (bundle): don't overlap |
| new `lib/core/perf/frame_stats.dart`, `lib/core/perf/device_tier.dart` | O0 | refactor P0 has `lib/core/perf/perf.dart`: different file names, keep them apart |
| new `test/perf/*_test.dart` | all | — |

---

## 3 · How to measure (build O0 first)

You can't fix frames you can't see. There are three levels: tests that run in CI, a
debug-only frame logger, and a device check.

### O0.1 · Frame stats, debug only
- **New file** `lib/core/perf/frame_stats.dart`:
  ```dart
  /// Frame timings for the performance work (UI_OPT.md §3). Compiled in only
  /// with --dart-define=POINTER_FRAMES=1; release builds never carry it.
  library;

  import 'package:flutter/foundation.dart';
  import 'package:flutter/scheduler.dart';

  const framesOn = bool.fromEnvironment('POINTER_FRAMES');

  abstract final class FrameStats {
    static final _build = <int>[], _raster = <int>[];
    static String? _label;

    /// Starts collecting under [label] ("theme", "push", "profile").
    static void start(String label) {
      if (!framesOn) return;
      _label = label;
      _build.clear();
      _raster.clear();
      SchedulerBinding.instance.addTimingsCallback(_on);
    }

    /// Stops and prints: frames, over-budget frames, worst build and raster.
    static void stop() {
      if (!framesOn || _label == null) return;
      SchedulerBinding.instance.removeTimingsCallback(_on);
      int over(List<int> l) => l.where((u) => u > 16700).length;
      int worst(List<int> l) => l.isEmpty ? 0 : l.reduce((a, b) => a > b ? a : b);
      debugPrint(
        '[Pointer frames] $_label: ${_build.length} frames, '
        'build over ${over(_build)} (worst ${worst(_build) ~/ 1000} ms), '
        'raster over ${over(_raster)} (worst ${worst(_raster) ~/ 1000} ms)',
      );
      _label = null;
    }

    static void _on(List<FrameTiming> t) {
      for (final f in t) {
        _build.add(f.buildDuration.inMicroseconds);
        _raster.add(f.rasterDuration.inMicroseconds);
      }
    }
  }
  ```
- **Wire it**:
  - `FrameStats.start('theme')` / `stop()` around `ThemeReveal._run`
  - `start('push')` / `stop()` on route animation start and end (`circle_reveal.dart`, via an
    `animation.addStatusListener`, only when `framesOn`)
  - `start('profile')` / `stop()` around the Home profile switch
  - Every call is a no-op unless the define is set.
- **Test** `test/perf/frame_stats_test.dart`: with `framesOn` false, `start` / `stop` add no
  timings callback (`SchedulerBinding.instance` has none registered). Check through a
  `@visibleForTesting` getter.

### O0.2 · Device tier (used only to choose quality, never to change the UI)
- **New file** `lib/core/perf/device_tier.dart`:
  ```dart
  enum DeviceTier { low, normal }

  /// Measured once per device: a low tier gets cheaper snapshots and clip
  /// edges (UI_OPT.md O1.3, O2.2). Stored in deviceBox under 'tier'.
  DeviceTier deviceTier = DeviceTier.normal;

  /// Call after the first frame: two seconds of frame timings, plus the
  /// browser's hints where it has them.
  Future<void> measureDeviceTier() async { … }
  ```
- **Rules for `low`**, any of these:
  - `navigator.hardwareConcurrency <= 4`
  - `navigator.deviceMemory <= 3` (Chrome only)
  - the median raster time of the first 60 frames after first paint > 12 ms

  Read the navigator values through the existing web / stub pair
  (`lib/core/platform/browser.dart`, `browser_web.dart`). Add `int? hardwareConcurrency()`
  and `double? deviceMemory()` next to `userAgent()`; the stub returns null.
- **Where it's called**: from `MyApp`'s first frame (`WidgetsBinding.instance.addPostFrameCallback`),
  not from `startApp`. Store the result in `deviceBox` (`'tier'`), and read the stored value
  at the next start so the first theme switch is already right.
- **Test** `test/perf/device_tier_test.dart`: a pure function
  `tierFrom({int? cores, double? memory, double? medianRasterMs})` returns `low` for
  `(4, null, null)`, `(8, 2, null)` and `(8, 8, 14)`, and `normal` for `(8, 8, 6)`.

### O0.3 · Test helpers that run in CI
**New** `test/perf/perf_helpers.dart`:
- `Future<int> countBuilds<T extends Widget>(WidgetTester t, Future<void> Function() act)`
  counts how often widgets of type `T` build during `act`. Use a test-only
  `BuildCounter` widget wrapped around the subject, or `debugOnRebuildDirtyWidget` in debug.
- `Finder repaintBoundaryAround(Finder f)`.

### O0.4 · Device check (manual, after each phase)
1. **Android**: open the deployed build in Chrome on the phone, or on desktop Chrome with
   DevTools → Performance → **CPU 6× slowdown**. Record a theme switch, a page push and a
   profile switch. Count frames over 16.7 ms in the timeline.
2. **iPhone**: Safari → Develop → the phone → Timelines → "Rendering Frames".
3. A local build with `flutter build web --release --dart-define=POINTER_FRAMES=1` prints
   the `[Pointer frames]` lines in the console. **Never deploy that build.**
4. Write the numbers into **`UI_PERF_BASELINE.md`**: one table per phase, before and after,
   for these rows:
   - theme switch light→dark
   - theme switch dark→light
   - push Settings
   - pop
   - profile switch Actual→Expected
   - DeptCourses typing 5 letters
   - Stats slider drag of 1 s

   The columns are frames, frames over budget, worst build (ms) and worst raster (ms). Ask the
   user to run the on-device rows, because this environment has no phone.

---

## 4 · Phase O1 · The theme switch, keeping the circle

**Today** (`circle_reveal.dart:147-170`, `script.dart:320-331`, `main.dart:269-280`):
1. On tap: `box.toImage(pixelRatio: min(dpr, 1.5))` snapshots the whole app. That is a GPU
   render plus a read-back of a roughly 600 × 1370 image, and the tap shows nothing until it
   completes.
2. `apply()`:
   - sets the palette
   - calls `setnavcolor()`
   - `themeVersion++` rebuilds `MaterialApp.router` with a new `thm.materialTheme`, which
     runs `ColorScheme.fromSeed`
   - `then` → `setState` on Home: a full Home build with Hive writes and tallies
3. `MaterialApp` has no `themeAnimationDuration`, so `AnimatedTheme` lerps `ThemeData` for
   200 ms. **Every widget that reads the theme rebuilds on every frame, about 12 times**,
   while…
4. …the reveal runs 560 ms. Each frame, `_HolePainter` draws the full-screen image through an
   even-odd path clip with `FilterQuality.medium`, over the live app.

**Target**: one app rebuild, done **under the cover** before the circle starts moving; a
snapshot that is ready by the time the finger lifts; and a cheap paint per frame. Same circle,
same 560 ms, same easing.

### O1.1 · No theme lerp (the biggest single win)
- **Files**: `lib/main.dart` (`SignInApp` build near line 256, `MyApp` build near line 272).
- **Steps**: add `themeAnimationDuration: Duration.zero` to **both** `MaterialApp`s:
  `MaterialApp(... theme: thm.materialTheme, themeAnimationDuration: Duration.zero, ...)`
  and `MaterialApp.router(... themeAnimationDuration: Duration.zero, ...)`. The colours still
  change in one step, as `AppPalette.lerp` already snaps at 0.5, and the reveal hides the
  switch.
- **Test** `test/perf/theme_switch_test.dart`:
  `'theme change rebuilds the app once'`.
  1. Pump `MaterialApp(theme: light.materialTheme, themeAnimationDuration: Duration.zero,
     home: BuildCounter(child: Builder(builder: (c) { Theme.of(c); return SizedBox(); })))`.
  2. Swap to dark.
  3. `pump()`, then `pump(Duration(milliseconds: 100))` twice.
  4. `expect(counter.builds, 2)` (the initial build + 1).
  5. Add the control case without the parameter, and expect more than 2. That shows what the
     parameter prevents.
- **Done**: the test passes, and on-device the theme row loses most of its build-over frames.

### O1.2 · Build each `ThemeData` once
- **Files**: `lib/app/theme/palette.dart`. **Do this after UI.md T3.1**, which rewrites
  `materialTheme`.
- **Steps**: turn `ThemeData get materialTheme` into a cached getter. The palettes are
  `const` singletons, so cache by `name`:
  ```dart
  static final _themes = <String, ThemeData>{};
  ThemeData get materialTheme => _themes[name] ??= _buildTheme();
  ThemeData _buildTheme() { /* T3.1's body, unchanged */ }
  ```
- **Test** (`test/theme/palette_test.dart`): `'materialTheme is built once per palette'`:
  `identical(AppPalette.dark.materialTheme, AppPalette.dark.materialTheme)`.

### O1.3 · A cheaper snapshot, taken before the tap ends
- **Files**: `lib/app/theme/circle_reveal.dart`, and every theme-toggle button: Home's header
  moon/sun (`semester_page.dart`, the `onToggleTheme` button) and Settings' Light / Dark
  buttons (`settings_view.dart`).
- **Steps**:
  1. Add `static void prepare()` to `ThemeReveal`. It starts a snapshot now and keeps the
     `Future<ui.Image>` until `run` uses it or 2 s pass (then it disposes the image). Call it
     from `onTapDown` on each theme button: wrap the buttons' `onPressed` sites in a
     `Listener(onPointerDown: (_) => ThemeReveal.prepare())`. The finger is down for about
     80–150 ms, so the capture mostly runs before `onPressed` fires.
  2. Pixel ratio: `deviceTier == DeviceTier.low ? 1.0 : math.min(dpr, 1.5)`. On a 2× phone at
     1.0 that is a quarter of the pixels of a 2× capture. The image is on screen for half a
     second while shrinking, so the lower resolution isn't visible. **Check it by eye in the
     device check.** If edges look soft on a 2× phone, use `math.min(dpr, 1.25)` for low tier.
  3. Try the synchronous path first: `box.toImageSync(pixelRatio: r)`. It exists on
     `RenderRepaintBoundary` since Flutter 3.7 and avoids the async read-back on CanvasKit.
     Wrap it in `try` and fall back to `await box.toImage(pixelRatio: r)` on
     `UnsupportedError`. Log once with `debugPrint('[Pointer theme] toImageSync unavailable')`.
  4. In `_run`: use the prepared image if one is ready, else capture now.
- **Tests** (`test/perf/theme_switch_test.dart`):
  - `'prepare then run uses the prepared snapshot'`: count captures through a
    `@visibleForTesting static int captures`. After `prepare()` then `run(apply)`, the count
    is 1, not 2.
  - `'a prepared snapshot expires'`: after `prepare()` and `pump(Duration(seconds: 3))`,
    `debugPreparedImage == null`.
  - The existing `test/theme/motion_test.dart` reduced-motion tests still pass unchanged.

### O1.4 · Rebuild under the cover, then move
- **Files**: `circle_reveal.dart` (`_run`).
- **Steps**: new order inside `_run`:
  ```dart
  final image = await _snapshot();             // O1.3 (prepared or now)
  if (!mounted) return image.dispose();
  setState(() { _old = image; _origin = …; _anim.value = 0; });  // cover shows, hole = 0
  await WidgetsBinding.instance.endOfFrame;     // cover is on screen
  apply();                                      // the one rebuild happens under the cover
  await WidgetsBinding.instance.endOfFrame;     // new theme laid out and painted, hidden
  FrameStats.start('theme');
  await _anim.forward(from: 0);                 // now only the hole moves
  FrameStats.stop();
  ```
  The circle starts one to two frames later than today, about 33 ms, well inside the 100 ms
  target, and every animated frame is cheap.
- **Test**: `'the theme applies before the circle moves'`. Record `_anim.value` inside the
  `apply` callback: `expect(valueAtApply, 0)`.

### O1.5 · Side effects after the animation
- **Files**: `lib/script.dart` (`switchTheme` only; edit by hand, no format).
- **Steps**: move `setnavcolor()` out of the `apply` closure, and run it and `await
  settheme()` after `ThemeReveal.run` returns. The `then` callback (Home's and Settings'
  `setState`) must stay inside `apply`, because it rebuilds with the new theme under the
  cover.
  ```dart
  await ThemeReveal.run(() {
    selected_theme = name;
    thm = AppPalette.byName(selected_theme);
    themeVersion.value++;
    then?.call();
  });
  setnavcolor();
  await settheme();
  ```
- **Test**: none new. `motion_test.dart` and `test/settings/settings_test.dart` stay green.

### O1.6 · A cheaper painter
- **Files**: `circle_reveal.dart` (`_ThemeRevealState.build`, `_HolePainter`).
- **Steps**:
  1. Wrap the overlay's `CustomPaint` in its own `RepaintBoundary`, so each tick repaints
     only the overlay layer, not the parent above `ThemeReveal`.
  2. `FilterQuality.low` on low tier, `medium` otherwise. Low bilinear-filters without
     mipmaps; the image is 1:1 or slightly upscaled, so it looks the same.
  3. Pass `isComplex: true, willChange: true` to that `CustomPaint`.
  4. Keep the even-odd clip and the final-25% fade; that is the look.
- **Test**: `'the reveal overlay has its own repaint boundary'`. During the animation,
  `find.ancestor(of: find.byType(CustomPaint)…, matching: find.byType(RepaintBoundary))`
  is found directly around it.

### O1.7 · Don't rebuild Home's world on the theme switch
- **Files**: `lib/home_page.dart` (by hand).
- **Steps**:
  - Home's `then: setState` currently runs its whole `build`, including about 12 Hive writes
    and the tallies (§6 fixes those; after O3.1 this build is cheap).
  - Until O3.1 lands, pass `then: null` from Home's toggle. `themeVersion` already rebuilds
    `MaterialApp`, and Home reads `thm` through `Theme(copyWith(extensions: [thm]))` at
    `home_page.dart:89-90`.
  - Check that the header's moon/sun icon flips without the `setState`. If it doesn't, keep
    `then`, but only after O3.1.
- **Test**: covered by O3.1's test.

### O1 acceptance
- CI: all O1 tests pass, plus `motion_test.dart`, `settings_test.dart` and the render tests.
- Device (§3 O0.4), theme row, 6× throttle:
  - tap → first circle frame ≤ 100 ms
  - ≤ 2 frames over budget during the 560 ms
  - no frame over 50 ms
- Record before and after in `UI_PERF_BASELINE.md`. Commit "UI_OPT O1: theme switch".

---

## 5 · Phase O2 · Page transitions, keeping the circle

**Today** (`circle_reveal.dart:59-100`):
- An anti-aliased `ClipPath` per frame over the pushed page, while the page under it also
  paints.
- On the last frame the builder returns `c!` instead of `ClipPath(child: c)`. The widget type
  changes, so the page subtree is reparented and fully relaid out in exactly that frame: a
  hitch at the end of every push, and again at the start of every pop.
- A new `CurvedAnimation` is created on every `buildTransitions` call and never disposed.

### O2.1 · Same widget type for the whole transition
- **Steps**: always return the `ClipPath`, and switch its behaviour instead:
  ```dart
  builder: (_, c) {
    final t = curved.value;
    return ClipPath(
      clipper: _CircleClipper(origin, t),
      clipBehavior: t >= 1 ? Clip.none : _edge,   // O2.2
      child: c,
    );
  },
  ```
  `Clip.none` at rest costs nothing: no clip layer, same picture.
- **Test**: update `test/theme/motion_test.dart` `'pages open as a circle from the tap'`.
  After `pumpAndSettle`, instead of `_clip() findsNothing`, assert
  `t.widget<ClipPath>(_clip()).clipBehavior == Clip.none`. Add
  `'no remount at the end of a push'`: a `StatefulWidget` page counts `initState`, and the
  count is 1 after the push settles.

### O2.2 · A hard edge on low tier
- **Steps**: `final _edge = deviceTier == DeviceTier.low ? Clip.hardEdge : Clip.antiAlias;`.
  The circle's edge moves fast; the missing anti-aliasing is not visible in motion, and a hard
  clip is much cheaper in CanvasKit on weak GPUs.
- **Test**: `'low tier clips with a hard edge'`: set `deviceTier = DeviceTier.low` in the test
  and check `clipBehavior == Clip.hardEdge` mid-animation. Reset it in `tearDown`.

### O2.3 · One curve per route
- **Steps**: cache the `CurvedAnimation` per route in an `Expando<CurvedAnimation>`, next to
  `_origins`:
  ```dart
  static final _curves = Expando<CurvedAnimation>();
  final curved = _curves[route] ??= CurvedAnimation(parent: animation, curve: …, reverseCurve: …);
  ```
- **Test**: `'one curve per route'`: push, pump 5 frames, and count `_curves` entries
  through a `@visibleForTesting` counter incremented on creation. It is 1.

### O2.4 · Build heavy pages before they show
- **Why**: the first frame of a push builds the whole new page. Stats computes in `build`, and
  admin pages build every row.
- **Steps**:
  - After refactor P4.4 and P5 (`StatsData.cached`), Stats' build is cheap. Until then, don't
    change Stats' logic here.
  - For every page, O5 (lazy lists) reduces the first-frame work.
  - No other code in this card; it's a note for the measurement: if the push row still shows
    a long first frame, find the page's build cost with DevTools and log it in §13.

### O2 acceptance
- CI: the updated `motion_test.dart` and the new O2 tests pass.
- Device, push/pop rows: ≤ 2 frames over budget and no end-of-animation spike.
- Commit "UI_OPT O2: page transitions".

---

## 6 · Phase O3 · Rebuild less

### O3.1 · Home's build does no writes and no repeated work
- **Files**: `lib/home_page.dart` (by hand).
- **Today** (`home_page.dart:68-90`): every build runs:
  - `setdis(); setsort(); setsem(); setprof(); settheme(); setnavcolor();`, about 12
    IndexedDB puts
  - `sgpa = sgcalc(currentsem); cgpa = cgcalc(); creditTotals();`
  - `Theme.of(context).copyWith(extensions: [thm])`
- **Steps**:
  1. **Writes**: remove the `set…()` calls from `build`. Call each one where its value
     changes instead:
     - `setsem` in `onSemesterSelected`
     - `setsort` in `onSortSelected`
     - `setprof` in the nav `onSelected` / `onSwipe`
     - `setdis` after Settings returns with a change
     - `settheme` is already called by `switchTheme`

     Keep the function names (refactor P4.2 hooks `setdis` / `setprof`). `setnavcolor()`
     runs in `initState` and after a theme switch (O1.5), not per build.
  2. **Tallies**: leave `sgcalc` / `cgcalc` / `creditTotals` calls where they are. Refactor
     P4.3 memoises them, so after the merge they are cheap. Don't edit `script.dart`'s tally
     functions.
  3. **Theme wrapper**: cache the `ThemeData`:
     `final _themed = <String, ThemeData>{}` keyed by `thm.name`, holding
     `Theme.of(context).copyWith(extensions: [thm])`. Clear it when `themeVersion` changes.
- **Tests** (new `test/perf/home_rebuild_test.dart`): Home needs Firebase, which widget tests
  can't provide (see `test/semester/expected_copy_test.dart`'s note). So:
  - Move the "which `set…` to call for which change" decisions into a pure function in a
    new `lib/features/semester/home_persist.dart`:
    `List<HomeWrite> writesFor(HomeChange c)`. Unit-test it:
    - `semester` → `[sem]`
    - `sort` → `[sort]`
    - `profile` → `[profile]`
    - `rebuild` → `[]`
  - Grep test: `test/perf/no_writes_in_build_test.dart` reads `lib/home_page.dart` and
    asserts no `set(dis|sort|sem|prof|theme)\(\)` call appears inside the `build` method's
    text range. Find the range from `Widget build(` to the matching `}` with a small brace
    counter.

### O3.2 · Home listens to size, not every MediaQuery change
- **Files**: `home_page.dart:125-147`.
- **Steps**:
  - Replace `final mq = MediaQuery.of(context);` with
    `final size = MediaQuery.sizeOf(context);`. Keep `MediaQuery.of` only where the whole
    data is copied (`mq.copyWith(size: …, padding: …)`), and read it there as
    `MediaQuery.of(context)` **inside** the `LayoutBuilder` builder, which already rebuilds
    on constraints.
  - Result: a keyboard opening in a sheet no longer rebuilds the whole semester view.
- **Test**: none practical (Firebase). Check by reading the diff and with the device row "open
  add-course sheet and type".

### O3.3 · Theme and profile switches don't rebuild unchanged courses
- **Files**: `features/semester/semester_page.dart`, `widgets/course_row.dart`.
- **Steps**:
  - `CourseRow` gets a `const` constructor where possible and a `==`-stable `key`. Use the
    Hive key, not the course code: **refactor Phase D adds two `BITS F412` rows for dual
    degrees**, with Hive keys `BITS F412` and `BITS F412#2`. Appendix U says list keys must
    not assume unique codes.
  - Wrap each row in `RepaintBoundary`: the list is a `SliverReorderableList`, so do it in
    `itemBuilder`.
- **Test** (`test/semester/semester_test.dart`): `'rows are keyed by Hive key, not code'`. Two
  courses with the same `id` and different keys render two rows, and reorder moves the right
  one.

### O3.4 · The profile switch: same fade and slide, half the cost
- **Files**: `semester_page.dart:145-166`.
- **Today**: an `AnimatedSwitcher` fades and slides two full pages for 380 ms, and the new page
  builds in the first frame.
- **Steps**:
  1. Wrap the switcher's child (`KeyedSubtree`) in a `RepaintBoundary`. Each page then
     rasterises once, and `FadeTransition` / `SlideTransition` only move and fade two cached
     layers.
  2. `layoutBuilder`: pass a builder that stacks the children with
     `Stack(children: [...previous.map((w) => IgnorePointer(child: w)), current])`, so the
     outgoing page takes no hit testing.
  3. **Reduced motion**: this switcher ignores it today. That is a UI.md bug, not a speed
     one, but fix it here since the file is open: `duration: disable ? Duration.zero :
     Motion.slow`. §1.3 rule 2 says reduced motion must keep working. Log it as a fix.
- **Tests** (`semester_test.dart`):
  - `'profile switch pages are repaint boundaries'`: mid-switch, both children have a
    `RepaintBoundary` ancestor below the `AnimatedSwitcher`.
  - `'reduced motion switches profile instantly'`.

### O3.5 · The Stats slider stays smooth
- **Files**: `features/stats/stats_page.dart:112-115`,
  `features/stats/widgets/progression_view.dart:345-363`.
- **Today**: every slider tick calls `setState` on the page, which rebuilds `StatsData`
  through the `_data` getter (§1.1 #4) and **writes the plan to IndexedDB**.
- **Steps**:
  1. **Write on release**: `onPlanChanged` does `setState` only. Add `onPlanChangeEnd` from
     the `Slider`'s `onChangeEnd` that calls `setStatsPlan(_plan)`. The same pattern works for
     any other per-tick persist.
  2. **Isolate the slider cards**: wrap each future-semester card in `RepaintBoundary`. The
     chart already has one (`cgpa_chart.dart:41`).
  3. **Cache the data within a build**: in `_StatsPageState`, compute
     `final data = _data;` once at the top of `build` and pass it down, instead of calling
     the getter more than once.
  4. After refactor P4.4 and P5 (`StatsData.cached`), recomputation is memoised. Nothing to
     do here; note it in §13.
  5. `cgpa_chart.dart:223` `shouldRepaint` compares list identity only. Include the colours
     (`line`, `grid`, `label`, `surface`, `forecastLine`, `targetLine`) so a theme switch
     repaints it once, and only then.
- **Tests** (`test/stats/stats_test.dart`):
  - `'dragging the slider writes the plan once, on release'`: inject the writer through a
    constructor parameter, the same way `onPlanChanged` is injected today. Drag across 10
    divisions, then release; the writer is called once.
  - `'chart repaints on a palette change'`: `shouldRepaint` returns true when only `grid`
    differs.

### O3 acceptance
- CI green.
- Device rows: profile switch ≤ 2 frames over budget; Stats slider drag with no frame over
  33 ms.
- Commit "UI_OPT O3: rebuild less".

---

## 7 · Phase O4 · Paint less

### O4.1 · No `Opacity` widget over a subtree
Use `FadeTransition` for animated fades, and colour alpha for static ones.
- `lib/main.dart:176` (the sign-in `_entrance`): replace `AnimatedBuilder(builder: (_, c) =>
  Opacity(...Transform.translate...))` with
  `FadeTransition(opacity: curve, child: SlideTransition(position:
  Tween(begin: const Offset(0, 18 / 60), end: Offset.zero).animate(curve), child: child))`.
  Use `AnimatedBuilder` + `Transform.translate` only for the 18 px lift if `SlideTransition`'s
  fractional offset is awkward. **Keep the 1250 ms, the stagger and the 18 px.** Also stop it
  under reduced motion, where the value jumps to 1. The board's rule is that every animation
  stops under reduced motion.
- `semester/add_course_sheet.dart:650` (`Opacity(0.55)` around held search hits): give the
  card `color: p.surface.withValues(alpha: .55)` and its texts `textMuted`, or keep one
  `Opacity` but only if the list is lazy (O5). Prefer the colour version; it is identical on
  the board (a "not counted" card is `surface` at 55%, UI.md §2.1).
- `semester/widgets/semester_pills.dart:167` (`Opacity(0.4)` on a 30 px arrow): colour alpha
  on the icon and border.
- **Test** `test/perf/no_opacity_test.dart`: grep `lib/` for `Opacity(`. Allowed: none,
  unless listed in the test's allow-list with a reason.

### O4.2 · Clips only where needed
- `Material(clipBehavior: Clip.antiAlias)` on `AppCard` (`shared/widgets/app_card.dart:37`)
  clips every card. `InkWell(customBorder:)` already clips its splash.
  - Set `clipBehavior: Clip.none` on `AppCard` **unless** a child needs clipping (an image or
    a progress bar at the edge).
  - Add `final bool clip` (default false) for those few cases, and pass `clip: true` where a
    render test shows a corner bleeding.
  - The UI.md `RowGroup` (`admin/widgets.dart:26`) wraps up to about 130 rows in one
    `AppCard`, so this matters most there. With O5 it becomes lazy slivers anyway.
- `setup/programme_pick_page.dart:123` `ClipRRect` around the whole list: clip only the first
  and last rows' corners (give their `Material` a matching `borderRadius`), or keep the clip
  once O5 makes the list lazy.
- **Test**: the render tests are the check. The board corners stay rounded because the card's
  `Material` shape still paints them; only content overflow would show, and the render tests
  fail on overflow. Also add `test/perf/app_card_clip_test.dart`: `AppCard` defaults to
  `Clip.none`.

### O4.3 · Repaint boundaries where things move on their own
Wrap each of these in a `RepaintBoundary`:
- `PulsingTab` (O6.1)
- the grade scrubber overlay (`grade_scrubber.dart:56`)
- each Stats slider card (O3.5)
- the semester pill strip (`semester_pills.dart:83`), which scrolls
- the floating nav fade (`responsive.dart:111`), static over a scrolling list

**Test**: a render test pumps each and finds a `RepaintBoundary` ancestor within two levels.

### O4.4 · Shadows
- `grade_menu.dart:170` (`blurRadius: 34`, animated by scale for 120 ms): keep it (the board
  draws it). Put the menu card in a `RepaintBoundary`, so the scale animation transforms a
  cached layer instead of re-blurring.
- `PulsingTab`'s animated `BoxShadow`: see O6.1.

### O4 acceptance
CI green; render tests unchanged. Commit "UI_OPT O4: paint less".

---

## 8 · Phase O5 · Lists build lazily

**Pattern**: a list longer than a screen is a `ListView.builder`, `SliverList.builder` or
`SliverList.separated`, never a `Column` of all rows. Keep the card look (one rounded surface
with hairlines) with slivers:
- a `DecoratedSliver`, or `SliverMainAxisGroup` with a top and bottom cap
- the rows in between, drawn on `surface`
- `Divider`s via `separatorBuilder`

### O5.1 · A lazy `RowGroup`
- **Files**: `lib/admin/widgets.dart` (`RowGroup`), `lib/shared/widgets/page_header.dart`
  (`PageFrame`).
- **Steps**:
  1. `PageFrame` becomes a `CustomScrollView` whose children are wrapped in
     `SliverToBoxAdapter`, except a new `SliverRowGroup` sliver.
  2. `SliverRowGroup({required int count, required IndexedWidgetBuilder row})` renders the
     same card: radius, `surface` fill, hairlines inset 15, with
     `DecoratedSliver(decoration: BoxDecoration(color: p.surface, borderRadius: …), sliver:
     SliverList.separated(...))`.
  3. Keep `RowGroup` (a `Column`) for groups under about 12 rows. Use `SliverRowGroup` for
     the long ones:
     - DeptCourses (`admin/maintain.dart:297-326`)
     - professors (`admin/professors.dart:155-162`)
     - roster and people (`admin/people.dart:178-190`)
     - resources (`features/resources/resources_page.dart:420-460`, `admin/dept_resources.dart`)
     - volunteers, representatives
- **Tests** (`test/shared/widgets_test.dart`):
  - `'SliverRowGroup builds only visible rows'`: 200 rows in a 640-tall view; count built
    rows; it is under 20.
  - `'SliverRowGroup looks like RowGroup'`: 3 rows each, same size and a `divider` between
    them.

  The render test `m_dept_courses` must still pass.

### O5.2 · Search fields debounce and don't re-lay out everything
- **Files**:
  - `admin/maintain.dart:285` (DeptCourses search)
  - `admin/professors.dart:152`
  - `features/setup/programme_pick_page.dart:97`
  - `features/semester/add_course_sheet.dart:118-128`
- **Steps**:
  1. A shared `Debouncer` (`lib/shared/debounce.dart`: `void call(VoidCallback f)` with
     `Timer(const Duration(milliseconds: 150), f)`, disposed with the state).
  2. The `setState` for the result list runs through it. The text field updates at once
     (it's a controller).
  3. The results use O5.1's lazy list.
  4. `add_course_controller.dart` `searchCourses` stays as it is (core logic). The debounce
     alone removes most of the calls.
- **Tests**:
  - `'search waits for a pause'`: type 5 letters with 50 ms pumps between them; the results
    builder ran once after 150 ms.
  - The existing search tests pass with a `pump(const Duration(milliseconds: 200))` added
    after `enterText`. Update them and say so in the log.

### O5.3 · Fixed-height rows tell the list
- Rows that are always the same height (programme pick 52, course rows in DeptCourses 58)
  give `itemExtent:` or `prototypeItem:` to the builder. Layout then skips measuring each row.
  Only where the board fixes the height and text can't wrap (check 200% text with the render
  tests; if a row can grow, don't set an extent).

### O5 acceptance
- CI green.
- Device row "DeptCourses typing 5 letters": no frame over 33 ms.
- Commit "UI_OPT O5: lazy lists".

---

## 9 · Phase O6 · Looping animations

### O6.1 · `PulsingTab`
- **Files**: `lib/admin/dept_resources.dart:205-285`. Done together with UI.md T8.13, which
  restyles the tab.
- **Steps**:
  1. Animate only transform and opacity:
     - The pulsing ring becomes a separate `DecoratedBox` (the ring colour at full alpha)
       behind the pill.
     - Drive it with `ScaleTransition` (1 → 1.35) and `FadeTransition` (0.35 → 0).
     - The pill itself doesn't rebuild per tick.
  2. Wrap it in a `RepaintBoundary`.
  3. Pause when off-screen: wrap with `TickerMode(enabled: visible, …)`, where `visible`
     comes from the route being current (`ModalRoute.isCurrentOf(context)`). A pushed page
     over it stops the pulse.
  4. Reduced motion: the **board** says the Reported dot keeps pulsing even under reduced
     motion (UI.md §10.1.2). Today's code stops it. Follow the board and keep a **slower,
     smaller pulse** (the dot only, opacity 1 ↔ 0.4, 2400 ms). This is a UI.md decision;
     record it as a Departure resolved in favour of the board.
- **Tests**:
  - `'the pulse rebuilds nothing per tick'`: a `BuildCounter` around the pill's label
    counts 1 after 10 frames.
  - `'the pulse stops under a pushed page'`.

### O6.2 · The install nudge (UI.md T4.5) and the loading screen
- The nudge: one `AnimationController`, `Transform.scale` / `Transform.rotate` through
  `ScaleTransition` / `RotationTransition` (no `setState`), in a `RepaintBoundary`,
  `TickerMode` off when the page is covered, and off under reduced motion. UI.md T4.5
  specifies the look; this card is its speed rule.
- `web/index.html` loader: already transform/opacity CSS with a reduced-motion override.
  Nothing to do.

### O6 acceptance
CI green. Commit "UI_OPT O6: loops".

---

## 10 · Phase O7 · Web load and assets

### O7.1 · Subset the fonts (identical glyphs, a tenth of the bytes)
- **Files**: `fonts/*.ttf`, a new `tools/subset_fonts.sh`, `pubspec.yaml`.
- **Steps**:
  1. `pip install fonttools brotli` (local tooling only).
  2. List every character the app draws. Take them from the source with a script that scans
     `lib/**/*.dart` string literals, **plus** the full printable ASCII range, **plus** these:
     `· — – → ← ↑ ↓ ✓ ✕ × ÷ ≤ ≥ − … ' ' " " ₹ ° • ▾ ▸`, and Latin-1 Supplement for names
     (é, ñ…).
  3. `pyftsubset fonts/Montserrat-Regular.ttf --unicodes-file=tools/font_chars.txt
     --layout-features='*' --output-file=fonts/Montserrat-Regular.ttf` for each of the five
     weights. Keep all layout features, so kerning and ligatures don't change.
  4. The legacy `Montserrat` family in `pubspec.yaml` points at SemiBold again. Remove it only
     once nothing names `'Montserrat'` (UI.md T9.2). Until then it costs nothing extra (same
     file), so leave it.
  5. A glyph missing from the subset would fall back to a Noto font downloaded at run time,
     and look different. So add a test that fails if any string literal in `lib/` has a
     character outside `tools/font_chars.txt`.
- **Tests**:
  - `test/perf/font_chars_test.dart` (the missing-glyph guard above).
  - The render tests still pass (`loadAppFonts` reads the subset files).
- **Check**: the size of `fonts/` before and after (expect about 2.1 MB → about 250 KB).
  Compare screenshots before and after with `SHOTS_DIR`; they must be pixel-identical for
  every `s_…`, `m_…` and `d_…` render. Use a small Python PIL diff script and put it in
  `tools/`.
- **Done**: identical shots, fonts under 300 KB.

### O7.2 · `web/index.html`: stop walking the DOM on every mutation
- **Today** (`web/index.html:137-160`): after the first frame, a `MutationObserver` with
  `subtree: true` re-runs `hook(document)`, which calls `querySelectorAll('*')` and recurses
  into shadow roots on every DOM change. Flutter changes the DOM for text input and
  semantics.
- **Steps**: keep the WebGL context-loss reload; that is a real fix.
  1. Hook the canvas once: find the Flutter view's canvas under `flt-glass-pane` /
     `flutter-view` right after `flutter-first-frame`, and add the listener.
  2. Observe only **`childList` of the view's shadow root** (not `subtree: true` on `body`),
     to catch a new canvas if the engine recreates it.
  3. Disconnect the observer after it has hooked a canvas and seen no new canvas for 10 s.
- **Test**: manual in Chrome. Type in a text field with DevTools' Performance panel
  recording; the `MutationObserver` callback no longer appears per keystroke. Note the result
  in `UI_PERF_BASELINE.md`.

### O7.3 · Cache headers for static assets (Cloudflare `_headers`)
- **Files**: `landing/_headers` (or the file `deploy.yml` copies there).
- **Steps**: Flutter web file names aren't content-hashed, so don't use `immutable`. Add
  this:
  ```
  /calculator/assets/*
    Cache-Control: public, max-age=86400, stale-while-revalidate=604800
  /calculator/canvaskit/*
    Cache-Control: public, max-age=604800
  ```
  Leave `index.html`, `flutter_bootstrap.js`, `main.dart.js` and the service worker on their
  current `no-cache`, so a deploy is picked up at once.
  - **Coordinate with refactor P7** (deferred loading, bundle work). If P7 has already changed
    `_headers`, merge its lines; don't overwrite them.
- **Test**: none in Dart. After the user deploys, check the response headers with
  `curl -I` (hand the user the command).

### O7.4 · Things not to do here
- **Deferred libraries and `--wasm`**: refactor P7 owns them. Don't duplicate.
- **Changing the renderer**: there's only CanvasKit or skwasm (`--wasm`) on Flutter 3.47.
  skwasm's threading needs COOP/COEP, which would break the Google sign-in popup
  (refactor P7 says the same).

---

## 11 · Phase O8 · Safari and old iPhones

- **O8.1 · Snapshot size**: iOS Safari limits canvas memory. The theme snapshot is at most
  `pixelRatio 1.5 × screen`. On an iPhone 8 (375 × 667 @ 2×) that is about 1.1 M pixels, which
  is safe. Keep the `min(dpr, 1.5)` cap, and on iOS use 1.0 regardless of tier:
  `installTarget().device == InstallDevice.ios` from `lib/core/platform/browser.dart`.
- **O8.2 · Context loss**: `web/index.html`'s reload-on-context-loss (O7.2) also covers Safari's
  `webglcontextlost`. Verify on iOS 15 by backgrounding the app for 5 minutes and returning.
- **O8.3 · Momentum scrolling and fixed layers**: Safari repaints fixed layers during momentum
  scroll. The floating nav fade (`responsive.dart:111`) gets a `RepaintBoundary` (O4.3), which
  keeps the gradient in its own layer.
- **O8.4 · Device check**: run the §3 O0.4 rows on an iPhone 7/8 (iOS 15–16), or on the closest
  device the user has, and record them. If only a newer iPhone is available, use Safari's
  Timelines with "CPU throttling" where it exists, and say so in the baseline file.

---

## 12 · Per-screen checklist (add to every UI.md card's "Done")

When building or restyling any screen from UI.md, check all of these:
1. **No `Opacity` widget** over a subtree. Fades are `FadeTransition`; static alpha is a colour.
2. **Lists longer than a screen are lazy** (`ListView.builder` / slivers / `SliverRowGroup`).
3. **Anything that animates or repaints by itself sits in a `RepaintBoundary`**: charts,
   sliders, pulsing badges, nudges, scrubbers.
4. **No work in `build`** that isn't layout: no storage writes, no network, no sorting a whole
   box, no `jsonEncode`. Compute once per change, in the handler or a memo.
5. **`MediaQuery.sizeOf` / `paddingOf` / `textScalerOf`**, not `MediaQuery.of`, unless the
   whole `MediaQueryData` is copied.
6. **Search fields debounce** (O5.2).
7. **Keys for list rows are stable and unique**: the Hive key, not the course code (Appendix U,
   PS II rows).
8. **Every animation stops or slows under reduced motion**, except what the board explicitly
   keeps.
9. **Its render test passes** (`test/ui/*_screens_test.dart`), and one device row is recorded
   when the screen animates.

---

## 13 · Merging with `pointer-refactor` (PERF_TEST_PLAN.md, Appendix U)

- **Who owns what**:
  - refactor owns data speed: startup, stores, caches, the tallies, `StatsData.cached`,
    deferred loading and wasm
  - UI_OPT owns frames: animations, rebuild scope, paint, lists and fonts

  They meet in these files:

  | File | UI_OPT touches | refactor touches | Merge rule |
  |---|---|---|---|
  | `lib/main.dart` | `SignInApp` / `MyApp` build: `themeAnimationDuration`, `_entrance` | `startApp()` (P3) | Different functions; take both |
  | `lib/script.dart` | `switchTheme` | tally memo (P4.3), `setdis` / `setprof` bump (P4.2) | Different functions; take both |
  | `lib/home_page.dart` | build writes moved to handlers (O3.1), sizeOf (O3.2) | none before P5; P5 may touch loaders | Keep UI_OPT's handler calls; refactor's `setdis` / `setprof` bumps still fire from the handlers |
  | `lib/features/stats/stats_page.dart` | `onChangeEnd` persist, one `_data` read (O3.5) | P5 one-line `StatsData.from` → `.cached` | Apply P5's swap inside the one `_data` read |
  | `lib/features/calendar/calendar_page.dart` | nothing | P4.1 `hasUnsynced` flag | — |
  | `landing/_headers` | O7.3 cache lines | maybe P7 | Merge lines |
- **Appendix U's visible changes and their performance notes**:
  - **Secretary rows / tags, grant choices, succession field**: new rows in existing lists.
    If they land after O5, they're lazy for free. The rows follow the §12 checklist.
  - **PS II twice (`BITS F412`, `BITS F412#2`)**: rows are keyed by the Hive key (O3.3). The
    `/course/:id` route opens the first; that's refactor's open question, not a speed one.
  - **Single M.Sc. loses ST 2 / 5-1 / 5-2**: fewer pills; nothing to do.
  - **More pages open from cache**: fewer spinners, so the push animation (O2) plays over a
    built page. That's better. Nothing to do.
  - **"The app may reload itself once" at start**: happens before the UI is interactive;
    nothing to do.
- **Order**: if refactor's P5.0 merge runs before UI_OPT O3, do O3.5 on top of the merged
  `StatsData.cached`. The steps don't change.

---

## 14 · Definition of done (whole guide)

1. **All phases O0–O8 committed**, each with its tests. `flutter analyze` at the baseline;
   `flutter test` green, including `test/ui/*_screens_test.dart`, which must pass with
   **pixel-identical** screenshots before and after O1–O7. Use the O7.1 diff script on every
   `SHOTS_DIR` render.
2. **`UI_PERF_BASELINE.md`** has before and after rows for every §3 O0.4 scenario, at 6× CPU
   on Chrome and on one old iPhone. Targets met:
   - theme switch: tap → first circle frame ≤ 100 ms, ≤ 2 frames over budget, none over
     50 ms
   - page push / pop and profile switch: ≤ 2 frames over budget
   - Stats slider and DeptCourses typing: no frame over 33 ms
   - fonts under 300 KB
3. **The same UI**: the user compares the deployed build with the boards and sees no
   difference, with the circle reveal on every device.
4. **UI.md**: §11 points here for the order, every UI.md card's Done includes the §12
   checklist, and §13 has a line per UI_OPT phase built.
