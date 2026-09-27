# Pointer: speed, test accounts and a pre-deploy test suite (execution plan for an implementing agent)

## Context
The user reported three problems:
1. **Firestore-backed pages load slowly.** The More section is worst: 5–10 s before Representatives, Course reviews or Resources shows anything.
2. **The app is slow on older phones.** The UI rebuild on `pointer-rebuild` handles rendering. This plan handles the background work: startup, sync, maths and data access.
3. **The user cannot test.** Sign-in is Google-only, gated to BITS addresses. The user has one BITS account, and it is an owner. There is no way to see a student, CR, president or admin with realistic data, and no test suite to run before deploying.

This plan is for a cheaper agent to follow. The rules in §0 are mandatory.

**Decisions already made by the user:**
- **Test environments:** build **both** local emulators and a staging Firebase project, seeded from one config file.
- **Branch:** the work lands on **`pointer-refactor`**, starting in `lib/core` and `tools/`. Edits to screen files come last, after merging the latest `pointer-rebuild`.
- **Freshness:** show cached data **at once, with a silent background refresh used on the next open**. There must be no visible or behavioural change. The user's own writes clear the relevant cache immediately.
- **"UI"** means anything visible: layout, buttons, structure and how they behave. Changing the backend wiring is allowed. Widget trees must not change.
- **Cost:** the project must run for up to 8,000 users on **Firebase Spark and the Cloudflare Pages free plan, at no charge** (§0.5).
- **Role and representative features (Phase F):**
  - Students see only their own department's presidents and secretary. Dual-degree students see both departments, and only ELEC students see the ELEC presidents.
  - CRs are shown for the courses a student is taking now.
  - A new **Department Secretary** role: one per department per campus. A secretary sees the president's screens but has no handover, and appoints CRs only.
  - A president appoints secretaries and CRs, and at election time hands over to the **new president and new secretary together**, both terms ending on the same day.
  - CRs can come from any branch or batch as long as they are taking the course. Volunteering shows only for courses with no listed CR.
- **Degree structure (Phase D):**
  - A single degree has one PS II, in 4-1 or 4-2; a dual degree has two, in 5-1 and 5-2.
  - Every M.Sc. programme can be a single degree (stored as `"B3--"`). Today several places mistake that for a dual.

---

## 0. Rules for the implementing agent (read first)
1. Work on branch **`pointer-refactor`** only. Commit after each numbered task with a clear message. Push with `git push -u origin pointer-refactor`.
2. **Step 0 (already done when this plan was committed):** the uncommitted leftovers from the earlier session were discarded with:
   `git checkout -- lib/sync.dart lib/core/storage/cache_boxes.dart lib/features/reviews/review_widgets.dart lib/features/roles/rep_profile.dart lib/features/resources/resources_page.dart && rm lib/core/storage/boxes.dart lib/core/stores.dart`.
   Then `git status` must be clean.
3. **No UI changes.** Never change a widget tree, a text string, a layout, a colour or a navigation flow. The only edits allowed in files under `lib/features/**`, `lib/admin/**`, `lib/home_page.dart` and `lib/shared/**` are the call-site swaps named in Phase P5, and only after P5.0.
4. **Never run `dart format` on whole directories** (ARCHITECTURE §14.2). Format only new files, and files that were already formatted at HEAD.
5. **Do not break the sync format** (`lib/sync.dart`):
   - the snapshot key order stays settings, courses, offshoot, marks
   - `format: 2` stays
   - settingsBox values stay JSON-safe (§14.3)
6. **Every new Hive cache box** goes into `cacheBoxes` in `lib/core/storage/cache_boxes.dart`. `test/core/cache_boxes_test.dart` must pass.
7. **Baseline:** `flutter test` at `pointer-rebuild` HEAD gives **338 passed, 50 skipped**. After every task, results must be the same or better. Flutter 3.47.5 (Dart 3.13) is required: `pubspec.lock` needs Flutter ≥ 3.47.0.
8. **Production project id is `cgpa-calculator-fb90c`.** No seed or test script may ever write to it. Each script must hard-fail if it sees that id.
9. Code style: match the surrounding code. Doc comments cite ARCHITECTURE sections the way existing files do (`(ARCHITECTURE.md §x)`). Use `package:cgpa_calculator/...` imports in alphabetical order.

---

## 0.5 Hard constraint: free tiers only, for up to 8,000 users
The user must never be charged. Every task below is judged against this section first.

**The platforms and their free limits.** Re-check the numbers on the pricing pages at implementation time.
- **Firebase Spark plan, production and staging (each a separate Spark project):**
  - Firestore: **50,000 document reads, 20,000 writes and 20,000 deletes per day**, 1 GiB stored, about 10 GiB egress per month.
  - **Rules `get()`/`exists()` calls count as reads.** A query costs one read per returned document, and **at least 1 read even when it returns nothing**.
  - Quotas reset at midnight Pacific time (about 12:30–13:30 IST).
  - On Spark, running out **does not bill**. Firestore refuses requests (`resource-exhausted`) until the reset, so the real risk is the app breaking for everyone, not a charge.
- **No Blaze-only features, ever:**
  - no Cloud Functions, scheduled jobs or Extensions
  - no BigQuery export
  - no paid App Check providers
  - never link a billing account
  - All aggregation stays client-side in batched writes, validated by rules, as the codebase already does (review counters, `resourceVersions`).
- **Firebase Auth:** Email/Password and Google are free. Never use phone auth.
- **Cloudflare Pages, free plan:** static requests and bandwidth are free, but there is a monthly build/deploy cap and a per-file size cap. Staging deploys run **only by manual `workflow_dispatch`**, never on every push. Nothing uses Pages Functions or Workers.
- **GitHub Actions:** free for public repos. **If the repo is private, the free allowance is about 2,000 minutes/month.** So `check.yml` on PRs runs only analyze, unit tests and rules tests (about 5 min). The emulator E2E and perf specs run locally through `tools/predeploy.sh`, or by manual dispatch.
- **Emulators** are free and local. All E2E and perf testing runs there, **never against production**, and against staging only by hand.

**Read and write budget.** Plan for 8,000 users with up to 40% active on a peak day, i.e. about 3,200 daily active users (DAU):
- Reads: 50,000 ÷ 3,200 ≈ 15 per DAU per day is the hard ceiling. **Target ≤ 8** average, for headroom.
- Writes: 20,000 ÷ 3,200 ≈ 6. **Target ≤ 3.**

Where today's code stands (from reading it):

| Per app open, today | Reads | Writes | Fix (task) |
|---|---|---|---|
| `Sync.pull` full `users/{uid}` get (also up to 500 KB of egress) | 1 | – | tiny meta doc, full doc only when changed (P3.2) |
| `Sync.push` transaction `tx.get(users/{uid})`, per debounced change | 1 each | 1 each | transaction reads the meta doc; debounce 3 s plus flush on page hide (P3.6) |
| `refreshCatalog` marker | 1 | – | once per 24 h (P3.4) |
| `RoleStore.loadMine`: `owners/{me}` + grants query (≥1) | ≥2 | – | once per 6 h, served from `deviceBox` (P3.4) |
| `recordSignIn` | – | **1 per open** (8,000 DAU would use 8,000 writes/day) | once per 7 days (P3.5) |
| `refreshCurrentOfferings`: per current course, up to twice a day | **~6–12/day** (8,000 users → up to ~96,000) | – | one marker read per day plus lazy per-course reads (P3.7) |
| Representatives: `directory` query for the **whole campus** (every rep doc) + `myOffer` per course | **N reps + courses** (could be 100+) | – | query only relevant scopes (P2b), cache 24 h |
| Resources: `resourceVersions` + whole department per dept | 1 + links | – | cache 24 h; per-department versions (P2c) |
| Reviews home: stats per current course + `mostReviewed` (10) | ~16 | – | cache 12 h |

**Rules for every task:**
- Every new or changed Firestore access states its reads and writes per user per day in a comment on the function, e.g. `// Budget: ≤1 read/user/day (24 h cache).`
- The perf and quota spec (T6) **fails the build if a simulated "busy student day" exceeds 8 reads or 3 writes**. The simulated day: open the app 5 times, visit every More page twice, open 3 Marks pages, edit grades once, write one review.
- Any `resource-exhausted` `FirebaseException` is treated exactly like offline:
  - serve the cache
  - no retries within the same session, except for Sync, which retries after 5 minutes and then with backoff
  - `problem()` wording is UI, so leave it alone; the cache-first path means users rarely reach it
- Avoid rules `get()` on hot student paths. Check `firestore.rules`:
  - `mayUse()` short-circuits on `isBits()`, so students pay no owner lookup. Keep it that way.
  - Any new rule for student-frequent writes must not add a `get()`.
- New docs written by the client must stay small. Firestore storage is 1 GiB total; at 8,000 users that is about 125 KB per user, including `users/{uid}`, which the rules already cap at 500 KB.
- `QUOTA.md` in the repo: the budget table above, updated with measured numbers. It also says how to read Firebase console → Usage for both projects, and what happens when a quota runs out.

