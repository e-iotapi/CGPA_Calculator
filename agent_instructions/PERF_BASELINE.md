# Perf baseline

Before/after numbers from `tools/e2e/specs/perf.spec.mjs`, run against the
seeded emulator with CPU throttled 4x and the network at ~300ms/1.6Mbps
down (PERF_TEST_PLAN.md P0/T6). Budgets: home < 3s cold; a More sub-page
< 1.5s first open, < 300ms second open with 0 blocking reads.

## How to record a run

```
tools/test_env/up.sh   # or: seed the emulator, then flutter build web --profile ...
npm --prefix tools/e2e test -- perf.spec.mjs
```

Copy each test's timing (and, once P1/P2 land, the before/after read count)
into the table below. `tools/e2e/out/report` has the full run if you need it
later.

## Baseline (before P1/P2)

> **Deprecated (cloud container):** the note below was about the cloud container; record locally.

Not yet recorded here: this container's egress policy blocks
gstatic.com, which the Flutter Firebase web plugins fetch the JS SDK from at
runtime, so no spec here could reach a signed-in app to time (see the T6
commit for the full explanation). Record the first real numbers on a
machine or CI runner with normal internet access, before starting P1.

First local numbers, 29 Sep 2026, after B7–B15 (the schema of
PERF_TEST_PLAN.md §A). Playwright's Chromium on the seeded emulator,
throttled to 300 ms latency and 1.6 Mbps down, as perf.spec sets it.

| Page | Cold (home) / first open | Second open | Target |
|---|---|---|---|
| Home, cold | 33.2 s | — | < 3 s ✗ |
| Representatives | < 1.5 s ✓ | 611 ms | < 300 ms ✗ |
| Course reviews | < 1.5 s ✓ | 805 ms | < 300 ms ✗ |
| Resources | < 1.5 s ✓ | 688 ms | < 300 ms ✗ |

- The cold home is the download: `main.dart.js` is 3.9 MB, about 19 s alone
  at 1.6 Mbps, before CanvasKit. P7 (deferred libraries) and the bundle
  report (P4.6) are the levers; no Firestore work is on this path.
- Second opens re-render the page (no reads; see below); the 300 ms target
  counts the route push and first frame under throttling.

## After P1 → P2 → P2b → P2c

Re-run and fill in the same table once those land, so the improvement is on
record.
