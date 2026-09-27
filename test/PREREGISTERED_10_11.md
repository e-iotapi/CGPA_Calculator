# Pre-registered tests: §9 steps 10 and 11

Registered 27 Sep 2026, before any of these tests were written or run. Each line is the
behaviour and the expected outcome. Once run, a failure is reported as a failure. The fix goes
in the app, not the expectation. If an expectation itself proves wrong, that is reported
separately, with the reason, and never changed silently.

Harness: widget tests on `FakeFirebaseFirestore` with `roleStore` set, pumped bare in a
`MaterialApp` (or a small `GoRouter` where navigation is under test). No UI-triggered Hive
writes (ARCHITECTURE.md §14): `settingsBox` and `reviewsBox` stay closed, so remembering a
review and caching pages are skipped. Security rules are covered separately in `test/rules/`.

## Step 10 — Reviews

| # | Behaviour | Expected |
|---|---|---|
| R1 | `ReviewsHome` with nobody signed in | Says "Sign in with your BITS account to read reviews."; no list |
| R2 | `ReviewsHome`, course stats on Goa for three courses | "Most reviewed at Goa" lists them by review count, highest first, each "N% take it · M reviews" |
| R3 | Type "men" in the search box | A Professors section lists Goa's "Ramesh Menon"; Pilani's Menon is not listed |
| R4 | Type "CS F21" | A Courses section lists CS F211 with its title |
| R5 | Tap a professor | Their page lists every course the offerings record them teaching, including one with no reviews, each with its review count |
| R6 | `CourseReviewsPage` with two visible reviews and one hidden | Shows the two, not the hidden one; the stats card shows the course average |
| R7 | Tap a professor's "Taught by" pill | Only that professor's reviews remain listed |
| R8 | Tap Helpful on someone else's review | Its helpful count goes up by one in the database; "Marked helpful." shows. The student's own review shows neither Helpful nor Report |
| R9 | `ReviewFormPage` editing an existing review | There is no Delete button; Save changes stores the new stars and moves the course counter by the difference only |
| R10 | `ReviewFormPage`, a new review | Post review is disabled until stars and "take it again" are both chosen, and disabled again past 600 characters |
| R11 | `DeptReviews`, Reported tab | Lists the reported review; Hide with a reason hides it, takes it off the counters and writes one audit entry; the Hidden tab then shows it with Unhide, and Unhide puts the counters back |
| R12 | Hide with an empty reason | Nothing changes |

## Step 11 — Succession, contacts, Representatives, volunteers, More

| # | Behaviour | Expected |
|---|---|---|
| S1 | `RepProfilePage` for a president, from Settings | Save is disabled until a valid phone is given and at least one student-facing field is on; saving writes `staffContacts/{me}` and `directory/{me}` |
| S2 | `RepProfilePage` while `profileDue` is true | Title "Before you start" and a Sign out button; after saving, `profileDue` is false and the app is on the Switch role route |
| S3 | `checkProfile()` for a president with no contact documents | Sets `profileDue` true; after `saveProfile`, a second `checkProfile()` sets it false |
| S4 | The router's profile gate | While `profileDue` is true, any location resolves to `/welcome`; `/welcome` itself is left alone; when false, nothing is redirected |
| S5 | `RepresentativesPage` for a student taking EEE F211 | Lists the ELEC president and the EEE F211 CR with only the contact fields each chose; a role whose `until` has passed is not listed; with two ELEC presidents, the one ending sooner shows "Handing over · access ends …" |
| S6 | A course the student takes with no CR listed | Shows Volunteer; tapping it writes an open offer and the button becomes Withdraw; Withdraw closes the offer |
| S7 | Roster › Volunteers for the ELEC president | Offers grouped by course; the copy button puts the verbatim WhatsApp message on the clipboard (election wording for two offers); Dismiss closes that one offer |
| S8 | Appointing a CR with the course's offers passed as `closeOffers` | The grant is written and every one of those offers is closed, in the same batch |
| S9 | `Succession`: a Pilani address, then an unknown Goa address, then a known one | Campus problem message; then "Can not be found…"; then "What happens" with the outgoing date = the earlier of today + 20 days and the current expiry |
| S10 | `SuccessionConfirm` | Hand over is disabled until the department code is typed; after tapping, the president's grant carries `handedTo` and the successor's grant is live |
| S11 | `Succession` while a handover runs | Shows "Handing over to …"; Cancel the handover restores the old expiry and revokes the successor |
| S12 | `MorePage` | Lists Representatives, Course reviews and Resources; each opens its page |
| S13 | The bottom bar at 390 px wide with five items | Every item, More included, is at least 50 px tall and at least 50 px wide |
| S14 | Roster | A maintainer with staff contacts shows their phone beside the appointment line; one without shows "No phone yet" |

## Results (27 Sep 2026)

Tests: `test/reviews/reviews_screens_test.dart` (R1–R12) and `test/roles/step11_screens_test.dart`
(S1–S14). No expectation above was changed.

First run: 21 of 26 passed.

| # | First run | Cause | Resolution |
|---|---|---|---|
| R3, R4, R5 | Failed | **App bug.** The debounced search in `ReviewsHome` assigned a `Future` inside `setState` with an arrow, which throws in debug builds on the first keystroke | Fixed in `reviews_home.dart`; all three pass |
| R11, R12 | Failed | **App bug.** `DeptReviews` disposed the Hide dialog's reason field while the dialog was still closing, which crashes in debug | The dialog now owns its field (`_ReasonDialog`); both pass |
| R6 | Failed | **Harness.** The default 800×600 test screen left the second review off-screen, so it was never built | The tests use an 800×2400 screen; the expectation is unchanged; passes |

Final: 26 of 26 pass.
