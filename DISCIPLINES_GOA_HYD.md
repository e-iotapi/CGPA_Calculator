# Programmes offered at Goa and Hyderabad

Filtered from the current BITS Pilani admissions programme list, restricted to the
**K K Birla Goa** and **Hyderabad** campuses. Pilani-only programmes are excluded.

Codes are from the official Programme Codes table. The "in app" column says whether the
code is present in `degreelist` in [script.dart](lib/script.dart) and whether
[course.dart](lib/course.dart) actually carries CDC rows for it.

## Single degree — Goa

| Code | Programme | In app |
|---|---|---|
| A1 | B.E. Chemical | ✔ full |
| A3 | B.E. Electrical & Electronics | ✔ full |
| A4 | B.E. Mechanical | ✔ full |
| A7 | B.E. Computer Science | ✔ full |
| A8 | B.E. Electronics and Instrumentation | ✔ full |
| AA | B.E. Electronics and Communication | ✔ full |
| AC | B.E. Electronics and Computer Engineering | ✔ full |
| AD | B.E. Mathematics and Computing | ✔ full |
| AJ | B.E. Environmental and Sustainability Engineering | ⚠ code only — common core, no branch courses |
| B1 | M.Sc. Biological Sciences | ✔ full |
| B2 | M.Sc. Chemistry | ✔ full |
| B3 | M.Sc. Economics | ✔ full |
| B4 | M.Sc. Mathematics | ✔ full |
| B5 | M.Sc. Physics | ✔ full |
| B7 | M.Sc. Semiconductor and Nanoscience | ✔ full |

## Single degree — Hyderabad

| Code | Programme | In app |
|---|---|---|
| A1 | B.E. Chemical | ✔ full |
| A2 | B.E. Civil | ✔ full |
| A3 | B.E. Electrical & Electronics | ✔ full |
| A4 | B.E. Mechanical | ✔ full |
| A5 | B.Pharm. | ✔ full |
| A7 | B.E. Computer Science | ✔ full |
| A8 | B.E. Electronics and Instrumentation | ✔ full |
| AA | B.E. Electronics and Communication | ✔ full |
| AD | B.E. Mathematics and Computing | ✔ full |
| AJ | B.E. Environmental and Sustainability Engineering | ⚠ code only — common core, no branch courses |
| — | B.E. Pharmaceutical Engg. | ✘ no code in the programme-codes table |
| B1 | M.Sc. Biological Sciences | ✔ full |
| B2 | M.Sc. Chemistry | ✔ full |
| B3 | M.Sc. Economics | ✔ full |
| B4 | M.Sc. Mathematics | ✔ full |
| B5 | M.Sc. Physics | ✔ full |
| B7 | M.Sc. Semiconductor and Nanoscience | ✔ full |

## Differences between the two campuses

| Programme | Goa | Hyderabad |
|---|---|---|
| A2 B.E. Civil | — | ✔ |
| AC B.E. Electronics and Computer | ✔ | — |
| A5 B.Pharm. | — | ✔ |
| B.E. Pharmaceutical Engg. | — | ✔ |

Everything else is common to both campuses.

## Dual degree pairs

The app stores a dual degree as the M.Sc. code followed by the B.E. code, e.g. `B3A7`
= M.Sc. Economics + B.E. Computer Science. Any of the six M.Sc. codes may pair with any
B.E. code on the same campus. `A5` (B.Pharm.) is a standalone first degree, not a dual half.

- **Goa** — 6 M.Sc. × 9 B.E. = **54** pairs
- **Hyderabad** — 6 M.Sc. × 9 B.E. = **54** pairs

## Codes valid elsewhere but not at Goa or Hyderabad

| Code | Programme | Where |
|---|---|---|
| A9 | B.E. Biotechnology | not in the current offerings anywhere |
| AB | B.E. Manufacturing Engineering | Pilani only |
| C2 | M.Sc. General Studies | Pilani only |

These should not be selectable on a Goa or Hyderabad profile. `A9` and `AB` are in the
app's `degreelist` today and need gating by campus; `C2` is absent and can stay absent.

## Codes in the official table that the app does not have

None of these appear in the user's current offerings list for any campus, so they are
listed for completeness rather than as work to do:

| Code | Programme |
|---|---|
| AE | B.E. Architectural and Urban Engineering |
| AF | B.E. Chemical with specialization in Energy, Environment and Sustainability |
| AG | B.E. Mechanical with specialization in Aerospace |
| AH | B.E. Biotechnology with specialization in Applied Molecular Biology |
| AI | B.E. Biomedical Sciences and Engineering |
| B6 | M.Sc. Physics with specialization in Space Science and Technology |
| C5 | M.Sc. Engineering Technology |
| C6 | M.Sc. Information Systems |
| C7 | M.Sc. Finance |
| C8 | Bachelor of Business Administration (Honours) |

## Open items

1. **AJ has no branch courses.** `course.dart` carries only the 16 common-core rows for
   `AJ`; the Environmental and Sustainability CDC list still has to be entered, or an AJ
   student's CGPA denominator will be wrong.
2. **B.E. Pharmaceutical Engg. has no code** in the programme-codes table as supplied.
   It cannot be added until the code is known.
3. **Campus gating does not exist yet.** `campuslist` (`Pilani` / `Goa` / `Hyd`) and
   `degreelist` are independent — every code is offered on every campus in the current UI.
   The tables above are the mapping needed to fix that.
