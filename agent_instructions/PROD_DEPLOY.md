# Production deploy: `pointer-rebuild` → production

Owner-run, in this order. Each step says how to check it before the next.
Production: Firebase project `cgpa-calculator-fb90c`, site on Cloudflare
Pages `pointer-bits-pilani` (landing at `/`, app at `/calculator/`), Worker
`pointer-heads`. CI deploys the site when `master` moves; everything else
here is by hand.

## Why the order matters
- The new rules require most staff writes and every review write to bump
  `heads/<campus>` in the same batch. The app on `master` today does not, so
  once step 3 is live an **old cached app cannot post a review or make a staff
  edit until it reloads** (the write fails with "Not allowed"; nothing is
  lost). Students' own grade sync (`users/{uid}`) is unaffected. Keep steps 3
  to 5 back to back, at a quiet hour.
- New queries need their composite indexes built before the new app runs.
- A missing `heads/<campus>` doc is fine on both sides: the rules read it as
  version 0 and the app falls back to each cache's max age.

## 1. Release check (Builder, before you start)
- [ ] `python3 agent_toolchains/code/verify.py` green; `cd test/rules && npm test`;
      `cd server && npm test`; the e2e suite (`.github/workflows/e2e.yml` steps,
      run locally until that workflow is on `master`).
- [ ] Staging retest done on your devices: theme switch, course search, Apply,
      calendar, reviews; the iPhone checks in `bugs/bug_tracker.md` (TM-6, TM-7,
      UT-3).

## 2. Worker (Cloudflare)
1. In Google Cloud for `cgpa-calculator-fb90c`, create a service account with
   **Datastore Viewer** only, and a JSON key for it. Never the admin key.
2. If the app has a custom domain, add it to `ALLOWED_ORIGINS` in
   `server/wrangler.toml` (now only `https://pointer-bits-pilani.pages.dev`).
3. `cd server && npx wrangler secret put FIREBASE_SA` (paste the JSON), then
   `npx wrangler deploy` (no `--env`: the top-level config is production).
4. Check: `curl https://pointer-heads.siddhu-cms.workers.dev/heads/goa` answers
   (empty heads are fine).
5. `gh variable set PROD_POINTER_HEADS_URL --body https://pointer-heads.siddhu-cms.workers.dev`
   and `gh variable set PROD_POINTER_LIVE_URL --body wss://pointer-heads.siddhu-cms.workers.dev`
   (the URL `wrangler deploy` printed, if different).

## 3. Firestore indexes, then rules
1. `firebase deploy --only firestore:indexes --project default`; wait until all
   20 show **Enabled** in the console (minutes).
2. `firebase deploy --only firestore:rules --project default`.
3. Check: the rules tab shows today's version.

## 3b. Backfill the summaries (before the site)
The new app reads review lists, the Reviews home, resources and
Representatives only from per-campus summaries that production does not have
yet; without them those screens show empty. Run, with the prod admin key:
1. `node tools/import/import.mjs rebuild --project cgpa-calculator-fb90c --allow-prod --key <key>`
   (dry run: check the counts look like production's reviews and links).
2. The same with `--commit`.
3. Check: `reviewIndex/goa`, `resourceVersions/goa.links` and `repIndex/goa`
   exist in the console.

## 4. Site
1. Open a PR `pointer-rebuild` → `master` and merge it yourself.
2. CI `deploy` runs: tests, rules tests, prod build with the prod guard, then
   Pages. Check `https://pointer-bits-pilani.pages.dev/calculator/version.json`
   moved and the app loads signed in.

## 5. Data
0. Faculty first, so the timetable and the reviews link to them:
   `node tools/import/import.mjs faculty --project cgpa-calculator-fb90c --allow-prod --key <key>`
   (dry run: 266 Goa faculty from `tools/course_reviews_out/faculty.json`, each under
   their own department; any "close to an existing professor" needs an answer), then `--commit`.
1. Timetable, with `--answers tools/course_reviews_out/tt_answers.json` (PDF names to
   faculty ids): `node tools/timetable/extract.mjs "<pdf>" --campus goa --sem 2026-1`
   (dry run, read the report), then the same with `--commit --project cgpa-calculator-fb90c
   --allow-prod --key <path to the prod admin key>`. Credits for the U-courses
   first (`--credits`).
2. Course reviews and handouts (after the timetable, so its professors link
   by name): `node tools/import/import.mjs reviews --answers tools/course_reviews_out/answers.json
   --project cgpa-calculator-fb90c --allow-prod --key <key>` (dry run: about 555
   reviews, 25 professors already there from the timetable or new, 50 handouts,
   class averages for 55 courses), then the same with `--commit`. It rebuilds
   the summaries itself. Re-running adds nothing.
3. Never run `tools/test_env/seed.mjs` against production.

## 6. After
- Sign in as yourself, a student and a president: Home, theme switch, reviews
  (post one), resources, calendar, Contribute, approvals.
- Watch Firebase usage and the Worker's request count for a day
  (`agent_instructions/QUOTA.md`).

## Rollback
- Site: Cloudflare Pages → Deployments → roll back to the previous one.
- Rules: Firebase console → Rules → history, or
  `git show <old master>:firestore.rules > /tmp/r.rules` and deploy that.
  The new collections are simply unreadable under the old rules.
- Worker: clear the two `PROD_POINTER_*` variables and redeploy the site; the
  app then reads heads from Firestore.
