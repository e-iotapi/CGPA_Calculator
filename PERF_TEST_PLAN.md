# Pointer: backend build-out plan (speed, quota, roles, degree fixes, analytics)

> **This file replaces the earlier PERF_TEST_PLAN.md** (commit 5ef00b3). Its Phase T
> (T1–T7), P0, P1 and the first P2 row are built; their full specs stay in git history.
> The rest was re-planned on 2026-09-28 after the UI rebuild finished (see
> UI_REBUILD_HANDOFF.md). Read items by id with `agent_toolchains/plan/plan.py get`.
>
> **Deprecated (cloud container):** the old §0 Step 0 cleanup, `/opt/pw-browsers`,
> `/opt/flutter`, "never `playwright install`", and the Flutter path under `/tmp/claude-0/…`.
> Locally: Flutter is `~/development/flutter/bin`; Chromium is Playwright's own download.

## Status (2026-09-28)
| Task | State |
|---|---|
| T1–T4, T6, T7 (test accounts, emulators, seed, Playwright specs, predeploy, CI) | Done |
| T5 staging | Scaffolding only; **deferred** (phones use the LAN emulator) |
| P0 perf counters, P1 `cacheFirst` | Done |
| P2 | `ContactStore.myOffer` only |
| Merge | pointer-refactor merged into **pointer-rebuild** (the working branch from now on) |

## Context
The pointer-rebuild UI is finished. `UI_REBUILD_HANDOFF.md` on it lists the backend work the UI waits for (§3, §6).

pointer-refactor holds the test environment, perf counters and the cache helper: T1–T7, P0, P1 and one P2 row. The two branches split at `8037abc` (13 vs 103 commits). A dry-run merge conflicts only in `lib/main.dart`.

**User decisions (this session):**
- Work lands on **pointer-rebuild**; pointer-refactor is merged in and retired.
- Secretary = **a flag on a dept grant**.
- Hand over **adds "Next secretary"**, built from the existing screen and checked with the UI tests.
- Single-degree M.Sc. **gets DEl1**.
- The dual-degree credit total stays **unresolved** (count both PS II rows; invent no total).
- Staging is **deferred** (use the LAN emulator for phones).
- **Scale:** all 8,000 users active on one day, across 3 campuses, with surges after evaluatives.

On Spark that is a hard ceiling of **50,000 ÷ 8,000 = 6.25 reads and 20,000 ÷ 8,000 = 2.5 writes per user per day**. The schema below is designed to that ceiling.

## UI rule (user, binding)
**No new UI code.** Every visible addition is composed only from existing widgets: the shared kit in `lib/shared/widgets/`, the manager kit in `lib/admin/widgets.dart`, and existing screen patterns. No new widget classes, no custom painters, no new styles or tokens. A new page is a copy of an existing screen's structure (`Loaded` → `PageFrame` → `PageHeader` / `RowGroup` / `CardRow` / `MiniChip` / `Notice` / `BottomAction`) with different data. Where the kit has no piece for something (e.g. a chart), show it as rows of numbers instead.

## 0. Merge (I run git, as the user allowed on 2026-09-28; never merge to or push master)
1. On pointer-rebuild, record the finished UI's baseline first (handoff §6): `pip install --user pillow numpy`, then `python3 agent_toolchains/ui_check/ui_check.py run` → `accept`. I run this.
2. `git checkout pointer-rebuild && git merge --ff-only origin/pointer-rebuild && git merge pointer-refactor`. Commits go through `commit.py`, which pushes to pointer-rebuild only. Update the git-preference memory to match.
3. I resolve `lib/main.dart`:
   - keep rebuild's lines
   - re-add refactor's `configureEnv()`, `if (isTestEnv) await testSignIn();`, the `Perf.time` wrappers and `openSharedCache()`
   - `main.dart` is legacy, so edit by hand and never format it
