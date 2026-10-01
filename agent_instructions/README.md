# Agent instructions

Plans, handoffs and records for agents working on Pointer. Code cites them by
name (for example "ARCHITECTURE.md §7"); they all live here.

## Current

| File | What it is |
|---|---|
| `ARCHITECTURE.md` | The design of record: data, roles, routes, rules. `test/core/capabilities_test.dart` reads its §4 table. `docs/ARCHITECTURE.md` is the contributor overview. |
| `LOADING_SERVER_PLAN.md` | **Next to build:** on-device store caches, level-by-level prefetch, per-path version markers, the Cloudflare Worker and Durable Object push (task by task). |
| `DATA_SYNC_PLAN.md` | The server design that plan implements: version markers, Worker, Durable Object, reviews on the edge cache, and the server parts of the proposed features (Stage 5). |
| `PROPOSED_FEATURES.md` | Features listed by the owner, not built: star ratings in the course picker, forced reviews, contributor role and leaderboard, resources by course, professor delete, calendar, initial data import. |
| `QUOTA.md` | Firestore reads and writes per user against Spark's caps; `tools/e2e/specs/quota.spec.mjs` writes it. |
| `DISCIPLINES_GOA_HYD.md` | Reference data: programmes per campus (`lib/core/models/programmes.dart` is built from it). |

## Deprecated

`deprecated/` holds finished or replaced plans, each with a banner saying
why. Read them for history only. Code comments still cite some of them by
section (`PERF_TEST_PLAN.md §A.1`, `UI_REBUILD_HANDOFF.md §3.9`);
`python3 agent_toolchains/plan/plan.py get <id>` reads PERF_TEST_PLAN's by id.
