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

- Owners/admins/presidents/secretaries switch it on (e.g. around timetable release).
- A student must post **at least 5 reviews** before reviews unlock.
- Which reviews count, (Mandatory: Star Ratings and Will I take it, Optional: Written Review).
- Only electives count: **HEL, DEL, OPEL**; never CDCs.
- By default the app pre-selects **last semester's electives** from the student's own courses; the
  student can change the selection manually.
- A forced review can be stars only (see open questions).
- Imported historical reviews never count toward anyone's 5.

Server: `DATA_SYNC_PLAN.md` §5.1.

## 3. Contributor role

1. **Apply:** any student can ask to become a contributor from Settings, and from a prompt when
   they open a resources page. (shown at most once per session or with "Not Now", "Apply Now";). After applying, they see the president's contact to talk about approval.
   Message: "Contribute to the Community Now, Become a Contributor"
3. **Approve:** the admins, department's president and secretary approves; the student gets privileged access to
   contribute resources, department-wide and per course.
4. **Publish, then approve within 15 days:** a contributor's link goes live immediately, but an
   approver (admin, president or secretary) must approve it within **15 days**. The contributor
   sees each link's state (awaiting approval, approved, rejected). **Points count only after
   approval.** This rule is shown to contributors upfront, when they apply. A rejection carries a
   reason. They can batch links into one approval request; approvers see it as one entry with
   clickable links. Not approved within 15 days: the link stops showing (see open questions).
5. **Leaderboard:** contributors pick a **username** when they become one. **+4 points** per
   contribution, awarded **only when it is published**; removing a published link does not take them back.
   Ranked **campus-wide**, shown with rank numbers in the **More** tab. Usernames only, never
   names or emails.
6. **A Contribute Tab inside More, Just like Resources etc.**, Opens the contribute Page.
7. **Everyone can be a contributor:** admins, presidents and CRs are contributors by default
   (their links publish directly and earn points). All contributors can be seen by all branches within a campus, Tag (Admins, Presidents and Secretaries by their Branch Codes).

Server: `DATA_SYNC_PLAN.md` §5.2.

## 4. Resources by course

Add a resource to a specific course (not only department-wide). The rules already allow
course-scoped links; only the screen is missing.

## 5. Professors