---

## Phase T: test accounts, fake data and environments (do FIRST; the user is blocked)
T must be self-contained: new files, a few lines in `lib/main.dart`, plus `firebase.json` and `tools/`. That lets the user merge or cherry-pick it into `pointer-rebuild` straight away and test the new UI.

### T1. App environment switch
- **New file `lib/core/env/app_env.dart`:**
  - `enum AppEnv { prod, staging, emulator }`
  - `const appEnv = ...`, parsed from `String.fromEnvironment('POINTER_ENV', defaultValue: 'prod')`
  - `const emulatorHost = String.fromEnvironment('POINTER_EMULATOR_HOST', defaultValue: 'localhost')`. Use a LAN IP here to test from phones.
  - `bool get isTestEnv => appEnv != AppEnv.prod`. It must be `const`-foldable so dart2js tree-shakes every test-only path out of the prod build.
- **Staging Firebase options:** `lib/firebase_options_staging.dart`, generated by the user with `flutterfire configure --project=<staging-id> --platforms=web --out=lib/firebase_options_staging.dart`. The agent writes a placeholder with the same API and a `TODO(user)` comment until then.
- **`lib/main.dart` `main()`:**
  - `Firebase.initializeApp` uses `appEnv == AppEnv.staging ? StagingFirebaseOptions.currentPlatform : DefaultFirebaseOptions.currentPlatform`.
  - Straight after init, when `appEnv == AppEnv.emulator`, call `FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099)` and `FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8085)`.
  - Put this in a function `configureEnv()` in `app_env.dart`, so `main.dart` gains about 2 lines.
- **Test sign-in with no UI change:** new function `Future<User?> testSignIn()` in `lib/core/env/test_sign_in.dart`, called in `main()` before `authStateChanges().first`, only `if (isTestEnv)`.
  - It reads `Uri.base.queryParameters['as']`, falling back to `String.fromEnvironment('POINTER_TEST_AS')`.
  - If the value is set and differs from the current user, it calls `signOut()`, then `signInWithEmailAndPassword(email, password)`.
  - The email comes from the generated account table (T3). The password comes from `String.fromEnvironment('POINTER_TEST_PASSWORD', defaultValue: 'pointer-test-only')`.
  - The existing `Sync.init` already wipes local data when the uid changes, so switching accounts via `?as=` is safe.
  - Also call `SemanticsBinding.instance.ensureSemantics()` when `isTestEnv`. The E2E tests (T6) need it to find text; production is unaffected.
- **Prod guard test** `test/env/prod_build_guard_test.dart`: checks `appEnv == AppEnv.prod` when no define is given.
- **CI guard** (T7): after `flutter build web --release`, grep `build/web/main.dart.js` for the marker string `pointer-test-only`. It must be absent.

### T2. Emulators
- `firebase.json` → `emulators`: add `"auth": {"port": 9099, "host": "0.0.0.0"}`, and set `"host": "0.0.0.0"` on firestore (the port stays 8085). Keep `ui` disabled, or enable it on port 4000 for the user's convenience.
- `tools/test_env/up.sh`:
  1. `firebase emulators:start --only auth,firestore --project demo-pointer &`
  2. wait for ports 9099 and 8085
  3. run the seed (T4) against the emulators
  4. `flutter run -d web-server --web-port 5000 --dart-define=POINTER_ENV=emulator --dart-define=POINTER_EMULATOR_HOST=${HOST:-localhost}`
  5. print URLs like `http://<host>:5000/?as=student_full` for every account
- A `demo-*` project id makes the emulators refuse to touch real services, which adds safety.

### T3. The single config file: `test_env/accounts.json`
The user edits this file to add accounts or change roles. Shape:
```json
{
  "password": "pointer-test-only",
  "accounts": [
    {"key": "owner", "email": "owner@pointer.test", "name": "Test Owner", "owner": true},
    {"key": "admin", "email": "f20209991@pilani.bits-pilani.ac.in", "name": "Test Admin",
     "roles": [{"role": "admin", "campus": "all", "scope": "all"}]},
    {"key": "president", "email": "f20239992@goa.bits-pilani.ac.in", "name": "Test President",
     "roles": [{"role": "dept", "campus": "goa", "scope": "ELEC"}], "dataset": "student_full",
     "profile": {"phone": "9000000001", "showEmail": true, "whatsapp": "9000000001"}},
    {"key": "cr", "email": "f20239993@goa.bits-pilani.ac.in", "name": "Test CR",
     "roles": [{"role": "course", "campus": "goa", "scope": "EEE F211"}], "dataset": "student_full"},
    {"key": "student_full", "email": "f20249994@goa.bits-pilani.ac.in", "name": "Test Student",
     "discipline": "--A3", "batch": 24, "dataset": "student_full"},
    {"key": "student_dual", "email": "f20229995@goa.bits-pilani.ac.in", "discipline": "B3A7", "batch": 22, "dataset": "student_dual"},
    {"key": "student_new", "email": "f20269996@goa.bits-pilani.ac.in", "name": "Test Fresher", "dataset": "first_login"},
    {"key": "student_hyd", "email": "f20249997@hyderabad.bits-pilani.ac.in", "discipline": "--A7", "batch": 24, "dataset": "student_full"},
    {"key": "president_expired", "email": "f20219998@goa.bits-pilani.ac.in",
     "roles": [{"role": "dept", "campus": "goa", "scope": "CS", "expiresInDays": -5}]},
    {"key": "faculty", "email": "testfaculty@goa.bits-pilani.ac.in", "dataset": "first_login"}
  ]
}
```
- `roles` values mirror `GrantRole` keys in `lib/core/roles/roles.dart`: `admin`, `dept` (president) and `course` (CR). **The agent must check them against `GrantRole.key`.**
- `dataset` names a generator in T4.
- `tools/test_env/gen_accounts.mjs` generates `lib/core/env/test_accounts.g.dart` (`const testAccounts = {'student_full': 'f20249994@goa…', …}`) from this file. Commit the generated file. A test checks it is in sync with the JSON.

### T4. Seed data: every page populated
Two stages, so the user's own data is produced by the **app's own code** and never hand-encoded.

**T4a. Build per-user snapshots with Dart**, in `tools/test_env/build_snapshots_test.dart`. It runs with `flutter test tools/test_env/build_snapshots_test.dart` and is skipped unless `POINTER_SEED=1`.
1. `Hive.init(tempDir)`, register `CourseAdapter` and `registerMarksAdapters()`, then `Sync.openBoxes()`.
2. Load the catalogue with `loadCatalog(asset: () => File('assets/catalog.json').readAsString(), cache: <temp box>)`.
3. For each dataset, fill the boxes through the app's existing functions:
   - **Settings:** put `selecteddiscipline`, `batch`, `campus`, `degree_selected=true`, `currentsem`, `profile1n`/`profile2n`, `comparePair`, `selected_theme`. Also the `stats_target`, `stats_plan`, `stats_skipped`, `degree_total` and `degree_needs` keys (`lib/core/storage/stats.dart`), `minor` (`lib/core/storage/minor.dart`), `offshoot_outof`/`offshoot_excluded`/`offshoot_view` (`lib/core/storage/offshoot.dart`), `overrides` (`lib/core/storage/overrides.dart`), `myReviews` (`review_widgets.dart` key) and pinned categories (`lib/core/storage/courses.dart`).
   - **Courses:** `seedCourses(discipline, chartRows(batch))` from `lib/core/storage/seed.dart`. Then set `grade1`/`grade2` on every past-semester course, using every grade code at least once: A…E, NC, RC, W, GD (`lib/core/grading/grade_scale.dart`). Mark the current-semester courses ongoing or CLR, so the "taking now" pages have data. Add electives (DEl, HuEl, OpEl) through `lib/core/models/elective.dart`, with extra profiles filled in via `Course.more`.
   - **Marks:** for every current course, add a `CourseConfig` and 4–6 `Evaluative`s through `lib/core/storage/marks.dart`, with every field populated. That includes multi-part evals, `countBest < parts`, averages, `date` values spread from −30 to +45 days of the seed date (so Calendar has past and upcoming items), `sourceId` links to seeded official schemes, and `seeded: true` placeholders.
   - **Offshoot:** add courses into `offshootBox` (see `lib/core/grading/offshoot.dart` and `features/offshoot/`).
   - **Minor:** a minor chosen with partial progress (`lib/core/models/minors.dart`).
4. Write `Sync.snapshot()` to `tools/test_env/out/<dataset>.json`.
5. Write `tools/test_env/out/<dataset>.expected.json`, holding the CGPA, SGPA per semester, credits and requirement progress, computed with `lib/core/grading/cgpa.dart` and `requirements.dart`. The E2E tests (T6) assert these values.
6. Run `Sync.validate()` on every output.

