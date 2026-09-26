# Course-requirement gaps — Goa and Hyderabad disciplines

Source: *Different course requirements.pdf* (105 pp.), semester-wise nominal charts for
each first-degree programme. Every course code in the chart for the 17 disciplines
offered at Goa/Hyderabad was diffed against `lib/course.dart`.

Method: `pdftotext -layout`, course codes matched as `PREFIX Fnnn`, compared per
discipline code. The app carries the pre-2023 first-year scheme (`MATH F111/F112`,
`PHY F110/F111`, `CHEM F110/F111`, `BIO F110/F111`, `ME F110`) alongside the current one
— those are not gaps, they support older batches.

> **Nothing in this report is a removal.** Old courses stay in the map exactly as they
> are: students on older batches still need them to reproduce their past semesters, and
> deleting a row would silently change the CGPA of anyone who has a grade against it.
> Every item below is an *addition*, except §5, which is a display fix that also keeps
> both rows.

**42 distinct courses are missing, across 122 discipline slots.**

---

## 1. Systematic gaps — affect almost every discipline

| Code | Title | Units | Missing from |
|---|---|---|---|
| BITS F412 | Practice School-II | 20 | **all 17** |
| BITS F421T | Thesis | 16 | 16 (all but B5) |
| MATH F102 | Linear Algebra and Complex Variables | 3 | 16 (all but A1) |
| ECON F211 | Principles of Economics | 3 | 15 |
| MGTS F211 | Principles of Management | 3 | 15 |

These four rows are the bulk of the problem.

**PS-II / Thesis is the serious one.** The app has `BITS F221` (Practice School I) but
neither `BITS F412` (20 units) nor `BITS F421T` (16 units). A final-year student cannot
enter the single largest course of the degree, so their credit total is short by 16–20
units and the CGPA denominator is wrong. The chart also lists two more thesis variants
that are worth supporting, `F425T` (18–20) and `F424T` (Thesis 9 + electives, 15–18).

**ECON F211 / MGTS F211 is an either/or slot** — the chart prints them as alternatives.
The app has both, but only under `B3`. Every other discipline is missing the slot
entirely. Adding both and letting the student pick one matches the chart; adding both as
required would inflate the denominator.

---

## 2. Environmental and Sustainability Engineering (AJ) — effectively absent

`AJ` has 15 rows in `course.dart`, all common core. **29 of its 41 charted courses are
missing**, including the entire discipline core.

| Code | Title | Units |
|---|---|---|
| ENVS F211 | Hydraulics & Fluid Mechanics | 3 |
| ENVS F212 | Environmental Chemistry and Biotechnology | 3 |
| ENVS F221 | Water and Wastewater Treatment and Management | 3 |
| ENVS F222 | Transport Phenomena for Environmental Systems | 3 |
| ENVS F223 | Material Science and Engineering for Sustainability | 3 |
| ENVS F224 | Sampling and Analytical Techniques for Pollutants | 3 |
| ENVS F311 | Environmental Modelling | 3 |
| ENVS F312 | Air Pollution Control | 3 |
| ENVS F313 | Digital Sustainability | 3 |
| ENVS F314 | Environmental Engineering Lab | 3 |
| ENVS F321 | Sustainability Policies and Measures | 3 |
| ENVS F322 | Solid and Hazardous Waste Management | 3 |
| ENVS F323 | Sustainable Urban Design and Smart Cities | 3 |
| ENVS F324 | Environmental Economics and Governance | 3 |
| CHE F211 | Chemical Process Calculations | 3 |
| BITS F240 | Introduction to Environmental & Sustainable Systems Engineering | 3 |
| BITS F225 | Environmental Studies | 3 |
| BITS F112 | Technical Report Writing | 2 |
| BITS F221 | Practice School I | — |
| MATH F102, MATH F211, ECON F211, MGTS F211, PHY F102, BITS F113, BITS F114, BITS F218 | (see §1 and §4) | |

Requirement footer: **Discipline Core 48 units / 16 courses; Discipline Electives 12
units / 4 courses.**

AJ also has three either/or first-year pairs the chart makes explicit, which no other
programme in the app uses: `MATH F101` **or** `BITS F113`, `MATH F102` **or**
`BITS F114`, `PHY F101` **or** `PHY F102`.

---

## 3. Electronics and Computer Engineering (AC) — no current first-year scheme

`AC` has only the pre-2023 first year. All 13 current-scheme first-year courses are
missing: `BIO F101`, `BITS F101`, `BITS F102`, `BITS F103`, `BITS K101`, `CHEM F101`,
`MATH F101`, `MATH F102`, `PHY F101`, plus `ECON F211`, `MGTS F211`, `BITS F412`,
`BITS F421T`. Its `ECOM F*` discipline core is complete.

A student admitted to AC in 2023 or later has no correct first year to select. Note AC
is **Goa only**.

---

## 4. Per-discipline one-offs

| Discipline | Missing | Title | Units |
|---|---|---|---|
| A3 EEE | ME F344 | Engineering Optimization | 2 |
| A3 EEE | MATH F212 | Optimization | 3 |
| AA ECE | ECE F314 | Electromagnetic Fields & Waves | 3 |
| AD Math & Computing | BITS F221 | Practice School I | — |
| B7 Semiconductor & Nanoscience | SNS F214 | Fundamentals of Solid State Devices | 3 |
| B7 | SNS F244 | Nanomaterials | 3 |
| B7 | BITS F112 | Technical Report Writing | 2 |
| A5 B.Pharm. | MATH F101, MATH F102, PHY F101 | current first-year scheme | 3 each |
| A1, AD, AJ | MATH F211 | Mathematics III | 3 |

`AD` missing `BITS F221` is a data error rather than a curriculum change — every other
B.E. discipline has it.

---

## 5. Separate bug found while diffing

`course.dart` contains **32 rows with a lowercase `l` instead of a digit `1`** in the
course id:

- `BITS F10l` × 16 (should be `BITS F101`, Social Conduct)
- `BITS K10l` × 16 (should be `BITS K101`, Physical Well-being and Creativity)

These sit alongside the correctly-spelled rows, so 16 disciplines carry each of those two
courses **twice**. Both are 1-unit, and `BITS K101` is starred (non-credit) in the chart,
so the CGPA impact is small — but they show as duplicates in the course list and will
double-count credits if both are graded.

**Do not delete the typo'd rows.** Anyone who has already graded `BITS F10l` would lose
that grade, and the key is what their stored data is keyed on. Handle it at the display
and counting layer instead: normalise `l` → `1` when matching, treat the pair as one
course, and keep both rows in the map.

---

## 6. Suggested order

1. `BITS F412` / `BITS F421T` (+ `F425T`, `F424T`) for all 17 — largest correctness impact.
2. The `BITS F10l` / `BITS K10l` duplicates — normalise on read, keep both rows.
3. `ECON F211` / `MGTS F211` as a mutually exclusive pair, 15 disciplines.
4. `MATH F102` where missing, 16 disciplines.
5. AJ discipline core — 16 new `ENVS` rows plus the either/or first-year pairs.
6. AC current first-year scheme.
7. The §4 one-offs.

Items 1, 3 and 5 introduce **alternative courses** (either/or slots), which the current
`Course` model has no way to express — every row is unconditionally required. That needs
a model change, not just data, and should be settled before the rows are entered.