4. Gates (handoff §5.1): `agent_toolchains/code/verify.py` passes, the `known` maps stay empty, and `ui_check.py run` shows **no new issues** against the step 1 baseline.
5. Tool tweaks in the same commit:
   - `rules.py` `sh()` PATH: prepend `~/development/flutter/bin` (the `/opt/flutter` path is cloud-only, so it is deprecated)
   - `plan.py`: `FILES += ['PERF_TEST_PLAN.md']`, and the `NUM` regex takes `[A-Z]\d+[a-z]?` so `P2b` parses
   - `playwright.config.mjs`: use `/opt/pw-browsers` only if it exists
6. Doc cleanup in `PERF_TEST_PLAN.md`:
   - a Status block
   - mark cloud-container text as `> Deprecated (cloud container)`: §0 rule 2, the T6 `/opt/pw-browsers` line, `PERF_BASELINE.md`'s egress note, the handoff's `/opt/flutter` lines
   - replace §0.5's budget with §A.3 below, and P2/P2b/P2c/P3.2/P3.7/P5 with §B
   - retire the F2 "new role + seats" design

## A. Database schema (as the Firebase console shows it)
Firestore bills per **document returned** (at least 1 per query) and not by path depth. Latency is per **sequential hop**. So each screen should be served by one document that already holds its summary. That document is written in the same batch as the source doc and checked by rules with `getAfter`, the same pattern as today's review counters and `resourceVersions` bump. No Functions, no Blaze.

### A.1 Tree (`📁 collection / 📄 {id} → fields`; NEW = proposed, CUT = dropped)
```
📁 heads                                                     NEW  one per campus (goa, hyderabad, pilani)
  📄 {campus} → catalog:int, contact:{…public contact…}, resources:int,
                reps:{ {dept}: int }, offerings:{ {courseId}: int }   (current term only)
📁 users
  📄 {uid} → rev:int, data:string(<500 KB), v1?:string, updatedAt
📁 people      📄 {email} → name, campus, firstSignIn, lastSeen NEW   (written ≤ once / 7 days)
📁 analytics                                                 NEW  owner-read only (§D)
  📄 {yyyy-mm-dd} (IST day) → {campus}: { dau:int, new:int, h:{ {00..23}: int },
                              reads:int, writes:int, pushes:int }, sample:20
📁 owners      📄 {email} → active, name, auditId
📁 grants      📄 {role|campus|scope|email} → role(admin|dept|course), campus, scope, email,
                programme?, secretary?:bool NEW, active, expiresAt, name, grantedBy,
                grantedAt, handedTo?, expiresBefore?, auditId
📁 staff       📄 {email} → presidentOf[], courses[]          (secretaries sit in presidentOf)
📁 staffContacts 📄 {email} → name, phone, email, updatedAt
📁 directory   📄 {email} → name, campus, roles[], email, whatsapp, phone, updatedAt   (admin screens)
📁 repIndex                                                  NEW
  📄 {campus|dept} → reps:{ {email}: {name, tier(president|secretary|cr), scopes[],
                     phone?, whatsapp?, email?, until} }
📁 volunteers  📄 {campus|course|email} → name, email, campus, courseId, dept, term, open,
                createdAt, closedBy
📁 audit       📄 {autoId} → actor{email,name}, action, path, campus, course?, at, before?, after?
📁 config      📄 grantTerms → term lengths      📄 public → contact (mirrored into heads)
📁 catalog     📄 marker → version, schema       📄 v{n} → bundle
📁 courses
  📄 {courseId} → id, title, credits, retired, elective, draft, auditId, updatedBy, updatedAt
     📁 offerings 📄 {campus_term} → courseId, campus, term, weighted, totalMarks, outOf? NEW,
                  components[…], courseAverage?, professors[], updatedBy, updatedAt, auditId
     📁 stats     📄 {campus}|{campus_prof} → count, starSum, recommendCount, …
                  (old app versions still write these; new client stops reading them)
📁 reviewIndex                                               NEW
  📄 {campus} → c:{ {courseId}: [count, starSum, recommendCount] }
📁 reviews
  📄 {courseId}
     📁 campus                                               NEW  (campus sandbox kept: 1 doc per campus)
       📄 {campus} → r:{ {reviewId}: {s:stars, y:recommend, t:text, term, p:professorId,
                        h:helpful, at} }                     (visible reviews only)
     📁 entries   📄 {sha256(uid+course)} → the full review (the source of truth; moderation)
        📁 votes 📄 {hash} → createdAt      📁 reports 📄 {hash} → createdAt
📁 professors  📄 {autoId} → name, campus, department, aliases[], nameTokens[], mergedIds[], active
📁 resources   📄 {autoId} → full link doc (source of truth)
📁 resourceVersions
  📄 {campus} → v:int, links:{ {id}: {t,u,k,d,c[],p,by,at} }  NEW map = the campus resource index
📁 resourceFlags 📄 {id} → …     📁 resourceReports/{id}/entries/{hash} → …
📁 reports     📄 {autoId} → write-only
CUT: users/{uid}/meta/rev, offeringVersions/*, seats/*, directory.scopes[], resourceVersions.depts
```

