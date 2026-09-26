# Pointer — implementation plan

Hand this to Claude Code from the repo root:
*"Read PLAN.md and execute it phase by phase. Stop after each phase's verification and show me the result."*

Design reference (all screens, with notes):
<https://claude.ai/artifact/K4H9w2Ad9cwdTqxPSAiWMW>

---

## 1. Where the project actually is

Verified, not assumed. `master` @ `af47351`, working tree clean.

**Already built, deployed and working:**

| | |
|---|---|
| Hosting | <https://cgpa-calculator-bits-goa.netlify.app> (Netlify free, no card on file) |
| Auto-deploy | GitHub Actions on push to `master` → `netlify deploy --prod` |
| Auth | Google sign-in, restricted to BITS campus domains, client **and** rules |
| Sync | Hive (local) ⇄ Firestore `users/{uid}`, debounced 1.5s, `rev` optimistic concurrency |
| Firebase | project `cgpa-calculator-fb90c`, Spark plan |
| Features | offshoot panel (47/50 verified), RC/W grades, CSV export, JSON import, in-app bug reports → `reports` collection |
| Analytics | degree-requirement audit (`analytics.dart`, 924 lines) — **existing, must be preserved** |

**Toolchain** (none on the default PATH — see `~/.claude/projects/.../memory/`):

- Flutter 3.47.5 / Dart 3.13.4 → `~/development/flutter/bin`
- `firebase`, `netlify`, `gh` → `~/.local/bin`
- `flutterfire` → `~/.pub-cache/bin`
- node comes from **nvm, initialised in `.bashrc` only** — the PATH export is now in `.zshrc`

---

## 2. Gotchas that will bite

Each of these cost time this session. Do not rediscover them.

### 2.1 The CGPA rule is not the obvious one
`cgcalc()` in `script.dart` filters courses by discipline (`selecteddiscipline` 0–2 and 2–4), and for GD grades **adds the credits to `s1` then subtracts them via `dontCount`**, so the denominator is `s1 - dontCount`. A naive `sum/credits` gives 7.563 where the app shows 7.71 on the same data.

**Any new feature that shows a CGPA must call the same function.** Stats will silently disagree with the home screen otherwise.

### 2.2 `main_ui_extension.dart` is the only CRLF file
1,667 lines, all CRLF. Any tool that rewrites it as LF produces a 1,667-line phantom diff. Read and write it with `newline=''` preserved, and check `git diff --stat` after touching it.

### 2.3 Sync JSON-encodes `settingsBox`
`Sync.snapshot()` runs `jsonEncode` over every box value. A raw `DateTime` **throws**, and the throw is swallowed by `push()`'s `catch` — so the first sync after a date is entered fails *silently*. Store dates as ISO-8601 strings or epoch ints.

### 2.4 New Hive boxes must be registered in three places
`Sync._boxes`, `Sync.openBoxes()`, and `Sync._box()`. Miss one and the box is never synced — also silently.

### 2.5 Firestore caps the snapshot at 500 KB
`firestore.rules` enforces `data.size() < 500000`. Marks data is unbounded per course. Either keep evaluatives lean or split them into a second document before this becomes a problem.

### 2.6 `addCourse()` uses `box.add()` → **int** keys
Other code writes with `box.put(course.id, …)` → **String** keys. Updating a course by re-keying duplicates it. Always write back under the key you read. (Already fixed in `copyGrades`; check any new write path.)

### 2.7 `BottomNavigationBar` silently changes mode at 4+ items
Defaults to `shifting`, which ignores `backgroundColor` and hides unselected labels. Must set `type: BottomNavigationBarType.fixed`. Already fixed — do not regress it when the nav is rebuilt.

### 2.8 Firestore `matches()` is case-sensitive
The BITS domain regex in the rules needs the `(?i)` prefix. Without it an uppercase email signs in fine and then has **every sync denied**.

### 2.9 Verification environment
- **No Chrome on this machine** — `flutter run -d chrome` does not work. Use `flutter build web --release` + `python3 -m http.server 5000 --directory build/web`, then the browser pane.
- **The browser pane cannot emulate viewports for this app** — the Flutter canvas does not repaint at the emulated size. The pane's real width (~320px) is a usable narrow-phone proxy; anything else needs a real device.

