> **Deprecated (2026-10-02):** the backend work it handed off shipped with the build-out (`deprecated/PERF_TEST_PLAN.md`). Code comments still cite its sections. Kept for history; current plans are listed in `agent_instructions/README.md`.

# UI rebuild → backend handoff

For the agent building the logic revamp on the other branch. The UI rebuild (branch
`pointer-rebuild`) changed **UI and its wiring only**: screens, shared widgets and how
screens call the stores. No store in `lib/core/**`, no model's stored shape, no
`firestore.rules` changed for the rebuild. Where a screen needs logic that does not exist
yet, it is **drawn and wired up to one clearly marked seam** and behaves safely until the
backend fills that seam in.

Read §1 before merging, §3 before writing any new logic the UI needs, and §5 before
changing a screen.

---

## 1 · Merging this branch with the logic branch

- **Conflicts to expect** are in the few places the UI builds or reads backend objects
  directly (§4.3) and in `firestore.indexes.json`. Everything else is UI-only.
- **Store method names and signatures are a contract.** §4.1 lists what each screen calls.
  If you rename or change one, update those call sites in the same commit. The screens hold
  no copies of store logic, so a changed store changes nothing else.
- **Do not reformat legacy files**: `main.dart`, `home_page.dart`, `script.dart`,
  `course.dart`, `mastercourselist.dart`, `sync.dart`, `settings_page.dart`,
  `settings_test.dart`, `circle_reveal.dart`. Edit them by hand.
- After merging, run the gates in §5.1. The render tests fail on any layout error, so a
  model change that breaks a screen shows up there, not on a device.

---

## 2 · How the new UI is built

### 2.1 Layers
| Layer | Where | What |
|---|---|---|
| Theme tokens | `lib/app/theme/palette.dart`, `tokens.dart` | `AppPalette.of(context)` colours by role (`text`, `textMuted`, `hero`/`onHero` mint, `inverse`/`onInverse` ink, `navBackground` ink card in both modes, `noticeTone` amber, `behind` red-brown, `surfaceSunken`, `outline`). `TypeScale` type, `Space` spacing, `Sizes` (44 px touch, 36 px pill). **No raw colours or font sizes outside these.** |
| Shared kit | `lib/shared/widgets/` | `PageFrame` / `PageHeader` / `BottomAction`, `AppCard`, `CardRow` + `CardDivider`, `PillButton`, `PrimaryButton`, `ChoicePills`, `SegmentedTrack`/`SegmentedPair`, `AppTextField` (`labelAbove`; `appFieldDecoration` for a raw field), `AppDialog` + `confirmDialog` (every dialog), `SearchBox`, `Notice` (amber), `DashedOutline`, `CountBadge`. |
| Manager kit | `lib/admin/widgets.dart` | `Loaded` (load → builder with reload, error card), `SectionLabel`, `Note`, `RowGroup`, `NavRow`, `ScopeChip`/`ScopePills`, `TierTag`, `NameEmail`, `SelectRow` (pill select opening a sheet), `InkCard`, `IconTile`, `TextLink`, `AmberPill`, `MiniChip`, helpers `shortDay`, `ago`, `shortEmail`, `problem(e)`. |
| Screens | `lib/features/**` (students), `lib/admin/**` (managers) | One file per board area. A screen is a `Loaded` whose `load` calls stores and whose `builder` draws a `PageFrame`. |
| Routes | `lib/app/routes.dart`, `lib/app/router.dart` | Every screen has a route. A new top-level route also needs a line in `landing/_redirects`. |

### 2.2 The screen pattern (every manager screen follows it)
```dart
Loaded<Data>(
  key: ValueKey(_loads),            // bump _loads to reload after a write
  load: () async => (...store reads...),
  builder: (context, data, reload) => PageFrame(
    header: PageHeader(eyebrow: 'UPPER CASE', title: 'Title'),
    bottom: BottomAction(child: PrimaryButton(...)),   // the one main action
    children: [...],
  ),
)
```
- **Reads** happen only in `load`. **Writes** happen in button handlers that call one store
  method, then reload (`setState(() => _loads++)` or `reload()`), and report errors with a
  SnackBar via `problem(e)`.
- **Optional counts** (badges, subtitles) are loaded through `_maybe(...)`
  (`maintain.dart`), which returns null on failure, so a missing index or permission only
  loses a number, never the page.
- **Forms** keep typed state in the widget and build the model object only on save.
- **Long lists** (more than about 12 rows) are a `SliverRowGroup(count:, row:)` placed
  straight in `PageFrame.children`: it builds only the rows on screen. A search over one
  runs through a `Debouncer` (`shared/debounce.dart`), so a store-backed search should be
  called from the debounced callback, never per keystroke.

