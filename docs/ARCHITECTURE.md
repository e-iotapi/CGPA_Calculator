# Pointer architecture

This document explains how Pointer is put together: where data lives, how it
moves, who may change what, and how a build reaches users. It is written for
contributors. The detailed design record, with every decision and its
reasoning, is [`agent_instructions/ARCHITECTURE.md`](../agent_instructions/ARCHITECTURE.md).

- [1. The shape of the system](#1-the-shape-of-the-system)
- [2. The budget that shapes every design choice](#2-the-budget-that-shapes-every-design-choice)
- [3. Code layout](#3-code-layout)
- [4. Starting the app](#4-starting-the-app)
- [5. Local data and sync](#5-local-data-and-sync)
- [6. Shared data: the catalogue, heads and index documents](#6-shared-data-the-catalogue-heads-and-index-documents)
- [7. Firestore data model](#7-firestore-data-model)
- [8. Roles and permissions](#8-roles-and-permissions)
- [9. Grades and the CGPA rule](#9-grades-and-the-cgpa-rule)
- [10. Routes and screens](#10-routes-and-screens)
- [11. Environments, testing and deployment](#11-environments-testing-and-deployment)
- [12. Things that will surprise you](#12-things-that-will-surprise-you)

## 1. The shape of the system

Pointer is a Flutter web app. It has no server of its own: the browser talks
directly to Firebase, and Firestore security rules are the only thing standing
between a user and data that isn't theirs.

```mermaid
flowchart LR
  subgraph Browser["Student's browser"]
    App["Flutter web app<br/>(CanvasKit)"]
    Hive[("Hive boxes<br/>in IndexedDB")]
    App <--> Hive
  end

  subgraph Firebase["Firebase (Spark plan)"]
    Auth["Firebase Auth<br/>Google sign-in, BITS accounts"]
    FS[("Cloud Firestore<br/>+ security rules")]
  end

  CF["Cloudflare Pages<br/>landing page at /, app at /calculator/"]
  FH["Firebase Hosting<br/>staging only"]

  CF -- "serves the build" --> App
  FH -. "staging build" .-> App
  App -- "sign in" --> Auth
  App <-- "reads and writes,<br/>checked by rules" --> FS
  Auth -- "verified email" --> FS
```

- **Offline first.** Every grade lives in Hive (IndexedDB) first. The app
  works with no network; Firestore is where a copy is kept so the grades follow
  the student to another browser.
- **Shared data is read-mostly.** The course catalogue, class averages,
  reviews, resource links and the representatives list are written by a few
  people and read by everyone, so each is cached on the device and refreshed
  only when it changed.
- **No Cloud Functions.** Anything a server would normally enforce is done by
  Firestore rules, including the consistency of summary documents (see §6).

## 2. The budget that shapes every design choice

Pointer runs on Firebase's free Spark plan: **50,000 document reads and 20,000
writes a day** for the whole project. The design target is 8,000 active
students in one day across three campuses, with surges after evaluatives. That
leaves about **6 reads and 2.5 writes per student per day**.

So every screen is designed around a question: *how many documents does this
cost?*

| Rule | Why |
|---|---|
| One document per screen where possible | Firestore bills per document returned, not per byte |
| A small "head" document says what changed | The app skips reading anything whose version didn't move |
| Local cache first, refresh in the background | A warm open costs zero reads |
| Writes are debounced | A burst of edits becomes one write |
| Summary documents are written in the same batch as the source | Screens read one summary instead of many sources |

Every freshness and throttle value (how long a cache is trusted, how often sync
pulls) lives in one file, [`lib/core/timings.dart`](../lib/core/timings.dart),
with the read and write cost of each. Change them there.

If the daily quota runs out anyway, Firestore answers `resource-exhausted`;
the app treats that as offline and keeps working from the cache.

## 3. Code layout

```mermaid
flowchart TD
  main["lib/main.dart<br/>startup, sign-in"] --> app["lib/app<br/>router, routes, theme"]
  app --> features["lib/features<br/>student screens"]
  app --> admin["lib/admin<br/>owner, admin, president, CR screens<br/>(loaded on demand)"]
  features --> shared["lib/shared<br/>widget kit, layout"]
  admin --> shared
  features --> core["lib/core<br/>stores, models, rules of the domain"]
  admin --> core
  core --> hive[("Hive")]
  core --> fs[("Firestore")]
  legacy["legacy: home_page.dart, script.dart,<br/>course.dart, sync.dart"] --> core
  features --> legacy
```

| Folder | What lives there |
|---|---|
| `lib/core/grading` | SGPA and CGPA, marks and best-of rules, degree requirements |
| `lib/core/models` | Programmes, disciplines, charts, campuses |
| `lib/core/catalog` | The course catalogue: loading, caching, publishing |
| `lib/core/heads` | The per-campus head document (§6) |
| `lib/core/roles` | Grants, the directory, contacts, sessions and capabilities |
| `lib/core/reviews`, `resources`, `professors` | The stores behind those screens |
| `lib/core/storage` | Hive helpers, overrides, seeding a new user's courses |
| `lib/core/platform` | Browser-only code behind a conditional import |
| `lib/core/env` | Which environment this build talks to (§11) |
| `lib/core/analytics`, `perf` | Sampled usage counters and dev-only timing |
| `lib/features/*` | One folder per student screen: semester, marks, stats, reviews… |
| `lib/admin` | Maintainer screens, a deferred import so students never download them |
| `lib/shared/widgets` | The shared widget kit every screen is built from |

**The UI rule.** New screens are composed from the existing widget kit
(`lib/shared/widgets` and `lib/admin/widgets.dart`), not new widgets or
styles. A new page is usually a copy of an existing screen's structure with
different data.

## 4. Starting the app

`main()` signs the user in, then `startApp()` opens local data and draws the
first frame. Nothing on the network blocks the first frame except the very
first sync on a new device.

```mermaid
sequenceDiagram
  autonumber
  participant B as Browser
  participant M as main.dart
  participant A as Firebase Auth
  participant H as Hive
  participant S as Sync
  participant F as Firestore

  B->>M: load main.dart.js
  M->>A: initializeApp, wait for the saved user
  alt not signed in, or not a BITS student
    M-->>B: sign-in screen (or refusal)
  else signed in
    par start together
      M->>H: open catalogue, offerings, shared cache
    and
      M->>H: open device, resources, reviews boxes
    end
    M->>S: Sync.init(uid)
    alt first open on this device, or last pull over 24 h ago
      S->>F: pull users/{uid} (0 docs if unchanged)
      F-->>S: snapshot
      S->>H: write boxes
    else warm open
      S->>H: read boxes only
    end
    M-->>B: runApp, first frame
    M--)F: background: catalogue, roles, analytics ping
  end
```

A deep link into a maintainer page (`/maintain/…`, `/admin/…`) on a first
sign-in waits for the user's roles, so the route guard doesn't bounce them
home before it knows who they are.

## 5. Local data and sync

### Hive boxes

| Box | Holds | Synced |
|---|---|---|
| `settingsBox` | Discipline, batch, campus, profile names, preferences | yes |
| `coursesBox` | Every course with its Actual, Expected and Compare grades | yes |
| `offshootBox` | Finance offshoot courses | yes |
| `marksBox` | Evaluative marks | yes |
| `syncMeta` | Local `rev`, last synced snapshot, backup, pull time | no |
| catalogue, offerings, shared cache, resources, reviews, device | Caches of shared data | no, re-fetched |

### The sync protocol

The four synced boxes are serialised into one document, `users/{uid}`, with a
revision counter `rev`.

```mermaid
sequenceDiagram
  autonumber
  participant U as User edits
  participant S as Sync
  participant H as Hive
  participant F as users/{uid}

  U->>H: change a grade
  H->>S: box changed
  Note over S: debounce 30 s (flush early<br/>when the tab hides)
  S->>F: update {rev: base + 1, data, updatedAt}
  alt rules accept (rev was base)
    F-->>S: ok, localRev = base + 1
  else rules refuse (someone else pushed first)
    S->>F: pull the newer document
    F-->>S: server snapshot
    S->>H: server wins, local copy kept as backup
  end

  Note over S,F: Pull, at most once a day:<br/>query users where rev > localRev.<br/>Unchanged costs 1 read and returns nothing.
```

- **Push costs one write and no reads.** The rules only accept
  `rev == old rev + 1`, which is how a conflict is detected without a read.
- **The server wins a conflict**, and the local snapshot that lost is kept in
  `syncMeta['backup']`.
- **The document is capped at 500 KB** by Firestore; the snapshot stays far
  below it.
- **Sign-out wipes every local box**, so a shared computer starts clean.

## 6. Shared data: the catalogue, heads and index documents

### The catalogue

The course catalogue (every course, credit and chart) is one versioned bundle:
`catalog/marker` names the current version, and `catalog/v{n}` holds it. A
copy ships inside the app as `assets/catalog.json`, so a new device has a
catalogue before it has a network. Owners edit drafts and publish a new
version from the admin screens.

### Heads: one small document per campus

`heads/{campus}` holds version numbers: the catalogue's, the public contact,
the resource list's, each department's representatives and each course's
offering (class averages and evaluation scheme). The app reads the head at
most every 6 hours and fetches only what moved.

```mermaid
flowchart LR
  subgraph Writers
    CR["CR saves a scheme"]
    Pres["President edits links<br/>or appoints a CR"]
    Owner["Owner publishes<br/>the catalogue"]
  end
  subgraph Batch["One atomic batch, checked by rules"]
    Src["source document<br/>(offering, resource, grant…)"]
    Idx["summary document<br/>(repIndex, resourceVersions…)"]
    Head["heads/{campus}<br/>version += 1"]
  end
  Writers --> Src & Idx & Head
  Student["Student opens a screen"] -->|"1 read every ≤ 6 h"| Head
  Head -->|"only if its version moved"| Idx
```

### Index documents

Screens that would otherwise read hundreds of documents read one summary
instead. Each is written in the same batch as its source, and the rules check,
with `getAfter`, that the summary matches the source after the write, so a
client can't forge it.

| Summary | Replaces | Read by |
|---|---|---|
| `reviewIndex/{campus}` | every course's review stats | Reviews home |
| `reviews/{course}/campus/{campus}` | every review of a course | Course reviews (search and filter run on the device) |
| `resourceVersions/{campus}.links` | every resource link | Resources |
| `repIndex/{campus}` | every grant and directory entry | Representatives |

## 7. Firestore data model

```mermaid
flowchart TD
  subgraph Personal["Personal (owner of the doc only)"]
    users["users/{uid}<br/>rev, data, updatedAt"]
    people["people/{email}<br/>name, campus, firstSignIn, lastSeen"]
  end

  subgraph Catalogue["Catalogue and courses"]
    catalog["catalog/marker, catalog/v{n}"]
    courses["courses/{courseId}"]
    offerings["courses/{id}/offerings/{campus_term}<br/>scheme, averages, professors"]
    professors["professors/{id}"]
    courses --> offerings
  end

  subgraph Roles["Roles"]
    owners["owners/{email}"]
    grants["grants/{role|campus|scope|email}"]
    staff["staff/{email}"]
    directory["directory/{email}"]
    repIndex["repIndex/{campus}"]
    volunteers["volunteers/{…}"]
    audit["audit/{id}"]
  end

  subgraph Community["Reviews and resources"]
    reviews["reviews/{course}/entries/{hash}<br/>votes, reports"]
    reviewCampus["reviews/{course}/campus/{campus}"]
    reviewIndex["reviewIndex/{campus}"]
    resources["resources/{id}"]
    resourceVersions["resourceVersions/{campus}"]
  end

  subgraph Campus["Per campus"]
    heads["heads/{campus}"]
    analytics["analytics/{day}"]
    config["config/public, config/grantTerms"]
  end
```

- A review is stored under `sha256(uid + courseId)`, so one person has one
  review per course and the review carries no name or email.
- `audit/` records every privileged change with the actor, before and after.
- Campus is part of almost every path or document, and the rules only let a
  student read their own campus.

## 8. Roles and permissions

Roles are data in Firestore, not Firebase custom claims (claims need Cloud
Functions). The rules look the role up on every request.

```mermaid
flowchart TD
  Owner["Owner<br/>listed in owners/"] -->|appoints| Admin["Campus admin"]
  Owner -->|appoints| President
  Admin -->|appoints| President["Department president<br/>(a student)"]
  President -->|names| Secretary["Secretary<br/>(a flag on a department grant)"]
  President -->|appoints| CR["Course representative<br/>(a student)"]
  President -->|hands over to| Next["Next president"]
  Student["Student<br/>f/h/p20XXNNNN@campus.bits-pilani.ac.in"]
  Faculty["Faculty or staff address"] -. refused .-> X["no access"]
```

| Who | Can |
|---|---|
| Student | Own grades; read their campus's shared data; review courses they took; report links; volunteer as CR |
| CR | A course's evaluation scheme, class averages and professors, for their campus |
| President (and secretary) | Their department: courses, professors, resource links, review moderation, CRs, handover |
| Admin | Appoint presidents and CRs on their campus; grant terms |
| Owner | Everything: owners, the catalogue, the public contact, site analytics |

- **Only student addresses get in.** The rules and the app both accept
  `f`, `h` or `p` followed by digits at a BITS campus domain, plus listed
  owners. Faculty and staff addresses are refused.
- **Every grant expires.** A grant carries `expiresAt`; the rules ignore an
  expired one, so nobody keeps access after their term.
- **The rules are the enforcement.** The app hides what a user can't do, but
  the rules in [`firestore.rules`](../firestore.rules) are what actually
  refuse it, and [`test/rules`](../test/rules) tests them against the
  emulator.
- **Capabilities** in `lib/core/roles/capabilities.dart` map each role to what
  the UI offers; `test/core/capabilities_test.dart` checks them against the
  design record.

## 9. Grades and the CGPA rule

All GPA figures come from one function, `tally` in
[`lib/core/grading/cgpa.dart`](../lib/core/grading/cgpa.dart). Anything that
shows a GPA or a credit count calls it, so no two screens can disagree.

```mermaid
flowchart LR
  C["Each course in the<br/>student's discipline"] --> G{"Grade"}
  G -->|"A … E (a number)"| P["points += grade × credits<br/>GPA credits += credits"]
  G -->|GD| D["shown credits += credits<br/>no points, not in the GPA"]
  G -->|"NC, RC, W"| N["left out of both"]
  G -->|not graded yet| U["shown, not in the GPA"]
  P & D & U --> R["GPA = points ÷ GPA credits"]
```

The semester list and the GPA both filter courses through the same
`inDiscipline` check, so a course is counted exactly when it's shown.

## 10. Routes and screens

Routing is [`go_router`](https://pub.dev/packages/go_router), defined in
[`lib/app/router.dart`](../lib/app/router.dart). Every admin route loads the
admin code as a deferred library.

```mermaid
flowchart LR
  Home["/ (Home: semesters)"] --> Course["/course/:id (marks)"]
  Home --> Stats["/stats"] & Cal["/calendar"] & More["/more"] & Settings["/settings"]
  More --> Reviews["/reviews → /reviews/:courseId,<br/>/reviews/professor/:id"]
  More --> Resources["/resources"]
  More --> Reps["/representatives"]
  Settings --> Roles["/roles"]
  Roles --> Admin["/admin/… (owners, admins)"]
  Roles --> Maintain["/maintain/:campus/:dept/…<br/>/maintain/:campus/course/:id"]
  Owner["/campus (owner's preview campus)"]
```

Route guards redirect anyone without the right grant back to `/`.

## 11. Environments, testing and deployment

The build chooses its backend with a compile-time define,
`POINTER_ENV=prod|staging|emulator` (`lib/core/env`). Production is the
default. Test sign-in (`?as=<account>`) exists only in staging and emulator
builds: `isTestEnv` is a `const`, so the compiler removes that code from a
production build entirely, and `test/env/prod_build_guard_test.dart` keeps it
that way.

```mermaid
flowchart LR
  subgraph Local
    Dev["flutter run / tests"]
    Emu["Firebase emulators<br/>tools/test_env/up.sh<br/>(seeded)"]
    Dev --> Emu
  end
  subgraph CI["GitHub Actions"]
    Check["check.yml on every PR:<br/>analyze, tests, rules tests,<br/>prod build guard"]
    E2E["e2e.yml: Playwright<br/>perf and quota specs"]
    Deploy["deploy.yml on master:<br/>checks, then build"]
    DStaging["deploy-staging.yml"]
  end
  Deploy --> Prod["Cloudflare Pages<br/>pointer-bits-pilani.pages.dev"]
  Rules["firebase deploy --only firestore:rules<br/>(by hand, when rules change)"] --> ProdFS[("Production Firestore")]
  DStaging --> Staging["Firebase Hosting<br/>pointer-staging.web.app<br/>(seeded test accounts)"]
  Local -- "tools/test_env/staging.sh" --> Staging
```

| Command | What it checks |
|---|---|
| `flutter test` | Unit, widget and render tests |
| `cd test/rules && npm test` | `firestore.rules` against the emulator |
| `python3 agent_toolchains/code/verify.py` | Format, analyzer baseline and the full test suite |
| `python3 agent_toolchains/ui_check/ui_check.py run` | Renders every screen in light and dark at phone widths and reports layout, contrast and tap-size problems |
| `tools/e2e` (Playwright) | End-to-end, performance and quota budgets on the seeded emulator |

## 12. Things that will surprise you

- **Legacy files are deliberately unformatted.** `main.dart`, `home_page.dart`,
  `script.dart`, `course.dart`, `mastercourselist.dart`, `sync.dart` and
  `settings_page.dart` predate the rebuild; running `dart format` on them
  rewrites them wholesale. Edit them by hand.
- **Email-keyed maps and Firestore.** On the web, `SetOptions(mergeFields:)`
  splits a field path at every dot, so an email as a map key breaks. Use
  `update` with a `FieldPath`. `fake_cloud_firestore` gets these writes wrong
  too, so test them on the emulator.
- **Hive writes in widget tests** stall under fake time; test storage in unit
  tests and give widget tests in-memory data.
- **A new Hive box** has to be opened at startup, added to sync if it's
  personal, and cleared on sign-out.
- **The web API key is public by design.** Firebase web config is meant to be
  shipped; the rules and API-key restrictions are what protect data.
