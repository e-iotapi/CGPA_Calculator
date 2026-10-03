# Build-out contracts (backend lane <-> UI lane)

Binding. Source plan: `BUILDOUT_PLAN.md`; server design `DATA_SYNC_PLAN.md` §5; product `PROPOSED_FEATURES.md`. If code must differ, the lane that needs it states the change to the other lane's controller first. UI builds against these signatures with `FakeFirebaseFirestore`; the backend matches them exactly. Rulings R-A..R-D apply.

## 0. Conventions

- **Marker budget (S5):** `heads/<campus>.v` allows at most **4 changed keys per write** (`firestore.rules:589-594`). Every batch below lists its marker bumps; none exceeds 3. `activity` and `contributors` are NOT markers (plain docs, plain `cacheFirst` with `maxAge`, no `version`).
- **Stores** take `FirebaseFirestore db` plus `RoleStore roles` (audit via `roles.logInto`, identity via `roles.me`/`roles.myName`) like `ProfessorStore`. Writes: one batch = shared doc(s) + `audit` entry + `bumpPath(...)` for each listed marker, then `LiveHeads.poke(path)` and `forget(<cache prefix>)`.
- **cacheFirst:** `key`, `version: await markerOf(db, campus, Paths.x)` where a marker exists. `peek...` = sync `peekCache(key, decode)`. Numbers decode as `num` (K18). Shared box `sharedCache` unless stated.
- **Errors:** every write may throw `FirebaseException` (`permission-denied`, `unavailable`, `aborted`/`failed-precondition` = stale, show Try again). Typed errors below extend `StoreError(String code)` in `lib/core/roles/store_error.dart` (new, BE-S). UI maps: `permission-denied` -> denied notice, `unavailable` -> offline strip + Try again, typed -> its message.
- **Dates in docs:** Firestore `Timestamp` for server times (`request.time`); cached/JSON as epoch ms (`num`). Calendar dates are `YYYY-MM-DD` strings, times are minutes since midnight (campus local, no zone).
- **Campus keys:** `goa|hyderabad|pilani|dubai`. **Dept keys:** `deptOf` output, plus `GEN` (B2).

### New `Paths` members (`lib/core/heads/paths.dart`, Builder owns)

| Member | Value | Bumped by |
|---|---|---|
| `Paths.reviewGate` | `'reviewGate'` | B6 gate switch |
| `Paths.pending(dept)` | `'pending/$dept'` | B7 contributor link create, approve, reject |
| `Paths.leaderboard` | `'leaderboard'` | B7 approve (points change) |
| `Paths.contribRequests(dept)` | `'contributorRequests/$dept'` | B7 apply, withdraw, decide |
| `Paths.courseClaims` | `'courseClaims'` | B2 claim/unclaim |
| `Paths.timetable` | `'timetable'` | B8b publish (value = publish counter) |

Existing reused: `resources` (links + their mirror), `professors/<dept>`, `grants`, `staff`.

### Rules vocabulary (BE-R)
`managingDept(campus, course)` = `deptOf(course)` unless prefix is GEN-mapped and `courseClaims/<campus>|<course>` exists, then claim `.dept`. Replace `deptOf` only at course-scoped sites (resources, CR checks, professor/structure edits). `isContributor(campus)` = live grant `contributor|...` on campus, or admin/president/secretary/CR/owner. All new docs: `audited(path)` where noted = `auditId` field and matching audit doc in the same batch (existing function).

---

## B1 Prefs

**Doc** `users/{uid}` gains optional top-level `prefs: {offshootHidden?: bool, tourSeen?: bool}` (no other keys). Write: owner of uid only (`request.auth.uid == uid`). Rule change (K12): an update whose `diff.affectedKeys().hasOnly(['prefs'])` and prefs values bool is allowed without `rev`/`data` (the `rev+1` rule stays for data pushes). The existing sync push must `merge` and never delete `prefs`.
**Audit:** none. **Markers:** none. **Cache:** Hive `deviceBox` keys `pref.offshootHidden`, `pref.tourSeen` (bool), so reads are sync.

`lib/core/prefs/prefs_store.dart`
```dart
class PrefsStore {
  PrefsStore(this.db, {required this.uid});
  bool get offshootHidden;            // peek twin: sync from deviceBox, default false
  bool get tourSeen;                  // default false
  Future<void> setOffshootHidden(bool v); // box first, then merge-set prefs.offshootHidden
  Future<void> setTourSeen(bool v);
  Future<void> pull();                // get users/{uid}.prefs into deviceBox; no-op offline
}
```
Errors: setters never throw to UI on `unavailable` (local value stands, retried by `pull`/next set); `permission-denied` rethrown.