### 2.3 Design rules the screens rely on
- Stadium pills, not Material chips or dropdowns: `ChoicePills` / `PillButton`, pickers are
  `SelectRow` + a bottom sheet (`DeptSheet` for departments). Switches are `MergeSemantics(Row(title+caption, Switch))`.
- Mint = on/positive, ink = selected/primary, amber (`noticeTone`) = needs attention,
  dashed = not there yet (e.g. `MiniChip(dashed: true)` "no avg").
- Every screen must lay out at 390 and 320 px wide, light and dark, and 320 px at 150% text.
  Prefer a shorter label to shrinking or wrapping one.
- Reduced motion (`MediaQuery.disableAnimationsOf`) turns looping animations off
  (`PulsingTab`, the Reported tab dot).

---

## 3 · Backend work the UI is waiting for

Each item says what the UI does today, where the seam is, what to build, and which test
flips.

### 3.1 Secretary tier (appointments)
- **UI today** (`lib/admin/grant_form.dart`): Appoint shows a **Secretary** tier pill for
  owners, admins and presidents. Choosing it fills the form (department scope, programme,
  term note "Ends with the department president's term…") and the bottom action reads
  "Grant — secretary, ELEC Goa", but the button stays **disabled** with the caption
  "Secretary grants open with the roles update." (`_ready` excludes `_secretary`,
  line ~226).
- **Rules the user set:** a secretary is a department grant with **every president right
  except handing over**. Elected on the same date as the president; term ends with the
  president's. Can appoint CRs like a president. Appointed by owners, admins and presidents.
- **Build:** a way to store a secretary (a role or a flag on a `dept` grant), rules that
  give it president rights minus `handOver`/`cancelHandover`, `appoint(...)` support, and
  how `myRoles` exposes it (the UI reads `myRoles.value.presidencies` for department
  screens).
- **Then in the UI:** pass the secretary flag into `roleStore.appoint` in `_grant()`, drop
  `!_secretary` from `_ready`, remove the caption, and set the expiry to the president's.
  Hide "Hand over" on `DeptHome` for secretaries.

### 3.2 "Graded out of" and the course average scale
- **User's request:** whoever maintains a course's structure sets the scale a weighted
  course is graded out of (e.g. 200), so students no longer set "Shown out of" by hand; the
  course average is entered from 0 to that number.
- **Seam:** `lib/admin/offering_scale.dart`. Every offering save in the UI goes through
  `withOutOf(...)`, and every read of the scale through `offeringOutOf(...)` / `scaleOf(...)`.
  - `outOfStored = false` → the scheme editor shows "Graded out of" with an amber caption
    "Not saved yet…", and every scale falls back to the course's own units (100 when
    weighted, the total otherwise). Nothing stored changes.
- **Units:** `Offering.courseAverage` stays stored in **course units** (percent when
  weighted, marks of `totalMarks` otherwise), the same units as the student's own score in
  `CourseSummary`. The UI converts: `toStored(typed, scale, units)` on save and
  `toShown(stored, …)` for display.
- **Build:**
  1. `Offering` (`lib/core/models/offering.dart`): an optional `double? outOf`, in
     `toMap` / `fromMap` (omit when null), and a `copyWith`.
  2. `offering_scale.dart`: `offeringOutOf` returns `o.outOf`; `withOutOf` returns the copy;
     `outOfStored = true`.
  3. `lib/core/grading/official_scheme.dart` (~line 169): when the offering has a scheme and
     `outOf`, set the student's `cfg.displayOutOf = off.outOf`, **with the same
     keep-your-own-edit rule the course average uses** (a detach granule; a student who
     changed it keeps theirs and is told).
  4. Anywhere a student sees the course average as a number on their shown scale, convert
     from course units with the student's factor (`CourseSummary.factor`).
  5. `lib/core/grading/eval_import.dart`: accept an optional `"outOf"` per course in the
     JSON and the extraction prompt; `existing?.outOf` must survive an import like
     `courseAverage` does (line ~306).
- **Tests that flip:** `test/roles/offering_scale_test.dart` asserts `outOfStored` is false
  and `withOutOf` is a no-op. Update them to the stored behaviour, and add a round-trip
  test. `step11_screens_test.dart` "the scheme editor bounds the average by the scale"
  checks the "Not saved yet" caption; change it to the stored caption.

### 3.3 Site analytics
- `lib/admin/admin_home.dart` (~line 253): the owner's Site analytics row is disabled with
  "Coming later". Wire it to a route once there is something to show.

