# UI handoff: build the boards as drawn

For the agent taking over the UI of **Pointer** (a BITS CGPA calculator, Flutter web). The data
layer, rules, routes and the logic behind every screen are built and tested (ARCHITECTURE.md §9
steps 2–11). **The screens do not yet match the design boards.** Your job is to make every screen
look and behave like its board, and stay fast on old phones and laptops. You decide how to build
each screen. This file tells you how to set up, where the truth lives, and what you must not
break.

---

## 1. Where the truth lives

| What | Where | Rule |
|---|---|---|
| **The design** | Artifact `https://claude.ai/artifact/K4H9w2Ad9cwdTqxPSAiWMW` ("UI Directions", a Design artifact) | The boards are the UI. When code and board disagree, the board wins, unless ARCHITECTURE.md §16 records a decision against it |
| **The plan** | `ARCHITECTURE.md` | The only plan. **Never read or edit `PLAN.md`**, which is retired |
| Board → route map | ARCHITECTURE.md **§16.1** | Every board has a route or is a sheet or dialog on one |
| Decisions the boards imply | ARCHITECTURE.md §13, §16.2–16.4 | e.g. write and edit are one screen; `Responsive` and `Logo` are references, not screens |
| Per-screen checks | ARCHITECTURE.md **§15** "Checks that apply to every screen" | 320 px, 200 % text, safe areas, 44 px targets, light and dark |
| Gotchas | ARCHITECTURE.md **§14** | Read all of it before touching legacy files |

### Reading the canvas

Use the **Artifact tool** (`action: "read"`). Never WebFetch or curl a claude.ai link.

1. Read `SKILL.md` of the artifact first: it explains the `.dc.html` board format.
2. Read `project/canvas.json`. It holds the board positions, the rows and flows, and the **notes
   beside each board**. The notes are part of the spec.
3. Read the boards one by one, e.g. `path: "project/Main.dc.html"`. There are about 64 boards
   under `project/`. Each is self-contained HTML/CSS at phone size. Take exact sizes, radii,
   colours, copy and spacing from it.
4. `project/Responsive.dc.html` defines the breakpoints. `project/DarkMain.dc.html` and
   `project/DarkOffshoot.dc.html` define dark mode. `project/Logo.dc.html` defines the mark.

Only edit the canvas if the user asks. If you do, read it first and republish to the same URL.

### Boards changed last (27 Sep 2026)

- `Roster`: staff phone beside each appointment, or "No phone yet".
- `ReviewEdit`: **no Delete**. Reviews are edit-only, and the rules refuse deletes.
- `ReviewsSearchProfessor` (new): search finds professors too.
- `ProfessorReviews` (new): a professor's page, listing every course they taught, including ones
  with no reviews.

---

## 2. Setting up

The machine is Linux with zsh. **There is no Chrome binary**, so `flutter run -d chrome` does
not work.

```bash
cd /home/eiotapi/Documents/CGPA_WEB
export PATH="$HOME/development/flutter/bin:$HOME/.local/bin:$PATH"   # Flutter 3.47.5, firebase CLI
source ~/.nvm/nvm.sh                                                  # nvm lives only in .bashrc; Node 22 default

flutter pub get
flutter analyze            # baseline: 7 existing "info" lines, nothing else
flutter test               # baseline: 341 passed, 36 skipped
(cd test/rules && npm test) # Firestore rules on the emulator; baseline 58/58
```

To see the app, build it and serve it the way production does. The site root is `landing/`,
with the app under `/calculator/`:

```bash
flutter build web --release --base-href /calculator/
S=/tmp/pointer-site; rm -rf $S; mkdir -p $S
cp -r landing/. $S/; cp -r web/icons web/favicon.png $S/
cp -r build/web $S/calculator; cp build/web/flutter_service_worker.js $S/
python3 -m http.server 8090 --directory $S     # the app is at http://localhost:8090/calculator/
```

`http.server` has no SPA fallback, so deep links 404 on reload. Open `/calculator/` and navigate
in the app, or write a tiny server that serves `calculator/index.html` for unknown
`/calculator/*` paths. **Sign-in does not work on localhost**: the auth domain is the production
site. For signed-in screens, rely on widget tests (§5) or ask the user to check on the deployed
site.