### A.2 Reads per screen: today vs proposed (one student, first visit of the day)
| Screen | Today (hops · docs) | Proposed (hops · docs) | How |
|---|---|---|---|
| Open app: sync | 1 · 1 full doc (≤500 KB) **every open** | 1 · **1 per 24 h**, ~0 bytes when unchanged | query `users where __name__==uid and rev > localRev`: returns 0 docs (billed 1) when unchanged |
| Open app: roles | 2 serial · 2 per open | 1 · 2 per **7 days** | `Future.wait`; refresh on sign-in; rules enforce anyway |
| Open app: catalogue + contact | 1–2 · 1 per open | 1 · **1 per 12 h** (`heads/{campus}`) | head says what moved |
| Open app: offerings | 6 serial · 6 | 0 · 0 | only on Marks, only if `heads.offerings[c]` moved |
| Marks page | 1 · 1 | 0–1 · 0–1 | fetch the offering only when its head version moved |
| Representatives | 1+6 serial · 100–300+6 | 1 · 2–4 + 1 | `repIndex` for myDepts ∪ depts(taking) in parallel, when `heads.reps[d]` moved; `myOffers` = 1 query |
| Reviews home | 7 serial · 16 | 1 · 1 per 12 h | `reviewIndex/{campus}`; most reviewed sorted client-side |
| Course reviews | 2 · 20 + profs | 1 · 1 | `reviews/{c}/campus/{campus}`; sort, page and per-professor stats client-side |
| Professor page | 2 · 1 + n | 2 · 1 + n | unchanged (rare) |
| Resources | 2 per dept serial · 1 + 20–60 each | 1 · 1 when `heads.resources` moved | `resourceVersions/{campus}.links` |
| Resources header | 1 per rebuild | 0 | contact comes from `heads` |

### A.3 Budget at 8,000 active users per day, 3 campuses
| Per user per day | Average user (opens 3×, Marks) | Surge user after evaluatives (5 opens, 3 Marks, More pages, 1 review) |
|---|---|---|
| heads | 1 | 2 |
| sync check | 1 | 1 (+1 on a conflict) |
| roles | 0.3 | 0.3 |
| offerings that moved | 1 | 3 |
| reps / reviews / resources | 0 | 1–4 / 2 / 1 |
| **Reads** | **≈ 3.3** | **≈ 10–13** |
| push (1 write, rules-guarded, no read) | 1 | 2 |
| recordSignIn | 0.14 | 0.14 |
| analytics (1 in 20 users, ~3 hourly pings) | 0.15 | 0.15 |
| review (entry + stats + index + campus doc) | 0 | 4 (rare) |
| **Writes** | **≈ 1.1** | **≈ 2–6** |

- If 80% of users are average and 20% surge: ≈ 8,000 × (0.8×3.3 + 0.2×12) ≈ **40 k reads (81%)** and ≈ 8,000 × (0.8×1.1 + 0.2×3) ≈ **12 k writes (59%)**.
- Every surge user fits under the hard ceiling on reads only if the average stays at or below 3.5. The quota specs enforce:
  - **average ≤ 4 reads / ≤ 1.5 writes**
  - **surge ≤ 13 reads / ≤ 6 writes**
