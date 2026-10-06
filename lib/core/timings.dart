// Edit these to trade freshness for Firestore quota; each line says what it costs.
//
// Spark budget (agent_instructions/PERF_TEST_PLAN.md §A.3): at 8,000 users an
// average user should cost <= ~4 reads and <= ~1.5 writes a day. Shorter
// durations mean more reads/writes; longer ones mean staler data.

// --- Sync of a student's own data (lib/sync.dart) ---

/// A push waits this long after the last change. Shorter: more writes/day.
const syncPushDebounce = Duration(seconds: 30);

/// The pull check runs at most this often per device. 1 read each time.
const syncPullEvery = Duration(hours: 24);

/// The user doc is read whole at least this often (older-app-version guard).
const syncFullReadEvery = Duration(days: 7);

// --- Cache-first reads (lib/core/cache/cache_first.dart): 1 read per refresh ---

/// Campus head (version marker): a publish lands on the first open past this.
const headMaxAge = Duration(hours: 6);

/// Catalogue bundle refresh check.
const catalogMaxAge = Duration(days: 1);

/// Reviews course index (`reviewIndex`) and professors.
const reviewIndexMaxAge = Duration(hours: 3);

/// A page of reviews for one course.
const reviewPageMaxAge = Duration(minutes: 10);

/// Representatives (CR) list per campus.
const repsMaxAge = Duration(hours: 3);

/// A student's own volunteer offer, per course.
const offerMaxAge = Duration(hours: 3);

/// Whether the review gate is on, and its counts.
const gateMaxAge = Duration(hours: 3);

/// Timetable bundle per campus.
const timetableMaxAge = Duration(hours: 3);

/// Any copy kept under a version is read again past this, live or not: the
/// safety net for a marker some write forgot to move (owner, 2026-10-06).
const fullReadEvery = Duration(days: 1);

/// Admin screens' reads (roster, owners, terms, audit, offerings, analytics).
const adminMaxAge = Duration(minutes: 10);

/// Public contact doc.
const publicContactMaxAge = Duration(days: 7);

/// Official offering (marks scheme) with no head version to compare.
const offeringMaxAge = Duration(hours: 24);

/// Official offering whose head version is unchanged: re-checked this often.
const offeringVersionRecheck = fullReadEvery;

// --- Session (lib/core/roles/session.dart) ---

/// My roles are re-read at most this often. 2 reads each.
const rolesRefreshEvery = Duration(days: 7);

/// The sign-in record is written at most this often per device. 1 write.
const signInRecordEvery = Duration(days: 7);

// --- Grants (lib/admin/grant_form.dart, lib/core/roles/role_store.dart) ---

/// A full term or a handover ends this much short of the rules' cap, which
/// counts from Google's clock: a device clock running fast was refused.
const clockSlack = Duration(hours: 1);

// --- Analytics (lib/core/analytics/analytics_store.dart) ---

/// One in this many users (re-drawn daily) pings analytics: ~1/N writes/day.
const analyticsSampleEvery = 20;