Firebase project: `cgpa-calculator-fb90c`. Hosting is Cloudflare Pages (`pointer-bits-pilani`),
deployed by `.github/workflows/deploy.yml` on push to `master`. Work on branch
`pointer-rebuild`.

---

## 3. The code you build on

```
lib/app/theme/palette.dart     AppPalette.of(context): every colour, light and dark. Never hard-code a colour
lib/app/theme/tokens.dart      Space, Radii, Sizes, Motion, TypeScale (family MontserratFull). Every gap and size comes from here
lib/shared/layout/             Breakpoints: compact < 720 ≤ medium < 1100 ≤ expanded; maxContentWidth 1180; context.windowSize
lib/shared/widgets/            AppCard, AppNav (bottom pill / left rail), PageHeader, PillButton, AppTextField, StatCard, GradeChip…
lib/admin/widgets.dart         PageFrame, RowGroup, NavRow, SectionLabel, ChoicePills, Note, Loaded<T>: the shared screen scaffolding
lib/app/router.dart, routes.dart   go_router. Routes.* builds every path. Admin screens are ONE deferred library (lib/admin/admin.dart)
lib/features/<area>/           student screens (semester, marks, stats, calendar, settings, reviews, resources, more, roles, setup, import…)
lib/admin/                     owner, admin, president and CR screens
lib/core/                      models, stores and logic. Do not change behaviour here for a UI task
```

- **Match the boards by restyling or rewriting widgets under `lib/features`, `lib/admin` and
  `lib/shared`.** Keep the stores, the route paths and the `Routes.*` helpers as they are. Tests
  and `landing/_redirects` depend on them.
- If the tokens do not match the boards, fix the tokens (palette.dart, tokens.dart) once, rather
  than patching each screen.
- Legacy files (`lib/course.dart`, `lib/mastercourselist.dart`, `lib/script.dart`, `sync.dart`,
  `home_page.dart`, anything CRLF) are unformatted. **Run `dart format` only on files you create
  or files already formatted at HEAD.** Formatting `lib/` wholesale rewrites thousands of lines.
- A new top-level route segment needs its own line in `landing/_redirects`. Never
  `/calculator/*`. A test enforces this.
- `BottomNavigationBar` changes mode at 4+ items (§14.7). The bar has five items, More included,
  each at least 50×50 at 390 px wide (test S13).
- Dart 3.7: **don't use null-aware element syntax** (`?x` inside collection literals).

---

## 4. Responsive, and fast on old machines

The user asked for this explicitly: it must run properly on **older phones and laptops**
(old iPhones, low-end Android, 4 GB laptops with integrated graphics).

**Layout**
- Three sizes, from `Breakpoints`. Compact: one column with the bottom pill nav. Medium: stat
  cards move to a right rail. Expanded: the pill becomes a left rail, and the body is capped at
  `maxContentWidth` and centred. Follow `Responsive.dc.html`.
- Heights are fixed, never a fraction of the screen. Widths flex. Use `Wrap` or flexing pill
  rows instead of fixed-width rows.
- Each check in §15 must pass: no overflow at 320 px wide or at 200 % text scale, a 60-character
  title wraps or ellipsizes, every target is at least 44 px, safe areas are cleared, and the last
  item clears any floating bar (§16.4).
- Don't set `TextScaler.noScaling`.

**Performance**
- The web build uses the default CanvasKit renderer. `web/index.html` reloads on WebGL context
  loss (the Android black-screen fix, §15). Keep that code.
- No `BackdropFilter` or blur. There are none today, so don't introduce any. The boards'
  frosted looks become flat translucent fills. Avoid `saveLayer` triggers: `Opacity` over large
  subtrees (use `FadeTransition` or colour alpha instead), big `ShaderMask`s, and clips with
  anti-aliasing on large areas.
- Keep shadows small and few. At most one elevation level per card, and none on list rows.
- Lists longer than a screen use `ListView.builder` or slivers, not a `Column` inside
  `SingleChildScrollView`. Put a `RepaintBoundary` around charts (`cgpa_chart.dart`) and
  anything animating.