### 2.10 The course map has duplicate ids and alias titles — **never delete a row**
Old courses stay in the map. Students on older batches need them to reproduce past
semesters, and deleting a row silently changes the CGPA of anyone holding a grade
against it. Every fix below is display-layer, not data removal.

**Nine codes carry more than one title** — the same course spelled differently across
disciplines. Collapse these to a single entry showing both names joined by ` / `,
keeping every row in the map:

| Code | Titles to join |
|---|---|
| `BITS F101` | Navigating Campus Life and Living Well / Social Conduct |
| `BITS F113` | Gen Maths 1 / General Mathematics I |
| `BITS F221` | PS 1 / Practice School I / Practice School-1 / Practice SchoolI |
| `BITS F225` | Environmental Science / Environmental Studies |
| `BITS K101` | Physical Fitness, Health Wellbeing and Creativity / Physical Well-being and Creativity |
| `PHA F214` | Anatomy Physio and Hygiene / Anatomy, Physiology, & Hygiene |
| `PHA F216` | Pharmaceutical Formulations 1 / Pharmaceutical Formulations I |
| `PHY F111` | Mechanical Oscillations and Waves / Mechanics, Oscillations and Waves |

⚠ **`MF F221` is not an alias.** It carries *Casting, Forming and Welding* and
*Mechanisms and Machines* — two genuinely different courses sharing one code. Joining
them with ` / ` would be wrong. This is a data error in the source list and needs the
correct code looked up before it is touched; leave both rows alone until then.

**32 rows use a lowercase `l` for the digit `1`** — `BITS F10l` (×16) and `BITS K10l`
(×16), duplicating `BITS F101` and `BITS K101` inside the same discipline. Normalise
`l` → `1` when matching and count the pair as one course. Do not rewrite or delete the
rows: a user's stored grade is keyed on the id as written.

---

## 3. Target architecture

The reason for the restructure: `script.dart` is 1,215 lines mixing globals, grading maths, Hive access, CSV and download helpers; `main_ui_extension.dart` (1,667) and `overlays_extension.dart` (2,047) are `part of home_page.dart`, so all UI is extension methods on one State class. Adding Stats, Marks and Calendar on top of that will not hold.

```
lib/
  main.dart                     bootstrap only — Firebase, Hive, auth gate
  app/
    app.dart                    MaterialApp, routes, theme wiring
    theme/
      tokens.dart               spacing, radii, type scale, durations
      palette.dart              light + dark + the existing named themes
      theme_controller.dart     mode switch, persisted
  core/
    models/                     Course, Evaluative, EvalPart, CourseConfig
    storage/
      boxes.dart                box names + open/clear in ONE place
      sync.dart                 (existing, extended)
    grading/
      grade_scale.dart          gradecalc / reversegradecalc / RC / W
      cgpa.dart                 SGPA + CGPA — THE single source of truth (§2.1)
      offshoot.dart             (existing offshoot_calc.dart, moved)
      marks.dart                evaluative totals, best-n-of-m, scaling
      forecast.dart             target maths
      requirements.dart         degree audit — CDC / DEl / HuEl / OpEl progress
  features/
    semester/  offshoot/  stats/  marks/  calendar/  analytics/  settings/
      each: <name>_page.dart + widgets/ + <name>_controller.dart
  shared/
    widgets/                    AppCard, GradeChip, StatCard, PillButton, AppNav
    layout/
      breakpoints.dart          720 / 1100
      responsive.dart           ResponsiveScaffold
```

**Rules that keep it modular:**

1. **Features never compute grades.** They call `core/grading`. One CGPA implementation, one grade scale.
2. **Features never touch Hive directly.** They go through `core/storage`.
3. **No new `part of`.** Each screen is its own widget file with its own State.
4. **Retire the globals.** `script.dart` has ~26 mutable globals (`selectedprofile`, `currentsem`, `thm`, `batch`…). `provider` is already in `pubspec.yaml` and **never imported** — use it. Migrate globals per-phase as each screen is touched; do not attempt a big-bang rewrite.
5. **Style lives in `shared/widgets`.** A card radius changes in one file, not forty.

---

## 4. New data models

`Course` is Hive `typeId: 0` and is the **only** adapter registered. New types need new ids and `registerAdapter` calls in `main.dart`.