### 3.8 Possible duplicates (Merge duplicates)
- `lib/admin/duplicates.dart`: `DuplicateSource.possible(campus, dept, listed)` returns
  likely pairs, most likely first. Merge duplicates fetches it on load and shows a
  "Possible duplicates" card; tapping a pair picks both (the one with more offerings is
  kept). Default `NameDuplicates` pairs names on screen with `likelySame`. Point
  `duplicateSource` at the backend endpoint (fuzzy names, shared courses, aliases).

### 3.9 Departments per campus
- `lib/admin/dept_list.dart`: `DepartmentSource.at(campus)` returns the department keys a
  campus runs, in display order. Every department picker reads it through
  `campusBranches` (Open as, Appoint a president, Merge duplicates, Volunteers), and
  each multi-branch department shows a row per branch (ELEC as A3, A8, AA, AC). The
  default `AllDepartments` gives every campus every department. Point
  `departmentSource` at the backend's campus-wise list.
- The Audit log's course filter matches names through the catalogue (`searchCourses`
  over `catalog.master`, the published id-to-name mapping), so it needs no seam.

### 3.10 Links may point at any website (user's decision)
- A link can be an article or any site, not only Drive, Docs, YouTube and the like; a bad
  one is what the Reported tab is for. The UI accepts any http or https address with a
  host (`isWebLink` in `lib/admin/dept_resources.dart`). The Firestore rules' `url` regex
  and `allowedHosts` in `lib/core/resources/resource.dart` still hold the old list:
  loosen the rule to "http(s) with a host" and drop the host list (keep `normaliseUrl`
  and `kindOf`, whose default is "link"). Until then a save to another site is refused
  by the rules.

### 3.4 Counts the UI works out on the client (fine now; faster as queries)
None of these is wrong, but each costs reads and would be cheaper as a store method:
| Screen | What | How today |
|---|---|---|
| `DeptHome` THIS WEEK | edits this week by you / other presidents / CRs | `audit(campus, limit: 200)` filtered to the department's courses and the last 7 days |
| `DeptHome` rows | links, reported links, reported reviews, professors | four store reads through `_maybe` |
| `DeptProfessors` | "Last taught <term>" | one `taught()` per professor not teaching now |
| `ProfessorMerge` | courses and offerings per professor | one `taught()` per professor |
| `DeptCourses` | "CR: f2023…" chip | `roster(campus)` filtered to CR grants |
| `SuccessionConfirm` | "n CRs move too" | `roster(campus)` filtered to the department |
| `DeptReviews` | All / Reported / Hidden counts | the three `moderation()` reads at once (limit 50 each) |

The board's "Ramesh Menon · 17 reviews" on Merge needs a per-professor review count; the
UI shows offerings instead until one exists.

