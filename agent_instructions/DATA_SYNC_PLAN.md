# Pointer — server structure for version markers and sync (plan)

**Status (2026-10-02): Stages 1–3 built on `pointer-rebuild`** (plan: `LOADING_SERVER_PLAN.md`; design: `ARCHITECTURE.md` §6, §13). Stage 3 differs here: no subscriptions, the hub broadcasts only the `v` map and clients read data from Firestore; pokes coalesce ~1.5 s, one head read per 20 s at most. Staging Worker + DO deployed and verified 2026-10-02; production awaits the owner's deploy (`server/README.md`).

Planning document, written 2026-09-30 from a design discussion with the
owner. Covers the server side only: Firestore version markers, a Cloudflare Worker and a
Durable Object. `ARCHITECTURE.md` stays the spec for data and rules; where this plan changes
something there, update `ARCHITECTURE.md` in the same change.

Stages are ordered; each works without the next. Do not start a stage before the owner has
reviewed it.

Constraints: Spark plan (no Cloud Functions, 50k reads / 20k writes a day), Firestore rules are
the only gatekeeper for Firestore data, Cloudflare free plan for anything new. **Firestore is
always the source of truth**; everything on Cloudflare is a hint that can be rebuilt from it.

---

## Stage 1 — Per-path version markers in Firestore

- One doc per campus: `heads/<campus> = { "<path>": v, … }` (e.g. `"resources/ELEC": 12`,
  `"course/EEE F211": 4`). One read gives per-path versions.
- Every write bumps its path's number in the same batch; rules enforce it, as they already do
  for `resourceVersions.v`.
- Small data (links, rep entries) may carry a copy in the head doc (the
  `resourceVersions.links` pattern, rules check the copy matches); larger data (reviews,
  offerings) carries only the version.
- Shared/privileged writes are **not** debounced: rules refusals must surface per action, audit
  entries are per action, and `versionBumped` (+1 per batch) refuses combined link writes.

---

## Stage 2 — Cloudflare Worker serving the markers

- `GET /heads/<campus>` returns every version marker. The Worker reads `heads/<campus>` from
  Firestore itself and caches at the edge ~60 s, so Firestore reads for version checks are flat
  (≈ per edge location per minute), independent of student count.
- Markers are public version numbers; the data itself stays behind Firestore rules.
- The Worker reads with a **new read-only Google service account** (Datastore Viewer), stored as
  a Worker secret. Never the staging admin key.
- If the Worker is down, clients fall back to reading `heads/<campus>` from Firestore.

---

## Stage 3 — Durable Object push, one socket per client

- One Durable Object per campus (`goa`, `hyderabad`, `pilani`, `dubai`). **One WebSocket per
  client**: the Worker verifies the Firebase ID token on upgrade; the DO tags the socket with
  the uid (hibernation API).
- **First message on connect:** the campus version list + that user's personal version, so a
  client is current on connect with zero Firestore version reads.
- **Shared edits — "poke, don't tell":** the writer commits the Firestore batch (rules, audit),
  *then* pokes `{path}` with its ID token. The DO reads the **committed** doc from Firestore
  (1 read) and broadcasts that copy, only if the version moved. Never broadcast
  client-supplied data (it would bypass the rules, e.g. a phishing link pushed to the whole
  campus). Fake pokes cost 1 read and broadcast nothing; rate-limit pokes per path.
- **Personal data:** after the client's Firestore push, it pokes; the DO bumps that user's
  version (SQLite inside the DO; no D1 needed) and sends `{you: true, v}` only to sockets tagged
  with that uid. **No grades ever go to Cloudflare**; the user's own doc is read from Firestore.
  Firestore bills per document, not per field, so one read of the user doc when the version
  moved is the design.
- **Subscriptions:** a client sends the paths it wants data for; the DO sends data only for
  those and a tiny "path X is v" for the rest.
