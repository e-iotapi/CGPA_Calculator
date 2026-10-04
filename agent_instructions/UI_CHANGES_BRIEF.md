# Pointer UI changes: implementation brief

Self-contained handover for an agent that has none of the earlier conversation. Read this file, then
`UI_MAP.md` (the tagged UML map, mermaid) and `PROPOSED_FEATURES.md` (the feature spec). Server design:
`DATA_SYNC_PLAN.md` Stage 5. System spec: `ARCHITECTURE.md`.

## 0. Purpose and governing rules (hard)

Implement the owner's proposed UI changes in the Flutter app (`lib/`, branch `pointer-rebuild`).

1. **Live staging (https://pointer-staging.web.app) is the UI spec.** These 36 screens are unchanged:
   get NO code change and are out of scope: SignIn, DegreeSetup, ProgrammePick, ErpImport, ImportPreview,
   InstallGuide, GradeMenu, CourseSetup, AverageSources, Stats (incl. its Degree tab), ReportLink,
   ProfessorReviews, RepProfile, ProfessorMerge, DeptReviews, DeptResources, CrHome, CourseScheme, Roster,
   AuditLog, People, Person, Terms, PublicContact, Owners, Publish, Analytics, OpenAs, ViewAsDept,
   ViewAsCourse, OwnerSetup, CampusPick, Succession, SuccessionConfirm, Volunteers, BulkUpload.
2. **On a changed screen, change ONLY the parts tagged NEW / CHANGED / REMOVED in `UI_MAP.md`** or named in
   `PROPOSED_FEATURES.md`. Everything else stays exactly as staging (layout, copy, order, controls, sizes).
   **DEFERRED = do not build** (the timetable planner). Untagged lines in the map exist today.
3. The design board's PLAY navigation and arrows were illustrative. An existing button keeps its current
   behaviour; a new control wires per the `UI_MAP.md` edges (solid = navigation, dashed = sheet/dialog)
   and the feature section.
4. Reuse existing widgets, theme and components (`lib/shared/widgets/`, `lib/app/theme/`); no restyling.
5. Where the board and the spec disagree, `UI_MAP.md` + `PROPOSED_FEATURES.md` win. The board
   (design artifact https://claude.ai/artifact/K4H9w2Ad9cwdTqxPSAiWMW) is private: the owner must share it with
   your account. It is a picture only.
6. Do not invent answers to open questions (section 6). Build what is decided; stub or skip the rest and ask.
7. **Cross-cutting rules for every new/changed screen (owner chat):**
   - Proper error states on every new screen (errors do not show properly today); reuse the existing `Notice`/problem() copy (owner chat, 2026-10-02).
   - No spinners: show cached data instantly; revisiting a page never shows a loader (owner chat, 2026-10-01 and 10-02). Follow the `lib/core/cache/` cache-first pattern and `test/core/nospin_test.dart`.
   - Loading priority by path: Home (all tabs), then More (Reviews, Representatives, Resources) and their sub-pages, admin paths last (owner chat, 2026-10-01). Register new paths in `lib/app/prefetch_levels.dart` / `lib/core/prefetch/`.
   - Keyboard: only the focused field scrolls with the keyboard, never the whole page (fixed in e433405; keep it for new inputs) (owner chat, 2026-10-02).
   - Leaving the role's pages back to student screens makes the user a student again (done in f2f0f17; do not break it) (owner chat, 2026-10-02).
   - Mass import of reviews/resources is an owner-run script, never an app feature (owner chat, 2026-09-30).
   - Already shipped, do not redo: ERP "Open ERP" goes to the BITS student content link (b441cdb).
   - Where owner chat conflicts with `PROPOSED_FEATURES.md`, the chat is later and wins; each conflict is noted below.

Nothing is built yet for any item below (checked by grep: no tour, contributor, review-gate or week-view code).

## 1. Codebase orientation

- Routes: `lib/app/routes.dart` (path constants, `openRoute`), `lib/app/router.dart` (go_router).
- Home with the bottom nav (Actual / Expected / Compare / Offshoot / More): legacy `lib/home_page.dart`
  (destinations list near line 125). Do not reformat it.
- Student features: `lib/features/{semester,marks,calendar,settings,more,resources,reviews,roles,offshoot,stats}/`.
- Staff screens (deferred library): `lib/admin/` (`maintain.dart` DeptHome/DeptCourses/CrHome,
  `professors.dart`, `admin_home.dart`, `grant_form.dart`, `dept_resources.dart` incl. the private `_LinkSheet`,
  `open_as.dart`, `widgets.dart`).
- Stores / data: `lib/core/{reviews,resources,professors,roles,catalog,storage,cache,heads,live}/`.
  Roles/capabilities: `lib/core/roles/{roles,capabilities,role_store,session,contacts}.dart`
  (`test/core/capabilities_test.dart` reads the ARCHITECTURE.md section 4 table: keep them in step).
- User preferences sync: `settingsBox` via `lib/core/storage/overrides.dart` (JSON-encoded, ARCHITECTURE 14.3).
  New Hive boxes must be registered in three places (14.4).
- Shared widgets: `app_card, card_row, pill_button, outlined_pill, segmented, search_box, notice, page_header,
  confirm_dialog, bottom_action, count_pill, tag_badge, app_text_field` (all `lib/shared/widgets/`).
- Server: `firestore.rules`, `server/src/` (Cloudflare Worker `index.ts, hub.ts, firestore.ts, token.ts`),
  rules tests in `test/rules/*.test.mjs`, seeds in `tools/test_env/seed.mjs`, accounts in `test_env/accounts.json`.
- No Cloud Functions: the design uses client batches, rules, and the Worker (Spark plan).

## 2. Per-feature work list

Format: **Map** = tags from `UI_MAP.md`; **Files** = verified by grep; **Data** = backend per `DATA_SYNC_PLAN.md`
Stage 5 / `ARCHITECTURE.md`; **Owner specifics** = comments from the owner's board rounds
(`.superpowers/proposed_boards/comments_round3.md`, `flow_brief.md`, `flow_brief2-5.md`,
`proposed_boards_report.md`) and answers in `PROPOSED_FEATURES.md` Open questions. Later statements win.

### 1. Star ratings while adding courses (screen: AddCourse sheet)
- Map: AddCourse: result row `CHANGED shows stars and review count`; `Add to semester` button `CHANGED no SGPA preview`;
  AddCourseRatingsOff `NEW notice Ratings did not load · rows show no stars`.
- Files: `lib/features/semester/add_course_sheet.dart` (`_HitRow` ~line 712; `AddCourseSheet`), `add_course_controller.dart`;
  rating source `lib/core/reviews/review_store.dart` (stats docs; `ReviewStats` in `review.dart`); `Stars` in
  `lib/features/reviews/review_widgets.dart`.
- Data: one rating summary per course per campus (DATA_SYNC_PLAN Stage 4: reviews on the edge cache). Reuse the existing stats docs; no
  per-row reads.
- Owner specifics: the button reads just "Add to <semester>", drop the "SGPA 9.17 -> 9.22" preview (comments_round3). A course
  with no ratings shows "No ratings yet". Failure shows the amber notice, rows without stars (never a spinner).
- Accept: rows show average + count; no SGPA text on the button; offline/failed load shows the notice.
- Owner specifics (chat): show the star rating in the add-course flow (owner chat, 2026-09-30).

### 2. Forced reviews (Reviews, ReviewsLocked, CompulsoryPick, Unlocked; DeptHome/AdminHome switch)
- Map: ReviewsLocked `NEW rule needed = min(electives taken, 5)`, `applies only once 2-1 is complete; first year and 2-1 never locked`,
  `never locked when no electives taken`, `NEW banner Reviews are locked · no count shown`, `NEW button Review your electives -> CompulsoryPick`,
  `CHANGED search and course rows locked`. CompulsoryPick (all NEW): elective checkbox (last semester preselected), course name -> ReviewForm,
  stars row 1, Would-you-take-it Yes/No row 1, Grade dropdown row 2, Marks field row 2, "Add another elective" search, `Post N reviews` posts all,
  unlock when posted reviews reach the needed number -> Unlocked -> Done -> ReviewsHome. DeptHome and AdminHome: `NEW row Compulsory reviews -> CompulsorySwitch`
  (pills Campus for admin/owner, switch -> SwitchOn dialog Cancel / Switch on, text "Turned on by, since").
- Files: new `lib/features/reviews/compulsory_pick.dart` (+ gate logic in `lib/core/reviews/`); gate in `reviews_home.dart`,
  `course_reviews.dart`; switch rows in `lib/admin/maintain.dart` (DeptHome) and `lib/admin/admin_home.dart`; routes in `routes.dart`/`router.dart`.
  Reuse `Stars`/`StarPicker`, `ReviewFormPage` (`review_form.dart`).
- Data: `config/public.reviewGate = { on, min: 5 }` set by owners/admins/presidents/secretaries (audited); `reviewCounts/<uid-hash> = { n }` incremented in
  the same batch as each review (rules verify the review id is new). Imported reviews (`source: imported`) never count. Only HEL/DEL/OPEL count,
  enforced in the app (never CDCs). Worker issues a signed "unlocked" token (can follow; client first).
- Owner specifics: (a) lock hides ALL reviews and also course-search review results; resources stay open (Open question 1 answer). Stars-only
  forced review is allowed per the DATA_SYNC_PLAN 5.1 ("stars and would-take required, text optional"). (b) Banner does NOT show the count (flow_brief).
  (c) The requirement is min(electives completed, 5). (d) Lock applies once 2-1 has grades, i.e. a student in 2-2 or later (flow_brief2 ruling).
  (e) Tapping a course name opens the normal review form (reuse ReviewForm); "Post N reviews" posts everything inline and must not open another
  screen; "Would you take it" Yes/No is required; grade and marks sit on a second row (comments_round3).
- Accept: unit tests for the gate (first-year, 2-1, no electives, min(n,5)); locked state hides lists and search; unlock after posting.
- Owner specifics (chat): triggerable by admin (owner chat, 2026-09-30). Count needed is min(electives taken, required) (owner chat, 2026-10-02). Lock applies only after 2-1 is completed: year 1 has no electives and in 2-1 students need reviews to pick (owner chat, 2026-10-02). Preselect last semester's electives, student can change the selection; HEL/DEL/OPEL only, never CDCs.
- Conflict: the first chat message (09-30) said "min 8"; PROPOSED_FEATURES.md (updated later by the owner) and UI_MAP use 5 as the cap. Build the cap as 5 (config `reviewGate.min`): later wins.

### 3. Contributor role (Settings, Resources prompt, Apply, Pending, Contribute, More, Leaderboard, Approvals, Reason, Revoke)
- Map: Settings `NEW row Become a contributor · hidden while applied or approved, back after rejection -> Apply`.
  ContributorPrompt `NEW Not now / Apply now -> Apply`, shown on first Resources open each session, stops once applied, restarts after rejection.
  Apply: rules text (live now, approved within 15 days, points after approval), username field (explained, shown on leaderboard), inline "username taken",
  `Apply -> ContributePending`. ContributePending: "Application sent", President contact pills (Email opens mailto, WhatsApp, Call); `REMOVED Add links` until approved.
  More: `NEW card Contributor Leaderboard (bigger, top 5 with your rank, shown to everyone) -> Leaderboard`; MoreContributor: `NEW card Contribute (appears when you apply)`, removed on rejection.
  Leaderboard rows (rank, username, branch tag, points), top 5 gold/silver/bronze + two soft purple, "You" highlighted; empty "No contributors yet".
  Contribute: pills All/Awaiting/Approved/Rejected, link rows with state chip (+reason when rejected) -> ContributeEdit, Add links -> ContributeAdd, points text.
  ContributeAdd: pills Department / A course, department dropdown (any on campus), course search (any), name + link per link, Another link, Publish (toast -> Contribute).
  ContributeEdit: name, link, Save, no delete. ContributeStaff: staff links publish directly, no approval states. Approvals (DeptHome/AdminHome row
  "Contributor approvals"): tabs Applications / Links, Approve all, Application row Approve/Decline -> Reason, Link request row (links open) Approve/Reject -> Reason,
  Contributor row Revoke -> Revoke dialog (Keep / Revoke). Reason sheet: presets, note (they see it), Send.
- Files: Settings rows `lib/features/settings/settings_view.dart`; prompt in `lib/features/resources/resources_page.dart` (`ResourcesPage`);
  More/Leaderboard `lib/features/more/more_page.dart` (`_MoreCard`); new `lib/features/contribute/` (apply, pending, contribute, add, edit, leaderboard);
  approvals `lib/admin/` (new `approvals.dart`, wired from `maintain.dart` DeptHome and `admin_home.dart`); link creation reuses `lib/admin/dept_resources.dart` `_LinkSheet`
  and `lib/core/resources/resource_store.dart`; grant form `lib/admin/grant_form.dart`; capabilities `lib/core/roles/capabilities.dart`.
- Data (DATA_SYNC_PLAN 5.2): `contributorRequests/<campus>|<dept>|<email>`; grant `contributor|<campus>|<email>` campus-wide, no expiry; links created live
  `status: published, approved: false, publishedAt: request.time`, copied into `links`, listed in `pending/<campus>|<dept>`, one batch; approve = `approved: true`, +4 points, drop from
  pending, audit; reject = `status: rejected` + reason; readers hide `approved:false` links older than 15 days for everyone (contributor included); `contributors/<email> = {username,campus,points}`;
  `leaderboard/<campus>`; `usernames/<campus>|<name>`. Admins/presidents/CRs are contributors by default. Batch several links into one approval entry.
  Add rules + `test/rules/*.test.mjs` cases for each. Update `firestore.rules`, seed, ARCHITECTURE.md section 4/6.
- Owner specifics: prompt wording "Contribute to the Community Now, Become a Contributor", buttons "Not Now" / "Apply Now", every app open (session) per Open question 12
  (PROPOSED_FEATURES). Do NOT print when the prompt appears (flow_brief3). Apply is a tighter sheet (no empty space; sheets sized to content). Username field help: it is the public
  contributor name on the leaderboard; "taken" error inline on Apply (no separate error screen). "Copy email" becomes a direct mailto: of the revealed method (comments_round3).
  Leaderboard card rename "Contributor Leaderboard", bigger, top 5 on More; shows every contributor's branch tag (admins/presidents/secretaries tagged by branch code); usernames only.
  Contributors may edit but not delete links; submit to any department on campus; term is until revoked; imports credit each president and secretary +4 per record; "Approve all" button at top of Approvals;
  remove the "See who contributes most on campus" line from the empty Contribute. Contribute tab appears as soon as the student applies; rejection removes it and restarts the prompts.
  Resolve note: Open Q "edit sends approved link back to pending?" is undecided (section 6).
- Owner specifics (chat): apply from Settings, plus the pop-up on opening resources; after applying show the President's contact to discuss approval (owner chat, 2026-09-30). Contributors add resources per course and per department. Leaderboard in More: chosen username, rank, +4 per contribution, campus-wide; admins, presidents and CRs are contributors by default (owner chat, 2026-09-30).
- Conflict resolved: "+4 once published" was superseded by "points count only after approval"; publish is immediate, approval within 15 days, status visible to the contributor, rule shown upfront (owner chat, 2026-09-30).
- Leaderboard is always visible to everyone; the Contribute tab appears as soon as someone applies; on rejection the tab disappears and the pop-ups resume (owner chat, 2026-10-02).

### 4. Resources by course (Resources, ResourceDegree, ResourceCourses, ResourceCourse, LinkSheet)
- Map: Resources `NEW card Degree (one per degree) -> ResourceDegree`, `NEW card Course resources -> ResourceCourses`, `REMOVED pills This semester / All (moved to Course resources)`.
  ResourceCourses: search a course (any degree), pills This semester (default) / All, course rows -> ResourceCourse. ResourceCourse: link rows (open URL), More options -> Report sheet,
  CR contact pills (Email, WhatsApp, Call), "Last updated Mon YYYY" beside the CR, `Add a link` (staff + contributors) -> LinkSheet. LinkSheet `CHANGED also opens from the student course page`.
- Files: `lib/features/resources/resources_page.dart` (`ResourcesPage`, `LinkRow`, `_ReportSheet`, `ResourcesEmpty`), `lib/features/more/more_page.dart` (card pattern to mimic),
  `lib/admin/dept_resources.dart` (`_LinkSheet`: extract to a shared widget rather than copying), `lib/core/resources/`.
- Data: rules already allow course-scoped links; client only (ARCHITECTURE 6, 10.4).
- Owner specifics: build from the More tab layout and reuse code; one card per degree that expands its department links in place, plus a Course resources card (flow_brief2 ruling). "No resources" empty
  page stays as it is. No degree barrier on Course resources. Reached also from Course reviews (feature 10).
- Owner specifics (chat): adding a resource per course did not exist; add it. The Course reviews page has a button straight to that course's resource page with the handout links already added (owner chat, 2026-09-30).

### 5. Professors (DeptProfessors, ProfessorAdd, ProfessorDelete)
- Map: DeptProfessors `CHANGED button Add a professor · always enabled -> ProfessorAdd`, `NEW icon Merge in the pill -> ProfessorMerge` (existing screen), `NEW icon Delete in the pill -> ProfessorDelete`, `NEW group Removed · listed last`.
  ProfessorAdd: name field, "Possible duplicates" rows (tap to open instead), `Add` or `Add anyway`. ProfessorDelete dialog: "Reviews stay under the name", Keep / Delete.
- Files: `lib/admin/professors.dart` (`DeptProfessors`), `lib/core/professors/professor_store.dart`, `professor.dart`.
- Data (5.3): soft delete `removed: true`, audited, by that department's president; removed professors leave pickers/search, reviews stay under the name (merge and `mergedInto` already exist). Update rules + `test/rules/professors.test.mjs`.
- Owner specifics: this fixes the bug where Add is greyed until you search (PROPOSED_FEATURES 5); no professor detail screen exists, actions are icons in the professor pill (flow_brief). Warn on possible duplicates.
- Owner specifics (chat): delete a professor; the greyed-out Add is a bug (owner chat, 2026-09-30). Merge: the merged-away professor's reviews become the survivor's. Delete is soft: reviews stay, are never deleted, keep the professor's name, filters keep working (owner chat, 2026-10-02; recorded in commit 5ba2e8e).

### 6. Course delete moves to the evaluation screen
- Map: Marks `NEW icon Bin, beside Edit -> DeleteCourse`; SchemeEditor `Credits and grades -> EditCourse CHANGED (was Credits, grades and delete)`; EditCourse `REMOVED button Remove`.
- Files: `lib/features/marks/marks_page.dart` (header), `lib/features/semester/edit_course_sheet.dart` (Remove button ~line 202; confirm 'Remove this course?' ~line 98: move/reuse the dialog), `scheme_editor_page.dart`.
- Data: none. Accept: bin beside Edit with the same confirmation; Edit no longer has Remove; delete still cleans marks/links as before.
- Owner specifics (chat): move delete out of Edit to the evaluation screen, with a confirmation (owner chat, 2026-09-30).

### 7. Offshoot tab optional (Settings, Home)
- Map: Settings `NEW switch Show Offshoot tab · on by default`; HomeNoOffshoot `REMOVED tab Offshoot`, `More takes its slot`.
- Files: `lib/home_page.dart` (legacy, no dart format; destinations list + the OffshootTab body), `lib/features/settings/settings_view.dart`, `settings_controller.dart`, `lib/core/storage/overrides.dart`/`offshoot.dart`; `lib/shared/widgets/app_nav.dart` (nav changes mode at 4+ items, ARCHITECTURE 14.7).
- Data: a synced preference in `settingsBox` (add the key to the user snapshot; mind the 500 KB cap). Owner specifics: default on; flow shows an undo snackbar (proposed_boards_report, optional).
- Owner specifics (chat): a Settings option removes the Offshoot tab and More takes its slot (owner chat, 2026-09-30).

### 8. Calendar integration (Settings, CalendarFeed)
- Map: Settings `NEW row Academic calendar -> CalendarFeed`; CalendarFeed `NEW switch Show the academic calendar in Pointer · on by default`, `Copy feed link`, `Add to Google Calendar`, `Add to Apple or Outlook`; Calendar `NEW academic calendar events shown by default`.
- Files: `lib/features/settings/settings_view.dart`, new feed page under `lib/features/calendar/`, `calendar_controller.dart`; Worker `server/src/index.ts` route `GET /calendar/<campus>.ics`.
- Data (5.4): Worker builds the `.ics` from Firestore and edge-caches it; no Google Calendar write scope. Owner specifics: the feed is a Settings option, not a standalone page; the in-app calendar subscribes to it by default (flow_brief).
- Owner specifics (chat): calendar feed only, no Google Calendar writes (owner chat, 2026-09-30).

### 9. Initial data import: no screen. Owner-run script only; out of scope for the UI.

### 10. Course reviews page (CourseReviews, ReviewForm, CourseReviewsNoMatch)
- Map: CourseReviews: `CHANGED dropdown Professor (search inside, empty allowed; was pills + search)`, `Year typed, validated (was pills)`, `Semester dropdown Sem 1 / Sem 2 / Summer (was pills)`, `CHANGED pills All · Helpful · Recent · Highest · Lowest`,
  `CHANGED card Stats follow the filters, no professor name`, `NEW Average grade and marks (marks only when shared)`, `NEW grade and marks on each review`, `NEW icon Course resources -> ResourceCourse`; CourseReviewsNoMatch `NEW text No reviews match`.
  ReviewForm: `NEW dropdown Grade (Not disclosed allowed, prefilled)`, `NEW field Marks (optional, prefilled)`.
- Files: `lib/features/reviews/course_reviews.dart`, `review_widgets.dart` (`StatsCard`, `ReviewTile`, `SortPills`), `review_form.dart`, `lib/core/reviews/review_filter.dart` + `review.dart`/`review_store.dart` (add `grade`, `marks`), tests `test/core/review_filter_test.dart`.
- Data: add optional `grade` (string, "Not disclosed" valid) and `marks` (number, optional) to review docs and the rules' field whitelist; average grade/marks computed from visible reviews (marks only when present) or stored in stats. Prefill from the student's CGPA data (grade from `courses` storage); user can change it.
- Owner specifics: Professor dropdown lists professors who taught the course, empty valid; combine professor + year + semester + sort; stats card follows filters; "All" is the unsorted default; the resources entry is just an icon (flow_brief), opens that course's resources with handouts; "Ordinary review" keeps staging's other filters (brief 5: staging's full filter set must remain). Grade + marks keep a small reviewer anonymous (optional marks, Not disclosed).

### 11. Your reviews page (ReviewsHome)
- Map: ReviewsHome `CHANGED pills All (default) · Helpful · Recent · Highest · Lowest · Your reviews tab`. Files: `lib/features/reviews/reviews_home.dart`.
- Owner specifics: Your reviews gets filter pills All (default) · This semester · Electives plus the sort pills (flow_brief2). No new screen (comments_round3).

### 12. Resources tab changes: see section 4 (same screens).

### 13. Elective Contributor / GEN (Appoint, RoleSwitch, DeptHome as Electives, DeptCourses claim)
- Map: Appoint `NEW row GEN · Electives (owner or admin) -> Elective Contributor`; RoleSwitch `CHANGED rows stack · Elective Contributor listed as Electives`; DeptHomeElectives `CHANGED label Electives where others show A3 or A7`, `REMOVED row Hand over`;
  DeptCourses `NEW pill Claim (GEN-prefix CDC, presidents) -> ClaimCourse` (dialog Cancel / Claim). Secretaries get the president's shared screens except Hand over and the GEN claim.
- Files: `lib/core/roles/roles.dart` (`deptOf`: unknown prefix -> GEN), `lib/admin/grant_form.dart`, `lib/features/roles/role_switch_page.dart`, `lib/admin/maintain.dart`, `lib/core/catalog/`; GEN never in setup/ProgrammePick (`lib/features/setup/`).
- Data (5.6): `courseClaims/<campus>|<course> = {dept}`; one `managingDept(campus, course)` in `firestore.rules`; GEN is a `dept` grant, per campus. Update ARCHITECTURE 4 and `capabilities_test.dart`.
- Owner specifics: GEN shown as "Electives"; claimed CDCs stay with the claiming department; roles stack, Working-as picks one at a time.
- Owner specifics (chat): one role manages all electives; privileged roles may hold it alongside their own and get mapped to its resources, reviews, structures and professors. GEN is not a selectable degree programme, it exists only to manage these resources. GEN cannot manage resources of a CDC a department already manages (owner chat, 2026-09-30).

### 14. Guided tour (Tour overlay, Settings Replay)
- Map: Home `NEW overlay Guided tour · first sign-in -> Tour`; Settings `NEW row Replay the tour -> Tour` (whole tour or one chapter). Full tour class: mermaid section 8 in `UI_MAP.md` (40 steps, 7 chapters).
- Files: new `lib/features/tour/`; hooks in `lib/home_page.dart` and `settings_view.dart`; preference `tourSeen` in `settingsBox` (synced).
- Owner specifics: students only, never on privileged screens; each step highlights a real control with one line, Skip and Next on every step, "Step n of 40 · chapter"; Skip ends the tour; Back returns; the tour moves between screens itself; shown once per account; steps reference only controls that exist (comments_round3: "look at the real screens").
  Step list/order awaits owner confirmation (section 6). No server work.
- Owner specifics (chat): runs on a student's first sign-in, students only (owner chat, 2026-09-30). It explains every feature, e.g. pull down to clear grades, tap a course to update marks, how the marks tracker works (owner chat, 2026-10-02).

### 15. Last updated (Representatives, ResourceCourse)
- Map: Representatives `CHANGED text Resources last updated Mon YYYY (per rep)`; ResourceCourse `NEW text Last updated Mon YYYY beside the CR`.
- Files: `lib/features/more/representatives_page.dart`, resources course page (section 4); writes in the stores that edit resources/structures/professors.
- Data: `lastUpdated` server timestamp on course/department set in the same batch as each meaningful edit (rules require `request.time`); only add/edit/remove of resources, structures, professors count.
- Owner specifics: text is exactly "Resources last updated <Mon YYYY>" on Representatives and "Last updated <Mon YYYY>" on the course; NO "N courses stale", no "2 semesters ago" (flow_brief, comments_round3 override PROPOSED_FEATURES 15). No separate screens.
- Owner specifics (chat): the owner asked for it (owner chat, 2026-09-30); details as above.

### 16. Weekly calendar (Calendar, CalendarWeek, ClassSheet; planner DEFERRED)
- Map: Calendar `NEW tabs Month · Week`; CalendarWeek: prev/next week, Today, hourly axis 8 AM-7 PM scrollable, Mon-Sat columns (Sun only with events), Now line, class blocks (code, name, room, start/end) -> ClassSheet, "Your time" tag, evaluative blocks -> Marks, all-day strip from the campus feed, `REMOVED cell Day grid`.
  ClassSheet: details, Open course -> Marks, Change time (only for me, day/time pickers), Reset to the published time, Remove from my timetable (confirm). TimetablePlanner: all DEFERRED, do not build.
- Files: `lib/features/calendar/calendar_page.dart`, `calendar_controller.dart`; published timetable: new data in `lib/core/` (owner publishes via `lib/admin/publish_page.dart` flow; scope to confirm).
- Owner specifics: class blocks show classroom and a shortened course name plus code and time (flow_brief3); "Remove from my timetable" only hides it from the timetable, grades stay; per-student time override stored in the user's data.
- Owner specifics (chat): week view has a time axis; a class shows classroom, course code, name and timings; users can delete a course from this timetable and change its timing locally, only for themselves. Deferred generator: the owner publishes the semester timetable, CDCs are added by degree and current semester, a non-clashing electives list disappears after finalising; build the current UI so this can be added without rework (owner chat, 2026-10-02).

### Other tagged edits (not numbered features)
- Marks divergence: `UI_MAP` Marks `CHANGED card Diverged · Keep my marks · Use official`, sits at the bottom of the screen; the full evaluative list takes its old place. One line saying what changed. File: `lib/features/marks/marks_page.dart`, `official.dart`. (flow_brief2 ruling; flow_brief3 C6.)
- AddEvaluative: `CHANGED` Date / You / Out of / Avg labels one weight, smaller, regular; Part n, published average and LIVE tag regular weight, one size; helper text exactly "Averages fetched from the server". File: `lib/features/marks/add_evaluative_page.dart`.
- Offshoot: remove the "RESTORED" text, keep Minor (flow_brief3 C5). Files: `lib/features/offshoot/offshoot_panel.dart`, `minor_panel.dart`. Check this against staging first; change only if it exists.
- Home with Offshoot off: see item 7.

## 3. Suggested order (small shippable commits, each with tests)

1. Client-only, independent: item 6 (course delete), AddEvaluative/Marks tweaks, item 11 pills, item 5 add-professor fix, item 1 (ratings) if stats docs are enough.
2. Client + preference: item 7 (Offshoot toggle), item 14 flag, Settings rows.
3. Reviews data: item 10 (grade/marks fields, rules, filters), then item 4/12 resources screens and item 15 `lastUpdated`.
4. Roles/backend: item 13 (GEN, `deptOf`, claims, rules), item 5 soft delete rules.
5. Contributor system (item 3): rules + tests first, then screens, then approvals.
6. Forced reviews (item 2): needs reviews (10) and the grade/marks form; then the gate token on the Worker.
7. Calendar feed (8, Worker) then week view (16); then the tour (14) last, since it points at every finished screen.
Backend needed: 2, 3, 5 (delete), 8, 10 (fields), 13, 15, 16 (timetable data). Client-only: 1 (if summaries exist), 4, 6, 7 (pref), 11, 14.

## 4. Testing

- `flutter analyze` (CI compares to `tools/analyze_baseline.txt` via `tools/check_analyze_baseline.mjs`: no new issues) and `flutter test`.
- Existing patterns: unit tests `test/core/`, screens `test/ui/*_screens_test.dart`, `test/reviews/reviews_screens_test.dart`, `test/resources/`, `test/settings/`, `test/roles/`; fixtures `test/helpers/fake_data.dart`, `fake_seed.dart`; rules tests `cd test/rules && npm test` (Firestore emulator), seeds `tools/test_env/`.
- **Widget-test caveat:** UI-triggered Hive writes stall under fake time. Unit-test storage separately; use in-memory stores in UI tests.
- Format only new files (`dart format <file>`). Never run it on legacy files: `main.dart, home_page.dart, script.dart, course.dart, mastercourselist.dart, sync.dart, settings_page.dart` (also `main_ui_extension.dart` is CRLF, ARCHITECTURE 14.2).
- Staging check: the build signs in a named test account with `https://pointer-staging.web.app/?as=<key>` (keys in `test_env/accounts.json`; hook in `lib/core/env/test_sign_in.dart`, non-prod builds only; Playwright helpers `tools/e2e/specs/helpers.mjs`). The password comes only from the `STAGING_PASSWORD` environment variable / CI secret; never write it anywhere. Local emulator: `tools/test_env/up.sh`, then `?as=student_full`.
- Compare each changed screen against staging region by region: untagged parts must be identical.

## 5. Workflow and hard rules

- Work on `pointer-rebuild`. Never merge or push `master`; production deploy is owner-only. Pushing to `pointer-rebuild` redeploys staging through CI (`.github/workflows/deploy-staging.yml`). The owner confirms deploys.
- Never commit: `bugs/`, `bug_*.md`, `sensitive_data_NO_COMMIT/`, `tools/course_reviews_out/`, `tools/perf_out/`, `tools/e2e/perf_run.mjs`, `tools/e2e/retest.mjs`, `tools/e2e/trace_run.mjs`, `.superpowers/`.
- Never read or print the Firebase service-account key or `STAGING_PASSWORD`.
- Keep `agent_instructions/ARCHITECTURE.md` updated whenever behaviour, routes, roles or rules change (and `PROPOSED_FEATURES.md` as items ship).
- Commit messages follow the repo style: `Area: what changed for the user`, imperative-free sentence, e.g. `Reviews: a professor who no longer exists no longer means a spinner every visit`; `Nav: the pill steps aside while the keyboard is up`.
- Keep ARCHITECTURE 14.x gotchas in mind: `box.add()` int keys, Firestore `matches()` case-sensitive, snapshot 500 KB cap, course ids with duplicates (never delete a map row).

## 6. Owner decisions needed (do not invent answers)

1. Which tour steps and order (the chat only gives examples): are the 40 steps in `UI_MAP.md` section 8 final, and is that length fine with chapter Replay?
2. Does editing an approved contributor link send it back to pending? (spec says "yes they can edit"; the board drew approved stays approved, rejected goes back to waiting.)
3. Forced reviews: may presidents/secretaries switch it on only for their own campus; does turning it off need a confirmation (board: no)?
4. The Your reviews filters beyond All (board drew This semester and Electives).
5. CR tag on the leaderboard (only Admins/Presidents/Secretaries are specified).
6. Secretary: confirm the president's shared screens except Hand over and the GEN claim.
7. GEN: do Elective Contributors see Representatives/Calendar differently; where the claim flow starts (map: DeptCourses pill).
8. Settings: keep PfContribSettings as its own board or the single "Become a contributor" row (map assumes one row).
9. Weekly calendar: the owner publishes the semester timetable (owner chat, 2026-10-02); still unclear is the storage shape and the room/time source for class blocks.
10. Stats card on Course reviews: average marks computed on the client from visible reviews, or stored? (affects rules/cost).
11. Undo after course delete (board: confirm dialog only, no undo) and unexpected-error code (PTR-4F2A + Report) were proposals only: build the confirm dialog; skip the error-code UI unless confirmed.
12. Grade and marks on reviews: the chat says "marks are optional and grades can just be not disclosed" without naming the screen; the brief assumes the review form and Course reviews (feature 10). Confirm.
13. Import credit: PROPOSED_FEATURES says points go to presidents and secretaries; confirm no UI is needed.

## 7. Reference

- `agent_instructions/UI_MAP.md`: tagged map (mermaid). Legend: solid = navigation, dashed = sheet/dialog, triangle = inheritance.
- `agent_instructions/PROPOSED_FEATURES.md`, `DATA_SYNC_PLAN.md` Stage 5, `ARCHITECTURE.md`.
- Design artifact (illustrative only): https://claude.ai/artifact/K4H9w2Ad9cwdTqxPSAiWMW (owner must share it with your account; UI_MAP + PROPOSED_FEATURES win).
- Boards that go away (content merges into the screen above): PfAddCourseRated, PfReviewsFilters/ProfPick/YearSem, PfReviewGradeSheet, PfYourReviewsAll, PfResDegrees, PfLastUpdatedReps/Course, PfSettingsToggles, PfContribSettings, PfMoreContribute, PfNavNoOffshoot, PfContribPublished, PfContribStaff, PfApproveQueue/Approvals, PfApproveReject/Decline, PfProfDeleted, PfGenGrant/Home/Courses/RoleSwitch, PfForcedSearchLocked, PfTour1-3.
