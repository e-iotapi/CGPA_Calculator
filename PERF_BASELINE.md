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

Not yet recorded here: this container's egress policy blocks
gstatic.com, which the Flutter Firebase web plugins fetch the JS SDK from at
runtime, so no spec here could reach a signed-in app to time (see the T6
commit for the full explanation). Record the first real numbers on a
machine or CI runner with normal internet access, before starting P1.

| Page | Cold (home) / first open | Second open | Second-open reads |
|---|---|---|---|
| Home | | — | — |
| Representatives | — | | |
| Course reviews | — | | |
| Resources | — | | |

## After P1 → P2 → P2b → P2c

Re-run and fill in the same table once those land, so the improvement is on
record.