```dart
@HiveType(typeId: 1)
class Evaluative {
  @HiveField(0) String courseId;     // "CS F372"
  @HiveField(1) String name;         // "Kernel Assignments"
  @HiveField(2) double weight;       // 20 → percent, or raw marks in total-marks mode
  @HiveField(3) List<EvalPart> parts; // 1 entry = a single-mark evaluative
  @HiveField(4) int countBest;       // 0 = all, else N of parts.length
}

@HiveType(typeId: 2)
class EvalPart {
  @HiveField(0) String name;         // "CPU Scheduling", or "" for single
  @HiveField(1) double? marks;       // null = not graded yet
  @HiveField(2) double outOf;
  @HiveField(3) String? date;        // ISO-8601 STRING, never DateTime (§2.3)
}

@HiveType(typeId: 3)
class CourseConfig {
  @HiveField(0) String courseId;
  @HiveField(1) bool weighted;       // true = % per component, false = total marks
  @HiveField(2) double courseTotal;  // e.g. 300
  @HiveField(3) double displayOutOf; // e.g. 100
  @HiveField(4) double? classAverage; // null = no comparison shown
}
```

**Class average** is entered per course and must be **for the same components the
user has entered**, not the whole course — comparing a part-graded total against a
full-course average is meaningless. Store it on the same scale as the running total,
so the delta is a subtraction. Null means the comparison is simply absent; never
invent or infer one.

**Scaling must derive from the parts.** For a group: sum the counted parts' `marks` over the counted parts' `outOf`, then multiply by `weight`. Never a hardcoded divisor — that is the bug in the source spreadsheet (`=4*H8/20`), which breaks the moment a part's maximum changes.

**Best-n-of-m:** sort counted-eligible parts by `marks/outOf` descending, take `countBest`. Parts with `marks == null` are never counted. Keep dropped parts visible in the UI.

---

## 5. Phases

Stop after each. Every phase ends green: `flutter analyze` with **0 errors** and `flutter build web --release` succeeding.

### Phase 0 — Baseline
Branch off `master`. Record `flutter analyze` output (currently 0 errors, ~111 issues, 3 pre-existing warnings) so new noise is visible. Delete `test/widget_test.dart` — it is the default counter test asserting `find.text('0')` against `MyApp`, and has never passed.

### Phase 1 — Foundation, no visible change
`app/theme/tokens.dart`, `palette.dart`, `shared/layout/breakpoints.dart`, `shared/widgets/*`. Wire the existing themes into the new palette. Nothing else moves.
Include **motion tokens** in `tokens.dart` — `fast` 120ms, `base` 220ms, `slow` 380ms, plus a standard curve.
The current code hard-codes `Duration(milliseconds: 500)` in eight places; every new animation uses a token,
and the existing eight are migrated as their screens are rebuilt in later phases.
**Verify:** app renders identically. This phase should produce no UI diff.

### Phase 2 — Extract grading core ⚠ highest risk
Move `gradecalc`, `reversegradecalc`, `sgcalc`, `cgcalc` into `core/grading/`, preserving §2.1 exactly. Add unit tests using the real numbers:

```
SGPA by semester: 8.76, 8.11, 7.67, 7.68, 7.83, 7.68, 7.28, 7.44, 9.17
CGPA after 4-1:   7.71  (158 credits shown, 155 denominator, 1195 points)
```

**Verify:** tests pass **and** the running app shows 9.17 / 7.71 unchanged. If these numbers move, stop.

### Phase 3 — Shell
`ResponsiveScaffold`, `SafeArea` everywhere, the nav: pill < 1100, left rail ≥ 1100, `type: fixed` (§2.7).
**Verify:** at ~320px and at desktop width, no overflow, all four labels legible.

### Phase 4 — Semester screen
Rebuild from `main_ui_extension.dart` into `features/semester/`. Greeting, editorial line, stat cards, semester pills, sort + export, course rows with `Expanded` + `min-width: 0` + ellipsis.
**Verify:** long titles ellipsize instead of pushing the grade chip off screen.

**Two tap targets per course row.** The row opens Marks; the grade chip opens a grade
menu and must **not** also open Marks. A nested target inside a tappable row fires both
handlers unless the inner one stops the event — the chip needs its own `GestureDetector`
with `behavior: HitTestBehavior.opaque` above the row's `InkWell`. The chip draws at
46×34 and its tap target must still reach 44px once padding is counted.