---

## B2 GEN + course claims

**Doc** `courseClaims/<campus>|<course>` (course id has a space: `goa|BITS F111`):

| Field | Type | Req | Notes |
|---|---|---|---|
| `campus` | string | y | == id part |
| `courseId` | string | y | GEN-mapped prefix only |
| `dept` | string | y | claiming dept, not `GEN`; course must be a CDC of one of its programmes (app-checked, rules check prefix is GEN-mapped) |
| `by` | `{email,name}` | y | `by.email == me()` |
| `at` | timestamp | y | `== request.time` |
| `auditId` | string | y | `audited('courseClaims/'+id)` |

Create/delete: president or secretary of `dept` on `campus` (owner/admin too). No update (unclaim = delete, claim by another dept = delete then create, each its own batch). Delete is allowed here (the only hard delete in the build-out) and audited. Markers: `Paths.courseClaims` (1).

**GEN in app** (`roles.dart`, mirrors rules): `deptOf` returns `GEN` for any prefix not in a known department; GEN has no branch code and is never returned by `programmes`/`departmentOfProgramme`. Elective Contributor = existing `dept` grant with `scope: 'GEN'`, appointed by owner/admin via `RoleStore.appoint(role: GrantRole.dept, scope: 'GEN', ...)` (no new grant type). Markers as existing grant writes.

`lib/core/roles/claim_store.dart`
```dart
class CourseClaim { final String campus, courseId, dept, byName, byEmail; final int at;
  static CourseClaim fromMap(Map m); Map<String,dynamic> toMap(); }
class ClaimStore {
  ClaimStore(this.roles);
  Future<Map<String, CourseClaim>> claims(String campus);   // courseId -> claim; cacheFirst key 'cl|$campus', version markerOf(Paths.courseClaims), maxAge 1h; query collection where campus==
  Map<String, CourseClaim>? peekClaims(String campus);
  Future<void> claim(String campus, String courseId, String dept);  // throws ClaimError('taken') if one exists
  Future<void> unclaim(String campus, String courseId);
}
```
Pure: `String managingDept(String courseId, Map<String,CourseClaim> claims)` (in `roles.dart`): `deptOf(courseId)`; if `GEN` and `claims[courseId]` exists -> its `dept`. Edge: claim for a non-GEN course is ignored; unknown id -> `GEN`. Client mirrors the rule; screens use it for "who manages this course" and the DeptCourses claim pill.

---

## B3 Professor soft delete

**Doc** `professors/<id>` gains optional `removed: bool`, `removedBy: {email,name}`, `removedAt: timestamp (== request.time)`. Existing keys unchanged. Rules: set `removed:true` (and un-set) only by `editsProfessors(campus, dept)` of a **president/secretary** (or owner/admin), `audited`, `pathBumped professors/<dept>`. A removed doc is frozen like a merged one (no rename/merge/alias edits) until restored. Markers: `Paths.professors(dept)` (1). Activity: same batch writes `activity/<campus>.dept.<dept>` (see B4).

`Professor` model: `final bool removed; final String? removedByName;` `fromMap` reads `removed` (default false); `toMap` writes it.
`ProfessorStore` additions:
```dart
Future<void> remove(Professor p);     // throws ProfessorError('merged') if p.merged
Future<void> restore(Professor p);
```
Behaviour: `department()` returns removed ones too (the UI groups them under "Removed"); `search()` and `taught()` **exclude** removed; `get(id)`, `peekGet`, `byProfessor` and review filters keep them. Cache: existing `prof|$campus|$department` (marker version already `professors/<dept>`).
Pure: `List<Professor> livePicks(List<Professor> all)` = not removed, not merged, `active`. `Professor? duplicateOf(String name, Iterable<Professor> all)` -> first non-merged professor whose `nameTokens` set equals or one contains the other (>=2 tokens) for the duplicate warning; null if none.

---

## B4 Last updated

**Doc** `activity/<campus> = { course: {<courseId>: ts}, dept: {<dept>: ts} }`. Timestamps are `request.time`. Writable (merge) only by a batch that also writes a resource (create/update, not unchanged), a course structure (offering scheme), or a professor, by the same actor; value must `== request.time` and key must be `managingDept`/`deptOf` of that write's course/dept. Read: any `mayUse()` on that campus. **Not a marker**; no audit of its own. Markers per write: unchanged.