The datasets are. All of them are relative to the seed date; for today (Sep 2026) the current term is 2026-27 semester 1.
- **`student_full`: single degree, currently in 3rd year**, e.g. `--A3`, batch 24.
  - `1 - 1`, `1 - 2`, `2 - 1`, `2 - 2` and `PS 1` are graded.
  - **`3 - 1` is current**: every course is ongoing, with the evaluatives and marks described above, so Calendar, Marks, Reviews "taking now", Representatives and Volunteer all have data.
  - `3 - 2`, `ST 1` and `4 - 1` hold ungraded seeded courses.
  - **One PS II (`BITS F412`) is scheduled in the 4th year**, ungraded at `4 - 2`, the chart default.
  - Every grade code appears at least once across the graded semesters, and electives are included.
- **`student_dual`: dual degree, currently in PS II in `5 - 1`**, e.g. `B3A7`, batch 22.
  - Every semester up to `4 - 2`, plus `PS 1` and `ST 1`/`ST 2` where charted, is graded.
  - **PS II #1 at `5 - 1` is ongoing** (the current term). **PS II #2 at `5 - 2` is scheduled and ungraded.** They use keys `BITS F412` and `BITS F412#2` (D3).
  - It has a minor and offshoot data.
- **`first_login`: a first-year student opening the app for the very first time**, batch 26 (`f2026…`).
  - **No `users/{uid}` document at all** and no local data, so the app runs its genuine new-user path: `Sync.pull` sees no doc and pushes, `degree_selected` is false, and setup / programme pick appears.
  - The seeder creates **only the Auth user**; the app itself writes `people/{email}` on first sign-in. After the account is used, re-running the seed deletes its `users/{uid}` again, so it stays "first login" every time.

**T4b. Write everything to Firebase with Node**, in `tools/test_env/seed.mjs` using `firebase-admin`. Add it to a new `tools/test_env/package.json`.
- **Target:** the emulators by default (`FIRESTORE_EMULATOR_HOST=localhost:8085`, `FIREBASE_AUTH_EMULATOR_HOST=localhost:9099`). Staging via `--project <id>` plus `GOOGLE_APPLICATION_CREDENTIALS`. **Refuse `cgpa-calculator-fb90c`.**
- **Wipe first**, emulator only: use the emulator REST DELETE endpoints. For staging, delete only documents carrying `seed: true`, or the known ids.
- **Auth users:** `admin.auth().createUser({uid: key, email, password, displayName: name, emailVerified: true})`. `emailVerified` is required because `firestore.rules` `signedIn()` needs `email_verified == true`.
- **User data:** `users/{uid}` = `{rev: 1, data: <snapshot string>, updatedAt: serverTimestamp()}`. This is the shape `Sync.push` writes.
- **Shared collections.** For each one the agent **must copy the exact field shape from the named source** and must not invent fields. Rules key checks such as `hasOnly` show exactly which fields are allowed.

  | Collection | Shape source |
  |---|---|
  | `owners/{email}` | `lib/auth_util.dart` `isOwner`, rules line ~127 |
  | `grants/{role\|campus\|scope\|email}`, `staff/{email}` + `audit/{id}` | `test/rules/helpers.mjs` `appoint()` and `RoleStore` grant writes in `lib/core/roles/role_store.dart`. Every grant gets a matching audit entry and `auditId`. |
  | `staffContacts/{email}`, `directory/{email}` | `ContactStore.saveProfile` in `lib/core/roles/contacts.dart` |
  | `volunteers/{campus\|course\|email}` | `ContactStore.volunteer`. Seed: an open offer by `student_full` for a course with no CR; another open offer in ELEC so the president can dismiss it; one closed offer. |
  | `people/{email}` | `RoleStore.recordSignIn` |
  | `config/grantTerms`, `config/public` | `lib/admin/config_pages.dart` writers and `RoleStore.publicContact` |
  | `catalog/*` | `lib/core/catalog/publish.dart` + `FirestoreCatalogSource` in `lib/core/catalog/catalog_store.dart`. Publish `assets/catalog.json` as version N+1 so the "newer catalogue" path runs. |
  | `courses/{id}/offerings/{term}` | `lib/core/models/offering.dart` `toMap` / `lib/core/storage/offerings.dart`. Official schemes for the current courses of `student_full` and `student_dual`, with professors. |
  | `professors/{id}` | `lib/core/professors/professor.dart` + `professor_store.dart` (including `nameTokens`, and one merged professor for the merge screens) |
  | `reviews/{course}/entries/{id}` (+ `votes`, `reports`) | `ReviewStore.save`, `vote`, `report` in `lib/core/reviews/review_store.dart`. At least 3 courses × 5 reviews on Goa, 1 on Hyderabad, covering all star values, hidden and reported ones, and one by `student_full` so "Your reviews" is populated. Ids use `hashedId(uid, courseId)`; port that function to JS and unit-test it against Dart output. |
  | `courses/{id}/stats/{statsId}` | **Computed by the seeder from the seeded entries**, never hand-written, using the `statsId` and `ReviewStats` shape in `review.dart`. Counters must equal the entries. |
  | `resources/{id}`, `resourceVersions/{campus}`, `resourceReports/…`, `resourceFlags/…` | `lib/core/resources/resource.dart` + `resource_store.dart`. Every department of the seeded disciplines on Goa gets 3–6 links of every resource type, plus one flagged or reported link for moderation screens. Bump `resourceVersions`. |

- All ids and dates are deterministic and relative to "now", so the seed can be re-run.
- **`tools/test_env/seed.test.mjs`** (node --test) does two things. First, it checks that each account can or cannot read what its role implies: a "role matrix" run against the seeded emulator with the real rules, reusing `test/rules/helpers.mjs`. Second, it checks review counters equal entries.

### T5. Staging project (user actions + agent scaffolding)
**The user must do these by hand:**
1. Create Firebase project `pointer-staging`.
2. Enable Authentication → **Email/Password** (staging only; never in production) and Google.
3. Create the Firestore database, ideally in the same region as production.
4. `flutterfire configure` for T1.
5. Create a service-account key and store it as the GitHub secret `STAGING_SA_KEY`.

**The agent adds:**
- `.firebaserc` alias `"staging": "pointer-staging"`.
- `tools/test_env/staging.sh`:
  1. `firebase deploy --only firestore:rules,firestore:indexes --project staging`
  2. run the seed with `--project`
  3. `flutter build web --release --base-href /calculator/ --dart-define=POINTER_ENV=staging --dart-define=POINTER_TEST_PASSWORD=$STAGING_PASSWORD`
- `.github/workflows/deploy-staging.yml`: on push to a `staging` branch or manual dispatch. It builds as above and deploys with wrangler to the same Pages project with `--branch=staging`, which gives a preview URL. It reuses the site assembly steps from `deploy.yml`.
- The staging password comes from a secret, not the default.

### T6. End-to-end tests against the seeded emulator (Playwright, pre-installed Chromium)
- `tools/e2e/`: Playwright test project (`package.json`, `playwright.config.mjs`).
  - Use `executablePath: '/opt/pw-browsers/chromium'` when present. Never run `playwright install`.
  - Serve `flutter build web --profile --dart-define=POINTER_ENV=emulator` with a static server.
  - Flutter's semantics tree is enabled by T1, so use `getByRole` / `getByText` / `getByLabel`.
- **Specs, one per account key:**
  - `student_full`:
    - Home shows the CGPA and SGPA from `<dataset>.expected.json`.
    - Visit `/stats`, `/calendar`, `/course/<id>` (marks), `/more`, `/representatives`, `/reviews`, `/reviews/<course>`, `/reviews/professor/<id>`, `/resources` and `/settings`. Each page shows its seeded items with no error text ("That did not work", "Not allowed", "No connection").
    - Volunteer, then withdraw. Write a review, then edit it.
    - Save a screenshot per page to `tools/e2e/out/`.
  - `student_new` (`first_login`): a brand-new user with batch 2026. Degree setup / programme pick appears, a first course list is seeded on completion, and `users/{uid}` is created by the first push.
  - `student_dual`: both programmes appear on Resources and Stats. `5 - 1` shows PS II as current, and `5 - 2` shows the second PS II.
  - `student_hyd`: sees Hyderabad data only, never Goa reviews or reps (campus sandbox).
  - `president`:
    - `/maintain/goa/ELEC` and its courses, professors, resources, reviews and succession pages load.
    - Dismissing a volunteer works.
    - Visiting `/admin/people` redirects home.
  - `cr`: `/maintain/goa/course/EEE F211` loads, and a scheme edit saves.
  - `admin`: `/admin`, people, grant, terms, contact, audit, roster and professor merge all load.
  - `owner`: everything above plus open-as and publish.
  - `president_expired`: treated as a student.
  - `faculty`: can use the app, but volunteering is refused.
