# Agent instructions

Plans, handoffs and records for agents working on Pointer. Code cites them by
name (for example "ARCHITECTURE.md §7"); they all live here.

## Current

| File | What it is |
|---|---|
| `ARCHITECTURE.md` | The design of record: data, roles, routes, rules. `test/core/capabilities_test.dart` reads its §4 table. |
| `PERF_TEST_PLAN.md` | The backend build-out plan (speed, quota, roles, degree fixes, analytics). Read items with `agent_toolchains/plan/plan.py get`. |
| `DATA_SYNC_PLAN.md` | Planned, not started: server structure for sync — per-path version markers, Cloudflare Worker and Durable Object, reviews on the edge cache. |
| `UI_REBUILD_HANDOFF.md` | What the finished UI waits on from the backend, and the §6 checklist. |
| `MANUAL_QA.md` | The checklist for a real old phone on staging. |
| `PERF_BASELINE.md` | Measured load times against the budgets. |
| `QUOTA.md` | Firestore reads and writes per user against Spark's caps; `tools/e2e/specs/quota.spec.mjs` writes it. |
| `COURSE_GAPS.md`, `DISCIPLINES_GOA_HYD.md` | Reference data: course requirements and programmes per campus. |

## Deprecated

`deprecated/` holds finished or replaced plans, each with a banner saying
why. Read them for history only.
