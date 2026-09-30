# Pointer — proposed features

Planning document. **Nothing here is built.** Listed 2026-09-30 by the owner. The server side of
each feature (data, rules, Cloudflare) is in `DATA_SYNC_PLAN.md` Stage 5; this file is the
features as the user sees them. Build nothing before the owner has settled the open questions.

---

## 1. Star ratings while adding courses

The add-course picker shows each course's average stars and review count, so students choose
with the ratings in front of them. Data: one rating summary per course per campus
(`DATA_SYNC_PLAN.md` Stage 4).

## 2. Forced reviews

- Owners/admins switch it on (e.g. around timetable release).
- A student must post **at least 8 reviews** before reviews unlock.
- Only electives count: **HEL, DEL, OPEL**; never CDCs.
- By default the app pre-selects **last semester's electives** from the student's own courses; the
  student can change the selection manually.
- A forced review can be stars only (see open questions).
- Imported historical reviews never count toward anyone's 8.

Server: `DATA_SYNC_PLAN.md` §5.1.

## 3. Contributor role

1. **Apply:** any student can ask to become a contributor from Settings, and from a prompt when
   they open a shared resource (shown at most once per session or with "Don't ask again"; owner
   to confirm). After applying, they see the president's contact to talk about approval.
2. **Approve:** the department's president approves; the student gets privileged access to
   contribute resources, department-wide and per course.
3. **Submit → publish:** a contributor's link is pending until an approver publishes it; a
   rejection can carry a reason.
4. **Leaderboard:** contributors pick a **username** when they become one. **+4 points** per
   contribution, awarded **only when it is published**; removing a published link takes them back.
   Ranked **campus-wide**, shown with rank numbers in the **More** tab. Usernames only, never
   names or emails.
5. **Everyone can be a contributor:** admins, presidents and CRs are contributors by default
   (their links publish directly and earn points).

Server: `DATA_SYNC_PLAN.md` §5.2.

## 4. Resources by course

Add a resource to a specific course (not only department-wide). The rules already allow
course-scoped links; only the screen is missing.

## 5. Professors

- **Delete a professor** (soft delete, audited, by the department's president; server §5.3).
- **Add professor** shows greyed out, with the reason, for people who can't add one.

## 6. Course delete moves to the evaluation screen

Move a course's delete button out of Edit into the evaluation screen, with a confirmation.

## 7. Offshoot tab optional

A Settings option to remove the Offshoot tab; More takes its place. Saved in the user's own
data (synced like other preferences).

## 8. Calendar integration

Get the student's schedule into their calendar (`.ics` download or "Add to Google Calendar").
Optional: a subscribable campus academic calendar served by the Worker (server §5.4).

## 9. Initial data import (not an app feature)

Presidents compile their department's links, professors and historical reviews with a fixed AI
prompt into a JSON file and hand it to the owner, who imports it with an owner-run script. No
screen. Details: `DATA_SYNC_PLAN.md` §5.5.

---

## Open questions

1. **Forced reviews:** what exactly stays locked until 8 — viewing reviews at all, or only the
   text (stars visible)? Can a forced review be stars only, text optional?
2. **Contributors — who publishes:** only the department's president and secretary, or can a CR
   publish course links for their own course?
3. **Contributors — scope:** submit only to the approving department, or any department on
   their campus?
4. **Contributors — edits:** can they edit their published links? Does an edit go back to
   pending?
5. **Contributors — term:** yearly expiry like CRs, or until revoked?
6. **Imports:** do they credit points to the president who compiled the data?
7. **Calendar:** the student's own schedule only, or also a campus academic calendar feed?
8. **Apply prompt:** how often may the "become a contributor" prompt appear?