### 3.5 Places the UI reads Firestore directly (move behind a store)
- `config_pages.dart` ~565–570: public contact reads `config/public` and the audit entry
  named by `auditId` (live read, a recorded Departure: the user chose live over "after the
  next publish").
- `open_as.dart` ~386: `collectionGroup('offerings')` for the course picker.
- `succession.dart` ~22: `_myGrant` reads the president's own grant document. For an owner
  or admin previewing a department, `_shownGrant` falls back to the department's live
  president from `roster`; only `_myGrant` is ever handed over.

### 3.6 Indexes the UI relies on
`firestore.indexes.json`: collection group `offerings (campus, term)` (Open as course
picker) and the `entries` indexes for review moderation (N10). Keep them when merging.

### 3.7 Behaviour decisions already made (don't undo without asking the user)
- Public contact is read live (T8.8).
- Every department picker (Open as, Appoint, Merge duplicates, Volunteers) is the one list
  in `admin/dept_list.dart` (`DeptSheet` for the sheets): one row per branch, named by
  branch, subtitles show branch codes only; "ELEC" never shows as a choice. Each ELEC
  branch opens the ELEC its presidents manage together; professors stay per department.
- Links may point at any website; the Reported tab handles bad ones (§3.10).
- Merge duplicates fetches possible duplicates on load (§3.8); tapping a pair picks both,
  keeping the one with more offerings.
- The Audit log's course filter takes a code or a name.
- An owner or admin previewing Hand over sees the department president's screen with a
  "Previewing as" note; only the president's own grant is handed over.
- Emails in rows are the short campus form (`f20230456@goa`, `shared/short_email.dart`).
- Text size: 120% is the bar. At 150% labels may ellipsize (eyebrows keep theirs); nothing
  may overflow, which the render tests check.
- DeptHome has no "Appoint a CR" row; People › Roster reaches it.
- DeptProfessors stays search-first: Add waits for a search (N22).
- New component opens with the same layout as Edit component (several parts, empty).
- CRs enter the course average on the course page (N25), stored with the offering and
  audited as set or cleared.

---

## 4 · Wiring map (what the UI calls)

### 4.1 Store methods per screen file
| File | Store | Methods |
|---|---|---|
| `admin/admin_home.dart` | RoleStore, ContactStore | `owners`, `publicContact`, `roster`, `terms` |
| `admin/config_pages.dart` | RoleStore | `addOwner`, `audit`, `owners`, `publicContact`, `savePublicContact`, `saveTerms`, `setOwnerActive`, `terms` (Audit course filter: `searchCourses` over the catalogue) |
| `admin/grant_form.dart` | RoleStore | `appoint`, `personName`, `terms` (+ `departmentSource`, §3.9) |
| `admin/people.dart` | RoleStore | `audit`, `revoke`, `roster` |
| `admin/roster.dart` | RoleStore, ContactStore | `owners`, `roster`, `staffPhones` |
| `admin/volunteers.dart` | ContactStore | `offers`, `dismiss` (+ `departmentSource`, §3.9) |
| `admin/open_as.dart` | RoleStore, ProfessorStore | `roster` (+ §3.5, `departmentSource` §3.9) |
| `admin/publish_page.dart` | CatalogStore | `publish`, `saveDraft` |
| `admin/maintain.dart` | MaintainStore, RoleStore, ResourceStore, ReviewStore, ProfessorStore | `offering`, `offerings`, `save`, `audit`, `roster`, `department`, `flags`, `moderation` |
| `admin/bulk_upload.dart` | MaintainStore | `offerings`, `upload` |
| `admin/scheme_editor.dart` | MaintainStore | `save` |
| `admin/professors.dart` | ProfessorStore, MaintainStore | `add`, `department`, `merge`, `rename`, `taught`, `offerings`, `save` (+ `duplicateSource` §3.8, `departmentSource` §3.9) |
| `admin/dept_resources.dart` | ResourceStore | `add`, `update`, `department`, `flags`, `courseFlags`, `dismiss` |
| `admin/dept_reviews.dart` | ReviewStore | `moderation`, `hide`, `unhide`, `keep` |
| `admin/succession.dart` | RoleStore | `handOver`, `cancelHandover`, `personName`, `roster`, static `successorProblem`, `outgoingExpiry` |
| `features/roles/rep_profile.dart` | ContactStore | `myDirectory`, `myStaffContact` (+ save) |
| `features/more/representatives_page.dart` | ContactStore | `directory`, `myOffer`, `volunteer`, `withdraw` |
| `features/resources/resources_page.dart` | ResourceStore | `department`, `report` |
| `features/reviews/*` | ReviewStore | `stats`, `byProfessor`, `mostReviewed`, `page`, `mine`, `get`, `save`, `vote`, `report`, `search` |

Regenerate this table when stores change: grep each file for `_store.`, `roleStore!.`,
`reviewStore`, `resourceStore`, `MaintainStore(`, `ProfessorStore(`, `ContactStore(`.

### 4.2 Session state the UI reads
`roleStore` (null when signed out), `myRoles.value` (`owner`, `admin`, `presidencies`,
`grants`), `refreshMyRoles()`, `profileDue`, `myContactSummary` (`core/roles/session.dart`).
Grant fields read by screens: `role`, `scope`, `campus`, `programme`, `active`, `expiresAt`,
`expiresBefore`, `handedTo`, `name`, `email`, `liveAt()`, `scopeLabel`.

Student settings writes (UI_OPT O3): Home's `build` saves nothing, and a test greps for it
(`test/perf/no_writes_in_build_test.dart`). Each handler saves what it changed through
`features/semester/home_persist.dart` `writesFor` (semester → `setsem`, sort and reorder →
`setsort`, profile tap or swipe → `setprof`); `setdis` runs after Settings, import and setup.
If the logic branch hooks `setdis` / `setprof`, keep the names; the hooks still fire from
the handlers. The Stats plan saves once per slider drag (`onPlanChangeEnd`), not per tick.

### 4.3 Places the UI builds a model object (update them when a model gains a field)
`Offering(...)` is built in **three** screens, each wrapped in `withOutOf(...)`:
`maintain.dart` `_CourseAverageState._save`, `professors.dart` `TakenBy._change`,
`scheme_editor.dart` `_build`. Plus `core/grading/eval_import.dart` (core). **A field added
to `Offering` must be carried through all four, or a save silently drops it.** Grep
`Offering(` after any model change.

---

## 5 · Editing or refactoring the UI safely

### 5.1 Gates (run all; `agent_toolchains/code/verify.py` runs them in order)
```
export PATH=~/development/flutter/bin:$PATH   # /opt/flutter: deprecated (cloud container)
dart format <only files you changed that were formatted at HEAD>
flutter analyze lib test          # baseline: exactly 7 infos, 0 new
flutter test                      # includes the render tests below
```
`python3 agent_toolchains/code/commit.py -m "msg" <files>` runs the gates, stages only the
named files, commits and pushes. Never `git add -A`.

### 5.2 What the tests pin
- **Render tests** `test/ui/{student,manager,sheet}_screens_test.dart` pump every screen at
  390/320, light/dark, 320@150% with seeded data (`test/helpers/fake_data.dart`) and fail on
  any overflow or layout error. Each file's `known` map is empty; keep it that way (an entry
  there hides a real bug).