- **Performance spec** `perf.spec.mjs`:
  - Use CDP `Emulation.setCPUThrottlingRate(4)` and `Network.emulateNetworkConditions({latency: 300, downloadThroughput: 1.6e6/8, uploadThroughput: 750e3/8})`. The 300 ms latency approximates India to a distant Firestore region.
  - Measure time-to-home, plus time from tapping each More row to its content showing, on first open and on second open.
  - Also read `window.pointerPerf` (P0) for the Firestore read count per screen.
  - Budgets, which fail the run:
    - home < 3 s cold
    - More sub-page < 1.5 s on first open
    - second open < 300 ms, with 0 blocking reads
- **Quota spec** `quota.spec.mjs`: plays the "busy student day" from §0.5 as `student_full`, then as `president`.
  - It reads `window.pointerPerf` read and write counters. P0 counts **documents returned**, with a minimum of 1 per query, the same way Firestore bills.
  - It fails if a student uses more than 8 reads or 3 writes.
  - It writes the numbers into `QUOTA.md`'s "measured" column.
- **Staging:** the seed costs a few hundred writes, well within Spark. Run it by hand, never on a schedule.

### T7. One command before every deploy
- `tools/predeploy.sh` runs these in order and stops on the first failure:
  1. `flutter pub get`
  2. `flutter analyze`, with no new issues versus baseline; save the baseline list in `tools/analyze_baseline.txt`
  3. `flutter test`
  4. `cd test/rules && npm ci && npm test`
  5. the T4a snapshot build plus `seed.test.mjs` on fresh emulators
  6. `flutter build web --release --base-href /calculator/`, then the prod guard grep from T1
  7. the E2E and perf specs from T6
- `.github/workflows/check.yml` runs only steps 1–4 and 6 on pull requests and on pushes to `master`. This keeps GitHub Actions minutes low (§0.5). The rules tests need `firebase-tools` and Java.
- The emulator E2E and perf specs run locally via `predeploy.sh`, or through a separate `workflow_dispatch`-only workflow `e2e.yml`.
- Make `deploy.yml`'s `web` job `needs: check`. **Do not change anything else in `deploy.yml`.**
- `MANUAL_QA.md`: a short checklist per role for a real old phone on staging (scroll smoothness on Home, Stats and Marks; sign-in; offline strip; install to home screen).

---

## Phase P: speed (backend only)

### P0. Measure first
- **New file `lib/core/perf/perf.dart`**, compiled in only when `const bool.fromEnvironment('POINTER_PERF')` or `isTestEnv`:
  - `Perf.mark(name)`
  - `Future<T> Perf.time<T>(name, Future<T> Function())`
  - `Perf.read(collection)` counters
  - on web, it exposes `window.pointerPerf` as JSON via `dart:js_interop`; follow the pattern in `lib/core/platform/browser_web.dart`
- Wrap each startup step in `startApp()` (main.dart) and every public store method that reads Firestore, in `ContactStore`, `ReviewStore`, `ResourceStore`, `ProfessorStore`, `RoleStore` and the offering/catalog sources.
- Record the baseline numbers from the T6 perf spec in `PERF_BASELINE.md` before changing anything.

### Diagnosis (verified in the code)
Why More pages take 5–10 s:
- **Serial round trips.** Every `await` inside a `for` loop costs one Firestore round trip, about 250–400 ms from India. That is multiplied by the number of courses and departments:
  - `representatives_page.dart` `_load`: runs `directory()`, then one `myOffer()` **per course, sequentially**.
  - `resources_page.dart` `_load`: runs `store.department()` **per department, sequentially**. Each call first awaits `_version(campus)` (a network read) **even when the cache is valid**, so the cached path still blocks on the network. That makes 2 serial round trips per department.
  - `reviews_home.dart`, courses tab: `[for id in now) await store.stats(id, campus)]` runs sequentially, and `stats()` loops sequentially over professor ids. Then `mostReviewed` runs after all of that.
  - `reviews_home.dart`, "Your reviews" tab: one `await store.mine(id)` per reviewed course, sequentially.
  - `professor_reviews.dart` `_load`, `review_form.dart` `_load`, `course_reviews.dart` and `marks/widgets/taken_by.dart`: audit each for the same pattern.
- **No cache-first path.** `directory()`, `stats()`, `mostReviewed()`, `mine()`, `myOffer()` and `publicContact()` always go to the network. `Loaded` (`lib/admin/widgets.dart`) shows a spinner until everything resolves.
- **A re-fetch on every rebuild:** `resources_page.dart` ~line 279 has `FutureBuilder(future: roleStore?.publicContact()…)`, which creates a new query on every build.

Why startup is slow:
- `startApp()` awaits `Sync.init()` → `pull()` **before `runApp`**. That downloads the whole `users/{uid}` document, up to 500 KB, **just to compare `rev`**, and has **no timeout**. On a slow network, first paint waits for it.
- `loadCatalog()` (`lib/core/catalog/catalog_store.dart`) parses the 125 KB asset **and** the cached copy on every start: two JSON parses on the main thread.
- `RoleStore.loadMine()` runs two serial reads.
- `recordSignIn` writes on every start.
- `refreshCurrentOfferings()` makes serial reads per course, competing with the first screen.

Why the app is slow on older phones (CPU):
- `OfflineStrip(pending: () => Sync.hasUnsynced)` (`calendar_page.dart:134`). `hasUnsynced` calls `snapshot()`, which **JSON-encodes all user data on every build**.
- `StatsPage._data` is a getter that rebuilds `StatsData` (audit, requirements, forecasts) **every time it is read**, several times per build.
- `script.dart` `sgcalc`/`cgcalc`/`creditTotals` re-tally every course on each call. `home_page.dart` calls them repeatedly: `creditTotals` alone runs 4 tallies.
- `initializeCourses()`, `relinkStoredCourses()` and seeding call `await box.put` **per course**. Each put is an IndexedDB write plus a watch event; use `putAll`.

### P1. Cache-first helper (core, no screen change)
- **New file `lib/core/cache/cache_first.dart`:**
  ```dart
  /// Returns the cached value at once when there is one, refreshing it in the
  /// background when older than [maxAge]; fetches (and caches) only when
  /// nothing is cached. Concurrent calls for one key share one fetch.
  Future<T> cacheFirst<T>({
    required String key,
    required Duration maxAge,
    required Future<T> Function() fetch,
    required Object? Function(T) encode,   // JSON-safe
    required T Function(Object?) decode,
    Box? box,                              // default: sharedCacheBox
    DateTime Function()? now,
  });
  Future<void> forget(String keyPrefix, {Box? box});
  ```
- Storage: `box.put(key, jsonEncode({'at': ms, 'v': encode(value)}))`, the same style `ReviewStore.page` already uses.
- Keep an in-memory `Map<String, Future>` to dedupe concurrent fetches.
- A background refresh that fails is swallowed with `debugPrint`, matching the style of the existing `[Pointer …]` logs.
- A decode error drops the entry and fetches again.
- **New cache box `sharedCache`:** add it to `cacheBoxes`, open it in `startApp()` next to `openReviews()`, and clear it on sign-out (P6).
- **Tests** `test/core/cache_first_test.dart`, using a fake clock and a counting fetch:
  - no cache → fetches
  - fresh cache → 0 fetches
  - stale cache → returns the old value at once and 1 background fetch, and the next call returns the new value
  - concurrent dedupe
  - `forget`
  - a fetch that throws with a cache present → returns the cache

### P2. Apply cache-first inside the stores (core only, which speeds pages at once)
Same signatures and return types, so no caller changes. Keys include campus and uid where relevant.

The TTLs are set for the §0.5 budget. The user's own writes invalidate at once, so they always see their own changes.

| Method | File | maxAge | Invalidated by |
|---|---|---|---|
| `ContactStore.directory(campus)` → becomes `directoryFor(campus, scopes)` (P2b) | `core/roles/contacts.dart` | 24 h | `saveProfile` |
| `ContactStore.myOffer(campus, course)` | same | 24 h | `volunteer`, `withdraw` → `forget('offer|$campus|')` |
| `ResourceStore.department` | `core/resources/resource_store.dart` | 24 h (and the version check, P2c) | existing writes → `forget` |
| `ReviewStore.stats` | `core/reviews/review_store.dart` | 12 h | `save` (extend `_forget`), `_moderate` |
| `ReviewStore.mostReviewed` | same | 12 h | same |
| `ReviewStore.page` (existing 10 min cache) | same | raise to 6 h | `save`, `vote`, `report` (already `_forget`) |
| `ReviewStore.mine` | same | 7 days | `save` |
| `ReviewStore.byProfessor` | same | 12 h | `save` |
| `RoleStore.publicContact` | `core/roles/role_store.dart` | 7 days | config write in `admin/config_pages.dart` path (the store method it calls) |
| `ProfessorStore` lookups by id | `core/professors/professor_store.dart` | 7 days | merge/edit writes |
| `ProfessorStore.search` | same | in-memory for the session, per query | – |

Maintainer screens (`lib/admin/**`) read with short TTLs or none. Presidents, CRs and admins are few, and they need fresh data.

