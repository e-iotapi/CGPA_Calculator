# Pointer — data loading, sync and routes (plan)

Planning document. **No code yet.** Written 2026-09-30 from a design discussion with the
owner, so it is not forgotten. `ARCHITECTURE.md` stays the spec for data and rules; where this
plan changes something there, update `ARCHITECTURE.md` in the same change.

Phases are ordered; each one works without the next. Do not start a phase before the owner
has reviewed it.

---

## 0. Why

- The app loads too much and the UI lags **today**, before any new data arrives.
- Caches go stale: an edit made on one page is not reflected by another page's cache (e.g. a
  CR saves a scheme, the student view still shows a 24 h old copy).
- A mode held in a global ("Working as") outlived its screens: Back did not leave it, and a
  cached theme copy stopped the theme switch (fixed in 5e2716a, but the pattern remains).
- Predictable spikes (results day, timetable release) would exhaust the Spark quota:
  ~3,000 students × ~15 review pages ≈ 45k reads against 50k/day.

Constraints that still decide everything: Spark plan (no Cloud Functions, 50k reads / 20k
writes a day), Firestore rules are the only gatekeeper for Firestore data, Cloudflare free
plan for anything new.

---

## Phase 1 — Deconstruct today's data loading (read-only audit, then fixes)

Before adding layers, measure what exists.

**Audit.** For every data source, one row:

| Question | Why |
|---|---|
| When does it load (startup, route open, timer)? | Startup work delays first paint |
| For whom (every student, or roles only)? | Students must not pay for privileged data |
| How big, and where is it decoded? | On web, JSON decode runs on the UI thread (`compute()` is not a separate thread on web) |
| Who rebuilds when it changes (one widget, a page, the app)? | Wide rebuilds are the lag |
| How often is it recomputed (once, or every build)? | Maths per build adds up |

**Profile** a real session on a mid-range phone: startup to first paint, Home frame times,
profile/semester/theme switches (hooks exist: `Perf.time`, `FrameStats`).

**Suspects already seen in code (verify, don't assume):**
1. `MyHomePage.build` runs `sgcalc`, `cgcalc`, `creditTotals` and a full sort on every build.
   Compute once when grades change.
2. Legacy `script.dart` globals + high `setState` rebuild whole pages.
3. Data loaded at startup that most sessions never use (catalogue bundle, course lists, roles);
   `initializeCourses()` re-runs whenever Settings closes.
4. Synchronous JSON decode of cache blobs on the UI thread.

**Output:** the table + measured costs, ranked by cost × effort, in
`agent_instructions/LOADING_AUDIT.md`. Fix the top items before Phase 2.

---

## Phase 2 — Routes as paths; the mode comes from the URL

Most screens already have paths (`/resources`, `/reviews`, `/representatives`,
`/maintain/<campus>/<dept>/…`, `/admin/…`) and `admin` is already `deferred`. Missing:

1. **Home tabs as paths:** `/home/actual`, `/home/expected`, `/home/compare`,
   `/home/offshoot`, `/home/minor`, `/home/calendar`, `/home/stats`, `/home/settings`,
   `/home/more`. A stateful shell keeps tabs mounted; only the URL changes.
2. **Privileged screens under their own prefix:** `/priv/<role>/<scope>/…`.
   - The strip shows exactly when the path starts with `/priv/`. Leaving the prefix is being a
     student: Back, refresh and the strip's Student button all work with no extra state.
   - Delete the persisted `workingAs` global.
   - Route guards keep people off screens they cannot use; **Firestore rules remain the only
     security.** Paths organise, they do not protect.
3. **Deferred loading for every privileged role** (not only admin): students never download
   rep/president/admin code.
4. **Give the ~18 screens opened with `MaterialPageRoute` / `openRoute` a path.**
5. Each route declares the **data paths** it shows (used by Phases 3–6).

---

## Phase 3 — Path-keyed cache with write-through

- **One cache entry per data path** (`resources/goa/ELEC`, `course/EEE F211`,
  `reviews/goa/EEE F211`, …). A page reads only its own entries.
- **Write-through:** the code that saves a change updates (or drops) every cached entry that
  shows it, and records the new version. Your own edits are never stale, on any page.
- **Per-path versions in one doc per campus** (`heads/<campus> = { "<path>": v, … }`). Every
  write bumps its path's number in the same batch; rules enforce it, as they already do for
  `resourceVersions.v`. One read gives per-path invalidation.
- **Invalidate vs patch:** small data (links, rep entries) can be patched from the head doc
  itself (the `resourceVersions.links` pattern); larger data (reviews, offerings) is dropped
  and re-read on next open.
- **Delivery A (first):** check the campus head at most once per N minutes per path
  (start N ≈ 5 min), plus a Refresh/pull-to-refresh that forces it. Timings live in
  `lib/core/timings.dart`.
- **Personal data is unchanged:** local cache → 30 s debounce (`syncPushDebounce`) → Firestore.
  **Do not** debounce privileged/shared writes: refusals must appear at the button, closing a
  tab must not lose an appointment or removal, audit entries are per action, and the rules'
  `versionBumped` (+1 per batch) refuses combined link writes.

---

## Phase 4 — Cloudflare Worker for version markers (delivery B)

- Worker `GET /heads/<campus>` returns every version marker; it reads Firestore itself and
  caches at the edge ~60 s. Firestore reads for version checks become flat (≈ per edge location
  per minute), independent of student count.
- The client swaps only `fetchHeads()`; the compare → drop/patch pipeline is unchanged.
- The Worker reads with a **new read-only Google service account** (Datastore Viewer), stored as
  a Worker secret. Never the staging admin key.
- If the Worker is down, the app falls back to Phase 3 behaviour.

---

## Phase 5 — Durable Object push (delivery C), one socket per app

- **One WebSocket per app** to the campus Durable Object (`goa`, `hyderabad`, `pilani`,
  `dubai`). The Worker verifies the Firebase ID token on upgrade; the DO tags the socket with
  the uid (hibernation API).
- **First message on connect:** the campus version list + the user's personal version, so every
  device is current on open with **zero** Firestore version reads.
- **Shared edits — "poke, don't tell":** the writer commits the Firestore batch (rules, audit),
  *then* pokes `{path}` with its ID token. The DO reads the **committed** doc from Firestore
  (1 read) and broadcasts that copy, only if the version moved. Never broadcast client-supplied
  data (it would bypass the rules: a user could push a phishing link to the campus). Fake pokes
  cost 1 read and broadcast nothing; rate-limit per path.
- **Personal edits:** after the debounced Firestore push, poke; the DO bumps the user's version
  (SQLite in the DO, no D1 needed) and sends `{you: true, v}` only to sockets tagged with that
  uid. **No grades ever go to Cloudflare** — the device reads its own doc from Firestore.
  Firestore bills per document, not per field, so "read only changed fields" saves nothing;
  one read of the user doc when the version moved is the design.
- **Subscriptions by path:** on route change the app sends the data paths on screen; the DO
  sends data only for those, a tiny "path X is v" for others.
- **DO coalescing:** hold per-path updates 1–2 s and send only the latest.
- **Fallbacks (dual-write can half-fail):** Firestore is always the source of truth.
  Socket down → Worker heads (Phase 4) → rate-limited Firestore check (Phase 3); keep a daily
  full check for anything missed.
- Rejected: Firebase RTDB (100 concurrent connections on Spark), FCM (needs a server; web push
  needs notification permission, iOS only in installed PWAs), Supabase/Ably/Pusher (~100–200
  connections), live Firestore listeners (a read per viewer per change), two sockets per app
  (double the connections for no gain).

---

## Phase 6 — Reviews for timetable day

- **Reads through the edge cache:** Worker `GET /reviews/<campus>/<course>` (token checked, not
  in the cache key), cached ~60 s. Firestore reads scale with courses × minutes, not students ×
  pages.
- **Writes stay immediate:** the student's review goes straight to Firestore (rules enforce one
  per course; the result shows at once).