- **Coalescing:** the DO holds per-path updates 1–2 s and sends only the latest.
- **Fallbacks (the writer's two writes can half-fail):** socket down → Worker `GET /heads`
  (Stage 2) → Firestore `heads/<campus>`; a daily full check catches anything missed.

**Rejected:** Firebase RTDB (100 concurrent connections on Spark); FCM (needs a server to send;
web push needs notification permission, iOS only for installed PWAs); Supabase / Ably / Pusher
(~100–200 connections free); live Firestore listeners (a read per viewer per change); two
sockets per client (double the connection requests for no gain); separate per-user DOs.

---

## Stage 4 — Reviews on timetable day

Spike: ~3,000 students × ~15 review pages ≈ 45k reads against 50k/day.

- **Reads through the edge cache:** Worker `GET /reviews/<campus>/<course>` (ID token checked,
  not part of the cache key), cached ~60 s. Firestore reads scale with courses × minutes, not
  students × pages.
- **Review writes stay direct to Firestore** (rules enforce one per course; the result is
  immediate).
- **Aggregates batched in the DO:** a poke "review added for <course>"; every ~60 s the DO reads
  the new committed reviews, recomputes each course summary and the campus index, and writes
  each once (no hot-document contention on `reviewIndex/<campus>`, ~1 write/s/doc). The DO
  writes with a service account, which bypasses rules, so it aggregates only what it read from
  Firestore, never client numbers.
- Then broadcast "reviews for <course> now v".

- **Rating summary per course** in `reviewIndex/<campus>`: average stars and count, kept current
  by the same DO batch. The Worker serves it as one cached response per campus, so the add-course
  picker shows every course's stars with zero Firestore reads (see `PROPOSED_FEATURES.md` §1).

---

## Stage 5 — Server parts of the proposed features

**Status (2026-10-03):** built on `pointer-rebuild`: §5.1 review gate (switch only, enforced in the app; ruling R-A in `BUILDOUT_PLAN.md`), §5.2 contributors (approve/reject one link per batch; contributor grants have no staff entry), §5.3 professor soft delete, §5.4 broadcast timetable + `.ics` (Worker deployed to staging). Not yet: §5.5 import script, §5.6 GEN. Shapes: `BUILDOUT_CONTRACTS.md`.

See `PROPOSED_FEATURES.md` for the features themselves; this section is only what they need
from Firestore, rules and Cloudflare.

### 5.1 Forced reviews (review gate)

- `config/public.reviewGate = { on, min: 5 }`, set by owners, admins, presidents and secretaries
  (audited). A counted review needs stars and "would take"; text is optional.
- While locked: every review is hidden, including in course search results; resources are not
  locked.
- Per-user counter `reviewCounts/<uid-hash>` = `{ n }`, +1 in the same batch as each review; rules
  check the review exists at its anonymous id (sha256 of uid + course) and did not before, so the
  count can't be inflated. It holds a number only, never which courses (anonymity holds).
- "Electives only" (HEL / DEL / OPEL, not CDC) is enforced in the app: the same course is DEL for
  one branch and CDC for another, and rules can't read the bundled catalogue efficiently.
- Imported reviews (`source: imported`) never count.
- **Gate at the edge:** once `n >= min`, the Worker checks the counter once and issues a signed,
  short-lived "reviews unlocked" token (HMAC); cached review reads verify only the signature (CPU,
  no Firestore read). Firestore rules check the counter too, for direct reads when the Worker is
  down.

### 5.2 Contributor role

- **Apply:** `contributorRequests/<campus>|<dept>|<email>`, the volunteer-offer pattern; the
  department comes from the student's branch. Scope once approved: **any department on their
  campus**. After applying, the app shows the president's
  public contact (existing directory entry, already readable).
- **Approve:** admins, the department's president or secretary grant `contributor|<campus>|<email>`
  (campus-wide), **no expiry, until revoked**; audit, revoke and the staff index work as for every
  grant. Admins, presidents and CRs are contributors by
  default: rules treat their grants as contributor rights; no second grant.
- **Publish, then approve within 15 days:** a contributor's link is created **live**:
  `status: published, approved: false, publishedAt: request.time`, copied into `links` with
  `approved` and `publishedAt`, campus version +1, and listed in a `pending/<campus>|<dept>` index
  doc (one read per approval queue), all in one batch. Rules let contributors create only
  `approved: false`. **Approving** is one batch by an admin, president or secretary:
  `approved: true`, the `links` copy updated, version +1, the contributor's points +4, their
  leaderboard entry, drop from the pending index, one audit entry. **Rejecting** sets
  `status: rejected` with a reason (removed from `links`); no points. Contributors can send
  several links as **one batched request**; approvers see one entry with clickable links.
- **The 15-day window without a timer (no Cloud Functions):** readers hide a `links` entry with
  `approved: false` once `publishedAt` is older than 15 days, **for everyone, the contributor
  included**; it earns nothing. Rules refuse approving it after the window
  (`resource.data.publishedAt + 15d > request.time`), and the pending index drops it. Once the Durable Object exists (Stage 3), it can also
  drop such entries from `links` daily with its service account.
- **Contributors can edit their own published links but cannot delete them.**
- **Points are awarded in the batch where a link becomes approved** (created approved by an
  admin/president/secretary/CR, or approved within the window). Rules allow +4 only on the
  `approved: false → true` transition (or an approved create) and only to `addedBy`. **Removing a published link does not take the points back** (owner's call).
- **Docs:** `contributors/<email> = { username, campus, points }`;
  `leaderboard/<campus> = { <username>: points }` (one read per view; rules check it mirrors the
  points doc; contributions are far below ~1 write/s, so no hot-doc problem; served from the
  Worker cache once Stage 2 exists); `usernames/<campus>|<name>` claims a unique name (length and
  charset checked; a president can reset an offensive one). The leaderboard shows usernames only,
  never email or name. All contributors are visible to every branch on the campus; admins,
  presidents and secretaries are tagged with their branch codes.
- **Imports credit points:** each of the department's presidents and secretaries gets +4 per
  imported record (the import script writes it, with the audit entry).

### 5.3 Professors

- Delete is a **soft delete** (`removed: true`, audited, by that department's president):
  reviews and stats point at professor ids, so a hard delete would orphan them. The professor
  leaves pickers and search, but its reviews stay under its name, and filters and counts treat it
  as before (owner, 2026-10-02). Merging duplicates already exists: the absorbed professor's
  reviews count as the survivor's (`mergedInto` / `mergedIds`), nothing rewritten.

### 5.4 Calendar

- **Campus academic calendar feed (wanted):** Worker `GET /calendar/<campus>.ics`, built from
  Firestore and edge-cached; students subscribe once.
- No automatic Google Calendar writes (a "sensitive" OAuth scope needing Google app
  verification); the feed covers it.

### 5.5 Data import (owner-run script)

Presidents compile their department's data with a fixed AI prompt into a published JSON schema
(links, professors, historical reviews) and send the file to the owner, who runs:
`import.mjs --dept ELEC --campus goa --from <president> file.json`.

- Admin SDK with the production service account; **bypasses rules, so the script validates every
  row as the rules would** (URL, lengths, known campus/dept/course codes, star range).
- **Dry run by default** (counts, duplicates, rejected rows with reasons, sent back to the
  president); `--commit` writes.
- **Idempotent:** ids derived from content (link: campus + dept + normalised URL; review:
  course + text); re-runs update, never duplicate; links already in the app are skipped.
- **Provenance:** `source: imported` on every record; one audit entry per run naming the
  department and the president who compiled it.
- Keeps derived data consistent: version markers, `links` copies, review summaries and the
  campus index rebuilt after each run.
- One department per run, chunked to stay well inside 20k writes/day; never writes `seed` or
  other test fields.

### 5.6 GEN department (Elective Contributors)

- `deptOf` (app and rules): a known department's prefix maps to it; **every other prefix maps
  to `GEN`** (today BITS, HSS, GS, IS, MST, MGTS, AN, MSE; 278 courses). New prefixes can't be
  orphaned. GEN is in the department table but **never a programme**: it has no branch code and
  never reaches setup or the discipline picker.
- An Elective Contributor is a `dept` grant with scope `GEN`, per campus, appointed by owners and
  admins; every existing department right applies unchanged (resources, reviews moderation,
  structures, professors, CRs, secretary, handover). Grants already stack, and checks take the
  union of a person's grants.
- **Claimed CDCs:** `courseClaims/<campus>|<course> = { dept }`, created by the president or
  secretary of a department for a GEN-prefix course that is a CDC of one of its programmes
  (audited). Rules: for a GEN-prefix course, the managing department is the claim's `dept` if the
  claim exists, else GEN. So GEN cannot touch a claimed CDC's resources, and the claiming
  department can. Every rule that uses `deptOf(course)` goes through one
  `managingDept(campus, course)` function (one extra `get` for GEN-prefix courses only).

---

## Budgets (free plans, checked against Cloudflare docs 2026-09-30)

Cloudflare free: Workers 100k requests/day; Durable Objects 100k requests/day (socket open = 1,
incoming messages 20:1, **outgoing free**), 13,000 GB-s/day (hibernated idle sockets cost 0),
SQLite storage not billed; D1 5M rows read / 100k written a day, 5 GB (hard-enforced since
2026-09-01). Limits reset 00:00 UTC = 05:30 IST. Workers CPU 10 ms/request (token check ~1–2 ms).

Estimate (≈5 connects/user/day, 1.5 personal syncs, ~200 rep edits):

| Users | Worker req | DO req | DO GB-s | Firestore version reads |
|---|---|---|---|---|
| 3,000 | ~20k | ~20k | ~500 | ~200 |
| 8,000 | ~52k | ~52k | ~1,300 | ~200 |
| 8,000, results day (15 opens) | ~132k ❌ | ~132k ❌ | ~3,000 | ~200 |

**Spike protections:** reconnect only when the socket actually dropped, with jitter; one socket
per client across tabs; if Cloudflare refuses, fall back to Firestore `heads/<campus>`;
escape hatch Workers Paid ($5/month, 10M requests).

**Verify before Stage 3:** max WebSocket connections per DO (~2–3k on the Goa DO; load-test),
and whether production uses Pages Functions (they share the Worker request count).

---

## Open questions

- Which data carries a copy in the broadcast vs only a version (proposed: links and rep entries
  carry data; reviews and offerings carry a version)?
- Succession: the Worker and DO live in the Cloudflare account the admins will co-own; add them
  to the deploy docs.