### P2b. Representatives read only the reps that matter (reads: campus-wide → ~5–10)
- **Directory docs** gain `scopes: [<course ids and dept keys from roles>]`, written by `ContactStore.saveProfile`.
- **Rules:** add `'scopes'` to the directory `hasOnly` list, and check `scopes` is a list of at most 4 strings matching the role scopes (mirror `listedAt`). Add a rules test.
- **New `ContactStore.directoryFor(campus, scopes)`:** `where('campus', ==).where('scopes', arrayContainsAny: scopes)`, where scopes are the courses being taken plus their departments (≤ 30 values; split into chunks of 30 if more). Add the composite index to `firestore.indexes.json`.
- **Migration with no Blaze and no prod script:** `checkProfile()` (`features/roles/rep_profile.dart` → moved to core in P5) rewrites the rep's own directory doc with `scopes` when missing. That costs 1 write, once per rep.
- **Until every rep has migrated,** `directoryFor` also falls back to the old campus query **once per 24 h**, controlled by a `deviceBox` flag. Drop the fallback after one term; leave a `TODO(date)` for that.
- **`myOffer`:** one query `volunteers where email == me && campus == c && open == true` costs 1 read, instead of one per course. First check the rules allow it: the `get` rule allows `resource.data.email == me()`, but the `list` rule does not. If needed, add `allow list: if signedIn() && resource.data.email == me()` plus a rules test. Fall back to a parallel per-course `get` if rules can't express it.

### P2c. Resources: version per department
- `resourceVersions/{campus}` gains `depts: {<dept>: <int>}`. Every resource write already bumps `v` in the same batch; bump `depts.<dept>` too, and update the rules check that validates the bump.
- `ResourceStore.department` re-queries only when **that department's** version moved, and checks the version doc at most once per 24 h.

- **`ResourceStore.department` specifically:** return the cached rows without awaiting `_version` when the cache is younger than maxAge. When it is older, return the cache and run the existing version-check-and-requery in the background.
- **`publicContact`:** also memoise the in-flight `Future` in memory for the session. That fixes the per-build re-query in `resources_page.dart` without touching that file.
- **Parallelise inside the stores:** `ReviewStore.stats` professor loop → `Future.wait`. `RoleStore.loadMine` owner read and grants query → `Future.wait`. `ContactStore.profileDue` → `Future.wait`.
- **Tests:** extend `test/core/reviews_test.dart`, `resources_test.dart` and `roles/contacts_test.dart` using `fake_cloud_firestore`, which is already a dev dependency. Cover: a second call makes 0 reads, a write invalidates, and results are equal to before.

### P3. Startup (core and `main.dart` `startApp` only)
1. **Pull without blocking** (`lib/sync.dart`):
   - Split `init` into `attach(uid)` (clear on uid change, set `_doc`, start watchers) and `pull()`.
   - In `startApp`: if this device has never synced this uid (`_meta.get('last') == null`), `await pull()` as today. Otherwise `await pull().timeout(const Duration(milliseconds: 1500), onTimeout: …)` and let it finish in the background.
   - If a late pull applies newer server data, call `reloadPage()` (`lib/core/platform/browser.dart`), **only if** no local change happened since start. Otherwise the existing server-wins-with-backup logic applies. On a normal network the timeout never fires, so nothing changes visibly.
   - Tests in `test/sync/`: timeout path; late apply triggers the reload callback, injected for the test; local edit during the wait keeps the backup behaviour.
2. **Tiny rev check:**
   - Also write `users/{uid}/meta/rev` = `{rev}` in the same transaction as `push()`.
   - `pull()` reads that tiny doc first, and fetches `users/{uid}` only when its rev differs from the local one, or when no full check has run for 24 h (`_meta 'fullAt'`). The 24-hour check covers older cached app versions that do not write meta.
   - **Needs a rules change:** `match /users/{uid}/meta/{d}` with the same owner condition as `/users/{uid}` (firestore.rules ~line 844).
   - Add a rules test in `test/rules/`, e.g. `users.test.mjs`, following the existing files.
3. **Catalogue:** store the cached catalogue's version under `catalogBox['version']` whenever `json` is written. `loadCatalog` compares versions first and parses only the chosen JSON. Keep the fallback: if the cached parse fails, parse the asset. Extend `test/core/catalog_test.dart`.
4. **After first paint, and throttled:** move `refreshCatalog()` and `refreshMyRoles()` after `runApp`, wrapped in `WidgetsBinding.instance.addPostFrameCallback` plus a short delay.
   - `refreshCatalog`: at most once per 24 h (`deviceBox['catalogAt']`).
   - `refreshMyRoles`: at most once per 6 h (`deviceBox['rolesAt']`). Run the two reads in `Future.wait`.
   - A person with a new appointment sees it within 6 h, or at once after signing out and in again (sign-out clears `deviceBox`, P6).
5. **`recordSignIn`:** at most once per 7 days per device (`deviceBox['signInAt']`). This is what saves up to 8,000 writes a day.
6. **Push cost** (`lib/sync.dart`):
   - The push transaction reads `users/{uid}/meta/rev` (tiny) instead of the full user doc. It writes the data doc plus the meta doc: 2 writes and 1 read per push.
   - Raise the debounce from 1.5 s to 3 s, and also flush on `visibilitychange` → hidden. Use a hook in `lib/core/platform/browser*.dart`, following the existing web/stub pattern.
   - If `push` gets `resource-exhausted`, wait 5 minutes, then retry with backoff. Local data is safe in Hive meanwhile.
   - Test: 10 rapid edits produce 1 push.
7. **Offerings** (`features/marks/official.dart` `refreshCurrentOfferings`, and `core/storage/offerings.dart`):
   - Stop refreshing every current course at startup.
   - Add an `offeringVersions/{campus}` doc shaped `{terms: {<term>: {<courseId>: <int>}}}`. The CR scheme-publish batch (`core/roles/maintain_store.dart`) bumps it, and the rules check the bump.
   - The app reads that one doc at most once per 24 h, and re-fetches only the offerings whose version moved, and only for courses the student is taking.
   - Opening a Marks page still calls `refreshOfferingFor`, but with `maxAge` 24 h.
   - Add rules tests.

### P4. CPU work (core only)
1. **`Sync.hasUnsynced`:**
   - Keep a `static bool _dirty` flag. Set it in the box `watch()` listener, and clear it after a successful push or a pull that applies data.
   - `hasUnsynced` returns `_dirty`, with no encoding.
   - `push()` still compares snapshots before writing, as today.
   - Test: `hasUnsynced` does not call `snapshot()`. Make `snapshot` injectable, or count through a `@visibleForTesting` hook.
2. **A courses revision counter:**
   - `lib/core/storage/courses.dart`: `final coursesRevision = ValueNotifier<int>(0)`, bumped on `coursesBox.watch()`. Start watching after `basicStartup`.
   - Also bump it when `selecteddiscipline` or `selectedprofile` changes (`setdis`/`setprof` in `script.dart`).
3. **Memoise the tallies in `script.dart`:** `_semTally` and `_cumTally` are cached in a map keyed by `(revision, sem, profile, discipline)`, cleared when the revision changes. `sgcalc`/`cgcalc`/`creditTotals` keep their signatures. Test: identical outputs to before across `test/grading/cgpa_test.dart` fixtures, and the second call does no work.
4. **Stats:**
   - Add `StatsData.cached({...})` in `lib/features/stats/stats_controller.dart`, a non-widget file. It memoises on `(coursesRevision, discipline, target, plan hash, skipped hash, degreeNeeds, totalSet)`.
   - The one-line swap in `stats_page.dart` (`StatsData.from` → `StatsData.cached`) waits for P5, because it is a screen file.
   - Test in `test/stats/stats_test.dart`.
5. **Bulk writes:**
   - `initializeCourses()` (`script.dart`) and `relinkStoredCourses()` (`core/storage/course_link.dart`): build a map, then `putAll`. Keep int-versus-String keys exactly as read (§14.6).
   - Same in `seed.dart` callers.
   - Test: same box contents as before for the seeding fixtures in `test/semester/`.
6. **Bundle size:**
   - Build with `--source-maps` and inspect `main.dart.js` using `npx source-map-explorer`. Record the biggest Dart libraries in `PERF_BASELINE.md`.
   - Check whether `lib/mastercourselist.dart` (3,561 lines) is needed at startup, given that `assets/catalog.json` exists. **Only report it; never delete rows** (§14.10).
   - The code changes for this are P7.

### P5. Call-site swaps in screen files (ONLY after P5.0)
- **P5.0:** `git fetch origin pointer-rebuild && git merge origin/pointer-rebuild` into `pointer-refactor`, resolving conflicts in favour of pointer-rebuild's UI. Re-run the baseline tests.
- Then move each screen's load logic into core. New core functions return **public** record typedefs; screens alias them to keep their private names, e.g. `typedef _Data = RepresentativesData;`.