- **Aggregates batched in the DO:** the app pokes "review added for <course>"; every ~60 s the
  DO reads the new committed reviews, recomputes each course summary and the campus index, and
  writes each once (no hot-document contention on `reviewIndex/<campus>`). The DO writes with a
  service account, so it must aggregate only what it read from Firestore, never client numbers.
- Then broadcast "reviews for <course> now v"; open apps refetch via the edge cache.

---

## Phase 7 — Responsiveness under incoming data (applies to every phase)

- The app only receives and processes data for the screen that is open (Phase 5 subscriptions).
- **Client queue:** keep only the latest message per path; apply at most one batch per frame;
  split heavy merges across frames with the scheduler (no isolates on web).
- **Hidden tab:** only mark paths dirty; process once on return.
- **Per-path listeners:** a message rebuilds only that path's widgets; no app-wide `setState`.
- **No jumps:** new items show a "N new" pill; insert on tap; keep scroll position.
- Lazy lists (`ListView.builder`, slivers) and paged reviews.
- **Cache size cap** with LRU eviction of unvisited paths; memory holds the open screen plus a
  few recent paths.

---

## Budgets (free plans, checked against Cloudflare docs 2026-09-30)

Cloudflare free: Workers 100k requests/day; Durable Objects 100k requests/day (socket open = 1,
incoming messages 20:1, **outgoing free**), 13,000 GB-s/day (hibernated idle sockets cost 0),
SQLite storage not billed; D1 5M rows read / 100k written a day, 5 GB (hard-enforced since
2026-09-01; resets 00:00 UTC = 05:30 IST). Workers CPU 10 ms/request (token check ~1–2 ms).

Estimate (≈5 connects/user/day, 1.5 personal syncs, ~200 rep edits):

| Users | Worker req | DO req | DO GB-s | Firestore version reads |
|---|---|---|---|---|
| 3,000 | ~20k | ~20k | ~500 | ~200 |
| 8,000 | ~52k | ~52k | ~1,300 | ~200 |
| 8,000, results day (15 opens) | ~132k ❌ | ~132k ❌ | ~3,000 | ~200 |

**Required protections for spike days:**
1. Reconnect only if the socket actually dropped, after the page is visible, with jitter.
2. One socket shared across tabs.
3. If Cloudflare refuses, degrade to the rate-limited Firestore check.
4. Escape hatch: Workers Paid, $5/month, 10M requests.

**Unverified — check before Phase 5:** max WebSocket connections per DO (~2–3k on the Goa DO;
load-test), and whether production uses Pages Functions (they share the Worker request count).

---

## Open questions for the owner

- Is ~5 minutes of staleness for other people's edits acceptable in Phase 3?
- Which data is patched from the broadcast vs dropped and re-read (proposed: links and rep
  entries patched; reviews and offerings re-read)?
- Succession: the Worker and DO live in the Cloudflare account admins will co-own; add them to
  the deploy docs.