- **Behaviour tests** find widgets by their **visible label** (e.g. 'Merge into Ramesh
  Menon', 'Reported 1', 'Hand ELEC to f20240001', 'Type a number from 0 to 100.'). Changing
  a label means updating its test in the same commit; `grep -rn "'<label>'" test` first.
- **Font subset** `test/perf/font_chars_test.dart`: every character in a `lib/` string must
  be in the subset fonts. `›`, for example, is not; use an icon.
- **No Hive writes triggered from UI in widget tests** except inside `t.runAsync`.
- Seed data in `fake_data.dart` drives the renders; if the backend changes a stored shape,
  update the seed so the renders still show real states.

### 5.3 Looking at a screen
`python3 agent_toolchains/ui_check/ui_check.py run --only <render names> <suite file>`
renders just those screens (about 10 s) and lists new issues (clipped text, overflow,
contrast, word breaks). The PNGs are in `build/ui_check/new/`; look at them. Full run:
`ui_check.py run`; the contact sheet: `ui_check.py atlas` → `ui_sheet/ui_sheet.png`.
Known false alarms: 36-tall pills and header blocks flagged `tap`, icon-only pills flagged
`dead`, `TierTag` contrast at 150%.

### 5.3.1 The UI-only demo
`demo/main.dart` runs the real app with no backend: a local Firebase stand-in, Hive in the
browser, and the seed data in `test/helpers/fake_seed.dart` (the web-safe half of
`fake_data.dart`, which re-exports it). Every sign-in is the owner. `demo/build.sh` builds
it into `build/demo` (it builds against a patched copy of `fake_cloud_firestore`, whose
test mock release builds refuse, and removes the override after). A change to a seeded
model shape goes in `fake_seed.dart`, and the demo picks it up.

### 5.4 Rules for changes
1. Colours, type and spacing only from the tokens (§2.1).
2. Reuse the kit (§2.1) before writing a widget; if a piece repeats on two screens, move it
   into `admin/widgets.dart` or `shared/widgets/` once.
3. Don't change a shared widget to fix one label's overflow; shorten the label.
4. Keep reads in `load` and writes in handlers (§2.2). A screen never computes what a store
   should decide (permissions, terms, sync). If it needs a new rule, add a store method and
   list it in §4.1.
5. New optional numbers go through `_maybe` so they can't take the page down.
6. A new top-level route needs `landing/_redirects`.
7. Check 320 px at 150% text for every changed screen.

---

## 6 · Backend checklist
- [x] §3.1 Secretary: store + rules + `appoint` + `myRoles`; then enable the tier in
      `grant_form.dart`, hide Hand over for secretaries.
- [x] §3.2 Graded out of: `Offering.outOf`, seam functions, `outOfStored = true`,
      `official_scheme.dart` sync with a detach granule, eval import, flip the two tests.
- [x] §3.5 Move the three direct Firestore reads behind store methods.
- [ ] §3.4 Optional: count queries for the client-side counts. (Cut: admin-only, few users.)
- [ ] §3.8 Serve possible duplicates; set `duplicateSource`. (Cut: no Functions on Spark; client-side `NameDuplicates` stays.)
- [x] §3.9 Serve the campus-wise department list; set `departmentSource`.
- [x] §3.10 Rules: accept any http(s) link; drop `allowedHosts`.
- [x] Before merging, on `pointer-rebuild` itself: `ui_check.py run`, then `ui_check.py
      accept`. The baseline lives in `build/ui_check/base/`, not in git, so a fresh checkout
      has none; this records the finished UI (354 renders, no issues) to compare against.
- [x] After merging: §5.1 gates green, `known` maps still empty, `ui_check.py run` shows no
      new issues against that baseline. A changed screen is fine only if the change was
      meant; an issue is a regression.
