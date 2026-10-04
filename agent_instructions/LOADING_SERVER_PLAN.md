# Loading + server markers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** No screen waits on the network: every data store keeps its data on the phone, refreshed only when its campus version marker moves, with screens prefetched level by level, and the markers eventually delivered by a Cloudflare Worker and pushed by a Durable Object.

**Architecture:** Four parts, each shippable alone, in order. **A** (client): `cacheFirst` gains a synchronous `peek` and an optional `version`; every store read goes through it; `Loaded` draws a store's peeked value in its first frame; a scheduler prefetches levels 2–4 after the first frame. **B** (DATA_SYNC_PLAN Stage 1): `heads/{campus}.v` holds a version per shared path; every write bumps its path in the same batch and `firestore.rules` enforces it; stores pass the marker as the cache `version`. **C** (Stage 2): a Worker in `server/` serves `GET /heads/<campus>` from the edge; the app reads it first and falls back to Firestore. **D** (Stage 3): one Durable Object per campus pushes marker changes (and the user's personal version) over one WebSocket per client.

**Tech Stack:** Flutter web (Dart 3), Hive CE, cloud_firestore, `@firebase/rules-unit-testing` (rules tests, emulator), Cloudflare Workers + Durable Objects (TypeScript, wrangler 4, vitest).

**Spec:** `docs/ARCHITECTURE.md` §13 "Loading design" and `agent_instructions/DATA_SYNC_PLAN.md` Stages 1–3. Owner decisions (2026-10-01): approach B (per data store), "no spinners", saved copies kept on the phone across sessions, levels Home → More → sub-pages → Admin (all at startup, Admin last and slow), read budget not a constraint (server work replaces it), Worker + DO code written here, Cloudflare resources and secrets created and deployed by the owner.

## Global Constraints

- **Firestore is always the source of truth.** Everything on Cloudflare is a hint that can be rebuilt from it (DATA_SYNC_PLAN).
- **Never broadcast client-supplied data.** The DO reads the committed document itself.
- **No grades ever go to Cloudflare.** Personal sync only moves a version number.
- **The Worker reads Firestore with a new read-only service account (Datastore Viewer)**, stored as a Worker secret. Never the staging admin key.
- **Cloudflare free plan:** Workers 100k requests/day, Durable Objects 100k requests/day, 10 ms CPU per request.
- **Rules and app ship together.** Part B's rules refuse writes from older app builds that don't bump markers, so a rules deploy goes out with (or after) the matching app build.
- **Production deploy is owner-only.** Staging deploys on push to `pointer-rebuild` (CI `deploy-staging`). Push only after a heads-up to Tester.
- **Formatting:** don't run `dart format` on legacy files (`main.dart`, `home_page.dart`, `script.dart`, `course.dart`, `mastercourselist.dart`, `sync.dart`, `settings_page.dart`); edit them by hand. Format new files only.
- **Never commit** `bug_*.md`, `bug_tracker.md`, `tools/perf_out/`, `tools/course_reviews_out/`, `sensitive_data_NO_COMMIT/`, or `tools/e2e/{perf_run,retest,trace_run}.mjs`.
- **Keys and markers:** campus ids are `goa | hyderabad | pilani | dubai`. Marker paths use `/` and never contain `.`.

## Review Focus

