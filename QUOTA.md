# Firestore quota budget

Tracks Pointer's Firestore read/write budget against Spark's free-tier caps,
for up to 8,000 users at ~40% peak-day activity (~3,200 DAU). See
PERF_TEST_PLAN.md §0.5 for the full reasoning; this file holds the numbers.

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