- Past the quota: `resource-exhausted` is treated as offline and the cache is served (unchanged).
- Write contention: a `heads` doc is bumped only by CR offering saves, resource writes, rep changes and publishes (dozens a day per campus, far under 1 write per second). Review writes don't touch `heads`.
- Doc size ceilings:
  - `reviews/{c}/campus/{campus}` reaches about 1,200 reviews at 800 B each before the 1 MiB cap. Leave `// ponytail: shard by year past ~1,000 reviews`.
  - `resourceVersions/{campus}` is about 120 KB.
  - `heads` is about 15 KB.

### A.4 Sync without the meta doc (replaces P3.2 and P3.6)
- **Push:**
  - `update({'rev': base+1, 'data': cur, 'updatedAt': serverTimestamp})`: 1 write, 0 reads. `update` leaves `v1` alone.
  - The rules add `request.resource.data.rev == resource.data.rev + 1` on update.
  - A denial is a conflict: `pull()`, and the server wins with a backup (today's behaviour).
  - The doc not existing, or no successful transaction push yet on this device (`_meta['v1ok']`), uses today's transaction path, which keeps the one-time `v1` copy.
  - Debounce goes from 1.5 s to **30 s**, plus a flush on `visibilitychange` hidden and `pagehide`, through `core/platform/browser*.dart`. Local data is safe in Hive meanwhile.
- **Pull:**
  - the `rev > localRev` query at most once per 24 h, on sign-in and when a push conflicts
  - the first open on a device keeps today's blocking pull; otherwise it's non-blocking (P3.1)
  - **Verify on the emulator first** that rules allow the `__name__ ==` list query. Fallback: `get()` once per 24 h.
- Old cached app versions write `rev = server+1` through a transaction, so they still pass the new rule.

## B. Work queue (in order, one commit each, checked with `verify.py`; `--affected` once built)
1. **Speed tools (§C).**
2. **Baseline:** `tools/test_env/up.sh` in a terminal tab; the perf and quota specs; numbers into `PERF_BASELINE.md` and `QUOTA.md`. Also a smoke check of each `?as=` role in the browser pane, reading `window.pointerPerf`.
3. **Handoff §3.10, links to any website:** loosen the `url` rule to http(s) with a host, drop `allowedHosts` in `resource.dart`, keep `normaliseUrl`/`kindOf`, and add a rules test.
4. **Handoff §3.2, Graded out of:**
   - `Offering.outOf` in `toMap`/`fromMap`/`copyWith`
   - `offering_scale.dart` seam filled in, with `outOfStored = true`
   - the `official_scheme.dart` sync with a keep-your-own-edit detach
   - `eval_import.dart` accepts `outOf` and keeps it on import
   - all four `Offering(` sites carry it (handoff §4.3)
   - flip the tests in `offering_scale_test.dart` and step11 "bounds the average"
   - The offerings rule has no `hasOnly`, so no rules change.
5. **Handoff §3.9, departments per campus:** a const `campusProgrammes` in `core/models/programmes.dart` from `DISCIPLINES_GOA_HYD.md`; `CampusDepartments` maps them through `departmentOfProgramme`; set `departmentSource`. No Firestore.
6. **Handoff §3.5, direct reads behind stores:**
   - `RoleStore.publicContactWithAudit`
   - `MaintainStore.campusOfferings(campus, term)` for Open as
   - `RoleStore.grant(id)` for succession `_myGrant`
7. **`heads/{campus}` + sync (§A.4) + throttles:**
   - roles every 7 days, `recordSignIn` every 7 days, catalogue and contact from `heads`
   - `heads` written in the batches of CR offering saves (`maintain_store`), resource writes, rep changes, catalogue publish and the contact save; rules check the bump
   - rules tests
8. **Index docs:** `reviewIndex`, `reviews/{c}/campus/{campus}` (save, vote, moderate batches), `resourceVersions.links`, `repIndex` (saveProfile, appoint, revoke, handOver batches).
   - Each has a rules check through `getAfter` that only the writer's own key changed and that it matches the source doc. Each has rules tests.
   - **Store signatures stay the same** (handoff §1 contract): `stats`, `mostReviewed`, `page`, `byProfessor` and `department` read the cached index docs inside. Only `ContactStore.directory` changes to `directoryFor(campus, depts)`, and `representatives_page.dart` rewires in one line (F1).
   - Admin screens pass `fresh: true` (optional, backward compatible) to read live.
8b. **Review search and filter by year and semester (new UI).** `reviews/{c}/campus/{campus}` already holds every visible review of the course, so filtering costs **0 extra reads**. It all runs client-side over the cached doc.
   - **Core:** `lib/core/reviews/review_filter.dart`, pure and tested.
     - `ReviewFilter({String? year, String? sem, String query})`, where `year` is the academic year taken from `term` (`'2025-26-1'` → year `2025-26`, sem `1`/`2`/`S`, per `currentTerm` in `features/marks/official.dart`)
     - `apply(List<Review>)` matches the query case-insensitively against review text and professor name
     - `yearsIn(reviews)` gives the choices, newest first
     - `ReviewStore.page(...)` gains an optional `filter` parameter (backward compatible) applied before sort and paging
   - **UI:** Course reviews (`features/reviews/course_reviews.dart`) and Professor reviews (`professor_reviews.dart`), existing widgets only, placed where the reviews home already puts its `SearchBox` and pills:
     - a `SearchBox` ("Search reviews") through the existing `Debouncer`
     - a `SelectRow` "Year" opening a sheet (All years + `yearsIn`)
     - `ChoicePills` "All / Sem 1 / Sem 2 / Summer"
     - the count line "n of m reviews"
     - empty state: the existing no-match card pattern with a "Clear filters" `TextLink`
     - the summary card (stars, % would take it) follows the filter, so it reads e.g. "2024-25 · Sem 2"
   - The admin `DeptReviews` gets the same year and semester pills over its `moderation()` results (client-side; no new query).
   - **Tests:**
     - `test/core/review_filter_test.dart`: year and semester parsing, including the summer term and empty `term` from old reviews (they go under "All years" only), plus query matching
     - render entries at 390/320, light/dark and 150% text, with seed reviews across 3 years and all semesters in `fake_seed.dart`
     - a behaviour test that picks year, semester and query and checks the "n of m" line
     - `ui_check run --only` for both screens, 0 new issues
9. **Secretary (handoff §3.1, flag design):**
   - `Grant.secretary`, and secretaries join `presidencies`, so every president screen and rule applies automatically
   - rules: `handsOver`/`cancelsHandover`/the own-grant succession update and `mayGrant(dept)` require `!secretary` for the actor
   - presidents may create a `secretary:true` dept grant in their own scope with `programme` null; secretaries may appoint CRs through the existing president path
   - `capabilities.dart` plus an ARCHITECTURE §4 row for `handOver`
   - "one per department" is checked in the app from `roster`: `// ponytail: app-side uniqueness, move to a rules seat doc if duplicates appear`
   - UI: pass the flag in `grant_form._grant()`, drop `!_secretary` from `_ready` and the caption, set expiry to the president's, hide Hand over on `DeptHome` when `grant.secretary`
10. **Hand over + Next secretary:**
    - STEP 1 gains an optional "Next secretary" field: a second instance of the **same** successor lookup field and its checks, with no new widget
    - Confirm's HANDING OVER card lists both people and the shared end date
    - `RoleStore.handOver(mine, email, {secretary})` adds the new secretary grant (expiry = new president's) and shortens the outgoing secretary to ≤ 20 days in one batch; rules allow it only inside a handover by that department's president
    - cancel restores both
    - UI checks: render tests plus `ui_check run --only` for the handover screens, 0 new issues; update label finders in the same commit
11. **F1:** `representativesFor` / `myDepartments` (pure, tested), with `representatives_page` using them.
12. **P6:** sign-out and account-switch hygiene (clear the personal boxes; `restoreMyRoles` checks the email).
13. **Degree fixes D1–D4, D6:** `isDualDiscipline` replaces every "is dual" `startsWith('B')`; `semestersFor`; dual PS II ×2 (`BITS F412#2`) with an idempotent migration; DEl1 for single M.Sc.; pickers include B codes. D5 only counts both PS II rows, with no invented total.
14. **P4.1** `_dirty` flag, **P4.5** `putAll`. P4.2–4.4 wait for a throttled profile.
15. **Site analytics backend and owner dashboard (§D).**
16. **P7** deferred libraries, later.
16. Tick the handoff §6 boxes as items land.

**Cut:**
- P2b `scopes`, its index and fallback (replaced by `repIndex`)
- P2c `depts` (replaced by `links`)
- P3.2 meta doc and P3.7 `offeringVersions` (replaced by `heads` and §A.4)
- F2 seats and the new role (replaced by the flag)
- §3.4 count queries (admin-only, few users)
- the §3.8 duplicates endpoint (keep client-side `NameDuplicates`; there are no Functions on Spark)
- P5's move of load logic into core (signatures stay, so screens don't change)

## C. Speed tools (about 150 lines)
1. **`verify.py --affected`:** a cached import graph of `lib/` and `test/`; runs only the tests that reach changed files; the full suite when `main.dart`, `sync.dart` or pubspec changed, and once per group.
2. **Warm rules tests:** `test/rules` `"test:warm"` runs `node --test` against the emulator `up.sh` keeps running. `verify.py` runs it when `firestore.rules` or `test/rules/**` changed.
3. **`test/quota/busy_day_test.dart`:** the average and surge days at store level on `fake_cloud_firestore` with Perf counters, in seconds. The E2E `quota.spec` stays the gate before deploy (it bills rules `get()`s).
4. `up.sh` runs once per session in a background terminal. Re-seed only when a shape changes; the seeder learns `heads`, the index docs and secretary grants.
5. **With the user's OK at start:** run D (13) in a parallel worktree agent while the main thread does 7–10.

## D. Site analytics (handoff §3.3), Spark-only, owners only
**The constraint:** a write per active user per day would be 8,000 writes, or 40% of Spark. Nothing third-party is used; gtag already exists, but this dashboard must be self-contained and free.

**Collection: sampled daily counters plus free aggregate counts.**
- **Sampled activity.**
  - `sampled = int(sha256(uid + day)[0..8], 16) % 20 == 0`: a stable 1-in-20 per day, rotating daily so every user is sampled over time.
  - A sampled client's first open of the IST day does one `set(merge)` on `analytics/{day}` with `FieldValue.increment`: `{campus}.dau +1`, `{campus}.h.{HH} +1`, `{campus}.new +1` if `firstSignIn` is today, and `{campus}.reads/writes/pushes += yesterday's own counts`.
  - Its first open in each later hour adds `h.{HH} +1`.
  - Cost: about 400 users × ~3 = **~1,200 writes a day (6%)**, 0 reads.
  - The dashboard multiplies by `sample` (20). The ±5% error at 8,000 users is shown on screen as "≈".
- **A usage counter in prod:** `core/analytics/usage.dart`, an always-on `Usage.read(n)` / `Usage.write(n)`, a few lines called from the same sites Perf wraps. It is kept separate from `Perf`, which stays compiled out. Only sampled users report it. It gives an **estimated Firestore reads/writes per day against Spark's 50k/20k**, the early warning before a surge breaks the app.
- **Free aggregates, owner only.** `count()` queries cost 1 read per 1,000 entries:
  - total users: `count(people)`, and per campus
  - new users in the last 7 and 30 days: `count(people where firstSignIn ≥ …)`
  - WAU and MAU: `count(people where lastSeen ≥ now−7d / −30d)`. `recordSignIn` also sets `lastSeen` (still ≤ once per 7 days), so WAU is approximate; label it "active this week (±7 d)".
  - users by batch: `count(people where __name__ ≥ 'f2023' < 'f2024')`, per campus by address suffix, done client-side over the few batches
- **Rules:**
  - `analytics/{day}`: `create`/`update` if `mayUse()`; the change only touches the caller's own campus key; `dau`, `new` and `h.*` rise by exactly 1; `reads`/`writes`/`pushes` rise by 0–5,000; `get`/`list` if `isOwner()`. `// ponytail: sampling is not verified server-side; a forged ping only skews stats`.
  - `people`: `list` if `isOwner()` (needed for count), and `lastSeen` added to `hasOnly`.
  - Rules tests for both.
- **Store:** `AnalyticsStore` in `core/analytics/analytics_store.dart`:
  - `days(n)` reads the last n day docs, n ≤ 30, so ≤ 30 reads per dashboard open (owners only)
  - `counts()` holds the aggregates, about 10 reads
  - `today()` is cached 5 minutes
  - `recordOpen()` is called post-first-frame in `startApp`; it's a no-op unless sampled, and throttled by `deviceBox['anaDay']`/`['anaHour']`

**Dashboard:** `lib/admin/analytics_page.dart`, route `/admin/analytics`, owner-only redirect through the new capability `viewAnalytics` (owner ✓, everyone else —; ARCHITECTURE §4 row plus the capabilities test).
- Wire the disabled "Site analytics" row in `admin_home.dart` (~line 253) to the route. Add the `landing/_redirects` line.
- Built only from the kit (§2 of the handoff): `Loaded` → `PageFrame`, `PageHeader(eyebrow: 'OWNERS ONLY', title: 'Site analytics')`, and campus `ScopePills` (All / Goa / Hyderabad / Pilani).
- **The page copies Controls' structure** (`admin_home.dart`: an ink card plus `RowGroup`s of `CardRow`s with subtitles and `CountBadge`s). No new widgets, and no charts (`CgpaChart` is CGPA-specific).
- **`InkCard`:** Users · New (7 d) · DAU ≈ today.
- **`RowGroup` "ACTIVITY":** `CardRow`s for WAU, MAU, and Peak hour today ("≈ n at HH:00", with a mint `MiniChip`).
- **`RowGroup` "LAST 30 DAYS":** a `SliverRowGroup` with one `CardRow` per day ("Mon 12 Oct" · "≈ 1,240"). The peak day gets a mint `MiniChip` "PEAK".
- **`RowGroup` "TODAY BY HOUR":** the hours with activity only, same row pattern.
- **`RowGroup` "BY BATCH":** `CardRow`s.
- **Spark quota:** two `CardRow`s ("Reads ≈ 31k of 50k", "Writes ≈ 9k of 20k"), with an `AmberPill` past 70%, plus the existing `Notice` stating it's an estimate from 1 in 20 users.
- **Tests:**
  - `sampled()` distribution (about 5% over 10k fake uids) and stability
  - increment rules
  - an `AnalyticsStore` scaling test
  - render test entries (390/320, light/dark, 150%) in `test/ui/manager_screens_test.dart` with fake analytics seed in `fake_seed.dart`, plus `ui_check run --only analytics`
  - the demo picks the seed up
- **Skipped:** real-time concurrent users (it needs a listener or presence writes, so it's too costly on Spark; the peak hour stands in), and per-screen funnels. Add those only if the owner asks.

## Verification
- `verify.py` passes (format, analyze baseline, full tests); the rules tests pass; `known` maps are empty.
- `ui_check run` against the pre-merge baseline: 0 new issues. CHANGED only on the Grant form, DeptHome and Hand over (intended).
- The quota specs meet §A.3's targets; the numbers are in `QUOTA.md`.
- The perf spec: More sub-pages < 1.5 s on first open and < 300 ms on second, at 4× CPU and 300 ms latency.
- `up.sh` → each `?as=` role in the browser pane shows seeded data, with no error text.
- The prod build grep guard passes, and nothing needs Blaze.