`lib/core/roles/activity_store.dart`
```dart
class Activity { final Map<String,int> course, dept;   // epoch ms
  int? ofCourse(String id); int? ofDept(String d); }
class ActivityStore {
  ActivityStore(this.db);
  Future<Activity> of(String campus);  // cacheFirst key 'act|$campus', maxAge 10 min, NO version
  Activity? peekOf(String campus);
  static void touch(WriteBatch b, FirebaseFirestore db, String campus, {String? courseId, String? dept});
      // merge-set; call from ResourceStore.add/update, ProfessorStore.add/rename/remove, structure saves
}
```
Pure: `int semestersAgo(int tsMs, DateTime now)` = whole academic semesters between (Aug-Dec = sem 1, Jan-May = sem 2, Jun-Jul = summer, counted as boundaries crossed; 0 = this semester); `bool isStale(int? tsMs, DateTime now)` = null or `semestersAgo >= 2`; `String updatedLabel(int? tsMs, DateTime now)` -> "Updated Aug 2026" / "2 semesters ago" / "Not updated yet". Neutral wording.

---

## B5 Review grade + marks

**Doc** `reviews/<c>/entries/<id>` gains `grade` (string, one of `A A- B B- C C- D E NC RC W ND`; **required on create when the writer's client is new**: rules require it on create, optional on update) and `marks` (num, optional, `0 <= marks <= 1000`; absent when not given). Update `hasOnly` list gains `grade`, `marks`. `source`/`imported` unchanged. Old reviews have neither: still valid. Review mirror `reviews/<c>/campus/<campus>.r.<id>` copies `grade` and `marks` (add to the mirror writer/check). No new counters (R-B), no markers beyond the existing `reviews/<c>` and `reviews`.

`Review` (lib/core/reviews/review.dart): `final String? grade; final num? marks;` in `fromMap`/`toMap`/`withHelpful`. `ReviewStore.save` gains `required String grade` and `num? marks` (before them: `Review? before`). Compat: `grade` default `'ND'` only for UI pre-fill, not store default.
Pure (new `lib/core/reviews/review_stats.dart`):
```dart
class ReviewSummary { final int count; final double? avgStars; final int? recommendPct;
  final double? avgGradePoints; final String? avgGradeLetter; final double? avgMarks; final int marksCount; final int gradeCount; }
ReviewSummary statsOf(Iterable<Review> rs);
```
`statsOf`: counts reviews passed (caller already applied filters); stars/recommend as `ReviewStats`; grade average over grades that are a letter with points in `gradeValues` (excludes `ND`, `W`, `NC`, `RC`), letter = nearest via `gradecalc(round)`; marks average only over non-null `marks`, `avgMarks == null` when none (UI hides marks). Empty -> all null, count 0. Hidden reviews must be excluded by the caller.
```dart
enum ReviewSort { helpful, recent, highest, lowest }
class ReviewQuery { final Set<String> professorIds; final String? year;  // '2023-24' validated
  final String? sem; /* '1'|'2'|'S' */ final String text; final ReviewSort sort; }
List<Review> applyQuery(Iterable<Review> rs, ReviewQuery q, Map<String,String> professorNames);
String? validYear(String input);   // accepts '2023-24' or '2023' (-> '2023-24'); null if odd or year<2000 or >now+1
```
`applyQuery` extends `ReviewFilter` (reuse `termParts`): empty professorIds = all; filters AND-combine; `professorIds` matched against `[id, ...mergedIds]` expanded by the caller; sort ties by `createdAt` desc; `highest`/`lowest` sort by stars then helpful. `ReviewStore.page` keeps its signature (loaded list is filtered in memory); add `Future<List<Review>> all(String courseId, String campus)` (same cacheFirst key `rcd|...`, no ordering) and `List<Review>? peekAll(...)`.

---

## B6 Review gate

**Doc** `reviewGate/<campus> = { on: bool, by: {email,name}, at: timestamp, auditId: string, dept?: string }`. Read: any `mayUse()` on that campus (get, one doc). Write (create/update): owner/admin any campus; president or secretary (a dept grant, checked with `isPresident(campus, dept)`) on their own campus, writing the `dept` they hold (owner/admin omit it); `at == request.time`, `audited('reviewGate/'+campus)`. Markers: `Paths.reviewGate` (1). Turning off is a write with `on:false`. Missing doc == off.

`lib/core/reviews/gate_store.dart`
```dart
class GateStore {
  GateStore(this.roles);
  Future<bool> of(String campus);      // cacheFirst key 'gate|$campus', version markerOf(Paths.reviewGate), maxAge 1h
  bool? peekOf(String campus);
  Future<void> set(String campus, bool on, {String? dept});   // throws on permission-denied
}
```
Pure (`lib/core/reviews/gate.dart`):
```dart
enum GateState { open, locked, unlocked, exempt }
bool pastTwoOne(String? currentsem);              // true only when the semester is after '2 - 1' in semesters.dart baseSemesters order; null/unknown/PS/ST handled by index; false for '2 - 1' and earlier
int required(int electivesTaken);                 // min(electivesTaken, 5)
GateState gateState({required bool on, required String? currentsem, required int electivesTaken, required int myReviewCount});
```
`gateState` spec: `on == false` -> `open`. Not `pastTwoOne` (incl. unknown) -> `exempt`. `required == 0` (no electives taken) -> `exempt`. `myReviewCount >= required` -> `unlocked`. Else `locked` (hides all reviews incl. in course search; resources are never gated). `myReviewCount` = caller's count of own **non-imported** reviews that have stars and `recommend` set (text optional), from the "mine" cache. `pastTwoOne` uses `baseSemesters.indexOf`; dual-degree extras (`ST 2`, `5 - x`) are past. UI treats `exempt` and `open` as show-reviews.

---

## B7 Contributors

### Docs

**`contributorRequests/<campus>|<dept>|<email>`** (volunteer pattern)

| Field | Type | Req | Allowed |
|---|---|---|---|
| `name` | string | y | `nameOk` |
| `email` | string | y | `== me()` on create |
| `campus` | string | y | `== campusOf(me())` |
| `dept` | string | y | the student's branch dept, `== deptOf` of their programme |
| `status` | string | y | `pending` (create, re-apply), `withdrawn` (student), `approved` / `declined` (approver) |
| `createdAt` | timestamp | y | `== request.time` on create/re-apply |
| `decidedBy` | string | on decide | approver email |
| `decidedAt` | timestamp | on decide | `== request.time` |
| `reason` | string | optional | on decline, <= 200 chars |

Read: the student (get own), and approvers (admin, president/secretary of `dept`, owner) via list. Write: student create/withdraw; approver decide. Markers: `Paths.contribRequests(dept)` (1). Approval = this doc `approved` + grant create in the **same batch** (markers: `contribRequests(dept)`, `grants`, `staff` = 3). Decline: `contribRequests(dept)` (1). Revoke: grant `active:false` (`grants`, `staff` = 2).

**Grant** `grants/contributor|<campus>|<campus>|<email>`: standard grant doc, `role:'contributor'`, `scope = campus key`, `expiresAt` = sentinel `2100-01-01` (UI shows "until revoked"; `Grant.liveAt` unchanged). Created by owner/admin/president/secretary (president: only where request `dept` is theirs). `GrantRole.contributor('contributor','Contributor','CONTRIBUTOR')`, `.role => Role.student`. Capabilities: new row `contribute` ("Contribute links (approved within 15 days)"), staff cells from the existing table (all staff are contributors by default, no second grant). Update `ARCHITECTURE.md` §4 in the same change (capabilities_test).

**Link (resource) fields**, added to `resources/<id>` and the `resourceVersions/<campus>.links.<id>` mirror (mirror check extended to `approved`, `publishedAt`):

| Field | Type | Notes |
|---|---|---|
| `approved` | bool | absent == true (all existing links). Contributor create must be `false` |
| `publishedAt` | timestamp | contributor create only, `== request.time` |
| `batchId` | string | contributor create only, groups one submission |
| `rejectedReason` | string | set with `removed:true` on reject |

Contributor rules: may create (scope department or course, any dept on their campus) with `approved:false`; may update own (`addedBy.email == me()`) title/url/courseIds, `approved` and `publishedAt` unchanged (ruling 2: an edited approved link stays approved, audited, no points); never delete/remove. Approvers (admin, `managingDept` president/secretary, owner; CRs for own courses unchanged) approve/reject. Existing presidents/CR creates stay `approved` absent.

**`pending/<campus>|<dept>`** = `{ batches: { <batchId>: { email, username, at: ts, links: { <resourceId>: {title, url} } } } }`. Written only in the same batch as the link create (adds to `batches.<id>.links`), approve/reject (removes the link; removes the batch when empty). One read per queue.

**`contributors/<email>`** = `{ username: string, campus: string, points: int }`. Read: self, approvers on campus (get). Created/updated: self for `username` only (at claim, with the `usernames` doc); `points` changes only in an approve batch, `+4` exactly, to `addedBy.email` (R-C: staff create writes +4 for themselves in their own create batch, optional). `points` never decreases.

**`usernames/<campus>|<name>`** = `{ email, claimedAt: ts }`. `name` charset `[a-z0-9_]`, 3-20, create-only by the claimant in the same batch as `contributors/<email>.username` (rules: doc did not exist, `email == me()`); a president/secretary may delete an offensive one and clear the username (audited). Username is immutable by the user once claimed.

**`leaderboard/<campus>`** = `{ p: {<username>: int}, tags: {<username>: string} }` (tag = branch code, only for admin/president/secretary; absent for others). Written only in an approve batch (and the staff points write): `p.<username>` must equal the `contributors/<email>.points` after the batch (rules mirror check via `getAfter`). Read: any `mayUse()` on the campus. A contributor appears here only after claiming a username.

### Batch table (≤4 markers each)

| Write | Docs in the batch | Markers |
|---|---|---|
| Apply / withdraw | request | `contribRequests(dept)` |
| Approve request | request, grant, staff entry, audit | `contribRequests(dept)`, `grants`, `staff` |
| Decline request | request, audit | `contribRequests(dept)` |
| Revoke | grant, staff, audit | `grants`, `staff` |
| Claim username | `usernames`, `contributors` | none |
| Contributor submit (1 link) | resource, `links` mirror, version, pending, audit | `resources`, `pending(dept)` |
| Contributor edit own link | resource, mirror, audit | `resources` |
| Approve link | resource `approved:true`, mirror, pending removal, `contributors.points +4`, `leaderboard`, audit | `resources`, `pending(dept)`, `leaderboard` |
| Reject link | resource `removed:true`+`rejectedReason`, mirror removal, pending removal, audit | `resources`, `pending(dept)` |

Approve is **one link per batch** if S1 shows the access limit is exceeded; `approveBatch` loops. Rules refuse approve when `publishedAt + 15d <= request.time` and refuse a second +4 (only the `approved:false -> true` transition).

### Dart

`lib/core/contrib/contributor_store.dart`
```dart
enum RequestStatus { pending, approved, declined, withdrawn }
class ContributorRequest { final String email, name, campus, dept; final RequestStatus status; final int createdAt; final String? reason, decidedBy; }
class MyContributor { final bool isContributor; final String? username; final int points; final ContributorRequest? request; }
class ContributorStore {
  ContributorStore(this.roles);
  Future<ContributorRequest?> myRequest(String campus, String dept);   // get own doc; cacheFirst key 'cr|$email', maxAge 5 min, version markerOf(Paths.contribRequests(dept))
  ContributorRequest? peekMyRequest(String email);
  Future<void> apply(String campus, String dept);                       // throws ContribError('exists') when pending/approved
  Future<void> withdraw(ContributorRequest r);
  Future<List<ContributorRequest>> requests(String campus, String dept);// pending only; cacheFirst 'crq|$campus|$dept', version marker, approvers only
  List<ContributorRequest>? peekRequests(String campus, String dept);
  Future<void> approve(ContributorRequest r);                           // doc + grant, via roles.appoint-style grant write
  Future<void> decline(ContributorRequest r, {String? reason});
  Future<void> revoke(Grant g);                                         // delegates RoleStore.revoke
  Future<MyContributor> me(String campus);                              // contributors/<email> + grant check; cacheFirst 'me-ct|$email', maxAge 10 min, no version
  MyContributor? peekMe(String email);
  Future<void> claimUsername(String campus, String name);               // throws UsernameTaken, ContribError('badName')
}
bool validUsername(String s);   // ^[a-z0-9_]{3,20}$ after trim+lowercase
```
`lib/core/resources/resource_store.dart` extensions (same class, new methods; existing ones unchanged):
```dart
Future<String> addAsContributor(Resource r, {String? batchId});         // approved:false, publishedAt
Future<String> addBatchAsContributor(List<Resource> rs);                 // one commit per link (marker budget), shared batchId; returns batchId
Future<void> updateOwn(Resource r);                                      // keeps approved/publishedAt
Future<List<PendingBatch>> pending(String campus, String dept);          // cacheFirst 'pend|$campus|$dept', version markerOf(Paths.pending(dept)), maxAge 5 min; Loaded(gated) + refresh on open (K16)
List<PendingBatch>? peekPending(String campus, String dept);
Future<void> approve(PendingBatch b, {Iterable<String>? linkIds});       // default all links; +4 each; stops and rethrows on first failure
Future<void> reject(PendingBatch b, {Iterable<String>? linkIds, required String reason});
Future<List<Resource>> mine(String campus);                              // contributor's own links incl. pending/rejected, cacheFirst 'rmine|$campus|$email'
List<Resource>? peekMine(String campus);
class PendingBatch { final String id, campus, dept, email, username; final int at; final List<({String id,String title,String url})> links; }
```
`Resource` gains `final bool approved` (default true), `final int? publishedAt`, `final String? batchId`, `final String? rejectedReason`. Errors: `ContribError('window')` approve/edit after 15 days, `ContribError('notContributor')`, `UsernameTaken`, `ContribError('stale')` (batch already decided by another approver; UI refreshes).
Pure (`lib/core/resources/contrib.dart`):
```dart
const approvalWindow = Duration(days: 15);
bool linkVisible(Resource r, DateTime now);              // approved || publishedAt == null -> true; else now < publishedAt+15d
LinkState linkState(Resource r, DateTime now);           // enum LinkState { approved, awaiting, expired, rejected }
```
`ResourceStore.department/_load` apply `linkVisible` to every read (for everyone, the contributor included); the contributor's own `mine()` shows expired/rejected states instead. `rejected` = `removed && rejectedReason != null`. Edge: clock skew uses device `now`; rules are the authority.

`lib/core/contrib/leaderboard_store.dart`
```dart
class LeaderRow { final int rank; final String username; final int points; final String? tag; }
class LeaderboardStore {
  LeaderboardStore(this.db);
  Future<List<LeaderRow>> of(String campus);     // ranked desc points, ties by username; cacheFirst 'lb|$campus', version markerOf(Paths.leaderboard), maxAge 30 min
  List<LeaderRow>? peekOf(String campus);
}
```

---

## B8a Timetable extractor
`tools/timetable/extract.mjs <pdf> --campus goa --sem 2026-1 [--commit] [--project staging]`; output is the schema of B8b below. Dry run default. Node test on synthetic fixtures. The PDF is never committed.

## B8b Broadcast timetable

### JSON schema (Worker `GET /timetable/<campus>.json`, `application/json`, one merged file)

```json
{ "v": 1, "campus": "goa", "sem": "2026-1", "publishedAt": 1790000000000, "marker": 3,
  "hours": { "1": [480, 540], "2": [540, 600], "...": "..." },
  "examSlots": { "FN": [570, 750], "AN": [840, 1020] },
  "events": [ { "from": "2026-08-03", "to": "2026-08-03", "title": "Instruction begins", "kind": "term" } ],
  "courses": { "CS F111": { "t": "Computer Programming", "cr": 4,
      "sec": [ { "ty": "L", "no": 1, "prof": ["Name"], "profIds": ["<professors id>"],
                 "slots": [ { "d": 1, "s": 540, "e": 600 } ], "room": "F101" } ],
      "compre": { "d": "2026-12-10", "slot": "FN", "s": 570, "e": 750 },
      "mid": { "d": "2026-10-12", "s": 570, "e": 660 } } } }
```
| Field | Type | Req | Notes |
|---|---|---|---|
| `v` | int | y | schema version, 1; client ignores unknown fields, rejects `v` greater than 1 as "update the app" |
| `campus`, `sem` | string | y | `sem` = `YYYY-N` (N = 1, 2, S) |
| `publishedAt` | int ms | y | |
| `marker` | int | y | publish counter (the `timetable` head marker at publish) |
| `hours` | map str -> [startMin, endMin] | y | hour code -> minutes (default `1:[480,540]`, one hour each) |
| `examSlots` | map | y | FN/AN minutes (correctable without re-parse) |
| `events[]` | `{from,to?,title,kind}` | y (may be empty) | dates `YYYY-MM-DD`, `kind` in `holiday|exam|deadline|term` |
| `courses.<id>.t` | string | y | title |
| `.cr` | num | optional | credits |
| `.sec[].ty` | `L|T|P` (`I`,`R` omitted) | y | |
| `.sec[].no` | int | y | section number |
| `.sec[].prof` / `profIds` | string[] | y (may be empty) | `profIds` only for matched professors; parallel, `""` for unmatched |
| `.sec[].slots[]` | `{d:1..6, s, e}` | y (empty for TBA) | `d`: 1 = Mon .. 6 = Sat; minutes since midnight; consecutive hours merged |
| `.sec[].room` | string | optional | |
| `.compre` | `{d, slot, s, e}` | optional | absent/TBA omitted |
| `.mid` | `{d, s, e}` | optional | |

Section key `sk = '<courseId>|<ty><no>'` ("CS F111|L1"); slot id `slotId = '<sk>|<d>-<s>'` (published day and start). Exam times always resolved to minutes in the file.
Worker: serves the current sem; memoized like `/heads`, `Cache-Control: public, max-age=300`, `ETag: "<marker>"`; 404 + `{"error":"not published"}` when none. Auth none (public data, no emails).

### Firestore (fallback and source)
- `timetable/<campus>|current = { sem: string, marker: int }` (write: owner/admin).
- `timetable/<campus>|<sem>` meta `{ v:1, sem, campus, hours, examSlots, events, chunks: int, publishedAt: ts, marker: int, auditId }`.
- `timetable/<campus>|<sem>|<n>` (n = 0..chunks-1) `{ n:int, courses:{ <id>:{...as above} } }`, each < 900 KB, grouped by course prefix.
- Read: any `mayUse()`. Create/update: owner or admin only (script), `audited`, meta write only (chunks need `auditId == meta.auditId` via getAfter). No delete from clients. Markers: `Paths.timetable` (1) with `current`.

### Dart `lib/core/timetable/`
```dart
// timetable.dart
class TtSlot { final int d, s, e; String get id => '$d-$s'; }
class TtSection { final String ty; final int no; final List<String> prof, profIds; final List<TtSlot> slots; final String? room; String key(String courseId) => '$courseId|$ty$no'; }
class TtExam { final String d; final String? slot; final int s, e; }
class TtCourse { final String id, title; final num? credits; final List<TtSection> sections; final TtExam? compre, mid; }
class AcademicEvent { final String from; final String? to; final String title, kind; }
class Timetable { final String campus, sem; final int publishedAt, marker; final Map<String,TtCourse> courses; final List<AcademicEvent> events;
  static Timetable fromJson(Map m);  Map<String,dynamic> toJson();
  List<TtCourse> search(String q);  // id/title word-prefix, <= 50, ids first
  String lastClassworkDay();        // latest 'to' (or 'from') of events with kind 'term' whose title contains 'last day' (case-insens.), else max over term events, else sem start + 16 weeks
}
// timetable_store.dart
class TimetableStore {
  TimetableStore(this.db, {this.workerBase, http.Client? client});
  Future<Timetable?> current(String campus);   // null = not published yet (UI: "Timetable not published yet")
  Timetable? peekCurrent(String campus);        // sync; decode from Hive off the first frame
}
```
`current`: cacheFirst key `tt|$campus`, `version: await markerOf(db, campus, Paths.timetable)`, maxAge 12 h, box = Hive `timetable` (new, opened lazily, not in `cacheBoxes` first-frame path), fetch = Worker JSON then, on any failure or when `workerBase == null`, Firestore (`current` pointer -> meta -> chunks in parallel) assembled to the same `Timetable`. `current` returns null on 404/pointer missing; it never returns a different campus's data. Parse once, memoize the `Timetable` object per `(campus, marker)`. Errors: network failure with nothing cached rethrows `FirebaseException(unavailable)`. Register `Paths.timetable` in prefetch level 2 (Builder 2).

### Calendar student model (device, Hive box `calendar`, never synced; legacy `Course` adapter untouched)
Box `calendar`, key `profile.<profileIndex>` -> JSON **string** (`jsonEncode`, no adapter):
```json
{ "ver": 1, "campus": "goa", "sem": "2026-1",
  "picks": { "CS F111": ["CS F111|L1", "CS F111|T3", "CS F111|P2"] },
  "slotOverrides": { "CS F111|L1|1-540": { "d": 2, "s": 600, "e": 660 } },
  "repeatUntil": { "CS F111": "2026-11-28" },
  "removed": { "CS F111|L1|1-540|2026-09-14": true },
  "examsOff": { "CS F111": true },
  "custom": [ { "id": "c1", "title": "Club", "d": 3, "s": 1020, "e": 1080, "room": "", "from": "2026-08-10", "until": "2026-11-28", "once": false } ] }
```
| Key | Meaning |
|---|---|
| `picks` | courseId -> section keys the student attends; removing the course deletes the entry (and its overrides) |
| `slotOverrides` | slot id -> replacement `{d,s,e}`; applies to **every week** (one edit, all occurrences) |
| `repeatUntil` | courseId -> last date (inclusive); default `Timetable.lastClassworkDay()` |
| `removed` | single occurrences hidden (`slotId|date`) |
| `examsOff` | course whose midsem/compre are not shown |
| `custom` | no-course events; `once:true` uses only `from`; else weekly on `d` from `from` to `until` |
| `sem` | when it differs from the published `sem`, state is read-only archived and "pick courses" restarts |

`lib/core/timetable/calendar_store.dart`:
```dart
class CalendarState { /* fields above */ static CalendarState fromJson(Map m); Map<String,dynamic> toJson(); }
class CalendarStore {
  CalendarStore(this.box, {required this.profile});
  CalendarState get state;                              // sync
  Future<void> addCourse(TtCourse c, List<String> sectionKeys);   // also clears stale removed/overrides for c
  Future<void> removeCourse(String courseId);
  Future<void> setSlotOverride(String slotId, {required int d, required int s, required int e}); // throws StateError if e <= s
  Future<void> setSlotOverrides(Map<String,({int d,int s,int e})> edits);  // one write for the whole class sheet
  Future<void> resetSlot(String slotId);
  Future<void> setRepeatUntil(String courseId, String date);
  Future<void> removeOccurrence(String slotId, String date);
  Future<void> setExamsShown(String courseId, bool shown);
  Future<void> addCustom(CalendarCustom e); Future<void> removeCustom(String id);
}
```
Writes await `box.put` (tests: unit-test the store, UI tests in memory).

### Pure expansion (`lib/core/timetable/occurrences.dart`)
```dart
enum OccKind { cls, midsem, compre, custom, event }
class Occurrence { final String id, courseId, title; final OccKind kind; final String date; final int start, end; final String? room, sectionKey; final List<String> prof; final bool edited, stale; }
List<Occurrence> expandOccurrences(Timetable? t, CalendarState s, {required String from, required String to}); // inclusive 'YYYY-MM-DD'
List<Occurrence> occurrencesOn(Timetable? t, CalendarState s, String date);
```
Behaviour: for each picked section and each published slot, apply `slotOverrides[slotId]` if present (`edited:true`) else the published `d,s,e`; emit one `cls` per week on that weekday from `max(from, sem start)` through `min(to, repeatUntil[course] ?? lastClassworkDay)`; drop dates in `removed`; sort by date, start, id. A pick whose section/slot no longer exists in `t` (republish): section gone -> emitted as nothing and listed by `staleSections(t, s)`; slot gone but override exists -> emitted with `stale:true` from the override ("your time (published time changed)"). Midsem/compre: one occurrence each on its date for courses in `picks` unless `examsOff`; kinds `midsem`/`compre`. `t == null` -> only `custom` items. Customs: once -> one date; else weekly from `from` to `until`. Events with `kind=holiday` are not emitted as occurrences; `eventsOn(t, date)` returns them. Edge: weekday of `d` uses ISO (1 Mon..6 Sat; no Sunday classes); an override may move to any weekday 1..7; DST none (floating times). Overrides never apply to exams.
`List<String> staleSections(Timetable t, CalendarState s)`.

### `GET /calendar/<campus>.ics`
RFC 5545, CRLF, lines folded at 75 octets. `PRODID:-//Pointer//Campus Calendar//EN`, `X-WR-CALNAME:<Campus> academic calendar <sem>`, `REFRESH-INTERVAL;VALUE=DURATION:P1D`, `X-PUBLISHED-TTL:P1D`. One `VEVENT` per academic `events[]` entry: all-day (`DTSTART;VALUE=DATE`, `DTEND` = to+1 day exclusive), `SUMMARY`, `CATEGORIES:<kind>`, `UID:<campus>-<sem>-<sha1(from|title)>@pointer`, `DTSTAMP` = publishedAt, stable across republish. Plus midsem and compre of **every** course as timed events in `Asia/Kolkata` (`DTSTART;TZID=Asia/Kolkata:`, a `VTIMEZONE` block included): `SUMMARY:<id> Midsem|Compre`, `DESCRIPTION:<title>`, UID `<campus>-<sem>-<id>-<mid|comp>@pointer`. No classes (those are per student). Edge-cached 1 h; 404 when no timetable; `Content-Type: text/calendar; charset=utf-8`. Large: compre/midsem events only, ~2 per course, under 1 MB. The app's Subscribe sheet shows `https://<workerHost>/calendar/<campus>.ics` and the Google link `https://calendar.google.com/calendar/r?cid=<webcal url, encoded>`.

---

## B9 Test accounts and seed
Extend `tools/test_env/gen_accounts.mjs` (generates `accounts.json`; staging only, prod guard kept) and `seed.mjs` (wipe list, `seed.test.mjs`):

| Account key | Setup |
|---|---|
| `contributor` | student with live `contributor|goa|goa|<email>` grant, username `ctest`, 8 points |
| `applicant` | student with a `pending` request in their dept |
| `electiveContributor` | `dept` grant scope `GEN`, campus goa |
| `gateStudent` | semester `3 - 1`, 3 elective courses, 0 reviews (locked when gate on) |
| `gateExempt` | semester `1 - 2` |
| `president` / `secretary` / `admin` / `owner` | existing keys; ensure a CDC claim target exists |

Seed data: `reviewGate/goa {on:true}`; two `pending/goa|ELEC` batches (3 links, 1 link, one 14 days old); `contributors/*`, `usernames/*`, `leaderboard/goa` (>=12 rows, mirrored); one `courseClaims` doc; `activity/goa` (some stale, some fresh); one soft-removed professor; reviews with `grade`/`marks`; a synthetic `timetable` (3 courses, 2 sections each, events, exams) with `current` pointer. Wipe list covers every new collection. All ids/names synthetic; the PDF never appears.