| Screen | New core function | What changes |
|---|---|---|
| `features/more/representatives_page.dart` `_load` | `lib/core/roles/representatives.dart` `loadRepresentatives(campus, courses)` | directory and all `myOffer` in `Future.wait` |
| `features/resources/resources_page.dart` `_load` | `lib/core/resources/resources_for.dart` `resourcesFor(campus, discipline)` | departments in `Future.wait` |
| `features/reviews/reviews_home.dart`, courses tab | `lib/core/reviews/reviews_home_data.dart` `reviewsHomeData(campus, taking)` | all stats and `mostReviewed` in `Future.wait` |
| `features/reviews/reviews_home.dart`, yours tab | same file, `myReviews()` | `Future.wait` |
| `professor_reviews.dart`, `course_reviews.dart`, `review_form.dart`, `marks/widgets/taken_by.dart` | functions beside their stores | `Future.wait` wherever there are independent awaits |
| `stats_page.dart` | — | `StatsData.from` → `StatsData.cached` |
| `calendar_page.dart` | — | nothing (P4.1 already fixed it) |

- Each screen's edit must be only the body of its `_load` or getter, replaced by one call. Diff check: `git diff --stat` shows ≤ 10 changed lines per screen file.
- The existing S12 test (`test/roles/step11_screens_test.dart`) and the other screen tests must pass unchanged.
- **Admin pages** (`lib/admin/dept_resources.dart`, `dept_reviews.dart`, `roster.dart`, `people.dart`, `volunteers.dart`, `professors.dart`): audit them for serial awaits and apply the same pattern. Lower priority; do them last.

### P6. Sign-out and account switch hygiene (a bug found during research; also needed for T's `?as=` switching)
`Sync.clearLocal()` clears only the synced boxes. Two consequences:
- `deviceBox` (cached roles, `workingAs`) and the shared caches survive a change of account.
- `restoreMyRoles()` (`core/roles/session.dart`) restores the **previous user's roles** without checking the email.

Fix:
- `restoreMyRoles` ignores cached roles whose `email` ≠ the signed-in email. It needs the email as a parameter; `startApp` passes it.
- On a uid change in `Sync.attach`, and in `signOut()`, also clear `deviceBox`, `sharedCache`, `reviewsBox` and `resourcesBox`. Keep `catalogBox` and `offeringsBox`: they are shared, not personal.
- Tests: add to `test/core/cache_boxes_test.dart` and a new `test/core/session_test.dart`.

### P7. Later, after the UI rebuild lands: deferred loading and build flags
- Make Reviews, Resources, Representatives, the ERP import (`features/import/*`) and the install guide into deferred libraries, like admin in `lib/app/router.dart` (`deferred as` + `DeferredPage`). This shrinks `main.dart.js`, which cuts the parse and compile time that dominates startup on old phones.
- It is shell wiring in `router.dart`, so it waits for the UI rebuild.
- Measure `main.dart.js` size and time-to-home before and after.
- Optional experiment only: `flutter build web --wasm`. It falls back to JS on browsers without WasmGC. Do not add COOP/COEP headers, because that would break the Google popup and gtag. Adopt it only if the T6 perf spec improves.

---

## Phase F: role and representative features (requested by the user)
The decisions below come from the user. Sub-tasks marked **[core]** touch no screen, so do them on `pointer-refactor` straight away, after P2b. Sub-tasks marked **[screen]** change what a screen shows, so they wait for the UI-rebuild merge (P5.0). Tell the user which screens gained what, so the UI rebuild can style it.

### F1. Each student sees only their own representatives
The rule:
- **Presidents and the secretary:** only those of the **department(s) of the student's own degree**. The department is `departmentOfProgramme(code)` for each code in `programmesOf(selecteddiscipline)`.
  - ELEC programmes (A3, A8, AA, AC) all map to ELEC, so **only electronics students see all the ELEC presidents**.
  - Dual-degree students see both of their departments.
  - A student taking an ELEC course from another branch **does not** see ELEC presidents or the secretary.
- **CRs:** only those of the courses the student is **taking now** (`takingNow()`), from any department.
- Today the page derives departments from the courses being taken (`representatives_page.dart:94`). That changes.

Tasks:
- **[core]** New pure function in `lib/core/roles/representatives.dart`:
  `RepresentativesView representativesFor({required List<DirectoryEntry> people, required Set<String> myDepts, required Set<String> taking, required DateTime now})`.
  It returns presidents and secretaries per department and CRs per course, with only live roles, sorted like today (latest `until` first). Also `Set<String> myDepartments(String discipline)`.
- **[core]** Query: P2b's `directoryFor(campus, scopes)` with `scopes = myDepts ∪ taking`, so the network never returns other departments' officers. This is also the §0.5 read saving.
- **Rules:** the directory stays campus-readable by design (§13.5), and a student's programme can't be verified server-side because it is self-declared. The restriction is in the app, and the scoped query is the privacy measure. Record this in ARCHITECTURE §13.5.
- **[screen]** In `representatives_page.dart`, the load calls `directoryFor` and the build uses `representativesFor`. That changes which rows appear, not how they look. Volunteer is shown **only for a course taken now with no live CR listed**, which is unchanged.
- **Tests:**
  - `test/core/representatives_test.dart`: an A3 student sees all ELEC presidents; a CS student taking EEE F211 sees that course's CR but no ELEC president or secretary; a B3A7 dual-degree student sees ECON and CS; expired roles are hidden.
  - Update S12 and the related screen tests if they relied on the old department logic.

### F2. New role: Department Secretary (one per department per campus)
Behaviour:
- A secretary sees **every screen a president sees for that department**: `DeptHome`, courses, professors, resources, reviews, roster/volunteers, audit (own campus), and grant (CRs only). There is **no Succession/handover**.
- **Presidents appoint and revoke secretaries and CRs. Secretaries appoint and revoke CRs only.** Owners and admins can do both.
- **Elections:** the president and secretary are elected together, and their terms end on the **same day** a year after the election. An outgoing president hands the department to the **new set** in one succession: the next president plus the next secretary. Admins don't need to add them.

Model and capabilities **[core]**:
- `lib/core/roles/roles.dart`:
  - `GrantRole.secretary('secretary', 'Department secretary', 'SECRETARY')` → `Role.secretary`.
  - `Grant.scope` is the department key. `programme` is null for secretaries: one per department covers all of ELEC.
  - `scopeLabel` handles the new role.
  - `MyRoles`: add `secretaryships`. `top` ordering is owner > admin > president > secretary > cr > student. `may()` loops `secretaryships` with `Role.secretary` and department scope matching the way presidents do (`deptOf(scope) == g.scope`).
  - `StaffEntry` gains `secretaryOf: List<String>`, and `after(g)` moves it.
- `lib/core/roles/capabilities.dart` and the **ARCHITECTURE.md §4 table** (they must match: `test/core/capabilities_test.dart` compares them):
  - Add `Role.secretary` and a Secretary column.
  - The Secretary column copies the President column, **except**:
    - `appointPresidents` is '—'
    - new row `appointSecretaries` ('Appoint / revoke secretaries'): owner ✓, admin ✓, president '✓ in scope', secretary '—', cr '—'
    - new row `handOver` ('Hand over the department (with the next secretary)'): owner —, admin —, president '✓ own', secretary '—', cr '—'
  - `appointCrs` stays ✓ for secretaries, in scope.
  - The `can()` rule that president and CR need `inScope` now also covers the secretary.
- `lib/core/roles/session.dart`: `actingNow()` maps the secretary grant to `'secretary'`; `ViewAs.label` gets `Role.secretary => 'Secretary · $scope …'`.
- `lib/core/roles/contacts.dart` `listedRoles`/`needsProfile`: secretaries are listed in the directory and must give a phone, like presidents.
- `lib/core/roles/role_store.dart`: grant-writing batches support the `secretary` role, and the staff index gets `secretaryOf`.

Rules (`firestore.rules`) and indexes:
- `function isSecretary(c, dept) { return isStudent(me()) && holds('secretary', c, dept); }`
- **Anywhere `isPresident(...)` grants department maintenance**, allow `isSecretary(...)` as well. Grep every `isPresident(` and `isPresidentOn(`: resources, reviews moderation, professors, courses/offerings, volunteers `readsOffers`, roster `readsRoster` (`isPresidentOn` → also `secretaryOf`), audit reads.
  - **Exceptions** that stay president-only: `handsOver`, `cancelsHandover`, the own-grant succession `update` rule, and `mayGrant` for `dept` and `secretary`.
- `mayGrant`:
  - `course`: `(isOwner() || isAdmin() || isPresident(c, deptOf(scope)) || isSecretary(c, deptOf(scope)))`, with `isStudent` and same campus as today. **No branch or batch condition** (F3).
  - new `secretary` branch: `(isOwner() || isAdmin() || isPresident(d.campus, d.scope) || handsOverSecretary(d)) && isStudent(d.email) && campusOf(d.email) == d.campus && seatOk(d)`.
