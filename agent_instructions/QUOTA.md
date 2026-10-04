# Firestore quota budget

Tracks Pointer's Firestore read/write budget against Spark's free-tier caps,
for up to 8,000 users at ~40% peak-day activity (~3,200 DAU). See
deprecated/PERF_TEST_PLAN.md §0.5 for the full reasoning; this file holds the numbers.

## Free-tier caps (Firebase Spark, re-check at
https://firebase.google.com/pricing at implementation time)

- Firestore: 50,000 document reads, 20,000 writes, 20,000 deletes per day.
- A query costs one read per document returned, at least 1 even when empty.
- Rules `get()`/`exists()` calls count as reads.
- Quotas reset at midnight Pacific time (about 12:30–13:30 IST).

## Budget

| | Cap ÷ 3,200 DAU | Target |
|---|---|---|
| Reads/user/day | ≈15 | ≤8 |
| Writes/user/day | ≈6 | ≤3 |

## How to read this

- **Firebase console → Usage** (both the production and staging projects):
  shows today's read/write/delete counts against the daily cap in real time.
- When a quota runs out mid-day, Firestore returns `resource-exhausted` for
  every further request until the Pacific-midnight reset; the app treats
  that exactly like being offline (cache-first, no retries within the
  session) — see §0.5.

## Measured (quota.spec.mjs, T6; needs P0's window.pointerPerf)

Each run of `npm test` in `tools/e2e` appends or updates one line per
account below once P0 lands. Until then, the specs are skipped and no lines
appear here.

<!-- measured:student_full -->
<!-- measured:president -->

## Measured, 29 Sep 2026 (after B7–B15)

`window.pointerPerf` in the browser, emulator seed, student_full on Goa:

| What | Reads | Writes |
|---|---|---|
| First open on a new device | 9 (users doc 1, roles 1, catalogue 2, offerings 4) | 0 |
| Any later open (caches warm) | 0 | 0 |
| Representatives | 2 (repIndex 1, own volunteer offer 1) | 0 |
| Course reviews home | 1 (reviewIndex) | 0 |
| Resources | 5 on this seed, 1 with the `links` map | 0 |

- Resources falls back to the old per-department query where
  `resourceVersions/{campus}` has no `links` map yet (seeded and existing
  production links). Backfill it once, or re-save one link per campus.
- The Playwright busy-day spec (quota.spec) needs its flow updated for the
  rebuilt UI (an overlay intercepts the More tap; the president lands on
  RepProfile first) before it can gate a deploy.

