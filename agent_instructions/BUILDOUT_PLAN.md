# Pointer: new-feature build-out (backend + UI), Builder and Builder 2

## Context
- **What is ready:** the 16 proposed features are specified in `agent_instructions/PROPOSED_FEATURES.md` (product), `DATA_SYNC_PLAN.md` §5 (server design), `UI_CHANGES_BRIEF.md` and `UI_MAP.md` (screens and the owner's specifics). The UI boards have been reviewed.
- **What is missing:** Stages 1–3 of the sync layer are live on staging (heads, Worker, DO hub, caches, prefetch levels), but no Stage 5 backend exists. No rules, stores or Worker routes are built for contributors, the review gate, the leaderboard, professor soft delete, GEN, the calendar feed or Last updated.
- **The ask:** build all the new features as fast as possible.
  - Two Claude sessions, Builder (this one) and Builder 2, each with 2 subagents.
  - Backend first; bugs scoped up front.
  - Nothing that works today may break: unchanged screens, the startup and caching optimisations, and the fixed bugs.

**Owner rulings (2026-10-03):**
1. No feature flags. Each feature appears on staging when it lands, so every push must keep the existing UI green.
2. An edited approved link stays approved: audited, no new points.
3. Forced reviews: owners and admins switch any campus; presidents and secretaries switch only their own campus. Turning it on asks to confirm; turning it off does not.
4. **Calendar (owner, 2026-10-03; replaces the earlier "student enters times"):**
   - **It works like a normal calendar.** Add a course. Change its timings: one edit sets the individual time of every occurrence of that class in the week. Set it to repeat until a specific date.
   - **One broadcast timetable.** The backend publishes a single campus timetable that every app subscribes to. It holds every offered course and section with timings, professors, rooms, and midsem and compre dates where they apply, plus the academic calendar dates.
   - **Its source** is the official timetable PDF (e.g. `Time Table - sem 1 26-27.pdf`, which must never be committed).
5. Speed over ceremony. No Tester messages for now, and no long Phase 0: the spikes run inside the first tasks.

**Builder rulings** (each says what it costs if wrong):
- **R-A. Review gate enforced in the app only.** The unlock count is min(electives taken, 5), and electives taken is local course data the rules can't see. So the server holds only the gate switch, and the app counts the student's own non-imported reviews (from the "mine" cache).
  - Skipped: the `reviewCounts` counter and the Worker HMAC unlock token. Add them when the Worker serves cached review reads.
  - Cost if wrong: someone bypassing the app could read reviews while locked. That's acceptable for a nudge feature.
- **R-B. Course-review stats per filter are computed in the app** from the loaded reviews of that course, which number in the hundreds at most. No new counters, no rules cost.
- **R-C. Staff points.** Admins, presidents and CRs earn +4 into `contributors/<email>`. Their links stay exactly as today; the new points write is allowed but not required. They appear on the leaderboard once they pick a username.
- **R-D. Last updated** is one doc per campus, `activity/<campus> = {course:{<id>:ts}, dept:{<d>:ts}}`, written in the same batch as each meaningful edit with `request.time`. That's one read for the Representatives page.

## Team, lanes, file ownership

| Session | Lane | Subagent 1 | Subagent 2 |
|---|---|---|---|
| **Builder** (this CLI) | Backend: rules, stores, Worker, seed, import | **BE-R**: `firestore.rules` + `test/rules/*.test.mjs` | **BE-S**: `lib/core/**` stores/models + unit tests, `server/**`, `tools/test_env/**` |
| **Builder 2** (Desktop) | UI: screens, routes, widget tests | **UI-S** (student lane): `lib/features/**`, `lib/home_page.dart` area, student routes | **UI-A** (staff lane): `lib/admin/**`, admin routes |

**Working rules:**
- **Worktrees:** each subagent works in its own worktree reset onto `origin/pointer-rebuild` (worktrees fork from master by default, so reset first). No two implementers ever share a tree.
- **Shared files, owned by one controller:**
  - Builder 2 only: `lib/app/router.dart`, `lib/app/prefetch_levels.dart`, `tools/font_chars.txt`, `lib/shared/widgets/**`.
  - Builder only: `lib/core/heads/paths.dart`, `docs/ARCHITECTURE.md` (backend sections), `DATA_SYNC_PLAN.md`.
  - A subagent that needs a change in one of these files states it in its report, and its controller applies it.
- **Contracts first:** `agent_instructions/BUILDOUT_CONTRACTS.md` (Builder, Phase 0) fixes every doc shape, path, heads marker and store method signature. UI-S and UI-A build against those signatures with `FakeFirebaseFirestore` before the real backend lands, and the backend must match them exactly.
- **Integration:** each controller rebases on `origin/pointer-rebuild` and runs the full verify (below), then pushes. The push deploys staging through CI. No Tester messages for now. Never touch master; production stays owner-only.
- **Ledger:** each controller keeps a SDD ledger (`.superpowers/sdd/<plan>/progress.md`). Builder 2 can be reached with `SendMessage` (find it with `ListAgents`); messages carry results and data only.

## Phase 0: scope the bugs (first hour only; spikes run inside the first tasks)
0. **Keep the PDF out of git:** add `/*.pdf` to `.gitignore` so `Time Table - sem 1 26-27.pdf` can never be committed.
1. **Baseline:** run on a clean `pointer-rebuild` and record the numbers in the ledger.
   - `python3 agent_toolchains/code/verify.py` (format, analyze against the baseline, `flutter test`)
   - `cd test/rules && npm ci && npm test` (about 159 tests)
   - `cd server && npm test`
   - the e2e job
2. **Spikes:** throwaway code, each answering one question.
   - **S1 (BE-R): rules access limits.** Firestore allows 10 `get`/`exists` calls per single write and 20 per batch. Measure the contributor approve batch (link, links mirror, pending index, points, leaderboard, audit, heads) on the emulator. If it doesn't fit, approve one link per batch and loop in the client.
   - **S2 (BE-R): `managingDept(campus, course)`.** Add it next to `deptOf` (`firestore.rules:39`) and replace `deptOf` only at the course-scoped call sites: resources, CR checks, professor and structure edits. All existing rules tests must still pass unchanged.
   - **S3 (UI-S): Offshoot tab hide.** `home_page.dart:113` hardcodes More as `index == 4`, and `selectedprofile = index+1`. Prototype mapping destinations by id, and confirm `nav_screenshots_test` and `responsive_test` still pass.
   - **S4 (UI-S): tour overlay.** It must not rebuild Home (PERF-02/TM-3). Prototype an `OverlayEntry` + `RepaintBoundary` that highlights by `GlobalKey`, then check `home_rebuild_test`.
   - **S5 (BE-S): heads marker budget.** List the new paths and confirm `heads/<campus>.v` stays well under 3000 keys and 4 keys per write: `contributors`, `leaderboard`, `pending/<dept>`, `reviewGate`, `activity`, `calendar`, `courseClaims`.
3. **Write `BUILDOUT_CONTRACTS.md`** (Builder) and **`UI_IMPLEMENTATION_GUIDE.md`** (Builder; outline below). Commit both and brief Builder 2.
4. **Risk register:** copy the list below into the ledger. Every task's review checks the risks it touches.

### Risk register (scoped early; each has a guard)

| # | Risk | Mitigation and guard |
|---|---|---|
| K1 | Approve batch exceeds the rules access limit | S1; one link per batch if needed; rules test with the maximum batch |
| K2 | `managingDept` change breaks existing department rights | Only course-scoped sites change; all old rules tests unchanged; new tests for GEN and claims |
| K3 | GEN shows up in setup, the discipline picker or the programme list | GEN gets no branch code; unit test that `programmes` and `departmentOfProgramme` never return GEN |
| K4 | Hiding Offshoot shifts nav indices and profiles (`home_page.dart:113`) | Map destinations by id; nav screenshot and responsive tests; profile index unchanged |
| K5 | Editing the legacy Hive `Course` adapter (`course.g.dart`) | Don't. New data goes in new boxes (`timetable`, prefs on `users`); never `dart format` legacy files |
| K6 | New strings or glyphs (★, ·, "Electives") missing from the font subset | Add to `tools/font_chars.txt`; `test/perf/font_chars_test.dart` |
| K7 | New screens show spinners on revisit | `Loaded` + `cacheKey` + `peek`, stores via `cacheFirst` with peek twins, register in `prefetch_levels.dart`; extend `test/ui/nospin_screens_test.dart` |
| K8 | Role drops on new staff screens (`leaveRoleOutside`, `router.dart:44`) | Approvals, claims, gate switch and events editor live under `/admin` or `/maintain`; Contribute stays a student route (it uses the grant, not working-as); extend `test/app/leave_role_test.dart` |
| K9 | Student code imports `lib/admin` and pulls the deferred admin bundle into startup | Staff screens only through `_admin()`/`_deferred`; `nospin_test:56` |
| K10 | Review write path regresses (the UT-4 area) | The only review-write change is the optional `grade`/`marks` fields; existing review rules tests unchanged |
| K11 | Old clients see unapproved links after 15 days | Accepted; new readers filter; optional DO daily cleanup later |
| K12 | `users/{uid}` key whitelist (`firestore.rules:1099`) refuses the new prefs | Add `prefs.offshootHidden` and `prefs.tourSeen` (bools); rules test |
| K13 | Keyboard band comes back (UT-3) in new sheets | Every new input sits in a `ResponsiveScaffold` page or an `isScrollControlled` sheet with `viewInsetsOf` padding; `responsive_test:199` |
| K14 | Tour overlay or new Home widgets cause full Home rebuilds (PERF-02) | S4; no writes in build (`no_writes_in_build_test`); `home_rebuild_test` |
| K15 | Tour targets near the nav pill tap through on iPhone (TM-6) | The tour blocks taps outside the highlight; owner checks on iPhone |
| K16 | Approval queue shows stale data from another admin (tracker note) | Queue uses `Loaded(gated:)` and refreshes on open; a write conflict shows Try again |
| K17 | Seed and staging lack the new roles and data, so Tester can't test | BE-S extends `tools/test_env/accounts.json` (contributor, applicant, Elective Contributor, gate on) and `seed.mjs` (wipe list, pending links, leaderboard, events); `seed.test.mjs`; prod build guard |
| K18 | wasm blanks from `as int` on JS numbers | Read numbers as `num`; analyzer grep in review |
| K19 | Analyzer baseline grows | `verify.py` against the baseline; zero new infos |
| K20 | Worker deploy is an owner step | The `/timetable` and `/calendar` routes ship with vitest; the owner runs `npx wrangler deploy --env staging`; until then the app reads the Firestore chunks and hides the Subscribe row |
| K21 | Timetable parse errors (wrapped rows, odd schedule codes) give wrong class times | Dry-run report is reviewed before `--commit`; fixture tests; owner spot-checks 10 courses against the PDF |
| K22 | Timetable size: about 1,000 courses and several thousand sections | Chunked docs under 900 KB; one Worker JSON fetch, edge-cached; app keeps it in a Hive box with peek, parsed once off the first frame |
| K23 | A republished timetable clobbers student edits | Edits are overrides keyed by course + section + slot; an override whose slot is gone shows as "your time (published time changed)" |
| K24 | The timetable PDF or its names end up in git | `/*.pdf` in `.gitignore`; fixtures are synthetic; the dry-run output goes to the scratch dir only |

## Phase 1: backend (Builder; BE-R and BE-S pair up on each item)
Per item: BE-R writes rules and rules tests while BE-S writes the store, models and unit tests against the contract. Builder merges them, runs the emulator integration, then pushes. The order goes from foundation to largest.

| # | Feature | Docs and rules | Store (`lib/core/...`) |
|---|---|---|---|
| B1 | Prefs (7, 14) | `users/{uid}.prefs.{offshootHidden,tourSeen}` bools; whitelist | Existing user sync; `prefs` getters and setters |
| B2 | GEN + claims (13) | GEN in the department table; `deptOf` maps unknown prefixes to GEN; `courseClaims/<campus>\|<course> = {dept, by, at, auditId}`, created or deleted by the president or secretary of a department whose programme has it as a CDC; audited; bumps `courseClaims` | `roles.dart:34` mirrors GEN; `managingDept()`; `ClaimStore.claim/unclaim/claims(campus)` cacheFirst; Elective Contributor = `dept` grant with scope GEN through the existing `RoleStore.appoint` |
| B3 | Professor soft delete (5) | `removed: true` + `removedBy`, president of the managing department, audited, bumps `professors/<dept>`; removed docs frozen like merged ones | `ProfessorStore.remove(id)`; `search`/`taught` exclude removed; `byProfessor` and filters keep them |
| B4 | Last updated (15) | `activity/<campus>` maps; writable only beside a resource, structure or professor write, value `== request.time` | Every resource, structure and professor write adds `activity` in the same batch; `ActivityStore.of(campus)` cacheFirst |
| B5 | Review grade and marks (10) | Review keys gain `grade` (one of the grade letters or `ND`, required on new writes) and `marks` (num, optional, 0–max); old reviews still valid | `Review` model plus `save()`; filters by professor, year, semester and sort; `statsOf(reviews)` helper (R-B) |
| B6 | Review gate (2) | `reviewGate/<campus> = {on, by, at, auditId}`; owners and admins any campus, president or secretary own campus; audited; bumps `reviewGate` | `GateStore.of(campus)`; pure `gateState({on, currentsem, electivesTaken, myReviewCount})`, where `pastTwoOne(currentsem)` uses `core/models/semesters.dart` and counted reviews need stars + would-take and are not imported |
| B7 | Contributors (3) | §5.2 in full: `contributorRequests/<campus>\|<dept>\|<email>` (volunteer pattern, `firestore.rules:464`); grant role `contributor\|<campus>\|<email>` (no expiry); contributor link create `approved:false, publishedAt`; `pending/<campus>\|<dept>`; approve and reject batches; `contributors/<email>`; `leaderboard/<campus>`; `usernames/<campus>\|<name>`; +4 only on false→true or an approved staff create; 15-day check; edit own link stays approved (ruling 2); no delete by contributors | `ContributorStore.apply/withdraw/myRequest/requests(dept)/approve/decline/revoke`; `LinkStore` extensions `addAsContributor/approve/reject/pending(dept)`; `LeaderboardStore.of(campus)`; `claimUsername`; readers hide unapproved links older than 15 days; new `GrantRole.contributor` + capabilities row |
| B8a | Timetable extractor (8, 16) | none (Admin SDK, owner-run) | `tools/timetable/extract.mjs <pdf> --campus goa --sem 2026-1`, details below |
| B8b | Broadcast timetable (8, 16) | `timetable/<campus>\|<sem>` meta doc `{sem, hours, chunks, publishedAt, auditId}` + chunk docs `timetable/<campus>\|<sem>\|<n>` (under 900 KB each, grouped by prefix); writes by owner or admin only (the script); bumps `timetable` | `TimetableStore.current(campus)`: cacheFirst on the `timetable` marker, read through the Worker first (`GET /timetable/<campus>.json`: one edge-cached merged JSON, memoized like `/heads`), Firestore chunks as fallback. Worker `GET /calendar/<campus>.ics` (RFC 5545) carries the academic dates plus midsem and compre exam slots; vitest for both routes |
| B9 | Seed and test env | New accounts and data (K17) | `seed.mjs`, `accounts.json`, `gen_accounts.mjs`, `seed.test.mjs` |
| B10 | Import script (9) | none (Admin SDK) | `tools/import/import.mjs` per §5.5: dry run by default, idempotent ids, `source: imported`, audit, president and secretary +4 per record, heads rebuild; node test on the emulator. Never paste `course_reviews_out` content |

### B8a: timetable extractor (owner-run, like the import script)
- **Input:** `pdftotext -layout` of the official PDF. It has 50 pages: the academic calendar on pages 1–2, the handout rules, then about 45 table pages headed `COURSE NO | TITLE | LPU | CREDIT | STAT | SEC | INSTRUCTOR | SCHEDULE | ROOM | COMPRE | MIDSEM DATE | MIDSEM TIME`.
- **Parse:**
  - **Rows:** a row starts with a course number (`[A-Z]{2,4} [A-Z]?\d{3}[A-Z]?`). Title, instructor and midsem-time lines that wrap are continuations, joined by column position from the header offsets on each page.
  - **Section type:** `STAT` is L (lecture), T (tutorial), P (practical), I (instructors list) or R (research). R rows have no schedule.
  - **Schedule codes:** `MWF9`, `T TH 4 W 1`, `F 4 5`, `TH 11 12`. Days are M, T, W, TH, F, S. Hours use H=1 → 08:00, one hour each (the PDF says "1 = 8 AM, 2 = 9 AM …"). Consecutive hours merge into one block. `TBA` means no slot.
  - **Exams:** compre is `dd/mm/yy (FN|AN)`, with FN = 09:30–12:30 and AN = 14:00–17:00. Check those times against the PDF notes and keep them in the meta `hours` table so they can be corrected. Midsem is `dd/mm/yyyy, hh:mm AM - hh:mm PM`, which wraps across lines. Either may be `TBA` or empty.
  - **Academic dates:** from pages 1–2, as `{date or range, title, kind: holiday|exam|deadline|term}`, where kind comes from `(H)` and keyword matching.
- **Output:** `{courses:{<id>:{title, sections:[{type, no, instructors[], slots:[{day, start, end}], room}], compre?, midsem?}}, events:[...], hours, sem, campus}`. Professors are matched to existing `professors/<dept>` ids by normalised name, and unmatched names are listed.
- **Dry run by default:** prints counts, rows it couldn't parse (with page and line), unmatched professors and unknown course ids. `--commit` writes the chunks, meta, audit and the heads bump. It is idempotent (same sem means replace). `--project staging` takes the SA key by path only, never read or printed.
- **Tests:** a `node --test` file runs on small synthetic text fixtures written by hand, covering wrapped rows, multi-hour slots, TBA, FN/AN and midsem wraps. Never fixtures copied from the PDF.

**Backend done means:**
- All rules tests pass, old and new.
- The store unit tests pass.
- `server` vitest passes.
- The seed works against the emulator.
- `docs/ARCHITECTURE.md` §13 is updated, with the data shapes and Mermaid diagrams.
- `DATA_SYNC_PLAN.md` §5 is marked built, noting rulings R-A to R-D.

## Phase 1′: client-only UI, in parallel with Phase 1 (Builder 2)
These items need no new backend, or only B1.
- **U1, star ratings in Add course (1):** from the existing `reviewIndex/<campus>`. A "ratings did not load" notice on failure.
- **U2, course delete moves to the evaluation screen (6):** with `confirmDialog`; the Remove button is removed from the Edit sheet.
- **U3, Offshoot optional (7):** after B1; spike S3.
- **U4, Resources by course (4, 12):** the ResourceDegree picker, the Course resources list (This semester by default, All, search) built from the More-tab layout, and adding a link to one course. The rules already allow course-scoped links.
- **U5, Your reviews "All" filter (11).**
- **U7, calendar (8, 16), behaving like a normal calendar.** Build it against the B8b contract with a fake timetable; it goes live when B8b lands.
  - **Views:** Month / Week (time axis 08:00–20:00) / Day. Today marker. Swipe between weeks.
  - **Add a course:** search the broadcast timetable, pick lecture, tutorial and practical sections, then save. The classes, room and professor are pre-filled, and that course's midsem and compre are added as exam events. Courses already on the student's Home semester are offered first. A custom event can be added with no course.
  - **Change timings in one edit:** a sheet lists every weekly occurrence of the class (e.g. M 9–10, W 9–10, F 9–10), and each row's day, start and end can be edited. It saves in one go, with a "your time" tag and Reset to published.
  - **Repeat until:** each class has a repeat end date. The default is the last day of classwork from the broadcast academic dates, and it can be any date. Occurrences stop after it.
  - **Remove** a course or a single occurrence.
  - **Storage:** student edits go in a device Hive box `calendar` keyed by profile. They store only overrides against the broadcast (section picks, slot overrides, repeat end, removed occurrences, custom events), so a republished timetable flows through. Never touch the legacy `Course` adapter (K5).
  - **Subscribe:** a "Subscribe to the campus calendar" sheet copies `/calendar/<campus>.ics` and offers an "Add to Google Calendar" link (8).
  - **Not built:** the deferred generator, which must fit as a later state on the same grid.
- **U8, guided tour (14):** after B1 and S4. 40 steps in chapters, Skip and Next, Replay from Settings, students only.

## Phase 2: backend-dependent UI (Builder 2, as each B item lands)

| U | Needs | Lane | Screens |
|---|---|---|---|
| U6 | B5 | UI-S | Course reviews: professor dropdown with search, typed year (validated), semester dropdown, sort, combined filters, stats follow the filter, grade and marks on each review, average grade and marks; review form gets grade (required, ND allowed) and marks (optional), both pre-filled from CGPA data; "Course resources" button |
| U9 | B3 | UI-A | Professors: fix the greyed-out Add (enabled without searching first), duplicate warning (fuzzy match on name), delete with confirm, a Removed group |
| U10 | B6 | UI-S + UI-A | Student: locked state in Reviews and course search, CompulsoryPick (pre-selects last semester's electives), Unlocked. Staff: switch in Controls / Your department with confirm on enable |
| U11 | B7 | both | Student: Settings row, resources prompt (once per session, Not now / Apply now), Apply (rule shown up front, president contact), username, the Contribute tab in More (pending, published, approved, rejected states; add, edit, batch submit), Leaderboard card for everyone. Staff: approvals queue (one entry per batch, clickable links, approve, reject with a reason), Revoke, staff tags |
| U12 | B4 | both | "Last updated" beside the course rep, "N courses stale" on Representatives; semesters wording |
| U13 | B2 | UI-A | Appoint tier "Electives", Work-as row, Your department as Elective Contributor (no Hand over), DeptCourses claim pill, department sheet GEN row |
| U14 | B8b | UI-S | U7 switches from the fake to the live `TimetableStore`; register the `timetable` marker in prefetch level 2 (Calendar is a Home tab, so data must be warm); show "Timetable not published yet" before the first broadcast. No staff editor: the owner publishes with B8a |
| U15 | all | both | Error states on every new screen: inline, load failure with Try again, offline strip, denied, failed write. Built from `Notice`/`problem()`/`OfflineStrip`, following the board patterns (PfErr*) |

## UI implementation guide (deliverable `agent_instructions/UI_IMPLEMENTATION_GUIDE.md`)
Written in Phase 0 and committed. Per feature: the screens (with board names), the routes and the guard each needs, which kit widgets to use, the store calls and cache keys, which prefetch level, loading/empty/error states, what must not change (staging is the spec; only tagged parts change), the tests to add, and Tester's check steps.

Its front section restates the existing invariants new code must keep, each with its guard:
- **Startup path:** nothing networked before `runApp`; analytics after first frame.
- **Caches:** `cacheFirst`/`peekCache`/`Loaded(cacheKey, peek, gated)`, so no spinner on revisit.
- **Prefetch:** level registration in `prefetch_levels.dart`.
- **Deferred admin:** staff screens only through `_admin()`.
- **Roles and routing:** role prefixes for `leaveRoleOutside`; go_router nesting, `_redirects`, `openRoute`.
- **Nav:** `AppNav` pill and rail rules.
- **Theme:** rebuild via `themeVersion`, no Theme on Home.
- **Widget kit only:** no new styles.
- **Keyboard:** the inset rules (UT-3).
- **Semantics:** containers, 44px targets, 320px width / 200% text.
- **Performance:** no `Opacity`, lazy lists over 12 rows, RepaintBoundary on anything self-animating, `sizeOf`/`viewInsetsOf`.
- **Fonts:** subset rule.
- **wasm:** read JS numbers as `num`.
- **Tests:** Hive under fake time.

It also lists the open tracker items on touched screens: PERF-02, TM-6, TM-7, UT-3, UT-4, UT-5, UT-1/2, TM-15, TM-16, QA-08, QA-01.

## Verification
- **Per task:** the SDD loop. Implementer TDD, a task review (spec and quality) against the brief and the risk register, then a fix loop.
- **Per push:** `python3 agent_toolchains/code/verify.py`, `cd test/rules && npm test`, `cd server && npm test`. CI then runs `check`, `e2e` and `deploy-staging`.
- **Per feature on staging:** the controller that landed it (no Tester for now) signs in through Playwright with `?as=<key>` accounts (new ones from B9) and checks that:
  - the feature works per its brief;
  - the screens untouched by the feature still match staging (the board screenshots are the reference);
  - nothing spins on revisit;
  - the keyboard and role checks pass.
- **End:** a whole-branch review on the most capable model, a perf re-measure (`ab2.mjs` warm first frame) to confirm no regression against the baseline, and owner sign-off. Production stays the owner's step.

## Deliverables and order
1. Phase 0 (Builder):
   - Write `agent_instructions/BUILDOUT_PLAN.md`, a copy of this plan, and commit it.
   - Write `BUILDOUT_CONTRACTS.md` and `UI_IMPLEMENTATION_GUIDE.md`, then brief Builder 2.
   - Run the baseline and the spikes S1–S5.
2. Run the two lanes in parallel:
   - Builder:
     - BE-R: B1 → B2 → B3 → B4 → B5 → B6 → B7 → B8b.
     - BE-S: B8a (the extractor, which needs no rules) first, then the stores for each B item as BE-R lands its rules.
     - B9 (the seed) grows with each item, and B10 comes last.
     - Builder runs the extractor dry run on the PDF and shows the owner the report before any `--commit`.
   - Builder 2: U1, U2, U4, U5, U7 right away; U3 and U8 after B1; then U6, U9–U14 as their B items land; U15 throughout.
3. Final review, staging check by both controllers, the docs updated, and owner sign-off.