The menu splits the scale deliberately: the eight graded values, then `NC` / `RC` / `W` /
`GD`, which do not behave like grades — RC and W drop the credits from the CGPA entirely,
GD keeps the credits but not the points (§2.1). The current dropdown hides that, and it
is exactly where a wrong tap costs someone a believable CGPA, so the menu states it.
Thirteenth option is "Not graded yet".

**Add a course** — board `AddCourse`. The current sheet offers a department-code
dropdown, a course-number dropdown *and* a search box: two ways in, neither explained,
and the title field clips mid-word with no ellipsis. Search becomes the only primary
path, over code or name; each result shows code, credits and category, and a course
already held in another semester says so rather than being silently addable twice.
Selecting one expands it — category stays editable (the same course counts differently
per discipline), and the grade is the pill row above, not a dropdown. The manual path
survives as a link for courses outside the master list. The submit button states the
consequence: *Add to 4 − 1 · SGPA 9.17 → 9.22*.
**Verify:** a 60-character course title ellipsizes in the result row, the selected card
and the course row, at 320px.

### Phase 5 — Offshoot restyle
`offshoot_calc.dart` → `core/grading/offshoot.dart`, panel into `features/offshoot/`. Logic already correct; this is presentation only.
**Verify:** still 47/50 and 54/60.

### Phase 5b — Analytics / degree audit *(preserve, then restyle)*
`analytics.dart` is an existing, working feature and **must not be dropped in the rewrite**.
It answers "how much of my degree is done": credits and course counts per elective
category — CDC1, CDC2, Disciplinary Elective 1/2, Humanity Elective, Open Elective —
against the requirement for the selected discipline.

- Move the `creditsforcourses` table (discipline → `[cdcCourses, cdcCredits, delCourses, delCredits]`)
  into `core/grading/requirements.dart` as reference data. It is currently a local
  variable inside a State class, and the same table is duplicated in the offshoot code.
- `creds(tag, courses)` uses the same counting rule as CGPA — `grade1 > 0 || grade1 == -3`
  — so it belongs beside `cgpa.dart`, not copied again (§2.1).
- It reads `grade1` only (the Actual profile). Keep that; do not silently make it follow
  `selectedprofile`.
- The elective tags are a shared vocabulary across analytics, offshoot and the master
  course list. Put them in one enum or constant set rather than string literals in three files.
- Entry point is currently a nav button in `main_ui_extension.dart` pushing a full page.
  **In the new UI it is not a separate page** — it becomes the second view of Stats
  (Phase 6), behind a `Progression | Degree` segmented switch at the top of that screen.
  So in this phase move the *logic* only and keep the old page reachable; the view is
  rebuilt under `features/stats/` in Phase 6 and the old page is deleted there.

**Verify:** for discipline `B3A7`, category totals and the "x / y" requirement counts match
the current app exactly, before any restyling.

### Phase 6 — Stats *(new)*
`core/grading/forecast.dart` — required average is exact, not a fitted curve:

```
required = (target × (doneCredits + futureCredits) − earnedPoints) / futureCredits
```

For target 8.00: **8.66 across the remaining 68 credits.** Chart, target line, per-semester sliders persisted to `settingsBox` (JSON-safe values only, §2.3).

Stats has **two views** behind one segmented switch:
- **Progression** — the chart, forecast and required-average card described above.
- **Degree** — the Phase 5b audit: overall credits earned / required with a progress bar,
  then one card per requirement category (earned / required credits, course counts, a bar,
  a check when complete, dashed outline when not started).

The switch is the only navigation between them; `analytics.dart` and its nav button are deleted
once Degree renders the same numbers.
**Verify:** the chart's last actual point equals the home screen's CGPA exactly.

### Phase 7 — Marks *(new, largest)*
Models (§4), `marksBox` registered in all three places (§2.4), `core/grading/marks.dart`, then the three screens: Marks, Add evaluative, Course setup.
Also the **class average**: an optional field in Course setup, the delta surfaced on the
Marks total card, and a compact `▲ 12.5 ahead` / `▼ 4.2 behind` on every course row on
the semester screen. Arrow plus word carry the meaning — colour alone must not, and the
green/orange pair is chosen over red/green for colour-blind readers.