- **Delete a professor** (soft delete, audited, by the department's president; server §5.3).
- **BUG: Add professor** shows greyed out, Have to click the search button and search, for them to be able to add; Check if duplicates exist and warn for potential matches.

## 6. Course delete moves to the evaluation screen

Move a course's delete button out of Edit into the evaluation screen, next to the edit button, with a confirmation.

## 7. Offshoot tab optional

A Settings option to remove the Offshoot tab; More takes its place. Saved in the user's own
data (synced like other preferences), Ships by default with the offshoot tab.

## 8. Calendar integration

A subscribable campus academic calendar feed served by the Worker (server §5.4); students add it
to Google Calendar (or any calendar) once. No automatic Google Calendar writes: that needs a
Google "sensitive" OAuth scope and app verification.

## 9. Initial data import (not an app feature)

Presidents compile their department's links, professors and historical reviews with a fixed AI
prompt into a JSON file and hand it to the owner, who imports it with an owner-run script. No
screen. Details: `DATA_SYNC_PLAN.md` §5.5.

## 10.Course Reviews Page Changes
The Stats on top (The Star Rating and Would Take): These should Change, based on the filter applied, for e.g. A Professor filter should only show these stats for the professor.
Filters: 
1. Professors (Make it a dropdown of the professor who took the course), Keep the search Option, Empty is a valid option.
2. Year (Make it a Typeable query, Validate Year), Semester (Make it a dropdown, Options: Sem 1;Sem 2;Summer);
3. Let them Combine Professors and Year and sorting options to create complex queries.
4. Sorting Options: Sort by Helpful, Recent, Highest, Lowest.
5. Show the Grade obtained by the reviewer, and the Marks they obtained
6. Display the average grade Obtained in the course and the marks along with the reviews, Only show marks field when it is present, otherwise Just Display Grades.
7. Write a Review, add a grade obtained field (Mandatory, Not Disclosed is a valid field), Add a marks obtained field (Not Mandatory). Both these fields will be autofilled from CGPA Data, but are changeable. 
8. **"Course resources" button** on a course's reviews page: opens that course's resources page
   directly, with its handout links already there (handouts come from the initial review import,
   `courses.json` → course resources).


## 11. Your Reviews Page Changes
1. Add a filter (All) and make it the default.

## 12. Resources Tab Changes
1. Give them a new screen to choose which Degree resources to view, Course resources button to view resources by all courses (Filter: This semester remains default, All; No degree barrier; Let them search), Build the UI from the More Tab screen, should look similar, Resuse code where possible.
3. No Resources page remains the same.

## 13. Elective Contributor role (the GEN department)

278 of the 1,111 catalogue courses have a code prefix no department owns (BITS 111, HSS 85,
GS 36, IS 21, MST 13, MGTS 6, AN 5, MSE 1), so no president can manage them; BITS, HSS and
MGTS include CDCs of many programmes.

- A management-only department **GEN ("Electives & General")** owns every prefix no other
  department owns. **Not a degree programme or branch:** it never appears in setup, the
  discipline picker, or anywhere a student chooses a programme.
- **Any future prefix defaults to GEN**, so a new catalogue prefix is never orphaned.
- An **Elective Contributor** is a department grant with scope GEN, per campus, appointed by
  owners and admins. They manage GEN courses like a president manages a department: resources,
  reviews moderation, course structures, professors, CRs for GEN courses, a secretary, handover.
- **CDCs already managed by a department stay with that department.** A GEN-prefix course that
  is a CDC of some programme (e.g. BITS F225 Environmental Studies) can be claimed by that
  programme's department; once claimed, GEN cannot manage its resources, and the claiming
  department can. Unclaimed GEN-prefix courses stay with GEN.
- **Roles stack:** any privileged user (admin, president, secretary, CR) can also hold it; their
  resources, reviews, structures and professors show both scopes. Working-as picks one role at a
  time.
- Shown as "Electives" where other roles show a branch code (A3, A7).

Server: `DATA_SYNC_PLAN.md` §5.6.

## 14. Guided tour for students

On a student's **first sign-in** (after setup), a short guided tour walks through each feature
where it lives: Actual / Expected / Compare / Offshoot / Minor, adding courses and grades,
Calendar, Stats, Resources, Reviews, Representatives, More and Settings.

- **Students only:** privileged roles (contributors, CRs, presidents, secretaries, admins,
  owners) never see it on their privileged screens.
- Each step highlights the real control with a one-line explanation; **Skip** and **Next** on
  every step; skipping ends the tour.
- Shown once per account: "tour seen" is saved in the user's own data (synced), so a second
  device doesn't repeat it. A "Replay the tour" option in Settings.
- No server work beyond that one preference field.

## 15. Last updated

Students see how current a representative's work is, so the branch can hold them to account.

- Counted in **semesters, not days** ("Last updated: Aug 2026", "2 semesters ago"); neutral
  wording, no shaming.
- **Only meaningful edits count:** adding, editing or removing resources, course structures and
  professors; not opening a page or re-saving unchanged data.
- **Course page:** "Last updated" beside the course's rep.
- **Representatives page:** "N courses stale" per rep or department.
- Server: a `lastUpdated` timestamp on the course/department, set in the same batch as each
  meaningful edit (rules require `request.time`).

---

## Open questions

1. **Forced reviews:** what exactly stays locked until 8 — viewing reviews at all, or only the
   text (stars visible)? Can a forced review be stars only, text optional?
   Answer: All reviews, no resources, The reviews also remain disabled for course Searches. 
2. **Contributors — who publishes:** only the department's president and secretary, or can a CR
   publish course links for their own course?
   Answer: Contributors can submit and publish 
4. **Contributors — scope:** submit only to the approving department, or any department on
   their campus?
   Answer: Any Department on campus.
5. **Contributors — edits:** can they edit their published links? Does an edit go back to
   pending?
   Answer: Yes they can edit their links, but can't delete them.
6. **Contributors — term:** yearly expiry like CRs, or until revoked?
   Answer: Until Revoked.
8. **Imports:** do they credit points to the president who compiled the data?
   Answer: Yes both to the president and Secretaries.
10. **Calendar:** the student's own schedule only, or also a campus academic calendar feed?
    Answer: An Academic Calendar Feed as well.
12. **Apply prompt:** how often may the "become a contributor" prompt appear?
    Answer: Each session, (Session: Every time they open the App.)
13. **Contributors publishing:** answered — they publish directly; approval within 15 days;
    points after approval.
14. **Calendar:** answered — campus feed only, no automatic Google Calendar writes.
15. **Grade and marks on reviews:** answered — marks optional and grade may be "Not disclosed",
    so a reviewer in a small class can stay unidentifiable.
16. **Import points:** answered — each president and secretary gets +4 per imported record.
17. **Unapproved after 15 days:** answered — the link is hidden from everyone, the contributor
    included, and earns nothing.