1. **Offline open after a relaunch.** Every screen shows its saved copy, with no spinner and no error notice. Test: A2 (store peek with fetch throwing) and A3 (`Loaded` with peek and a failing load).
2. **Your own edit, then reopen.** After adding a link, voting or editing a roster, reopening shows the change, not the old saved copy. Test: A2 (a write forgets or bumps, then peek misses or the version differs) and B3 (the store write bumps its path).
3. **Sign-out, then another account on the same phone.** No saved copy of the first account is shown. Test: A2 (`clearAccountCaches()` empties `sharedCache`, so peek returns null).
4. **Worker down or socket refused.** The app still opens and marks freshness from Firestore `heads/{campus}`. Test: C3 (`headFor` with a Worker client that throws falls back) and D4 (the live client gives up and fetches).
5. **Owner viewing another campus.** No data from the owner's own campus leaks into the viewed campus's screens. Test: A2 (keys include the campus; peek for campus X never returns campus Y's value).

---

## File structure

| File | Responsibility |
|---|---|
| `lib/core/cache/cache_first.dart` (modify) | adds `peekCache`, `version`-aware freshness, `isFreshCache` |
| `lib/core/stores/*` — no new folder; the existing store files below are modified | |
| `lib/core/resources/resource_store.dart`, `lib/core/reviews/review_store.dart`, `lib/core/roles/contacts.dart`, `lib/core/roles/role_store.dart`, `lib/core/professors/professor_store.dart`, `lib/core/roles/maintain_store.dart`, `lib/core/analytics/analytics_store.dart` (modify) | every public read goes through `cacheFirst` and gets a `peek…` twin; writes forget or bump |
| `lib/admin/widgets.dart` (modify) | `Loaded.peek` |
| `lib/core/prefetch/prefetch.dart` (create) | level runner: delay, order, offline pause, once per session |
| `lib/app/prefetch_levels.dart` (create) | which store calls make up levels 2–4 for the signed-in user |
| `lib/main.dart` (modify by hand) | starts the prefetch after the first frame |
| `lib/core/heads/heads.dart` (modify) | `Head.v`, `Head.version(path)`, `bumpPath`, `bumpPathOnAllHeads` |
| `lib/core/heads/paths.dart` (create) | the marker path names, one function each |
| `firestore.rules` (modify) | `pathBumped(campus, path)`; head `v` updates; every shared write requires its bump |
| `test/rules/markers.test.mjs` (create) | rules tests for the markers |
| `server/` (create) | Worker + Durable Object: `wrangler.toml`, `package.json`, `src/index.ts`, `src/google.ts`, `src/firestore.ts`, `src/token.ts`, `src/hub.ts`, `test/*.test.ts` |
| `lib/core/heads/heads_client.dart` (create) | reads heads from the Worker (C) |
| `lib/core/live/live_heads.dart` (create) | the WebSocket client (D) |
| `.github/workflows/deploy-staging.yml` (modify) | `--dart-define=POINTER_HEADS_URL` and `POINTER_LIVE_URL` from repo variables |
| `docs/ARCHITECTURE.md` §6, §13 (modify) | the markers, the Worker and the DO as built |

---

# Part A — Store caches, peek and level prefetch (client only)

### Task A1: `cacheFirst` gets `peekCache` and version-aware freshness

**Files:**
- Modify: `lib/core/cache/cache_first.dart`
- Test: `test/core/cache_first_test.dart`

**Interfaces:**
- Produces:
  - `T? peekCache<T>(String key, T Function(Object?) decode, {Box? box})`: the saved value, synchronous; null when there is none or it doesn't decode.
  - `cacheFirst<T>({... , String? version})`: stores `{at, v, ver}`. When `version != null`, the saved value is fresh exactly when `ver == version`, whatever its age; a different version refetches (cached value returned at once, refresh in the background, or awaited with `awaitStale`). When `version == null`, behaviour is unchanged (`maxAge`).

- [ ] **Step 1: Write the failing tests** (add to the existing `group('cacheFirst', …)`; reuse its `box` setup)

```dart
    test('peekCache returns the saved value synchronously', () async {
      final calls = <int>[];
      await fetchWith(calls);
      expect(peekCache<int>('k', (v) => v as int, box: box), 1);
      expect(peekCache<int>('missing', (v) => v as int, box: box), isNull);
    });

    test('a matching version is fresh at any age', () async {
      var n = 0;
      Future<int> get(String? ver, DateTime now) => cacheFirst<int>(
        key: 'v', maxAge: const Duration(minutes: 1), box: box,
        now: () => now, version: ver,
        fetch: () async => ++n, encode: (v) => v, decode: (v) => v as int,
      );
      final t0 = DateTime(2026, 10, 1);
      expect(await get('3', t0), 1);
      expect(await get('3', t0.add(const Duration(days: 30))), 1);
      expect(n, 1);
    });

    test('a moved version refetches', () async {
      var n = 0;
      Future<int> get(String ver) => cacheFirst<int>(
        key: 'v2', maxAge: const Duration(days: 9), box: box, version: ver,
        awaitStale: true,
        fetch: () async => ++n, encode: (v) => v, decode: (v) => v as int,
      );
      expect(await get('3'), 1);
      expect(await get('4'), 2);
    });
```

- [ ] **Step 2: Run, expect FAIL** — `flutter test test/core/cache_first_test.dart` (`peekCache` undefined, no `version` parameter).

- [ ] **Step 3: Implement**

```dart
/// The saved value under [key], read synchronously (for a screen's first
/// frame); null when nothing is saved or it no longer decodes.
T? peekCache<T>(String key, T Function(Object?) decode, {Box? box}) {
  final raw = (box ?? sharedCacheBox)?.get(key);
  if (raw is! String) return null;
  try {
    return decode((jsonDecode(raw) as Map)['v']);
  } on Object {
    return null;
  }
}
```

In `cacheFirst`, add the `String? version` parameter. Replace the freshness test with:

```dart
      final fresh = version != null
          ? m['ver'] == version
          : at - (m['at'] as int) < maxAge.inMilliseconds;
      if (fresh) return value;
```

Thread `version` into `_fetchAndCache`/`_run` and save `{'at': at, 'v': encode(value), 'ver': version}`.

- [ ] **Step 4: Run, expect PASS** — the same command, including all the earlier tests.
- [ ] **Step 5: Commit** — `git commit -m "cacheFirst: synchronous peek and version-aware freshness"`

### Task A2: Every store read goes through `cacheFirst`, with a `peek…` twin

**Files:**
- Modify: the seven store files in the File structure table.
- Test: `test/core/store_cache_test.dart` (create). Use `fake_cloud_firestore` (already a dev dependency; check `pubspec.yaml`) and a temp Hive dir like `cache_first_test.dart`.

**Interfaces:**
- Consumes: `cacheFirst`, `peekCache`, `forget` (A1).
- Produces: for each read below, an unchanged `Future` method that now goes through `cacheFirst`, plus a synchronous `peek…` with the same arguments:

| Store | Read → key (maxAge from `lib/core/timings.dart`; add new constants there) | peek |
|---|---|---|
| `ResourceStore` | `department(campus, dept)`: keep its own `resourcesBox` version logic, but return the Hive copy at once and check the version in the background (`unawaited`); a version change updates Hive and the next open shows it | `peekDepartment(campus, dept)` |
| `ReviewStore` | `stats(courseId, campus)` (via the index, existing `rix|`); `stats(..., professorIds)` → `rst|$campus|$courseId|${ids.join(',')}` (`reviewIndexMaxAge`); `byProfessor` → `rbp|$campus|$courseId`; `mine(courseId)` → `rmine|$courseId|$uidHash` (`reviewPageMaxAge`); `page` (existing `rcd|`); `mostReviewed` (existing) | `peekStats`, `peekByProfessor`, `peekMine`, `peekPage`, `peekMostReviewed` |
| `ContactStore` | `directory` (existing `reps|`), `myOffer` (existing), `myStaffContact` → `staffme|$me`, `myDirectory` → `dirme|$me`, `staffPhones` → `staffall`, `offers(campus, dept, term)` → `vol|$campus|$dept|$term` (`repsMaxAge`) | `peekDirectory`, `peekMyOffer`, … one per read |
| `RoleStore` | `publicContact` (existing), `roster({campus})` → `roster|${campus ?? '*'}`, `owners()` → `owners`, `terms()` → `terms`, `audit(...)` → `audit|<every argument>` (new `adminMaxAge = Duration(minutes: 10)`) | one `peek…` per read |
| `ProfessorStore` | `department(campus, dept)` → `prof|$campus|$dept`; `taught(p, campus)` → `taught|$campus|${p.id}`; `get(id)` → `pid|$id` (`reviewIndexMaxAge`). `search` stays uncached. | `peekDepartment`, `peekTaught`, `peekGet` |
| `MaintainStore` | `offering` → `mo|$campus|$term|$courseId`; `offerings` → one `mo|` entry per course; `campusOfferings` → `mco|$campus|$term` (`adminMaxAge`) | `peekOffering`, `peekOfferings` (null if any is missing), `peekCampusOfferings` |
| `AnalyticsStore` | `days(n, campus)` → `ana|$campus|$n`; `counts(campus)` → `cnt|$campus` (`adminMaxAge`) | `peekDays`, `peekCounts` |

Encode and decode with the models' existing `toMap`/`fromMap`. Where a model has none (records, `PeopleCounts`, `DayCounts`, `Grant`, `AuditEntry`, `Professor`, `Offering`, `Volunteer`, `DirectoryEntry`), add `toMap()` and `static fromMap(Map)` beside the class, in the same file.

**Every write forgets what it changed:**
- ResourceStore writes bump the version already.
- ReviewStore writes `_forget` already; also `forget('rmine|$courseId|')`, `forget('rbp|$campus|$courseId')` and `forget('rst|$campus|$courseId|')`.
- ContactStore `volunteer`/`withdraw` already forget `offer|`; also `forget('vol|')`. `saveProfile`: also forget `dirme|` and `staffme|`.
- RoleStore `appoint`/`revoke`/`handOver`: `forget('roster|')`. `addOwner`/`setOwnerActive`: `forget('owners')`. `saveTerms`: `forget('terms')`.
- ProfessorStore `add`/`rename`/`merge`: `forget('prof|$campus|')`, `forget('pid|')`, `forget('taught|')`.
- MaintainStore `save`/`upload`: `forget('mo|$campus|')` and `forget('mco|$campus|')`.

- [ ] **Step 1: Write the failing tests**, one per Review Focus item that A2 owns:

```dart
  test('offline: a saved department is returned and peeked', () async {
    // 1. department() with a working fake → saves.
    // 2. A store whose Firestore throws FirebaseException(code: 'unavailable')
    //    → department() returns the saved rows; peekDepartment() == rows.
  });
  test('a write forgets the saved roster', () async {
    // roster() → saved; appoint(...) → peekRoster() is null.
  });
  test('sign-out clears every saved copy', () async {
    // directory() saved → clearAccountCaches() → peekDirectory() is null.
  });
  test('keys are per campus', () async {
    // directory('goa') saved, peekDirectory('hyderabad') is null.
  });
```

Write each body fully against `FakeFirebaseFirestore`. Seed the docs the read uses (`repIndex/goa`, `grants`, `resourceVersions/goa`).

- [ ] **Step 2: Run, expect FAIL** — `flutter test test/core/store_cache_test.dart`.
- [ ] **Step 3: Implement** the table store by store. Run that store's existing tests after each one (`flutter test test/core test/admin test/features`).
- [ ] **Step 4: Run all** — `flutter test`. Expect the previous count (634 passed, 51 skipped) plus the new tests.
- [ ] **Step 5: Commit** — `git commit -m "Stores keep their data on the device and can be peeked"`

### Task A3: `Loaded.peek`: the first frame draws the saved copy

**Files:**
- Modify: `lib/admin/widgets.dart` (`Loaded`, `_LoadedState`)
- Test: `test/admin/loaded_cache_test.dart` (extend)

**Interfaces:**
- Produces: `Loaded({..., T? Function()? peek})`. When `peek` returns non-null and the load hasn't completed yet, `build` uses it: no spinner. If the load fails, it keeps the peeked value and `debugPrint`s, as the session cache does. The session `cacheKey` stays (used by `prefetchLoaded`).

- [ ] **Step 1: Failing tests**

```dart
  testWidgets('a peeked value shows in the first frame', (t) async {
    final c = Completer<String>();
    await t.pumpWidget(MaterialApp(home: Loaded<String>(
      peek: () => 'saved', load: () => c.future,
      builder: (_, v, _) => Text(v))));
    expect(find.text('saved'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    c.complete('fresh'); await t.pump();
    expect(find.text('fresh'), findsOneWidget);
  });
  testWidgets('a failed load keeps the peeked value', (t) async {
    await t.pumpWidget(MaterialApp(home: Loaded<String>(
      peek: () => 'saved', load: () async => throw StateError('offline'),
      builder: (_, v, _) => Text(v))));
    await t.pump();
    expect(find.text('saved'), findsOneWidget);
  });
```

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.** In `_LoadedState`, add `late final T? _peeked = widget.peek?.call();`. In `build`, treat `_peeked != null` like `_cached`: use `_loadedCache[key] ?? _peeked`.
- [ ] **Step 4: Run, expect PASS**, plus `flutter test test/admin`.
- [ ] **Step 5: Wire `peek` into every keyed `Loaded`.** For each `Loaded` that has a `cacheKey` (`grep -rn "cacheKey:" lib`), add `peek:`, built from the same store calls as its `load` using their `peek…` twins, returning null if any part is null. Example, `resources_page.dart`:

```dart
      peek: () {
        final store = resourceStore, campus = viewCampus();
        if (store == null || campus == null) return null;
        final out = <_Degree>[];
        for (final code in programmesOf(selecteddiscipline)) {
          final dept = departmentOfProgramme(code);
          if (dept == null) continue;
          final links = store.peekDepartment(campus, dept);
          if (links == null) return null;
          out.add((code: code, dept: dept, links: links));
        }
        return out;
      },
```

- [ ] **Step 6: Run** `flutter test` and `flutter analyze` (only pre-existing infos).
- [ ] **Step 7: Commit** — `git commit -m "Loaded draws the saved copy in its first frame"`

### Task A4: Level prefetch after the first frame

**Files:**
- Create: `lib/core/prefetch/prefetch.dart`, `lib/app/prefetch_levels.dart`
- Modify: `lib/main.dart` (by hand: replace the `prefetchPresidentPages` wiring), `lib/app/router.dart` (`prefetchPresidentPages` becomes level 4's entry)
- Test: `test/core/prefetch_test.dart`

**Interfaces:**
- Produces:

```dart
/// One level: independent jobs that run together.
typedef PrefetchLevel = List<Future<void> Function()>;

/// Runs [levels] in order after [delay], each level's jobs together, each
/// job's failure dropped; [gap] between jobs of the last level (admin). Skips
/// while [isOnline] is false (resumes on [onlineChanges]). Runs once per
/// session: a second call returns the first's future.
Future<void> runPrefetch(List<PrefetchLevel> levels,
    {Duration delay = const Duration(seconds: 2),
     Duration gap = const Duration(milliseconds: 400),
     bool Function()? online, Stream<bool>? onlineChanges});

/// Levels 2–4 for the signed-in user (level 1 is already local).
List<PrefetchLevel> prefetchLevels();
```

`prefetchLevels()` (in `lib/app/prefetch_levels.dart`):
- **Level 2:**
  - `reviewStore.mostReviewed(campus)`
  - `stats` for each of `takingNow()`
  - `mine` for each of `myReviewedCourses()`
  - `contactStore.directory(campus)`
  - `myOffer` for each current course without a CR
  - `resourceStore.department` for each programme department
  - `roleStore.publicContact()`
- **Level 3:** for each of `takingNow()`:
  - `reviewStore.page(c, campus)`
  - `byProfessor(c, campus)`
  - `ProfessorStore.get(id)` for each professor id of `cachedOffering(c)`
- **Level 4:** `prefetchPresidentPages()` (existing). For CR grants, `MaintainStore.offering` per course. For owners and admins: `roster`, `owners`, `terms`, `AnalyticsStore.counts`, `days(14)`.

Each job is `() => call().then((_) {})`.

Add `fake_async` to `dev_dependencies` (`flutter pub add --dev fake_async`).

- [ ] **Step 1: Failing tests** (fake time):

```dart
  test('levels run in order after the delay, failures dropped', () {
    fakeAsync((f) {
      final log = <String>[];
      runPrefetch([
        [() async => log.add('2a'), () async => throw 'x'],
        [() async => log.add('3')],
      ], delay: const Duration(seconds: 2), online: () => true);
      f.elapse(const Duration(seconds: 1)); expect(log, isEmpty);
      f.elapse(const Duration(seconds: 2)); expect(log, ['2a', '3']);
    });
  });
  test('waits while offline', () { /* online false + controller → runs after true */ });
  test('runs once per session', () { /* second call → same future, jobs once */ });
```

Expose a `@visibleForTesting void resetPrefetch()` for the once-per-session test.

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement** `prefetch.dart` (about 40 lines) and `prefetch_levels.dart`.
- [ ] **Step 4:** In `main.dart`'s `startApp`, after `runApp(MyApp());`, add (by hand):

```dart
  // ARCHITECTURE.md §13: screens load ahead, level by level, after the
  // first frame.
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => unawaited(rolesDone.whenComplete(() => runPrefetch(prefetchLevels()))),
  );
```

Remove the old `prefetchPresidentPages` `unawaited(...)` block; level 4 calls it. Keep `rolesDone` in scope; it's null when `email == null`, in which case pass `Future.value()`.

- [ ] **Step 5: Run** `flutter test`, `flutter analyze`.
- [ ] **Step 6: Manual check on a local build** against the emulator (`tools/test_env/up.sh`, then `?as=student_full`). Open More → Resources 5 s after the first frame: no spinner. Relaunch with DevTools → Network offline: Resources shows the saved links.
- [ ] **Step 7: Commit** — `git commit -m "Prefetch levels 2-4 after the first frame"`. Heads-up to Tester, then push. CI deploys staging.

---

# Part B — Stage 1: a version marker per shared path

### Task B1: `Head.v`, marker paths and bump helpers

**Files:**
- Create: `lib/core/heads/paths.dart`
- Modify: `lib/core/heads/heads.dart`
- Test: `test/core/heads_test.dart` (extend)

**Interfaces:**
- Produces:

```dart
// paths.dart — the marker path names (no '.' allowed).
abstract final class Paths {
  static const resources = 'resources';
  static const reps = 'reps';
  static const reviews = 'reviews';                     // reviewIndex
  static String reviewsOf(String courseId) => 'reviews/$courseId';
  static String professors(String dept) => 'professors/$dept';
  static const grants = 'grants';
  static const owners = 'owners';                       // on every head
  static const terms = 'terms';                         // on every head
  static String volunteers(String dept) => 'volunteers/$dept';
  static const staff = 'staff';
  // Offerings keep their existing `heads.offerings` map (bumpOfferings).
}
```

In `Head`: `final Map<String, int> v;`, `int? version(String path) => v[path];`, and `fromMap`/`toMap` carry `'v'`.

In `heads.dart`:

```dart
/// In a write batch: moves [path]'s marker on [campus]'s head by one.
void bumpPath(WriteBatch b, FirebaseFirestore db, String campus, String path) =>
    b.set(headRef(db, campus), {'v': {path: FieldValue.increment(1)}},
        SetOptions(merge: true));

/// The same on every campus head (owners, terms).
void bumpPathOnAllHeads(WriteBatch b, FirebaseFirestore db, String path) {
  for (final c in Campus.values) { bumpPath(b, db, c.name, path); }
}
```

- [ ] **Steps:** failing test (`Head.fromMap({'v': {'reps': 3}}).version('reps') == 3`; `bumpPath` on `FakeFirebaseFirestore` increments `v.reps`), run, implement, pass, commit `"Heads carry a version per shared path"`.

### Task B2: Rules enforce the bumps

**Files:**
- Modify: `firestore.rules`
- Test: `test/rules/markers.test.mjs` (create; reuse `helpers.mjs`: `as`, `seed`, `useEmulator`, `PRES`, `STUDENT`, `OTHER`)

**Interfaces:**
- Produces, in `firestore.rules`, beside `versionBumped`:

```
    function headPath(campus) { return /databases/$(db)/documents/heads/$(campus); }
    // A write to a shared path moves that path's marker by exactly one in the
    // same batch (DATA_SYNC_PLAN Stage 1).
    function pathBumped(campus, path) {
      let was = exists(headPath(campus))
        ? get(headPath(campus)).data.get('v', {}).get(path, 0) : 0;
      return getAfter(headPath(campus)).data.get('v', {}).get(path, 0) == was + 1;
    }
```

In `match /heads/{campus}`, add an `||` branch:

```
        || (mayUse() && (campus == campusOf(me()) || isOwner() || isAdmin())
            && headDiff().hasOnly(['v']) && request.resource.data.v is map
            && request.resource.data.v.diff(resource == null ? {} : resource.data.get('v', {}))
                 .affectedKeys().size() <= 4)
```

The head rule only limits who may move markers and how many at once. The source rules enforce the exact +1. A stray bump costs readers one re-read and never shows wrong data (the same ponytail as `offerings`).

Add `&& pathBumped(<campus>, '<path>')` to every create/update rule of:

| Collection | Campus from | Path |
|---|---|---|
| `resources` | the doc's `campus` | `'resources'` (keep `versionBumped`) |
| `repIndex/{campus}` | `campus` | `'reps'` |
| `reviewIndex/{campus}` | `campus` | `'reviews'` |
| `reviews/{course}/campus/{campus}` | `campus` | `'reviews/' + course` |
| `professors` | the doc's `campus` | `'professors/' + department` |
| `grants` | the doc's `campus` | `'grants'` |
| `volunteers` | the doc's `campus` | `'volunteers/' + dept` |
| `staffContacts`, `directory` | the doc's `campus` | `'staff'` |
| `owners` | every campus | `'owners'` (the rule checks `pathBumped('goa', 'owners')`; the client bumps all heads) |
| `config/grantTerms` | every campus | `'terms'` (same) |

Leave out `audit` and `analytics`: they're append-only and use time limits.

- [ ] **Step 1: Failing rules tests**, per collection: a write *with* `bumpPath` in the same `writeBatch` succeeds, and the same write *without* it fails. Also: a student can't bump another campus's head, and bumping 5 paths at once fails. Example:

```js
test('a president edits professors only with the marker bump', async () => {
  const db = as(PRES);
  const b = writeBatch(db);
  b.set(doc(db, 'professors', 'p1'), professor({ campus: 'goa', department: 'ELEC' }));
  b.set(doc(db, 'heads', 'goa'), { v: { 'professors/ELEC': increment(1) } }, { merge: true });
  await assertSucceeds(b.commit());
  await assertFails(setDoc(doc(db, 'professors', 'p2'), professor({ campus: 'goa', department: 'ELEC' })));
});
```

Build each collection's valid document from that collection's existing test file (`test/rules/<x>.test.mjs`).

- [ ] **Step 2: Run, expect FAIL** — `cd test/rules && npm test`.
- [ ] **Step 3: Implement the rules.**
- [ ] **Step 4: Run, expect PASS.** All existing rules tests must still pass after Task B3 adds the bumps to their batches. Update those tests' batches in this task so the suite is green.
- [ ] **Step 5: Commit** — `"Rules: every shared write moves its path's marker"`.

### Task B3: Stores bump on write and read with the marker as the cache version

**Files:**
- Modify: the store files from A2.
- Test: `test/core/store_cache_test.dart` (extend)

**Interfaces:**
- Consumes: `bumpPath`, `bumpPathOnAllHeads`, `Paths`, `headFor`, `Head.version`, `cacheFirst(version:)`.
- Each write batch adds the matching `bumpPath`, per the B2 table.
- Each cached read gets its head with `final h = await headFor(campus);` and passes `version: h?.version(<path>)?.toString()`. With no marker (null), it falls back to `maxAge`.

- [ ] **Step 1: Failing tests:**
  - a write puts `v.<path>` +1 on the fake head;
  - a read whose marker hasn't moved does no Firestore read (count reads with a wrapper around `FakeFirebaseFirestore`, or check `Perf` read counters);
  - a moved marker refetches.
- [ ] **Steps 2–4:** run (FAIL), implement, run all Dart tests, rules tests and analyze.
- [ ] **Step 5: Commit** `"Stores read by marker and bump on write"`, heads-up to Tester, push. Staging CI deploys the rules with the app (`deploy-staging.yml` runs `firebase deploy --only firestore:rules,firestore:indexes`), so they go live together.

---

# Part C — Stage 2: Worker serving the markers

### Task C1: `server/` scaffold, Firestore REST decode, Google service-account token

**Files:**
- Create:
  - `server/package.json` (`wrangler@4`, `typescript`, `vitest`, `@cloudflare/workers-types`)
  - `server/tsconfig.json`
  - `server/wrangler.toml` (name `pointer-heads`, `main = "src/index.ts"`, `compatibility_date = "2026-09-01"`, `[vars] PROJECT_ID`, `ALLOWED_ORIGINS`)
  - `server/src/firestore.ts`, `server/src/google.ts`
  - `server/test/firestore.test.ts`, `server/test/google.test.ts`
  - `server/README.md`: setup the owner runs. Create a service account with the **Datastore Viewer** role only. Run `wrangler secret put FIREBASE_SA` (paste the JSON). Then `wrangler deploy`.

**Interfaces:**
- `decodeValue(v: FirestoreValue): unknown` handles `integerValue` (to number), `doubleValue`, `stringValue`, `booleanValue`, `nullValue`, `mapValue`, `arrayValue`, `timestampValue`. `decodeDoc(doc): Record<string, unknown>`.
- `getAccessToken(saJson: string, now = Date.now()): Promise<string>` builds an RS256 JWT (`iss` = the SA email, `scope` = `https://www.googleapis.com/auth/datastore`, `aud` = `https://oauth2.googleapis.com/token`, 1 h), posts it to the token endpoint, and caches the token in module scope until 60 s before expiry.
- `readDoc(path: string, env): Promise<Record<string, unknown> | null>` does a GET on `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/${path}`. 404 returns null.

- [ ] **Steps:**
  - Write the vitest tests first: decode of a nested map with an integer, an array and null; a JWT header and claims built with a test RSA key generated in the test via `crypto.subtle.generateKey`; token caching (fetch mocked, called once for two calls).
  - Run `cd server && npm i && npx vitest run` and expect FAIL.
  - Implement, then expect PASS.
  - Commit: `"server: Firestore REST and service-account token"`.

### Task C2: `GET /heads/<campus>` with an edge cache and CORS

**Files:**
- Create: `server/src/index.ts`, `server/test/index.test.ts`

**Interfaces:**
- `export default { fetch(req, env, ctx) }` handles:
  - `GET /heads/:campus`, with campus in `goa|hyderabad|pilani|dubai` (anything else is 404). It checks `caches.default` first; on a miss it calls `readDoc('heads/'+campus)`, answers `200` with the JSON (`{}` when missing) and `Cache-Control: public, max-age=60`, and stores the response via `ctx.waitUntil(cache.put(...))`.
  - CORS: echo the `Origin` if it's in `ALLOWED_ORIGINS` (comma list). Answer `OPTIONS` with 204.
  - On a Firestore error, answer 502 and don't cache.
- [ ] **Steps:**
  - Write the tests first, with `readDoc` mocked through `vi.mock('../src/firestore')` and `caches` stubbed: bad campus → 404; first call reads and second is cached (`readDoc` called once); a disallowed origin gets no `Access-Control-Allow-Origin`; an error → 502.
  - Run FAIL → implement → PASS.
  - Commit: `"server: GET /heads/<campus> from the edge"`.

### Task C3: The app reads heads from the Worker, with a Firestore fallback

**Files:**
- Create: `lib/core/heads/heads_client.dart`
- Modify: `lib/core/heads/heads.dart` (`headFor`'s `fetch`), `.github/workflows/deploy-staging.yml` (`--dart-define=POINTER_HEADS_URL=${{ vars.POINTER_HEADS_URL }}`)
- Test: `test/core/heads_test.dart` (extend)

**Interfaces:**
- `const headsUrl = String.fromEnvironment('POINTER_HEADS_URL');` (empty means off).
- `Future<Map<String, dynamic>?> workerHead(String campus, {http.Client? client})`: a GET with a 3 s timeout. Null on a non-200 or error.
- `headFor`'s fetch tries `workerHead` first when `headsUrl` is non-empty, else (or on null) reads Firestore as today. `http` is not a dependency: use `package:web`'s `fetch` through a conditional-import shim (`heads_client_stub.dart` / `heads_client_web.dart`), following `lib/core/platform/online.dart`.
- [ ] **Steps:**
  - Write the failing tests: a Worker that returns `{v: {reps: 2}}` gives a `Head` whose `version('reps')` is 2; a Worker that throws gives the Firestore head (Review Focus 4).
  - Run FAIL → implement → PASS → `flutter test` → commit `"Heads come from the Worker first"`.
- [ ] **Owner step (not code):** deploy the Worker. Set the repo variable `POINTER_HEADS_URL` to its URL and add `pointer-staging.web.app` to `ALLOWED_ORIGINS`.

---

# Part D — Stage 3: Durable Object push

### Task D1: Firebase ID-token verification in the Worker

**Files:**
- Create: `server/src/token.ts`, `server/test/token.test.ts`

**Interfaces:**
- `verifyIdToken(token: string, projectId: string, now = Date.now()): Promise<{uid: string, email?: string}>` checks:
  - RS256 against the JWKS at `https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com` (cached per `Cache-Control` max-age);
  - `iss == "https://securetoken.google.com/" + projectId`;
  - `aud == projectId`;
  - `exp > now/1000`, `iat <= now/1000 + 300`;
  - `sub` non-empty.
  
  It throws `Error('bad token: <reason>')`.
- [ ] **Steps:** write the tests first, signing with a generated test key whose JWK is served by a mocked `fetch`. Cover: valid; expired; wrong aud; wrong iss; bad signature. Run FAIL → implement → PASS → commit `"server: verify Firebase ID tokens"`.

### Task D2: `CampusHub` Durable Object

**Files:**
- Create: `server/src/hub.ts`, `server/test/hub.test.ts`
- Modify:
  - `server/wrangler.toml`: `[[durable_objects.bindings]] name = "HUB", class_name = "CampusHub"`, plus a `[[migrations]] tag = "v1", new_sqlite_classes = ["CampusHub"]`.
  - `server/src/index.ts`: `GET /live/:campus` with WebSocket upgrade. The token comes from `Sec-WebSocket-Protocol: pointer, <idToken>`. Verify it with D1, then forward to `env.HUB.get(env.HUB.idFromName(campus))` with header `X-Uid`. Echo the `pointer` subprotocol.

**Interfaces (messages, JSON):**
- server → client:
  - `{t:'hello', head:{...}, me:<int>}` on connect: the head read from Firestore (one read, cached in the DO for 60 s) and the uid's personal version from SQLite.
  - `{t:'head', v:{path:n,...}}`: only the paths that moved.
  - `{t:'me', v:<int>}`
- client → server:
  - `{t:'poke', path:'<path>'}`: rate-limited to 1 per path per 2 s. The DO arms an alarm 1.5 s ahead (coalescing). On the alarm it reads `heads/<campus>` from Firestore, diffs it against the last broadcast, and broadcasts `{t:'head', v: diff}` if anything moved. It never echoes client data.
  - `{t:'pokeMe'}`: SQLite `UPDATE users SET v = v + 1 WHERE uid = ?` (insert if missing). Send `{t:'me', v}` to every socket tagged with that uid (`ctx.acceptWebSocket(ws, [uid])`, `ctx.getWebSockets(uid)`).
- Use the hibernation API (`acceptWebSocket`, `webSocketMessage`, `webSocketClose`).
- [ ] **Steps:**
  - Write the tests first, with `@cloudflare/vitest-pool-workers` if it installs cleanly; otherwise unit-test the pure parts: a `diffVersions(prev, next)` function and the rate-limit map.
  - Cover: hello carries the head and `me`; two pokes within 1.5 s cause one Firestore read; an unchanged head broadcasts nothing; `pokeMe` reaches only that uid's sockets.
  - Run FAIL → implement → PASS → commit `"server: CampusHub pushes markers and personal versions"`.

### Task D3: The app's live client

**Files:**
- Create: `lib/core/live/live_heads.dart`
- Modify:
  - `lib/main.dart`: start after the first frame, beside the prefetch.
  - the store write methods: `LiveHeads.poke(path)` after a successful commit.
  - `lib/sync.dart` (by hand): `LiveHeads.pokeMe()` after a successful push; on `{t:'me'}` with `v` > the last seen, run `Sync.pull`.
  - `.github/workflows/deploy-staging.yml`: `POINTER_LIVE_URL`.
- Test: `test/core/live_heads_test.dart`

**Interfaces:**
- `class LiveHeads { static void start(String campus, Future<String?> Function() idToken); static void poke(String path); static void pokeMe(); static Stream<Set<String>> get moved; }`
  - Off when `POINTER_LIVE_URL` is empty.
  - A message updates the saved head (`head|$campus` in `sharedCache`, merged so `v` holds the new numbers) and emits the moved paths on `moved`.
  - Reconnect only after a real drop, with jitter (1–10 s, doubling, capped at 5 min).
  - After 3 failed connects, stop for the session; `headFor` keeps working through the Worker or Firestore.
  - The transport goes through a conditional import (stub on the VM, `package:web` `WebSocket` on the web), so tests inject a fake channel.
- Screens don't need to listen: the next `load` sees the moved marker (A1 version check). Prefetch re-runs the level that owns a moved path, once.
- [ ] **Steps:** write the tests first with a fake channel. Cover: hello saves the head; `head` merges and emits; poke sends JSON; three failures stop; `me` greater than the last seen calls the injected pull. Run FAIL → implement → PASS → `flutter test` → commit `"Live markers and personal version over one WebSocket"`.

### Task D4: Docs and the end-to-end check

**Files:**
- Modify: `docs/ARCHITECTURE.md` (§6 heads: the `v` map and `Paths`; §13: what is built and what is pending; a sequence diagram of poke → DO → broadcast), `agent_instructions/DATA_SYNC_PLAN.md` (mark Stages 1–3 built and the open questions answered), `README.md` performance table (add rows once measured).
- [ ] **Step 1:** End-to-end check on staging once the owner has deployed the Worker. Use two browsers signed in as two Goa test accounts. A president adds a link in A, and B's Resources shows it on reopen without a relaunch (the marker was pushed). Kill the Worker's route, reload: the app still opens (Review Focus 4).
- [ ] **Step 2:** Measure:
  - repeat-visit Resources and Reviews open to content, before (`a9d7978`) and after, on the throttled Chrome script;
  - Firestore reads per open via `window.pointerPerf.summary()`.
  
  Add both to the README and §13.
- [ ] **Step 3: Commit** `"Docs: markers, Worker and live push as built"`.
