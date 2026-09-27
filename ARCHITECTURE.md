# Pointer — architecture for shared data, roles and routes

Planning document. No code yet. This covers five changes that are really one
change: named routes, a maintainer/admin surface, a resources section, moving the course
catalogue out of the app bundle and out of every user's document, and the rule for what
happens when a user edits data that someone else maintains.

**This is the only plan.** `PLAN.md` is retired and is not to be read or updated; everything
from it that still matters — the maintainer and student screens (§13), the engineering gotchas
(§14) and the open UI work (§15) — has been carried into this document.

**USE UI DIRECTIONS artifact to build UI.** Every screen is designed on the *UI Directions*
canvas (https://claude.ai/artifact/K4H9w2Ad9cwdTqxPSAiWMW): page 1 is the student flow in order,
page 2 is arranged by role. Build each screen from its board — layout, copy, states and the link
to the next screen — and read the note under it. Where a board and this document disagree, this
document decides the data and the rules and the board decides the UI; fix whichever is wrong
instead of improvising. §16 maps every board to a route and a data source.

---

## 1. The constraint that decides everything

**No billing.** That rules out Cloud Functions, which rules out:

- custom auth claims (they can only be set by the Admin SDK), so roles live in Firestore
- server-side validation, so every write rule has to be expressible in the rules language
- scheduled jobs and triggers, so nothing can revoke, recount or publish on a timer

**And the free Firestore tier is 50,000 reads/day.** The catalogue is ~2,400 entries
(1,258 course rows + 1,111 master-list entries), so *one document per course* would cost a
single user 2,400 reads on open and twenty users a day would exhaust the quota. The fix is not
to move the data out of Firestore — it is to **stop shipping it one document at a time.**

### The split: per-course documents to edit, one bundle to read

| | Where | Who reads | Cost |
|---|---|---|---|
| Catalogue **source** | Firestore, one document per course | maintainers only, a few dozen reads | negligible |
| Catalogue **distribution** | Firestore, **one bundled document** + a tiny version marker | every student | **1 read, then cached** |

Measured: the course rows are **144 KB as compact JSON** — 1,272 rows, 10.8 KB gzipped — against
a **1 MiB** document limit. ⚠ That figure does not include the 1,111 master-list entries or the
degree requirements; **re-measure with everything the bundle will carry** before building it.
If the total ever passes ~800 KB, the bundle chunks by campus and a student reads only their own
slice.

At 2,000 users that is ~2,000 bundle reads a day against a 50,000 quota, and the Hive cache
plus the version marker means most app opens read only the marker.

There is **no CI in the data path**: no service account key in GitHub secrets, no deploy
coupling, and no second copy of the data that can drift from the first. **Publishing is a copy
inside Firestore**, done from `/admin` by an owner: assemble the per-course documents into the
bundle, write it, bump the version. That costs the publisher ~2,400 reads per publish, which is
nothing at a few publishes a day. The previous bundle is kept as a document, so any publish is
revertible.

**Two cadences.** Course identity changes rarely and is high-stakes, so it goes into the bundle
and publishes deliberately. Everything that changes weekly is **read live from Firestore**, in
small campus-scoped documents, fetched only for the student's own courses and cached:

- per-term **offerings** — components, averages, professors (§4, §10.1)
- **resources** (§6)
- **reviews** (§10.3)

A maintainer's edit to the catalogue is **not** live instantly: it ships on the next publish.
That is a review point before shared data reaches every student. An edit to an offering or a
resource is live on write; the audit log (§4) is its review point.

---

## 2. What moves, and the hidden win

Today `coursesBox` holds the catalogue *and* the user's grades together, and `sync.dart`
JSON-encodes the whole box into `users/{uid}`. **Every user's document therefore contains
a private copy of all 1,258 courses.** That is why the 500 KB cap (§14.5) is
close because the catalogue is in there 1,258 rows at a time. Splitting them shrinks the user
document to grades keyed by course id, which retires the problem rather than managing it.

| Data | Today | After |
|---|---|---|
| Course catalogue | `course.dart` (192 KB, compiled in) + every user doc | Firestore source → **bundle document** |
| Degree requirements (data) | `requirements.dart` | same bundle; the audit *logic* stays in code |
| Evaluative components | typed by each user; four seeded per course | published per term on the offering, user may detach (§5) |
| Class averages — course, component, part | typed by each user | published per term on the offering, user may detach (§5, §8) |
| Resources | — | Firestore, read live per department, cached (§6) |
| **Category / "Counts as"** | `coursesBox` + `pinned_categories` | **stays the user's** — published tag is only the default (§5) |
| **Courses not in the catalogue** | `coursesBox` | **stays** in `users/{uid}` as a custom entry (§5) |
| **Marks** | `marksBox` | **stays** in `users/{uid}` |
| **Overrides** | — | **`users/{uid}/overrides/`**, a sparse diff (§5) |
| **Grades** | `coursesBox` | **stays** in `users/{uid}` |
| **Settings, profiles, targets** | `settingsBox` | **stays** in `users/{uid}` |

The rule: **anything true for everyone is shared and published; anything true for one
person stays in their document.** A course's category is true for one person — the same
course counts differently per discipline — so it stays theirs.

### Grades must not reference a moving target

A grade is stored against a course id. If a maintainer renames or removes a course, a
user's history must not change meaning.

- **Ids are immutable.** A correction to a code is a new entry plus a retirement, never
  an edit in place.
- **Nothing is ever deleted** — `retired: true` only. This is §14.10 promoted from a
  course-map quirk to a platform rule.
- Retired entries are hidden from Add a course but still resolve, and still count, for anyone
  holding a grade against them — and every row they appear in says **Retired** (§11). *Built:
  `RetiredTag`, fed by `retiredCourses`, which the bundle fills.*
- The bundle carries a **schema version**; an older cached client that does not understand it
  keeps its previous copy instead of misreading the new one.

---

## 3. Offline is now a correctness requirement

Today the catalogue ships inside the bundle, so it cannot fail to load. Fetching it makes
it a network dependency, and the app is used on campus wifi.

- The catalogue caches in its own Hive box, `catalogBox` (register in all three places,
  §14.4), keyed by version.
- The app **boots from cache** and checks the version marker in the background. It never
  blocks first paint on the catalogue.
- **A fallback copy ships as an asset**, so a cold install with no network still works. It is
  written by an export script (`tools/export_catalog.dart`) that reads the current bundle, and
  **committed with each release**. It can lag the live bundle by one release — that is fine,
  because the first online open replaces it.
- The version check is one small document read, not the whole bundle.
- *Built (step 2):* `catalog/marker` `{version, schema}` and one `catalog/v{n}` per publish,
  whose `json` field is the bundle as a **string** — 2,400 nested rows would pass Firestore's
  per-document index-entry limit. Rows are arrays; the asset is 126 KB. Reverting a publish is
  pointing the marker back. Code: `lib/core/catalog/`.

Net effect: the app becomes *less* network-dependent than it is now, because the user
document no longer has to carry the catalogue.

---

## 4. Maintainers, without custom claims

### Who holds what

| | Owner | Admin | Department president | Course manager (CR) |
|---|---|---|---|---|
| Who | you, and whoever you add | a trusted second pair of hands | a student, for one department on their own campus | a student, for one course on their own campus |
| Account | **any verified Google account**, BITS or not | BITS | **BITS student address** | **BITS student address** |
| Scope | everything | appointments, every campus | one department, own campus | one course, own campus |
| Add / remove owners | ✓ (never themselves) | — | — | — |
| Appoint / revoke admins | ✓ | — | — | — |
| Appoint / revoke presidents | ✓ | ✓ | — | — |
| Appoint / revoke CRs | ✓ | ✓ | ✓ in scope | — |
| Publishing, analytics | ✓ | — | — | — |
| Public contact (`config/public`) | ✓ | ✓ | — | — |
| Grant terms — CR and president lengths | ✓ | ✓ | — | — |
| Grant terms — admin length | ✓ | — | — | — |
| Merge duplicate professors | ✓ | ✓ | ✓ in scope | — |
| Course structures, eval schemes | ✓ | — | ✓ | ✓ own courses |
| Bulk upload a JSON of eval schemes | ✓ | — | ✓ | — |
| Degree requirements | ✓ | — | ✓ | — |
| Department resources | ✓ | — | ✓ | — |
| Course resources | ✓ | — | ✓ | ✓ own courses |
| Averages — course, component, part | ✓ | — | ✓ | ✓ own courses |
| Professors — create, rename | ✓ | — | ✓ | pick only |
| Moderate reviews | ✓ | — | ✓ in scope | — |
| **Read the audit log and the roster** | ✓ | ✓ | ✓ own campus | — |

**Admin is deliberately narrow.** It exists so appointments do not queue behind one person,
and nothing else. An admin cannot publish, cannot appoint another admin and **cannot touch
course data** — the rules give an admin write access to grants and nothing else. That is the
whole point of separating it from Owner: the dangerous powers stay with named owner accounts.

### Owners are a list, and any verified account can be on it

The owner does not need a BITS address — the first one is a personal Gmail account — and must be
able to sign in everywhere: the calculator, `/admin`, `/maintain`.

```
owners/{email}      { name, email, active, addedBy: {email, name}, addedAt, auditId }
```

- **Sign-in accepts a non-BITS account only if `owners/{email}` exists and is active.** The app
  reads that one document after a non-BITS sign-in; anything else is signed straight out, as
  today. BITS accounts never make that read. Every `isBits()` in the rules becomes
  `isBits() || isOwner()`.
- **Owners add and remove owners from `/admin`**, which is how ownership is handed on or shared
  with more non-BITS accounts. Removing is `active: false`, logged like everything else.
- **An owner can never deactivate themselves**, so the app can never reach zero owners. Two
  owners removing each other in the same second is the only way round that, and it needs both.
- **Recovery is the Firebase console.** The first owner document is created there, and if every
  owner account is lost it is the only way back in. Write that down outside this repo.
- **An owner using the calculator** has no campus or batch in their address, so setup asks for
  both once, for owner accounts only; the answers are then final like everyone else's.

### Presidents and CRs are students, on their own campus

- **Only a BITS student address can hold a president or CR grant** — a letter, the four-digit
  batch year, the serial, a campus subdomain. A faculty address (`name@goa.bits-pilani.ac.in`)
  and an alumni address cannot. The rules check the pattern on every such grant.
- **The appointee's campus must be the grant's campus.** Read from their address; the
  appointment form never offers a campus picker, so a mismatch cannot be entered.
- **The rules check campus twice**: when the grant is written (the appointee's address), and
  when it is used (the signed-in address of whoever is acting under it). The second check
  catches a grant typed by hand in the console.

```
function campusOf(email) { return email.split('@')[1].split('[.]')[0]; }
function isStudent(email) {
  return email.matches('^[fhp][0-9]{4}[0-9]+@(goa|hyderabad|pilani|dubai)[.]bits-pilani[.]ac[.]in$');
}
```

### Departments are keyed by course prefix — electronics is one department

A president's scope is a **department key**, derived from the course code so that every rule is
a lookup and never a search:

```
function deptOf(course) {
  let p = course.split(' ')[0];
  return p in ['EEE', 'ECE', 'INSTR', 'ECOM'] ? 'ELEC'
       : p == 'FIN' ? 'ECON'
       : p;
}
```

- **`ELEC` is one department** covering every EEE, ECE, INSTR and ECOM course — programmes A3,
  A8, AA and AC. **Every president of any of those four programmes controls all of it**, as
  equals: any of them can appoint or remove any electronics CR, whoever appointed them, and
  edit any electronics offering. Last write wins; the audit log says who.
- **`ECON` covers ECON and FIN**, for B3, on the same reasoning. *(Assumed; say if FIN should be
  its own department.)*
- Every other department is its own prefix: `CS`, `ME`, `CHEM`…
- The grant records **which programme** the president was appointed for (`A3`) — for the roster
  and for succession — but rules only ever read the department key.
- Presidents cannot revoke each other. Owners and admins can.

### Grants: one document per person per scope

```
grants/{role}|{campus}|{scopeKey}|{email}
  { role: 'admin' | 'dept' | 'course',
    email, name,                         // from the appointee's account; shown, never hidden
    campus,                              // 'goa'…; admins: 'all'
    scope,                               // department key ('ELEC'), or course id ('CS F211')
    programme?,                          // dept only: 'A3'
    active, expiresAt,
    grantedBy: {email, name}, grantedAt, auditId }
```

- **The id is deterministic**, so a rule checking "may this person edit CS F211 on Goa" makes at
  most two lookups — `course|goa|CS F211|<me>` and `dept|goa|<deptOf>|<me>` — and never
  searches. It is also what makes a list of courses unnecessary: a CR of three courses holds
  three grants.
- **Only someone who has signed in to Pointer can be appointed** (decided 27 Sep 2026,
  superseding the next bullet's "before that student has ever signed in"). `AdminGrant` looks the
  address up in `people/{email}` and says **"Can not be found"** when there is none (§16.3 fix 12).
- **Grants are keyed by email, not uid.** A president appoints a CR by address, before that
  student has ever signed in; there is no invite-and-claim step.
- **Two presidents for one scope is legal** — that is how succession overlaps (§13.4)
  and how four electronics presidents share `ELEC`.
- **Grants expire.** `expiresAt` is required on every admin, president and CR grant, counted from
  the day it is given using `config/grantTerms`: **CR one semester, president one year, admin two
  years** (decided 27 Sep 2026), stored as whole days — `{crDays: 183, presidentDays: 365,
  adminDays: 730}` — because rules can add a `duration` in days but not calendar months; the UI
  still says "1 semester". Owners and admins change the CR and president lengths; only owners
  change the admin length. A new length applies to grants given or renewed afterwards; running
  grants keep their date. Rules refuse an expired grant for free, so lapsing is the default and
  renewal is deliberate. Owners do not expire.
- **Deactivate, never delete.** `active: false`, kept, so the audit log never points at nobody.
- **Revoking a president leaves their CRs in place.** CRs were appointed for a course, not for
  a person — the same reasoning as succession (§13.4), where schemes and resources belong to the department.
  A new president can remove them if they choose.
- **Removal does not undo what they wrote.** Their edits stay. If the removal was *because* of a
  bad edit, that edit is reverted separately — which is why `/admin` shows a person's recent
  edits from the audit log beside their revoke button.

### Reading the roster and the audit log

Maintainers are named people. **An owner, admin or president is never anonymous**: every grant
carries the holder's name and email, and every audit entry carries the actor's.

- **Owners and admins** read every grant and every audit entry.
- **Presidents** read the grants and audit entries **for their own campus**, plus the admin and
  owner entries (`campus: 'all'`), so they can see who appointed whom.
- **CRs and students read neither.** A CR sees only their own grants. The student-facing
  `Representatives` board is separate and shows names plus only the contact fields each person
  opted into (§13.5).

Rules cannot search grants to decide whether the reader is a president somewhere on this
campus, so each maintainer has one index document, **`staff/{email}`** — `{ name, email,
campus, owner, admin, presidentOf: ['ELEC'], courses: ['CS F301'], expiresAt }` — `courses`
feeds the Settings *Your roles* chips (§16.4) — written **in the same batch** as
every grant change, with the rules checking via `getAfter()` that it agrees with the grant being
written. Read rules then cost one `get()`. ⚠ This consistency rule is the one part of the rules
that must be **prototyped against the emulator before any UI is built on it.**

### Audit trail

Every write to shared data — grants, owners, courses, offerings, resources, professors, review
moderation, config — appends to `audit/` in the same batch:

```
audit/{id}
  { actor: {email, name, role}, action, collection, docId, campus,
    before, after, at }
```

- **Bound both ways by rules.** The shared write carries `auditId`, and its rule checks
  `getAfter(audit/{auditId})` names the same collection, document and actor. The audit entry's
  rule checks `existsAfter()` on that document with the same `auditId`. So no shared write
  lands without an entry, and no entry can be written for a change that did not happen.
- **The actor cannot be forged**: `actor.email` and `actor.name` must equal
  `request.auth.token.email` and `request.auth.token.name`, and `at == request.time`.
- **Append-only**: no client may update or delete an entry.

### Rules sketch

```
function me()         { return request.auth.token.email.lower(); }
function isOwner()    { return request.auth.token.email_verified == true
                          && exists(/databases/$(db)/documents/owners/$(me()))
                          && get(/databases/$(db)/documents/owners/$(me())).data.active; }
function grant(role, campus, scope) {
  return /databases/$(db)/documents/grants/$(role + '|' + campus + '|' + scope + '|' + me());
}
function holds(role, campus, scope) {
  return exists(grant(role, campus, scope))
    && get(grant(role, campus, scope)).data.active
    && request.time < get(grant(role, campus, scope)).data.expiresAt
    && (campus == 'all' || campusOf(me()) == campus);        // used on the holder's own campus
}
function isAdmin()             { return isBits() && holds('admin', 'all', 'all'); }
function isPresident(c, dept)  { return isStudent(me()) && holds('dept', c, dept); }
function isCr(c, course)       { return isStudent(me()) && holds('course', c, course); }
function canEditCourse(c, course) {
  return isOwner() || isPresident(c, deptOf(course)) || isCr(c, course);   // not admins
}
```

Things to know before relying on this:

1. **Each `get()`/`exists()` is a billed read**, and rules allow 10 document lookups per request
   (20 in a batch). Fine at maintainer volume; never on a student read path.
2. **A role change takes effect immediately**, unlike custom claims.
3. **`exists()` before `get()`**, always: a `get()` on a missing document fails the whole rule
   instead of denying cleanly, and almost every student has no grant.

### Campus sandboxing is a data rule, not a filter in the UI

Everything a maintainer touches, and everything a student reads, is scoped to one campus.

- **Reviews, resources, averages, eval schemes, professors and appointments** carry `campus`.
- **A user's campus comes from their sign-in address**, permanently (§11). Rules read it from
  `request.auth.token.email`, never from a field the user wrote.
- **Course identity stays shared.** One `courses/{id}` for CS F211 across all campuses;
  everything that varies by campus hangs off it.

Enforce it in rules on the write path *and* in the query on the read path.

### The tiers own whole documents, not fields

```
courses/{id}                               identity: code, title, credits, semester,
                                           discipline, retired
                                           -> owner (+ president in scope, drafts only)

courses/{id}/offerings/{campus}_{term}     components (with stable ids), weights, averages,
                                           professors, updatedBy, updatedAt
                                           -> owner, president in scope, CR of the course

courses/{id}/stats/{campus}                review counters, all professors
courses/{id}/stats/{campus}_{profId}       review counters, one professor
                                           -> written only in a review batch (§10.3)

requirements/{campus}/{programme}          degree structure
                                           -> owner, president in scope

resources/{id}                             one named link (§6)
                                           -> owner, president in scope, CR of the course

professors/{id}                            -> owner, president in scope
config/public, config/grantTerms           -> owner, admin (the admin length: owner only)
```

Counters live in their own documents because CRs write offerings under last-write-wins, and a
CR's `set()` must never be able to wipe a course's rating.

---

## 5. Imported data, and the user's right to diverge

> All this data gets imported automatically when a course is added and the User can change
> all this data on his side, provided he gets a warning that updates will no longer be
> fetched and he has to maintain it himself.

### "Imported" must mean linked, not copied

If adding a course copies the published components into the user's data, every user is
frozen at the moment they added it and nobody ever receives a correction. So: **adding a
catalogue course stores an id and nothing else.** Published values are read through the cached
bundle and offerings at display time.

**Courses that are not in the catalogue** — typed in by hand, or imported from ERP under a code
the catalogue lacks — have nothing to link to, so they stay whole in the user's document as
**custom entries** (title, credits, category). The step 3 migration must keep them whole.

### Overrides are a sparse diff, and detachment is per component

Layers resolve in exactly one place — `override ?? published ?? custom ?? empty` — and no
screen branches on this for itself.

`users/{uid}/overrides/{courseId}` holds only what the user actually changed, under independent
granules:

| Granule | Covers | Detaching it stops |
|---|---|---|
| `identity` | title, credits | credit corrections |
| `components.{id}` | one component: weight, out of, dates | updates to that component only |
| `average.course`, `average.component.{id}`, `average.part.{id}` | one average each | that published average |

Per granule — not per course, and not globally. A student correcting one quiz weight must still
receive a credit correction that changes their CGPA.

**Category is not a granule.** "Counts as" is the user's from the start: the published tag is
the default for a course they have not categorised, and a category they set by hand (already
built as `pinned_categories`) always wins. A publish that changes a tag changes nothing for
anyone who pinned one.

### Seeded components are placeholders, not overrides

Phase 12b seeds Quiz 1, Quiz 2, Midsem and Compre on every new course. Stored as ordinary
evaluatives, the resolver would read them as the user's own scheme and detach every course from
the published one on day one.

- **Seeds carry `seeded: true`** (appended to the evaluative record the way `average` was). A
  seed nobody has edited counts as *no scheme*, so a published scheme replaces it silently.
- **No seeding at all when the offering already has a published scheme.**
- **Existing data:** a Quiz 1 / Quiz 2 / Midsem / Compre at weight 0 with no marks is a seed.

### The warning fires at the moment of divergence

The first edit to a published value opens a small confirmation naming exactly what stops
updating — "Mid Semester becomes yours; official changes to it will no longer arrive" — with
**Keep official** and **Make it mine**. Only the fields with a published counterpart detach:
**weight, out of, dates and averages**. A student's own marks never detach anything, and the
components they leave alone keep updating (decided 27 Sep 2026). After that the component
carries a quiet marker, and:

- **A later published change becomes a notification, not an overwrite.** "The official
  scheme for CS F211 changed — review, or keep yours."
- **Reattaching must exist.** "Use the official version" discards the override.

### Marks pin their components

Published components carry **stable ids**, and each user evaluative records the id it came from.
Matching by name breaks on the first rename. If a maintainer *removes* a component the user holds
marks in, it is **never removed from their view** — it is flagged as no longer part of the
official scheme and stays until they clear it.

---

## 6. Resources

One flat, campus-scoped document per link; the hierarchy the student sees is a view (§10.4).

```
resources/{id}
  { title, url, host, kind, campus, scope: 'department' | 'course',
    department?, courseId?, pinnedToDepartment: bool,
    addedBy: {email, name}, addedAt, auditId }
```

- **Read live, not bundled.** A CR's link should appear when they add it, not on the owner's
  next publish, and resources grow without bound inside a 1 MiB bundle. The app queries one
  department on one campus at a time, caches the result in Hive, and re-reads only when a
  per-campus version marker (`resourceVersions/{campus}`, bumped in the same batch as every
  resource write) has moved.
- **Rules restrict the host** to an allowlist (`drive.google.com`, `docs.google.com`,
  `youtube.com`, …) with a regex on `url` — the single most effective control available without a
  server — and cap length and count.
- **`addedBy` must equal the signed-in account**, so authorship cannot be forged.
- **Rollup**: a course resource whose normalised URL (scheme, `www.`, trailing slash and query
  string stripped) the department does not already have is listed under the department too — the
  same document with `pinnedToDepartment: true`, never a copy. The department can unpin it. A CR
  choosing from the department's resources links to the same document.
- Every link shows who added it, and has a "report this link" path, read back by the people who
  can fix it (§16.3).
- **`noindex` on the resources page**: it is a list of links to third-party material.

---

## 7. Routes

There is no router today — one page and a bottom nav.

| Path | What | Rendering | Audience |
|---|---|---|---|
| `/` | landing page | **static HTML** | everyone, crawlers |
| `/calculator/` | Pointer | Flutter | students |
| `/calculator/admin` | owners and admins: people, grants, publishing, audit | Flutter, deferred | a handful |
| `/calculator/maintain` | presidents and CRs | Flutter, deferred | ~dozens |

**`/admin` and `/maintain` live inside the Flutter app**, so they sit under its path — decided
in favour of one design language, one auth session and one set of widgets. They go behind a
**deferred library** (`deferred as admin` + `loadLibrary()`) so the 3.3 MB students download
does not grow; if the split proves awkward, measure before accepting the weight. **Route guards
are a courtesy**: the rules must assume the UI is hostile.

Moving the app off `/` is not free:

- **Build with `--base-href /calculator/`**; the workflow assembles `site/` from `landing/`
  (the landing page, `_headers`, robots, sitemap, the auth helper) with `build/web` under
  `calculator/`. Once `/` is a real landing page, Cloudflare's fallback for an unknown path is
  *that page*, so each app route needs its own `_redirects` line
  (`/calculator/admin* /calculator/index.html 200`). **Never `/calculator/*`**: Pages applies a
  redirect even when a file matches, so it would rewrite `main.dart.js` too.
- **Sign-in is first-party.** `authDomain` is this site, and `landing/__/auth/` serves
  Firebase's helper (`handler`, `iframe` and their scripts, fetched from `firebaseapp.com`). An
  iOS home-screen app signs in by redirect (Safari blocks or loses the popup), and a blocked
  popup anywhere falls back to it. The Google OAuth client must list
  `https://pointer-bits-pilani.pages.dev/__/auth/handler` as a redirect URI; a new domain needs
  it added **before** it is deployed, or every sign-in fails.
- A root `flutter_service_worker.js` (Flutter's self-unregistering one) retires the worker that
  installs from before the move registered at `/`.
- **`manifest.json`**: `start_url` and `scope` become `/calculator/`.
- **Installed copies** still open `/`. The landing page sends a standalone-mode visit
  (`display-mode: standalone`) straight on to `/calculator/`, so an installed app never lands on
  marketing.
- **Inside Pointer**, adopt `go_router` and `usePathUrlStrategy()` so tabs get real URLs and the
  back button works.
- The COOP header stays on `/*` in `web/_headers` — `same-origin-allow-popups`, or
  `signInWithPopup` fails silently.

**Hosting, for the record:** Cloudflare Pages (`pointer-bits-pilani`), deployed by
`.github/workflows/deploy.yml` on push to `master`. Netlify only 301s the old address across.

---

## 8. Class averages have three levels and three sources

Phase 12b built course, component and part averages on the Marks page, with the component
average derived from the parts when none is typed. Published averages add a third source.

**At each level separately: typed, then published, then derived.** A student who has the real
number from their instructor should not have it silently replaced; one who has nothing should
not see a blank where a published figure exists; the derived sum is the last resort. The UI
says which is in play — *yours*, *official*, *from parts* (the last is built).

An average is only comparable against *the same components*, which is why it is stored on the
offering (`{campus}_{term}`) beside the component set: the UI can say "mid-sem, 2026-27 Sem 1"
instead of an unqualified figure. Typing over a published average detaches that one average
(§5), with the same warning and the same way back.

**Where each source is shown (decided 27 Sep 2026, from the boards).** The Marks screen shows
**official averages only**, unlabelled — "class avg 14.2", or "no class avg yet". The resolver
above is unchanged and still feeds every calculation; a student's own and from-parts averages are
shown, labelled, on *Edit evaluative* (`MarksAdd`) and nowhere else.

---

## 9. Sequencing

Each step ships on its own and is reversible.

0. **Verify the Android black-screen fix on a real phone** (§15). The fix is
   built — context-loss reload, the import error card, released PDF memory, staged logs. What
   is missing is a Chromium/Android run with `chrome://inspect` attached. Migrating the
   catalogue on top of an unverified blank-screen bug means nobody can tell which change caused
   the next one.
1. **Routes and the landing page.** `go_router`, `/calculator/`, the base href, the redirect
   rule, the manifest. No data changes.
2. **Catalogue read path.** Same data, new source: publish today's `course.dart` as the bundle,
   load from it, cache in `catalogBox`, ship the exported fallback. The app should behave
   identically — that is the test.
3. **Split the user document.** Grades keyed by id, custom entries for courses outside the
   catalogue; stop syncing the catalogue. The one step that touches user data: it needs a backup
   path and a reversible rollout. *Built:* the snapshot is `format: 2`; a course whose title and
   credits are the catalogue's is stored without them and read back from it, anything else stays
   whole (`core/storage/course_link.dart`). A published correction relinks stored courses before
   the bundle is cached. The first format-2 push keeps the old snapshot once as `v1` on the user
   document — the way back.
4. **Overrides, seeds and the divergence warning (§5).** Before any maintainer can change
   anything, the app must already resolve `override ?? published ?? custom`, treat seeds as
   placeholders and warn on detach. *Built:* `core/grading/official_scheme.dart` is the one
   resolver. It copies published values into the student's evaluatives (each pinned by
   `sourceId`) so every screen reads one list, and never over a detached granule. Overrides
   are `{granule: basedOn}` per course in `settingsBox.overrides`, which syncs inside
   `users/{uid}` rather than a subcollection. A student's own component with an official one's
   name is linked on first sight, detached with `basedOn: 0` if its values differ. Offerings
   cache in `offeringsBox`: read on opening Marks (10 min) and for this term's courses on app
   open (12 h).
5. **Owners, grants, staff index, audit, `/admin`.** Rules first, proven against the emulator —
   the `staff/` consistency rule above all. Read-only screens first, then writes. Owners and
   admins only. *Built:* `firestore.rules` holds owners, grants, staff, audit, people and
   config; `test/rules/` proves them on the emulator (`cd test/rules && npm test`). Every grant
   write is one batch — grant, `staff/` index, audit entry — and the rules tie the three
   together. `/admin` is a deferred library (`lib/admin/`); `core/roles/` holds the models, the
   store and the session (Open as for owners, Switch role for presidents and CRs, both shown in
   a strip at the top). `config/grantTerms` must exist before the first grant: an owner saving
   Terms creates it.
6. **Maintainer editing + publish.** Presidents next, CRs last — the narrowest tier is the
   largest group and the least reviewed. *Built:* offerings are written with their audit entry
   by an owner, the president in scope or the course's CR, checked against the grant
   (`test/rules/maintain.test.mjs`). `core/grading/eval_import.dart` reads `pointer.eval.v1`,
   rejects the whole file on one bad row and ships the prompt verbatim; component ids are kept
   by name. Uploads write five courses a batch under one `uploadId`. `courses/{id}` holds
   drafts; `core/catalog/publish.dart` applies them, diffs in CGPA terms and writes `v{n}` plus
   the marker. Screens: `DeptHome`, `DeptCourses`, `CrHome`, the scheme editor, the upload
   preview and `Publish`, all in `lib/admin/`.
7. **Resources**, once editing and audit are proven on the catalogue. *Built:* `core/resources/`
   holds the model, the host allowlist (the rules repeat it as a regex), address matching for
   the rollup and a store that re-reads a department only when `resourceVersions/{campus}` has
   moved. A CR links a department resource by adding their course to its `courseIds` — the same
   document. Reports are `resourceReports/{id}/entries/{sha256(uid + id)}` plus the flag in the
   same batch; `DeptResources` has Dept / By course / Reported (amber, pulsing while open), and
   `CrHome` shows its course's links and reports. Students: `/resources`.
8. **Class averages**, once publishing, the term/component scope and the override rule exist.
9. **Professors** (§10.1). Before reviews, because a review filed against a typed name cannot
   be repaired later.
10. **Reviews** (§10.3), with the counters and the composite indexes from the start.
11. **Succession, Representatives, the More hub.** Last: they are the surface over everything
    above.

Step 2 before step 3: prove the new read path against unchanged data before changing the data.
Step 4 before step 6: have the divergence machinery working before shared data can change.
Step 9 before step 10: the same argument, one layer down.

---

## 10. Professors, reviews and resources — shapes, queries and screens

They share one spine: **a course is shared and permanent; everything about how it was taught is
campus-, term- and professor-scoped.**

### 10.1 Professors are entities, never text on a course

```
professors/{id}
  { name, campus, department, aliases: [], active, updatedBy: {email, name}, updatedAt }
```

Free-text names are the single mistake that quietly breaks this feature: "Dr. R. Menon",
"Ramesh Menon" and "R Menon" become three people and the reviews split three ways.

- **One document per person per campus.** A president creates and renames; a **CR picks from the
  list** for their own course each term and cannot create one.
- **Ids are immutable.** A rename keeps the id, so every review follows it.
- **Search matches partial names** before the Add button is reachable.
- `aliases` holds the spellings a merge absorbed.
- **Merging two duplicates** (owner, admin, or a president in scope) **never rewrites reviews.**
  The absorbed document gets `mergedInto: <survivor id>` and joins the survivor's
  `mergedIds`; review queries use `professorId in [survivor, ...mergedIds]` and the rating sums
  both counters. One audited write instead of an unbounded batch no rule could authorise
  (decided 27 Sep 2026, §16.3).

**Who teaches what, per term**, lives on the offering:

```
courses/{courseId}/offerings/{campus}_{term}
  { professors: [profId], components: [...], averages: {...},
    updatedBy: {email, name}, updatedAt, auditId }
```

A course can have two professors in one term, so it is a list. Several CRs may write it (§11).

### 10.2 The professor on the Marks screen is read-only

Board `Marks` carries a **Taken by** row above the running total: the professor for the current
term, plus a link into that course's reviews. **It is not editable by the student** — if it is
wrong, the CR fixes it once for everyone. Where no professor is set yet, the row says so rather
than disappearing.

### 10.3 Reviews

```
reviews/{courseId}/entries/{reviewId}
  { stars: 1..5, recommend: bool, text?, campus, term, professorId,
    hidden: false, hiddenBy?: {email, name}, reason?, helpful: 0, createdAt, updatedAt }
```

**A review belongs to a professor and a term, not to a course**: a course taught by someone new
starts a fresh set instead of inheriting an old reputation.

**Reviewers are pseudonymous, by construction.** `reviewId = sha256(uid + courseId)`, checked in
rules with `hashing.sha256`, and the review stores no uid. One review per user per course stays a
rules invariant, and nobody reading reviews can link one person's reviews across courses.
Helpful votes use the same construction (`votes/{sha256(uid + reviewId)}`). *Maintainers are
named (§4); students writing reviews are not.*

**Reads** are live from Firestore, so the query shape is the cost model:

```
where campus == me.campus
where professorId == <selected>      // default: whoever teaches it this term
where hidden == false
orderBy helpful | createdAt | stars
limit 10, then paginate
```

Every ordering needs a **composite index**, declared in `firestore.indexes.json` up front. Cache
pages in Hive and **never read reviews on app open**.

**Counters, not queries.** `{ count, starSum, recommendCount }` in
`courses/{id}/stats/{campus}` and `…/stats/{campus}_{profId}`, written **in the same batch** as
the review, with rules verifying the delta via `getAfter()`. An edit adjusts by the difference;
**a hide decrements and an unhide restores.** The professor filter reads the per-professor
counter, so "4.1 under this professor" costs one read.

**Writes.** `stars` and `recommend` are required; `text` is not. `campus` must equal the
writer's campus from their address, and `term` and `professorId` must match an existing offering.

**Moderation** is `hidden: true` with a reason and an audit entry, by a president in scope.
Never a delete.

### 10.4 Resources, and the shape the student sees

Storage is §6. The student screen groups them **by degree, then by level**:

```
B3 M.Sc. Economics
  Department resources
  Course resources     ← default: courses taken THIS SEMESTER; "All" is one tap
A7 B.E. Computer Science
  Department resources
  Course resources
```

Both degrees appear for a dual degree, in the order the rest of the app uses. An electronics
student sees `ELEC`'s department resources under their own programme's name.

### 10.5 The empty state is a screen, not a blank

Board `ResourcesEmpty`. A department with nothing is the **normal state on day one**, so it says
who can fix it:

> No resources here yet. Ask your CR or department president to add some.
> **Are you the department president?** Message [the admin] to get access.

**The contact is configuration, not markup**, set by an owner under *Public contact* in `/admin`:

```
config/public
  { contactName, contactMethod: 'whatsapp' | 'phone' | 'email',
    contactTarget, contactEnabled: bool }
```

- **Owner- and admin-writable, everyone-readable** (admins since 27 Sep 2026), and **read live**,
  one cached document, only when the empty state is on screen — so an admin's change shows at
  once instead of waiting for an owner's publish (superseded 27 Sep 2026: it was in the bundle).
- **The number is not drawn on the page.** The button reads "Message <name>"; the target sits
  behind the link.
- **Off is a real state.** With `contactEnabled: false` the whole block is absent. It also hides
  once the department has one resource.

### 10.6 Navigation

The bottom bar is four grade profiles plus **More**, a hub holding Representatives, Course
reviews and Resources. All five targets stay 50px. `Reviews` is also reached from the Marks
screen's **Taken by** row. Representatives is **not** a fifth destination of its own; it lives
in the hub.

---

## 11. Decisions

Settled. Each one carries the consequence it has for the build.

### The catalogue is one Firestore document, and it is not secret

The catalogue lives in Firestore as the source and is distributed as one bundled Firestore
document (§1). Leaking it is acceptable — BITS course lists are published anyway — so the bundle
is readable by any signed-in user without further checks.

### Publishing is an explicit button, and the diff is stated in CGPA terms

An owner presses **Publish** in `/admin` after reading a diff:

| Change | Effect | Treatment |
|---|---|---|
| Credits changed | **Moves the CGPA of everyone holding that grade** | listed first, needs a second confirm |
| Course retired | Hidden from Add a course; existing grades keep counting, marked Retired | listed second |
| Title; default category or elective tag | Cosmetic, or a default only — a hand-set category wins (§5) | listed last, no confirm |

**The publisher cannot count who is affected, and should not pretend to**: that would mean
reading every user's private document. The diff names the courses and the kind of change, never
a headcount.

### A retired course says so

Retired courses keep counting toward the CGPA and the degree audit, but the row is marked
**Retired** wherever it appears, and it is hidden from Add a course. *Built.*

### Campus and batch are final

**Campus and batch are whatever the sign-in address says, permanently.** Every BITS address
follows the fixed pattern, so both always parse; there is no setting, no correction and no
support flow. Settings shows both read-only (*built*); **setup's `Change` affordance goes.**
The one exception is an owner's non-BITS account, which setup asks once (§4).

### Changing the first discipline wipes the user's data

As it does today. The warning says so before it happens; overrides go with everything else.

### Maintainers are named students on their own campus

Presidents and CRs hold a BITS **student** address on the campus they serve (§4); faculty and
alumni addresses cannot hold either. Owners, admins and presidents are **never anonymous** —
their names and emails appear in the roster and the audit log, readable by owners, admins and
presidents, and by nobody else.

### Electronics is one department

A3, A8, AA and AC share one department, `ELEC`, and every president of any of them controls all
of it (§4).

### A CR's scope is the course, never a section

Papers are set by one Instructor-in-Charge for the whole course, so **section is not part of any
key** — not for the offering, not for averages, not for reviews.

### Several CRs per course, and edits simply land

Multiple CRs may hold one course, several presidents may hold one department, and **the last
write wins**. What makes that workable:

- **`updatedBy` and `updatedAt` on every shared document**, with "changed by X, N minutes ago"
  shown in the editor before a keystroke is typed.
- **The append-only `audit/` log**, so an overwritten value is recoverable and attributable.

The accepted cost: someone can silently overwrite another's work, and the first will not be told.

### Alumni are out of scope

A graduate's `@alumni` address is not accepted, and linking it to their student record is not
designed. Revisit before the first batch that used Pointer graduates.

---

## 12. Still open

- **FIN under `ECON`.** Assumed on the same reasoning as electronics; confirm.
- **The `staff/` consistency rule** (§4) needs an emulator prototype before it is relied on. If it
  cannot be expressed cleanly, the fallback is presidents reading only their own department's
  grants and audit entries, which needs no index.
- **When a rename changes a course's meaning** rather than correcting its spelling, the immutable
  id keeps old grades attached to a course that is no longer the same subject. Retire and re-add;
  nothing enforces it.
- **Whether last-write-wins holds at scale.** If overwrites start showing up in the audit log,
  the answer is a revision counter.
- **Alumni** (§11).

---

### Raised by the 27 Sep boards

- ~~**A grant's `name` before the appointee has signed in.**~~ Resolved in §16.3.
- **Superseded 27 Sep:** grant expiry no longer reads term end dates; it is counted from the
  grant date (§4), so campus term calendars no longer matter here.
- ~~**Where a link report goes.**~~ Resolved in §16.3: the course's CRs and the department's
  presidents read and clear them.

### Raised by the 27 Sep comments

- ~~**How long "one semester" is**~~ — 183 days (§4).
- **A professor who teaches in two departments.** A president may merge only professors wholly
  inside their own department and campus; anyone else is merged by an admin or owner.
- **The sign-in and loading wording is "Your grades stay private to your account"**, not
  "de-identified" or "your data doesn't stay with us": grades sync to `users/{uid}` in our
  Firestore, so those would be untrue. Reviews are pseudonymous (§10.3) and say so.

## 13. Screens

**Built in Flutter, inside Pointer**, in the same design language as the rest: same palette,
same cards, same flexing pill rows, same 44px targets.

- `/calculator/admin` and `/calculator/maintain` (§7) sit in **one deferred library** —
  `import 'admin/admin.dart' deferred as admin;` then `await admin.loadLibrary()` on first entry.
- **The entry point is one row in Settings**, rendered only when the signed-in account is an
  owner or holds a live grant (`staff/{email}`, §4). No visible-but-disabled row for students.
- **Every maintainer screen wears its scope in the header** — a campus pill and a department pill
  (`ELEC · A3` for an electronics president), always visible. Someone holding two roles must never
  have to guess which one they are acting under.
- **Every editor shows "changed by X, N minutes ago"** before a keystroke is typed (§11).

### 13.1 Boards

> **The UI Directions artifact is now the list of screens** — 57 boards, arranged by flow and by
> role, each with its note. The tables below are the history of why some of them exist; §16.1 is
> the current board → route map.

Designed boards (canvas page 2), none built yet:

| Board | Who | What it holds |
|---|---|---|
| `More` | students | bottom-bar hub: Representatives, Course reviews, Resources; all five targets 50px |
| `Representatives` | students | president + CR directory; contact fields opt-in **separately** (§13.5) |
| `ReviewsSearch` | students | search any course |
| `Reviews` | students | one course, filtered by professor; defaults to who teaches now |
| `Resources` | students | by degree → department / course; courses default to **this semester** |
| `ResourcesEmpty` | students | day-one state; contact from `config/public`, hidden when off (§10.5) |
| `AdminHome` | owner, admin | tier and scope, then the sections they can reach; publish and analytics **owner only** |
| `AdminPeople` | owner, admin | every grant: name, email, tier, scope pills, expiry, active; revoke beside that person's recent edits |
| `AdminGrant` | owner, admin | appoint by email: tier, scope, expiry. **Campus is read from the address**, never picked; one scope per grant; a non-student address is refused on the form |
| `DeptHome` | president | campus + department pill, then courses / CRs / reviews / resources / averages |
| `DeptCourses` | president | course list, eval structure editor, JSON bulk upload (§13.2) |
| `DeptReviews` | president | campus-filtered reviews, hide with a reason; counters adjust |
| `DeptResources` | president, CR | department and course links; rollup marked, unpin ≠ delete; pick-from-department |
| `DeptProfessors` | president | the professor list; search before add; CRs cannot create |
| `CrHome` | CR | their courses, eval structure, averages, resources; professor picked from the list |
| `Succession` | president | hand over, step 1; expiry = min(now + 20 d, current) (§13.4) |
| `SuccessionConfirm` | president | hand over, step 3; department code typed, not tapped |

**Designed 27 Sep 2026** — each follows from a decision above. Canvas page 2 rows *Owner tools* and
*Roster and audit*; page 1 row *Official data you can make yours*; `OwnerSetup` beside setup.
`AdminGrant`, `AdminPeople`, `AdminHome`, `DeptHome`, `Representatives` and the `Landing` footer
were updated to match §4 and §13.5 the same day:

| Screen | Who | Why |
|---|---|---|
| Owners | owner | add or deactivate owners; self-removal blocked (§4) |
| Owner setup | owner | a non-BITS owner is asked campus and batch once (§4) |
| Roster | admin, president | every grant on the campus with name and email; `AdminPeople` is owner/admin only (§4) |
| Audit log | owner, admin, president | who did what, with names and emails, filterable by person and course (§4) |
| Publish | owner | the diff in CGPA terms, credit changes first with a second confirm (§11) |
| Grant terms | owner, admin | how long a grant lasts from the day it is given: CR 1 semester, president 1 year, admin 2 years; admins change the first two (§4) |
| Public contact | owner, admin | writes `config/public` (§10.5) |
| Professor merge | owner, admin, president | merge duplicates, rewriting reviews, logged; a president only within their own department and campus (§10.1) |
| Divergence dialog | students | **Keep official** / **Make it mine**, the detached marker, the "official changed" notice and **Use the official version** (§5) |
| Average source labels | students | *yours* and *official* beside the built *from parts* (§8) |
| Report this link | students | on every resource (§6) |

### 13.2 What a president can do in `DeptCourses`

All of it scoped to their own department **and** their own campus.

**Course structures** — add and edit evaluative schemes for courses in their department:
components, weights, parts, best-n-of-m rules. Writes `courses/{id}/offerings/{campus}_{term}`,
never `courses/{id}` identity fields.

**Bulk upload by JSON** — a file picker taking one JSON document describing eval structures
for many courses at once. **It must behave like the ERP importer, not like a save button:**
parse in the browser, validate against a stated schema, then show a preview of exactly what
will be created, changed and left alone, with a confirm step. A silent bulk write over a
department's schemes is the single most destructive action in this app. Reject the whole file
on a schema error rather than importing half of it, and name the offending row.

**The extraction prompt, shipped beside the upload button.** Handouts are PDFs written
differently by every professor, so the hard part is getting *to* clean JSON, not uploading it.
The card carries a collapsed prompt and a **Copy** button: the president pastes it into any AI
tool with the handouts attached, and what comes back conforms. This removes most schema errors
before the importer ever sees them — it does not replace the preview.

**The schema is `pointer.eval.v1`:**

```json
{
  "schema": "pointer.eval.v1",
  "campus": "Goa",
  "term": "2026-27-1",
  "courses": [{
    "code": "CS F301",
    "professors": ["Dr. R. Menon"],
    "weighted": true,
    "totalMarks": 100,
    "components": [{
      "name": "Quiz 1",
      "weight": 10,
      "outOf": 20,
      "date": "2026-09-08",
      "rule": { "type": "all" },
      "parts": [{ "name": "Part A", "outOf": 10 }]
    }],
    "notes": "compre weight not stated in the handout"
  }]
}
```

`rule` is `{"type":"all"}` or `{"type":"bestNofM","n":2,"m":3}`. `parts` is omitted for a
single-mark component. `weight` is a percentage when `weighted` is true, otherwise marks.

**The prompt text, verbatim — ship this string, do not paraphrase it:**

> Read every attached course handout and return one JSON object and nothing else. No prose, no
> markdown fences, no explanation.
>
> Use exactly this shape: `{"schema":"pointer.eval.v1","campus":…,"term":…,"courses":[…]}`.
> Each course is `{"code","professors","weighted","totalMarks","components","notes"}` and each
> component is `{"name","weight","outOf","date","rule","parts"}`.
>
> Rules you must follow:
> - **Never invent a value.** If the handout does not state something, leave the field out. Do
>   not infer a weight from the other components, and do not assume a standard BITS split.
> - Put anything you are unsure about in that course's `notes` field, in plain English.
> - Use the course code exactly as printed, including the space: "CS F301", not "CSF301".
> - `weighted` is true when components carry percentages, false when the course is marked out
>   of a single total.
> - `rule` is `{"type":"all"}` unless the handout says best N of M, which is
>   `{"type":"bestNofM","n":N,"m":M}`.
> - `outOf` is that component's own maximum, never a shared divisor.
> - Dates are `YYYY-MM-DD`. Omit the field if the handout gives no date.
> - If weights do not sum to 100 on a weighted course, still return them as printed and say so
>   in `notes`. Do not adjust them to fit.
> - One entry per course. If a handout covers two sections with different schemes, return one
>   course entry per scheme and note which section each is.

**Why the prompt is verbatim and not a paraphrase:** "never invent a value" and "do not adjust
them to fit" are the two lines that stop an agent producing a plausible, wrong scheme that
passes validation. A prompt that silently fills gaps is worse than no prompt, because the
importer cannot tell a guess from a reading.

### 13.3 What a CR can do

- **Eval structure for their own courses**: add, edit and remove components and their attributes.
  Same document as §13.2, narrower scope.
- **Averages** — course, component and part (§8).
- **Course resources**: add a new named link, **or pick one from the department's existing
  resources**. Picking links to the same resource document; it does not copy it.
- **The professor for the term**, picked from the list; never typed.

### 13.4 Succession — a president names the next one
Boards `Succession`, `SuccessionConfirm`. Reached from `DeptHome`.

The outgoing president enters the successor's **BITS address**. The new grant starts
immediately; the outgoing grant ends **20 days later**, so both hold the department during the
overlap. A handover with no overlap hands someone a department they have never seen while the
one person who could explain it is already locked out.

- **The overlap must never extend your own term.** Outgoing expiry =
  `min(now + 20 days, the expiry already held)`. Without the `min()`, a president whose grant
  lapses next week can hand over and buy themselves another twenty days.
- **Same campus only**, read from the successor's address, and the department is not editable on
  this screen. A handover transfers one scope; it is not a route to another campus, nor to a
  department you do not hold.
- **Two presidents at once is a legal state.** Nothing in the rules may assume one holder per
  scope. CRs, resources and schemes are untouched — they belong to the department, not the
  person.
- **Cancellable by the outgoing president while the overlap runs.** After it ends only an admin
  can give the department back, and the screen says exactly that rather than implying it is
  reversible.
- **One pending succession at a time.** Naming a second successor during an overlap is refused.
- **Three screens, because it cannot be undone from inside the app:** name them and see the
  parsed campus and batch; read what happens on which date; then **type the department code** —
  typed, not tapped, the same bar as any destructive action. Both parties and the owners are
  notified, and it is written to `audit/`.

### 13.5 Representatives — the student-facing directory
Board `Representatives`, on the main app.

Lists the department president and the CR for each of the student's courses, with contact
details. This is the **only screen in Pointer that publishes personal contact details of named
students**, so the defaults carry the design:

- **Every field is opt-in, separately.** Email and phone are independent choices. A CR who will
  answer email but does not want their number on a page the whole campus can open must be able
  to say exactly that — which is why a listing can read "email only" rather than showing a gap.
  **At least one is required** (decided 27 Sep 2026): accepting a role means students can reach
  you by some route, and you choose which. Set on `RepProfile` before anything else (§16.3 fix 8).
  **Separately, every privileged role — owner, admin, president, CR — must give a phone number**,
  which only other privileged roles can see. Owners and admins are never listed here.
- **Revocable, and campus-scoped.** Visible only to the same campus; turning it off removes the
  listing everywhere. The opt-in must say plainly that anything shown can be screenshotted —
  revoking removes the listing, not what people already saw.
- **Show a handover in progress.** Someone who needs a fix should not email a president whose
  access ends in twelve days.
- **A course with no CR shows a "Volunteer" action.** The people who notice a missing CR are the
  ones taking that course; this is the cheapest recruitment the app will get. The offer is
  recorded and reaches the department's presidents on *Roster › Volunteers* (§16.3 fix 16).

---

## 14. Engineering gotchas

Each of these cost time already. Do not rediscover them.

### 14.1 The CGPA rule is not the obvious one
`cgcalc()` in `script.dart` filters courses by discipline, and for GD grades **adds the credits
then subtracts them via `dontCount`**, so the denominator is `s1 - dontCount`. A naive
`sum/credits` gives 7.563 where the app shows 7.71 on the same data. **Anything that shows a CGPA
must go through the same core** (`lib/core/grading/cgpa.dart`), or Stats silently disagrees with
the home screen.

### 14.2 `main_ui_extension.dart` is CRLF, and legacy files are unformatted
Any tool that rewrites a CRLF file as LF produces a whole-file phantom diff. Never run
`dart format` on `lib/` or `test/` wholesale: format only files that were formatted at HEAD
(check a copy of `git show HEAD:<f>` with `dart format --language-version=3.7 -o none
--set-exit-if-changed`). `test/fixtures/legacy_constants.dart` stays verbatim.

### 14.3 Sync JSON-encodes `settingsBox`
`Sync.snapshot()` runs `jsonEncode` over every box value. A raw `DateTime` **throws**, and the
throw is swallowed by `push()`'s `catch`, so the sync fails silently. Store dates as ISO-8601
strings or epoch ints.

### 14.4 New Hive boxes must be registered in three places
`Sync._boxes`, `Sync.openBoxes()` and `Sync._box()`. Miss one and the box is never synced —
also silently.

### 14.5 Firestore caps the user snapshot at 500 KB
`firestore.rules` enforces `data.size() < 500000`. Marks data is unbounded per course. The
catalogue split (§2) is the real fix; until then keep evaluatives lean.

### 14.6 `addCourse()` uses `box.add()` → **int** keys
Other code writes with `box.put(course.id, …)` → **String** keys. Re-keying a course duplicates
it. Always write back under the key you read.

### 14.7 `BottomNavigationBar` changes mode at 4+ items
It defaults to `shifting`, which drops the background and hides labels. The app uses its own
`AppNav` for this reason; do not regress to the Material widget when the More hub is added.

### 14.8 Firestore `matches()` is case-sensitive
Email regexes in the rules need `(?i)`, or compare `request.auth.token.email.lower()`. Without it
an uppercase address signs in and then has every sync denied.

### 14.9 Verification
- **No Chrome on the development machine** — `flutter run -d chrome` does not work. Build with
  `flutter build web --release`, serve `build/web`, and drive it in a browser.
- **Screens can be checked without a browser**: the widget tests write PNGs when `SHOTS_DIR` is
  set (`test/helpers/fonts.dart` loads the real fonts). Say which way a screen was checked.
- **Hive writes started from a UI callback stall under the widget tester's fake clock.** Test
  storage in plain `test()`s; test screens with in-memory data.

### 14.10 The course map has duplicate ids and alias titles — **never delete a row**
Old courses stay in the map: students on older batches need them, and deleting a row silently
changes the CGPA of anyone holding a grade against it. Every fix is display-layer
(`lib/core/models/course_names.dart`):

- **Eight codes carry more than one title** (`BITS F101`, `BITS F113`, `BITS F221`, `BITS F225`,
  `BITS K101`, `PHA F214`, `PHA F216`, `PHY F111`) and show one joined name.
- ⚠ **`MF F221` is not an alias** — *Casting, Forming and Welding* and *Mechanisms and Machines*
  are two courses sharing one code. Leave both rows until the correct code is known.
- **32 rows use a lowercase `l` for `1`** (`BITS F10l`, `BITS K10l`). Normalise when matching;
  never rewrite the rows — a stored grade is keyed on the id as written.

---

## 15. Open UI work carried over

Unfinished before `PLAN.md` was retired; none of it waits on the platform work above.

**Contradicts a decision — fix first**
- ~~Setup's **`Change`** on campus and batch~~ — removed 27 Sep 2026 (b20fdd2); only an
  address without them is asked (§11).
- ~~**Sign-in rejects every non-BITS account**~~ — an active `owners/{email}` gets in, app and
  rules (abb7d97, 27 Sep 2026). Rules must be deployed; owner docs are keyed by the **lowercased**
  email and written in the console until step 5.
- **The Android black screen** — the fix is built (context-loss reload in `web/index.html`, the
  import error card, PDF memory released in `finally`, `[Pointer import]` stage logs); it has
  never been run on Chromium/Android with `chrome://inspect` attached. This is §9 step 0.

**Screens never checked against their boards**
`SignIn` (names the ERP import and the on-device promise), `Landing`, `AddManual`, `Offshoot`,
`DarkOffshoot`, `Discipline`, `Import` (reachable without Settings), `DisciplinePick` (replaces
both dropdowns), `MarksSetup`, `Calendar`, `Responsive` (breakpoints), `Logo`.

**Old screens that must no longer be reachable** — grep and confirm nothing routes to them:
the manual add-course dialog in `overlays_extension.dart`; the old settings page in
`settings.dart`; the analytics page in `analytics.dart` and its nav button; every `Marquee`
(`overlays_extension.dart`, `home_page.dart`); `TextScaler.noScaling` in `MyApp`.

**Checks that apply to every screen**
- a 60-character course title ellipsizes or wraps — never clips mid-word, never scrolls
- nothing overflows at 320px, and nothing overflows at 200% text scale
- top content clears the safe area; the nav clears the home indicator
- every tap target reaches 44px, including ones nested inside another target
- light and dark both render — dark is not a dimmed light

**Known small defect**: on Add a course at 320×640, the selected card's bottom padding slips under
the action bar (every grade stays visible).

---

## 16. Building from the UI Directions boards

Written 27 Sep 2026, when every screen had a board. The boards are the UI; this section is what
the data, rules and routes need so that each board can be built as drawn.

### 16.1 Board → route

All paths are under `/calculator/`. **Sheets and dialogs are not routes** — they open over the
route that owns them. Admin and maintain screens live in the one deferred library (§13).

| Route | Board(s) | Notes |
|---|---|---|
| `sign-in` | `SignIn`, `Loading` | `Landing` is the static `/` page, not a route |
| `setup/owner`, `setup/discipline`, `setup/import` | `OwnerSetup`, `Discipline` + `DisciplinePick` (sheet), `Import` | first sign-in only; `OwnerSetup` only for a non-BITS owner |
| `` (home), `expected`, `compare`, `offshoot` | `Main`, `DarkMain`, `Offshoot`, `DarkOffshoot` | the four grade profiles; `GradeMenu` is a sheet on Home |
| `add`, `add/manual` | `AddCourse`, `AddManual` | |
| `course/:id` | `Marks`, `Diverged` (a state of it) | `Divergence` and `AverageSources` are dialogs on it |
| `course/:id/setup`, `course/:id/eval/:evalId` | `MarksSetup`, `MarksAdd` | |
| `calendar`, `stats`, `stats/degree`, `settings` | `Calendar`, `Stats`, `StatsDegree`, `Settings` | |
| `more`, `representatives` | `More`, `Representatives` | |
| `reviews`, `reviews/mine` | `ReviewsSearch`, `YourReviews` | two tabs of one screen |
| `reviews/:courseId`, `reviews/:courseId/write` | `Reviews`, `ReviewWrite` / `ReviewEdit` | write and edit are one screen, empty or filled |
| `resources` | `Resources`, `ResourcesEmpty` (a state) | `ReportLink` is a sheet |
| `admin` | `AdminHome` | owner, admin |
| `admin/open-as`, `…/department`, `…/course` | `RolePick`, `ViewAsDept`, `ViewAsCourse` | owners only (§16.3) |
| `admin/people`, `admin/grant`, `admin/owners`, `admin/publish` | `AdminPeople`, `AdminGrant`, `Owners`, `Publish` | |
| `admin/terms`, `admin/contact`, `admin/audit`, `admin/roster`, `admin/professors/merge` | `Terms`, `PublicContact`, `AuditLog`, `Roster`, `ProfessorMerge` | roster, audit and merge are also reached by presidents |
| `maintain/:campus/:dept` and `/courses`, `/reviews`, `/resources`, `/professors`, `/succession`, `/succession/confirm` | `DeptHome`, `DeptCourses`, `DeptReviews`, `DeptResources`, `DeptProfessors`, `Succession`, `SuccessionConfirm` | the scope is in the path, so the header pills cannot disagree with it |
| `maintain/:campus/course/:courseId` | `CrHome` | |
| `maintain/:campus/:dept/resources/reported` | `DeptResourcesReported` | the Reported tab; a CR reaches it filtered to their course |
| `admin/roster/volunteers` | `RosterVolunteers` | Roster's second tab |
| `welcome`, `roles` | `RepProfile`, `RoleSwitch` | `welcome` is forced after an appointment (§16.3 fix 8) |

`Responsive` and `Logo` are references, not screens.

**Deep links need `_redirects`.** With path URLs every top-level segment above must serve
`/calculator/index.html`, and `/calculator/*` cannot be used (§7). So `_redirects` carries **one
line per top-level segment** (`/calculator/course/* /calculator/index.html 200`, …), and a test
fails when a `go_router` top-level segment has no line.

### 16.2 Problems found by laying the boards against this document

1. **Open as has no design here.** `RolePick`, `ViewAsDept` and `ViewAsCourse` let an owner see
   the app as any role, but the rules still see an owner, so every save is real.
2. **Two sources for "who may do what".** The rules encode §4's table; the screens will hide or
   show actions on their own, and Open as needs the same table on the client.
3. **Link reports have no shape and no reader.** `ReportLink`, and the REPORTED blocks on
   `DeptResources` and `CrHome`, need somewhere to write and someone allowed to read.
4. **Your reviews cannot be found.** A review stores no uid (§10.3), so nothing can query "my
   reviews" for `YourReviews` and `ReviewEdit`.
5. **Taking a course is self-declared.** `ReviewWrite` takes the term and professor from the
   student's grades, which the student typed; and older offerings may have no professor recorded.
6. **Deleting a review** is on `ReviewEdit`, but §10.3 only defines hiding.
7. **A professor merge cannot be written.** §10.1 rewrote the professor id on every affected
   review: an unbounded batch, over the rules' 20-lookup limit, by people who cannot write reviews.
8. **Representatives has no data, and nobody is asked for it.** Contact opt-ins and the "Volunteer" action have no document,
   and `staff/` is readable only by maintainers.
9. **The "official changed" notice (`Diverged`) cannot be detected**: an override does not record
   which published version it was detached from.
10. **"Best three semesters" (`Stats`) needs to know what a full semester is.** Summer terms and
    Practice School semesters are excluded, silently; nothing in the core classifies a semester.
11. **Bulk upload (`DeptCourses`) cannot be one batch.** Each offering write checks its grant and
    its audit entry; a department's worth of courses passes the rules' 20-lookup limit.
12. **A grant's name before first sign-in** (§12) — the roster shows a blank. *(27 Sep: gone —
    only people who have signed in can be appointed.)*
13. **Caches must not sync.** Reviews, resources, reports and the directory are cached in Hive;
    registering those boxes in `Sync` (§14.4) would push them into `users/{uid}` and its 500 KB cap.
14. **Queries without indexes.** `ReviewsSearch` ranks courses by review count, `AuditLog` filters
    by person and by course, `Reviews` searches professors by partial name.

### 16.3 Fixes (decided 27 Sep 2026)

1. **Open as is a client-side lens.** `viewAs = {role, campus, scope}` lives in memory for the
   session, never in Firestore. It drives which screens and actions render, through the same
   capability table as fix 2. A strip at the top names the role and returns to *Owner*. Writes
   made under it are the owner's: the audit entry carries `actor.role: 'owner'` and an
   informational `viewingAs`. **Testing what a role may actually do** uses the emulator and test
   accounts, never Open as. The route guard sends a non-owner home; the rules never trust it.
2. **One capability table in Dart**, `lib/core/roles/capabilities.dart`, a literal copy of §4's
   table: `can(role, action, scope)`. Screens ask it and never inline a role check. The rules
   tests walk the same table against the emulator, so the two cannot drift silently.
3. **Reports:**
   ```
   resourceReports/{resourceId}/entries/{sha256(uid + resourceId)}
     { reason: 'broken' | 'wrong' | 'spam' | 'other', note?, campus, createdAt }
   resourceFlags/{resourceId}
     { campus, department, courseId?, open: bool, count, reasons: {broken: 2, …}, lastAt }
   ```
   One report per person per link, pseudonymous like reviews; the flag is updated in the same
   batch, delta checked with `getAfter()`. **Read and cleared** by the owner, a president in
   scope and a CR of the course: `DeptResources` queries `open == true` for the department (course
   links rolled up included), `CrHome` for the course. *It works · dismiss* sets `open: false`;
   *Fix the link* edits the resource (audited) and closes the flag in the same batch.
4. **Your reviews:** the user's own document keeps `myReviews: [courseId]` — private, only they
   read it. `YourReviews` reads each `reviews/{courseId}/entries/{sha256(uid + courseId)}`.
   Nobody reading reviews can link them; the console could already.
5. **Accepted: taking a course is self-declared.** Rules require only an existing offering for
   that campus and term; the hashed id keeps it to one review per person per course. The term is
   derived from the grade's semester and the user's batch (`termOf(batch, semester)` in the core).
   An offering with no professor recorded takes `professorId: null`, which counts toward the
   course's rating and no professor's.
6. **A student may delete their own review.** Counters decrement in the same batch; helpful votes
   go with it. An edit keeps its votes and shows *edited* when `updatedAt > createdAt`.
   Moderation is still hide-only.
7. **Merge by pointer** (§10.1): `mergedInto` on the absorbed professor, `mergedIds` on the
   survivor, resolved at read.
8. **Directory:** `directory/{email}` `{ name, campus, roles: [...], email?, whatsapp?, phone?,
   handoverUntil? }`, written only by that person, each role checked against a live grant on
   write, **at least one contact field required by the rules**; read by the same campus;
   `Representatives` filters out lapsed roles. **`RepProfile` ("Before you start") is served
   first** on the first sign-in after an appointment — when `staff/{email}` exists and
   `staffContacts/{email}` does not, or a president's or CR's `directory/{email}` lacks a role
   they now hold. It cannot be skipped; Sign
   out is the only other way off it. Name (prefilled from Google) and contact switches, then
   *Save and continue* opens Switch role. Reopened from Settings › Contact details.
   **Two documents, two audiences** (decided 27 Sep 2026). `staffContacts/{email}` `{ name,
   phone, email, updatedAt }` — **`phone` required for every privileged role**, owners and admins
   included, who also get `RepProfile`. Readable only by privileged roles (an active owner, or a
   live grant via `staff/{me}`), so owners, admins, presidents and CRs can reach each other; the
   roster shows it. `directory/{email}` holds only what a **president or CR** chose to show
   students (at least one of email, WhatsApp, phone); owners and admins have no directory entry.
   `RepProfile` writes both in one batch.
9. **Every override granule records `basedOn`** — the offering's `updatedAt` when it detached.
   `Diverged` shows the notice when the offering is newer; *keep mine* moves `basedOn` forward.
10. **Semester kind in the core**: `regular | summer | practiceSchool`, from the semester label
    (`ST n` is summer) and its courses (a semester holding PS-II is Practice School). Stats'
    best-N counts `regular` only, and the screen does not mention the exclusion.
11. **Bulk upload writes in chunks** of five courses, each chunk an offering batch plus its audit
    entries, all tagged with one `uploadId`. Parsing and validation still reject the whole file
    first; a failed chunk stops the run, and the preview says which courses landed so the rest
    can be retried.
12. **Only people who have signed in can be appointed.** Every first sign-in writes
    `people/{email}` `{ name, campus, firstSignIn }` — self-written, and readable by owners,
    admins and presidents with `get` only, never `list`, so it can be checked but not browsed.
    `AdminGrant` looks the typed address up and shows the person's name, or **"Can not be
    found"**; the grant rule requires `exists(people/{email})`. The grant takes its `name` from
    there, and `RepProfile` lets the holder correct it (fix 8). *(Superseded 27 Sep 2026: the
    appointer typing a display name.)*
13. **Cache boxes stay out of `Sync`.** Only the user's own data is synced; a cache is a
    separate box registered in `Hive` alone, and a test asserts no cache box is in `Sync._boxes`.
14. **Indexes, declared up front in `firestore.indexes.json`:** a collection-group index on
    `stats` (`campus`, `count desc`); `audit` on (`campus`, `at desc`), (`actor.email`, `at desc`)
    and (`docId`, `at desc`); `professors` gets `nameTokens` (lowercased words and their prefixes)
    for `array-contains`; and every review ordering (§10.3).
15. **Switch role, for presidents and CRs** (`RoleSwitch`, from Settings › Working as). What Open
    as is for owners, except real: it lists Student and every live grant from `staff/{email}`,
    and the chosen role decides the home screen and the top strip until switched back. It is
    stored on the device (`settingsBox`, not synced), and a lapsed grant drops the app back to
    Student. Rules are unchanged — they already check the grant on every write. Owners see Open as
    in the same place.
16. **Volunteers.** `volunteers/{campus}|{courseId}|{email}` `{ name, email, campus, courseId,
    dept, createdAt, open }`, written by the student themselves (their own email, their own
    campus, a course with no live CR grant), withdrawable by them; read by presidents of
    `deptOf(courseId)` on that campus, admins and owners. *Roster › Volunteers* lists open offers
    by course. *Appoint as CR* opens `AdminGrant` filled in and, in the grant's batch, closes every
    offer for that course; *Dismiss* closes one. Offers close when the term ends.
    **The clipboard beside each offer copies a formal message** for the course's WhatsApp group,
    filled from the offers and the president's grant. Nothing is sent by Pointer and nothing is
    recorded; the poll runs in WhatsApp and the president appoints afterwards. Ship these two
    strings verbatim:

    *Several offers — election:*
    > Dear students of {courseCode} {courseTitle},
    >
    > The course does not have a Class Representative at present. The following students have
    > volunteered for the role:
    >
    > {1. Name — one line per volunteer}
    >
    > The Class Representative will be chosen by election. A poll will follow this message; kindly
    > cast your vote by {deadline}. Should you have an objection to any candidate, please write to
    > me directly before that time.
    >
    > The result will be announced in this group.
    >
    > Regards,
    > {presidentName}
    > Department President, {departmentName} ({deptKey}), {campusName}

    *One offer — objection notice:*
    > Dear students of {courseCode} {courseTitle},
    >
    > The course does not have a Class Representative at present. {volunteerName} has volunteered
    > for the role.
    >
    > Unless an objection is received by {deadline}, {volunteerName} will be appointed as the
    > Class Representative for {courseCode}. Should you have an objection, please write to me
    > directly before that time.
    >
    > Regards,
    > {presidentName}
    > Department President, {departmentName} ({deptKey}), {campusName}

    `{deadline}` defaults to three days ahead at 6:00 PM, written out ("6:00 PM on Wednesday,
    30 September 2026"); the president edits the text in WhatsApp before sending.
17. **Reported links are a tab.** `DeptResources` has three tabs — Dept, By course and
    **Reported** — and the Reported tab (`DeptResourcesReported`) holds every open report (fix 3).
    While any is open the tab keeps its amber colour and pulses (a 1.8 s ring and a pulsing dot,
    off under `prefers-reduced-motion`). A CR's course page shows the same thing as one pulsing
    amber row, opening that tab filtered to their course.

### 16.4 Smaller rules the boards set

- **Owners land on Open as after an explicit sign-in**, not on every app open (a cached session
  skips sign-in), and reach it from Settings any time.
- **Settings › Your roles** holds two rows — *Working as* (Switch role, or Open as for an
  owner) and *Contact details* (`RepProfile`) — for anyone with a live grant or an owner document
  (`staff/{email}`, §4). The block is absent for everyone else.
- **Every screen that scrolls is drawn full length** on the canvas. Build it as one scroll view
  with the bottom bar or button floating over it, and the last item clear of that overlay.
- **Resources: every link has ⋯**, opening `ReportLink`.

### 16.5 Additions to the sequence (§9)

- Fix 2 (capabilities) and fix 13 (cache boxes) land with **step 1**, before any screen needs them.
- Fix 9 (`basedOn`) lands with **step 4**; fix 10 (semester kind) can ship any time.
- Fixes 1, 11 and 12 land with **step 5–6**; fix 3 with **step 7**; fix 7 with **step 9**;
  fixes 4–6 and 14 with **step 10**; fix 8 with **step 11**.
- Fix 12 (`people/`) lands with **step 5**, before the first grant is written; fix 15 with it.
  Fix 16 with **step 11**; fix 17 with fix 3.
