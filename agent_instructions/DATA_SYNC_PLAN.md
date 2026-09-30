# Pointer — server structure for version markers and sync (plan)

Planning document. **No code yet.** Written 2026-09-30 from a design discussion with the
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