- Animations use `Motion.*` durations, only on user action, never looping. Respect
  `MediaQuery.disableAnimations`, which is reduced motion.
- Mark widgets `const` wherever possible. Don't rebuild the whole page from a `setState` meant
  for one field.
- Keep the admin library deferred, and don't import `lib/admin/**` from student code.
- Fonts: Montserrat only, and only the weights in `pubspec.yaml`. No new font families, icon
  packs or image assets unless a board needs them. Use SVG or `CustomPaint` for the logo.
- Before calling a screen done, profile it in `flutter build web --profile` with the DevTools
  performance overlay. Scroll and open sheets while throttled (Chrome DevTools, 4× CPU slowdown).
  Frames should stay under 16 ms.

---

## 5. Testing: how to check a screen is done

- **Widget tests** run on `FakeFirebaseFirestore` with the global `roleStore` set. See
  `test/reviews/reviews_screens_test.dart` and `test/roles/step11_screens_test.dart` for the
  harness. Use a tall test view (800×2400) when a list must be fully built. Mock the clipboard via
  `SystemChannels.platform`.
- **No UI-triggered Hive writes in widget tests.** They stall under fake time. Leave
  `settingsBox`/`reviewsBox` closed, unit-test storage separately, and keep UI tests in memory.
- Test at 320, 390, 800 and 1280 px wide, at text scale 1.0 and 2.0, in light and dark.
  Golden tests are optional.
- The existing tests encode behaviour: which copy shows, which button is disabled, what gets
  written. **A restyle must keep them passing.** If a board's copy differs from a test's
  expectation, the board wins. Change the test in the same commit, and say so in the commit
  message.
- If the user wants tests registered before you write them, follow the model of
  `test/PREREGISTERED_10_11.md`: write the expectations first, then run them. A failure is fixed
  in the app, never by editing the expectation silently.

---

## 6. Working rules (from the user)

- **The repo is public.** Never commit `test/fixtures/transcript.csv`,
  `test/fixtures/performance_sheet.json`, or any `*.pdf`. Stage specific files only. Leave the
  untracked files (`idthp`, screenshots) and the `PLAN.md` modification alone.
- **The user runs push, merge and deploy.** Commit locally, then hand over the commands as `!`
  lines. Never ask for the Cloudflare token.
- Keep messages short: brief reports and targeted reads.
- After each screen or group: `flutter analyze`, `flutter test`, a local commit, and a
  one-line "*Built:*" note under the board's row in ARCHITECTURE.md if it helps.
- The user's email is for identification only. Keep it out of docs and code.
- Commit trailers:
  ```
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  ```

---

## 7. Suggested order (you may change it)

1. Tokens and shared widgets against `Main`, `DarkMain` and `Responsive`: palette, type,
   radii, the nav pill and rail, cards, pills. Most screens inherit from these.
2. The student core: `Main`/`Offshoot` and their dark versions, `AddCourse`, `AddManual`,
   `GradeMenu`, `Marks` and its dialogs, `MarksSetup`, `MarksAdd`, `Stats`, `StatsDegree`,
   `Calendar`, `Settings`.
3. First run: `SignIn`, `Loading`, `Discipline`, `DisciplinePick`, `Import`, `OwnerSetup`.
4. `More`, `Representatives`, `Reviews*`, `ProfessorReviews`, `ReviewWrite`/`ReviewEdit`,
   `YourReviews`, `Resources`, `ResourcesEmpty`, `ReportLink`.
5. Roles: `RoleSwitch`, `RepProfile`, `RolePick`, and the rest of the admin and maintain boards.

---

## 8. Open issue, not UI

**iPhone sign-in fails with `Error 400: redirect_uri_mismatch`.** The iOS home-screen app signs
in by redirect through `https://pointer-bits-pilani.pages.dev/__/auth/handler`, and the live
site serves that page. Google rejects it because that URI is not on the OAuth client. The fix is
in the Google Cloud console, not in code (ARCHITECTURE.md §7, "Sign-in is first-party"). The user
has been told the steps. Don't change the auth code for this.