- **One secretary per department per campus, enforced by a seat document** (rules can't count). `seats/{campus|dept}` = `{secretary: email|null, auditId}`, written in the same batch as every secretary grant change.
  - `seatOk(d)`: `getAfter(seat).secretary == d.email`, and the previous seat holder is either none, or that holder's grant becomes inactive or ends within 20 days in this same batch (the handover overlap, as for presidents).
  - Revoking a secretary sets the seat to null.
  - A seat doc is written only on appointments, so this costs one read and one write per appointment: negligible against §0.5.
- `staffWriteOk`/`staffAgrees`: add the `secretary` branch, moving `secretaryOf` only.
- `listed(r)`: `r.role in ['dept', 'secretary', 'course']`.
- **Election handover (the new set).** Extend succession so one batch contains all of:
  1. the outgoing president's own grant update (`handedTo`, shortened ≤ 20 days; the existing rule)
  2. the successor president's grant (existing `handsOver`)
  3. optionally, the **successor secretary's** grant, allowed by new `handsOverSecretary(d)`: the writer is a live president of `d.scope` whose own grant `getAfter` has `handedTo` set in this batch, **and `d.expiresAt == getAfter(successor president grant).expiresAt`** (terms end the same day)
  4. if a current secretary exists, the outgoing secretary's grant shortened to ≤ 20 days, never extended. A new update rule lets a president of that scope shorten the secretary grant, by analogy with the own-grant rule.
  5. the seat doc now naming the new secretary, and the staff index docs and audit entries as usual
  - The expiry of the new set comes from the president term length in `config/grantTerms`, starting on the handover day.
  - Cancelling a handover (the existing `cancelsHandover`) also revokes the new secretary grant, restores the outgoing secretary's expiry (keep `expiresBefore` on the secretary grant too) and restores the seat.
- **Rules tests:** a new `test/rules/secretary.test.mjs` plus updates to `roles.test.mjs`/`maintain.test.mjs`/`contacts.test.mjs`:
  - a secretary may appoint and revoke CRs in their department and campus, and **may not** appoint presidents or secretaries, hand over, or act on another department or campus
  - a president may appoint a secretary; a second live secretary is refused outside a handover
  - an election handover with president plus secretary succeeds, but a secretary expiry different from the new president's is refused
  - cancel restores everything
  - a secretary can do every maintenance write a president can
- Add any new composite index the roster queries need to `firestore.indexes.json`.

Screens **[screen]**, done after P5.0 and with the smallest possible edits, since each is required by the feature:
- `lib/app/router.dart`:
  - `_staff()` includes secretaryships.
  - The admin `grant` route allows secretaries.
  - **`maintain/:campus/:dept/succession` (and `/confirm`) gets its own redirect that requires `Capability.handOver`**. Today it has no guard of its own, so a secretary would reach it.
- `DeptHome` (`lib/admin/maintain.dart` or wherever the Succession row lives): hide the Succession entry unless `may(Capability.handOver)`.
- `lib/admin/grant_form.dart`:
  - Role choices follow capabilities: a president sees Secretary and CR, a secretary sees CR only, an owner or admin sees everything.
  - Refuse "a live secretary already exists" before submitting, using the seat doc.
  - A secretary has no programme picker.
- `lib/admin/succession.dart`: an optional "Next secretary (BITS address)" field that runs the same checks as the successor field (student, same campus). Confirm screens state both people and the shared end date.
- The Roster, Role switch and Open-as lists show secretary grants; the labels come from `GrantRole.label`/`tag`.
- `representatives_page.dart`: show the department's secretary beside its presidents, with the same row widget and a "Secretary" tag from `GrantRole.tag`.

### F3. CRs from any branch or batch, if they take the course
- **Today's rules already allow it:** a CR grant needs only `isStudent` and the same campus, and a volunteer offer only `isStudent` and the same campus. **Keep it that way.**
- Add explicit tests so nobody adds a branch or batch check later:
  - rules: a CS 2022 student is appointed CR of EEE F211 by the ELEC president and by the ELEC secretary; a Hyderabad student is refused for Goa
  - unit: `grant_form` `_refusal` has no branch or batch condition
- **"Taking the course"** is enforced in the app: the Volunteer action appears only for courses in `takingNow()` that have **no live CR listed** (unchanged). The server can't verify enrolment, because the user's data is an opaque snapshot. Note this in ARCHITECTURE §13.5.
- An offer goes to that course's department (the `volunteers.dept` rule is unchanged). So a CS student's offer for an EEE course reaches the ELEC president **and secretary**: extend `readsOffers` to secretaries, which F2 already covers.

### F4. Test environment additions (extend T3/T4/T6)
- `accounts.json` gains:
  - `secretary`: an ELEC secretary on Goa
  - `student_elec_a8`: an A8 student who must see all ELEC presidents and the secretary
  - `cr_cross_branch`: a CS 2022 student who is CR of EEE F211
  - `president_handover`: a president mid-succession with a pending new set
- The seeder writes the `seats/*` docs.
- E2E specs:
  - `secretary` sees DeptHome and its pages but no Succession, and `/maintain/goa/ELEC/succession` redirects home
  - the secretary's grant form offers CR only
  - a president's election handover names president plus secretary with the same end date
  - `student_full` sees only their own department's officers and their courses' CRs
  - `student_elec_a8` sees all ELEC presidents
  - `cr_cross_branch` reaches `/maintain/goa/course/EEE F211`

---

## Phase D: degree structure fixes (PS II, single-degree M.Sc.)
The facts, from the user:
- A **single degree** has **one PS II** semester, in **4-1 or 4-2**.
- A **dual degree** has **two PS II semesters: 5-1 and 5-2**.
- **Every M.Sc. programme (B-codes) can be taken as a single degree**, so single-degree lists and logic must include the M.Sc. programmes.

A single M.Sc. is stored as **`"B3--"`**, a dual as `"B3A7"`, a single B.E. as `"--A7"` (`degree_setup_page.dart` `_discipline`, `performance_sheet.dart:159`).

What the code gets wrong today (verified):
- `lib/core/models/semesters.dart` `semestersFor`: `discipline.startsWith('B')` treats **`B3--` as dual**. A single M.Sc. student gets a fifth year (`ST 2`, `5 - 1`, `5 - 2`).
- `lib/features/settings/settings_controller.dart:28`: `current.startsWith('B') ? 2 : 1` sends a single M.Sc.'s discipline change down the dual "reseed second half" path (`erase == 2`). So their old courses are not replaced.
- `lib/features/semester/add_course_controller.dart:86`: `!discipline.startsWith('B')` hides the `DEl1` elective option from single M.Sc. students. Check against the official structure whether that is wrong; if unsure, ask the user, don't guess.
- `lib/core/storage/seed.dart` `reseedSecondHalf`/`needsSeed` and `lib/core/grading/requirements.dart:360` use the same prefix test. Audit each one.
- `lib/core/storage/courses.dart` `placeDualPracticeSchool` moves the single seeded `BITS F412` (Practice School-II, 20 credits, charted at `4 - 2` for every programme in `assets/catalog.json`) to `5 - 2`. **Duals get only one PS II; they need two, in 5-1 and 5-2.**

Tasks (**[core]** unless marked):
- **D1.** Add one helper in `lib/core/models/programmes.dart`: `bool isDualDiscipline(String d) => d.length == 4 && d.substring(0, 2) != '--' && d.substring(2) != '--';` plus `String primaryProgramme(String d)`.
  - Replace **every** prefix test (`grep -rn "startsWith('B')" lib`) where it means "is dual" with `isDualDiscipline`.
  - Keep `Programme.isMsc` (`code.startsWith('B')`), which is correct for a single programme code.
  - The two logic-only controller files, `settings_controller.dart` and `add_course_controller.dart`, contain no widget code, so they may be edited now. They are the only exception to rule 3.
- **D2.** `semestersFor`: the fifth year only when `isDualDiscipline`. Single B.E. and single M.Sc. both end at `4 - 2`.
  - `performance_sheet.dart`'s `semestersFor(discipline).contains(sem)` then correctly refuses 5-x rows for single degrees. Add a test.
- **D3. Dual PS II ×2:** rewrite `placeDualPracticeSchool` (still called from `initializeCourses` in `script.dart:145`):
  - Dual: the seeded, ungraded `BITS F412` at `4 - 2` moves to **`5 - 1`**. A **second PS II** row (a copy of the chart row, ungraded) is added at **`5 - 2`**.
  - The second row's Hive key must differ from the first. Use the key `'BITS F412#2'`, with `id` still `BITS F412`. **Always write back under the key read** (§14.6).
  - Check everything that assumes key == id: `Sync` (keys are stored separately, so fine), `course_link.dart` encode/decode, `edit_course_sheet`'s write-back, `allCourses().where(id)` in `router.dart` `_course()` (the first match wins; acceptable, since PS II has no marks), CSV export and the ERP import `planImport`. Add tests for each path the agent touches.
  - **Migration for existing dual users.** It runs where `placeDualPracticeSchool` runs today, is idempotent, and never moves a **graded** row:
    - one `BITS F412` at `4 - 2`, ungraded → move it to 5-1 and add #2 at 5-2
    - one at `5 - 2`, left by the old code → add #2 at 5-1
    - two already present → do nothing
  - Tests in `test/semester/` or `test/core/`, including a graded row staying where it is.
  - Use `putAll` (P4.5).
- **D4. Single-degree PS II in 4-1 or 4-2:** keep seeding at `4 - 2`, the chart default.
  - Check that the existing edit-course flow can move PS II to `4 - 1` (`edit_course_sheet.dart` shows "leaves <sem>" text, so it probably can). If it can't, report to the user as a **[screen]** item; don't build UI.
  - `requirements.dart`/stats must treat PS II in either semester the same. Add a test.
- **D5. Credit totals and audit:** check that `lib/core/grading/requirements.dart` and `degreeTotalFor` count **both** PS II rows for duals, i.e. 40 PS credits.
  - Compare against `DISCIPLINES_GOA_HYD.md` / `COURSE_GAPS.md`. **If the official dual total isn't documented there, stop and ask the user for it.** Do not invent credit numbers.
  - CGPA maths stays in `core/grading/cgpa.dart` (§14.1); no change there beyond counting both rows.
- **D6. Single M.Sc. in lists and representatives:**
  - `programmesOf("B3--")` → `[B3]`, and `myDepartments` (F1) → `{ECON}`. Add a test.
  - Check every single-degree picker offers M.Sc. codes: `degree_setup_page` already does for `!_dual`; check `programme_pick_page.dart` and the settings discipline picker.
  - A picker that leaves out B-codes for single degrees is a **[screen]** fix: an options list, not a layout change.
- **D7. Test data:**
  - `accounts.json` gains `student_msc_single` (`"B3--"`, batch 23, 4th year, with PS II ongoing at `4 - 1`), which also covers PS II in 4-1.
  - `student_dual` is currently in PS II at 5-1, with the second PS II at 5-2 (T4a).
  - `student_full` has its one PS II scheduled at 4-2.
  - E2E: a single M.Sc. has no fifth year; a dual shows both PS II semesters; the expected CGPA and credits come from T4a.

---

## Appendix U: visible changes, for the UI agent on `pointer-rebuild`
Anything a user can see or feel change. Everything else in this plan is invisible.

**New screen content (Phase F, Department Secretary):**

| Page (route) | Change |
|---|---|
| Representatives (`/representatives`, More) | Different people are listed: only the student's own department's president(s) (ELEC students see all ELEC presidents; dual degrees see both departments) and the CRs of courses taken now. **New "Secretary" row** per department, tagged `SECRETARY`. The Volunteer action is unchanged: only on courses with no listed CR. |
| Grant / appoint (`/admin/grant`) | Role choices depend on who is appointing. President: **Secretary, CR**. Secretary: **CR only**. Owner or admin: all roles. A Secretary has a department picker but **no programme picker**. New refusal message: "This department already has a secretary." Secretaries can now open this page. |
| Succession (`/maintain/:campus/:dept/succession`) | **New optional field "Next secretary (BITS address)"**, with the same parsed campus and batch preview as the successor field. |
| Succession confirm (`…/succession/confirm`) | Shows **both** incoming people and their **shared end date**, plus the outgoing secretary's last day (≤ 20 days). Cancel restores both, so the wording should say so. |
| DeptHome (`/maintain/:campus/:dept`) | The **Succession entry is hidden for secretaries**. The page heading or role label can read "Secretary". The route itself redirects secretaries home. |
| Controls entry / role strip | Secretaries now reach Controls, just as presidents do. |
| Roster and Volunteers tab (`/admin/roster`, `/admin/roster/volunteers`) | Secretary grants are listed (`SECRETARY` tag). Secretaries can open both for their own campus and department. |
| Switch role (`/roles`), RoleStrip | Secretary grants appear, labelled "Secretary · ELEC Goa". |
| Open as (`/admin/open-as`, owner) | Can view as Secretary. |
| RepProfile (`/welcome`) and Settings › Contact details | Shown to secretaries, as to presidents: a phone is required and directory fields are opt-in. |
| Audit log, People | Entries and filters can show the role `secretary`. |

**Degree structure (Phase D):**

| Page | Change |
|---|---|
| Home semester pills / semester list | A single M.Sc. (`B3--`) **no longer shows ST 2, 5-1 and 5-2**. A dual shows **PS II in both 5-1 and 5-2**. That means two rows with the **same code `BITS F412`**, so list keys must not assume codes are unique (the Hive keys are `BITS F412` and `BITS F412#2`). |
| Course row → Marks (`/course/BITS F412`) | For duals, both PS II rows open the first one, because the route is by code. The UI agent may want to pass the key, or accept this. |
| Stats (progression, degree view) | No fifth year for single M.Sc. Dual totals count 40 PS credits (pending the user's confirmation of the official total). |
| Edit course sheet | Must let a single-degree student move PS II between **4-1 and 4-2**. If it can't today, that's new UI. |
| Add course sheet | Single M.Sc. may gain the `DEl1` elective option (pending the user's confirmation). |
| Degree pickers (setup, programme pick, Settings discipline) | The single-degree list must include **M.Sc. (B) codes** wherever it doesn't already. |
| ERP import preview | 5-x rows are refused for single degrees, with a message. |

**Speed and quota work (Phase P); layouts don't change, behaviour does:**
- **More pages (Representatives, Course reviews, Resources) open instantly from cache.** The content can be up to 24 h old (reviews 12 h) until the next open. The user's own edits show at once. There are fewer spinners.
- **At startup,** if the network is very slow and another device changed the data, the app **may reload itself once** shortly after opening.
- **A new role appointment** can take up to 6 h to appear, or appears at once after signing out and in again.
- **When the free quota runs out,** screens behave as if offline and show cached data.
- The Calendar offline strip looks the same, but is now cheap to compute.
- No other visible change: sync timing, caching, and test-only `?as=` sign-in (compiled out of production).

**The UI agent does not need to change:** the sign-in page, the bottom bar, or any page's layout because of the P or T phases.

---

## Order of work, and what the user gets when
1. **Step 0**, then **T1–T4 plus T2 up.sh.** The user can now run everything locally with any role. Tell the user it is ready and how to merge it into `pointer-rebuild`: `git merge origin/pointer-refactor`, or cherry-pick the T commits.
2. **P0** baseline numbers, plus the quota spec's "today" numbers → **P1 → P2 → P2b → P2c**. These are the More-page fixes that need no screen changes. Re-run the perf and quota specs and record the numbers.
3. **P3 (including P3.6–P3.7) → P4 → P6.**
   - P2b, P2c, P3.2, P3.7 and P6 change `firestore.rules` and `firestore.indexes.json`, each with rules tests.
   - The user deploys them with `firebase deploy --only firestore:rules,firestore:indexes`, which is free on Spark.
   - Deploy them **before** shipping the app build that relies on them. Old cached app versions must keep working under the new rules; the rules tests cover old write shapes too.
4. **T5** (staging, once the user has created the project) → **T6 → T7** (CI).
   Then **D1–D3, D5 and D6 [core]**: degree-structure fixes. D5 may block on a question to the user about the official dual credit total. Then **F1–F3 [core]**: roles model, capabilities plus the ARCHITECTURE §4 table, rules with seats and election handover, rules tests, and the `representativesFor` logic. Deploy the rules before any app build that writes `secretary` grants.
5. **P5** and **F [screen]** tasks, once the UI rebuild is merged.
6. **P7** later.
7. Commit this plan to the repo as `PERF_TEST_PLAN.md` in the first commit, so the agent and the user share it.

## Verification (definition of done)
- `flutter test`: 338 or more passing, with no new failures, plus all the new tests. `flutter analyze` shows no new issues.
- `test/rules` `npm test` passes, including the new `users/{uid}/meta` rules test.
- `tools/test_env/up.sh` starts everything. `http://localhost:5000/?as=<key>` signs in as each account in `test_env/accounts.json`, and every page shows seeded data.
- The T6 E2E specs pass for every account.
- The perf spec meets its budgets: More sub-pages < 1.5 s first open and < 300 ms second open at 300 ms latency with 4× CPU throttling. Record the before and after numbers in `PERF_BASELINE.md`.
- The prod build contains no test-sign-in code (the grep guard) and still uses `cgpa-calculator-fb90c`.
- The quota spec passes: a busy student day uses ≤ 8 reads and ≤ 3 writes. `QUOTA.md` shows that about 3,200 daily active users fit inside Spark's 50,000 reads and 20,000 writes a day.
- Nothing needs a billing account:
  - no Blaze-only APIs or features added
  - staging is a separate Spark project
  - Cloudflare deploys stay manual for staging
  - CI minutes stay within the free allowance
- Screenshot tests (`SHOTS_DIR`) produce identical images before and after P2–P6, which confirms no UI change.
