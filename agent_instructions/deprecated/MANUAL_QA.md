> **Deprecated (2026-10-02):** staging QA on real phones ended on 2026-10-01 (Tester / Tester Mac); staging is now https://pointer-staging.web.app, not a Pages preview. Kept for history; current plans are listed in `agent_instructions/README.md`.

# Manual QA on a real old phone (staging)

`tools/test_env/staging.sh`'s build is deployed to the staging Pages preview.
Automated checks (T6, `tools/predeploy.sh`) cover behaviour; this is for
what only a real device shows: jank, real network conditions, install
prompts. Run this on the oldest/slowest Android phone available, on mobile
data if possible, before every release that touches startup, caching or a
More page.

Sign in on the staging build with `?as=<key>` (`test_env/accounts.json`),
password from the `STAGING_PASSWORD` secret.

## Per role

- [ ] **student_full** — Home, Stats, Marks (`/course/EEE F311`) scroll
      smoothly, no visible jank on first paint.
- [ ] **student_dual** — same, on a course list with two Practice School-II
      rows.
- [ ] **student_new** — degree setup completes and lands on a populated
      Home.
- [ ] **president** — `/maintain/goa/ELEC` and its sub-pages open without a
      long stall.
- [ ] **owner** — `/admin` and `/admin/open-as` work.

## Cross-cutting

- [ ] **Sign-in**: Google sign-in completes normally (not `?as=`) on at
      least one real BITS-style flow, if a real test account is available.
- [ ] **Offline strip**: turn on airplane mode mid-session; the Calendar's
      offline strip appears; turning it back on clears it without a manual
      refresh.
- [ ] **Install to home screen**: the browser's install prompt appears (or
      the app's own "add to home screen" steps show when it doesn't); the
      installed icon and splash screen look right.
- [ ] **Scroll smoothness**: Home, Stats and Marks scroll without dropped
      frames on the throttled hardware — this is what the perf spec's CPU
      throttling approximates, but a real device is the ground truth.