**Verify:** reproduce the source spreadsheet — Assignment 0 = 6.00, Kernel best 2/3 = 14.00, Eval Labs best 3/4 = 2.76, In-Lab Quiz best 4/6 = 2.60, total 11.36 / 45. A course with no class average entered shows no delta anywhere.

### Phase 8 — Calendar *(new)*
Dates read from `EvalPart.date` — no separate store, nothing entered twice. Month grid + agenda. Add the offline status strip (offline already works; this only surfaces it).
**Verify:** a date entered in Marks appears in the Calendar without a second entry.

### Phase 9 — Rename + branding
`Pointer` in `pubspec.yaml` description, `web/index.html` title and meta, `manifest.json`, sign-in, landing. Tassel logo (concept 04) → regenerate all five icon sizes from the source, maskable at 60% for the circular crop.

**The loading screen goes in this phase too.** `web/index.html` currently ships a blue
card reading "Loading CGPA Calculator, Please Wait..." that looks nothing like the app
it is loading. Replace it with the `Loading` artboard on the canvas — that board is the
real markup, not a picture of one.

It is the only screen in the design that is **not Flutter**: it paints before the engine
boots, so it must stay pure CSS. No JS, no framework, nothing that waits on the bundle.
The animation is the logo itself — the cap floats, the tassel bead swings off its cord,
a sweep runs the bar — all compositor-only transforms, because the people who see this
screen are the ones on a slow connection.

Four things not to lose:
- **The SEO fallback text stays in the DOM.** The old block doubles as crawlable content
  and the site ranks on it. Keep the `h1` and the description; they move to a quiet
  footer, they do not get deleted.
- **`prefers-reduced-motion`** stops all three animations and leaves the bar filled and static.
- **Fade, don't snap.** The current handler sets `display: none` on `flutter-first-frame`.
  Use a short opacity transition instead, or the handoff to the app visibly jumps.
- **Montserrat needs `preconnect` + `display=swap`**, or the font blocks first paint and
  the loading screen is itself slow to load.

Also stale in `index.html` and worth fixing in the same pass: `author`, `publisher` and
the `og:site_name` / schema.org `author` still say Srijen Raja, and
`apple-mobile-web-app-title` is `cgpa_calculator`.

⚠ **If the Netlify subdomain changes, the Firebase authorized domain must change with it, or sign-in breaks on the new URL.** Update both in the same sitting.

### Phase 10 — Responsive + accessibility sweep
Replace all **62** `MediaQuery.size.height × n` / `width × n` call sites with fixed or intrinsic heights and flexible widths. Then **remove `TextScaler.noScaling`** from `MyApp` — it currently overrides the reader's font-size setting, which costs accessibility and hides exactly the layout bugs this phase is fixing.
**Verify:** 320 / 768 / desktop with no overflow, and the layout survives 200% text scale.

### Phase 11 — Ship
Rules redeploy if touched, full build, deploy, and the acceptance list below.

---

## 6. Acceptance

- [ ] Two BITS accounts see only their own data
- [ ] A non-BITS Google account is rejected at sign-in **and** by the rules
- [ ] Edit on device A → reload device B shows it
- [ ] Airplane mode: app loads, edits work, sync resumes on reconnect
- [ ] CGPA identical on home screen and Stats
- [ ] Marks reproduces the source spreadsheet exactly (Phase 7)
- [ ] A date entered once appears in Calendar
- [ ] Class-average delta matches `yours − average`, and is absent when unset
- [ ] Degree audit shows the same category credits and counts as the current app, as the Degree view of Stats
- [ ] No overflow at 320px, tablet, desktop, or at 200% text
- [ ] Icons correct on iOS home screen, Android launcher, browser tab
- [ ] Firestore usage well inside the free tier

---

## 7. Deliberately out of scope

- **Encryption.** Decided against: rules already isolate users, and the only meaningful further step is a user passphrase, which means unrecoverable data on loss. Not worth it for a student tool.
- **Live sync listeners.** Remote changes appear on reload. Settings globals are read once at startup, so a listener would need the state migration (§3.4) finished first.
- **Native platforms.** Web only. Do not re-add `android/` or `ios/`.
