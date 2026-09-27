# UI.md — building Pointer's UI from the UI Directions boards

This file is the build spec for every screen in the **UI Directions** artifact
(`https://claude.ai/artifact/K4H9w2Ad9cwdTqxPSAiWMW`, canvas version 67). Write the UI from
this file. Where this file and a board disagree, the board wins, unless this file gives the
departure and the reason. Where a board and ARCHITECTURE.md §13–16 disagree about behaviour,
ARCHITECTURE.md wins. PLAN.md is retired; don't read it.

- **Part 1**: how to work (§1), foundations (§2) and shared components (§3). **§3.30 lists
  six global fixes (G1–G6) that break many screens at once; do them before any screen.**
- **Part 2**: every board, screen by screen, in canvas order (§4–§10). Each screen gives its
  file, its layout from top to bottom with sizes and copy, its states, its behaviour (tap,
  hold, drag, swipe), its tests, and its current status.
- **Part 3**: build order, the definition of done, and the log of what is already built (§11–§13).
- **Part 4** (second audit, 27 Sep 2026): new findings N1–N30 (§15), every board → Dart file
  (§16), every reachable screen → board (§17), the route check (§18), redundant code (§19),
  and **the task cards to build from (§20)**. A builder starts at §20.

Numbers are CSS px on a 390 × 844 board, which is the same as Flutter logical px. "Ink" is
`#17170F`, "mint" is `#B4DED0`, "ground" is `#F2F2EF`.

---

## 1 · How to work

### 1.1 Reading a board
- Read the artifact with the Artifact tool (`action: read`, `path: project/<Board>.dc.html`).
  The canvas notes in `project/canvas.json` are part of the spec: each board has one
  coloured note describing it, and some also have a grey **BEHAVIOUR** note.
- Boards are static HTML mock-ups with inline styles. Take sizes, colours, copy and order from
  them, but take data from the app. Names such as "Siddharth", "Dr. R. Menon" and "CS F372"
  are sample content.
- Boards drawn taller than 844 (Marks 1060, Settings 1030, Stats 980…) are scrolling screens
  drawn out in full. Build them as one scroll view.
- Boards are drawn in light mode only, except Main/DarkMain and Offshoot/DarkOffshoot. Every
  other screen uses the same layout on the dark palette (§2.1).

### 1.2 The loop, per group
1. Pick the next group from §11. Re-read its boards and notes; the user edits the canvas live.
2. Build each screen with the tokens (§2) and shared widgets (§3). Don't put colours or sizes
   inline when a token exists; add a token when one is missing.
3. Write or adjust its widget tests (§12). Include the screenshot test that uses
   `test/helpers/shots.dart`.
4. Compare the screenshots with the board at 390 and 320, light and dark. Fix anything that
   differs, or record the difference in the screen's **Departures** line with a reason.
5. Run `flutter analyze` (7 existing infos are expected) and `flutter test`. Run
   `cd test/rules && npm test` too when rules or storage changed.
6. Add the screen's **Built** entry to §13, then commit locally, staging specific files only.
   The user pushes and deploys.

### 1.3 Repository rules that bind UI work
- **Never commit** `test/fixtures/transcript.csv`, `test/fixtures/performance_sheet.json` or
  any `*.pdf`. Leave `idthp`, the screenshots and the `PLAN.md` change untracked.
- The user's email stays out of code and docs.
- Run `dart format` only on new files, or on files that were already formatted at HEAD. The
  legacy files use CRLF and a different style, and formatting them rewrites the whole file.
  Use `scratchpad/fmt.sh`, which checks this.
- Widget tests must not trigger Hive writes through the UI; they stall under fake time. Test
  storage in unit tests. Where a UI test must save, wrap the tap in `t.runAsync`, as
  `marks_test.dart` does.
- Don't touch the auth code for the iPhone `redirect_uri_mismatch` issue.
- Tooling: `export PATH="$HOME/development/flutter/bin:$PATH"` (Flutter 3.47.5, Dart
  language 3.7). Run `source ~/.nvm/nvm.sh` before the rules tests. There is no Chrome on
  this machine, so the live check uses the user's deployed site in the built-in browser.

### 1.4 Checking a screen
- **Screenshots**:
  `SHOTS_DIR=<dir> flutter test <test>`.
  - `shoot(t, name, () => Screen(...))` renders light and dark at 390 × 844 and 320 × 640,
    at DPR 2, with the real Montserrat. It fails on any overflow.
  - Pass `sizes:` to draw a scrolling board full length, e.g. `('390', Size(390, 1060))`.
  - Pass `textScale: 2` to check 200% text.
- **Live**: the user's deployed build in the built-in browser. The pane is about 309 px wide,
  which makes it a free narrow-phone check. Navigate with
  `history.pushState({}, '', '/calculator/<path>'); dispatchEvent(new PopStateEvent('popstate', {state: {}}))`.
- **Old devices**: there is no real CPU throttling. As an approximation, run a
  requestAnimationFrame loop that burns about 12 ms per frame, and log frame times while
  scrolling or animating. Nothing on a screen should drop frames except the first build.

---

## 2 · Foundations

All of these already exist. Colours live in `AppPalette` (`lib/app/theme/palette.dart`, a
`ThemeExtension` that code reads with `AppPalette.of(context)`). Sizes, radii, motion and type
live in `lib/app/theme/tokens.dart`.

### 2.1 Colour roles

| Role | Light | Dark | Used for |
|---|---|---|---|
| `background` | `#F2F2EF` | `#0D0D0C` | page ground |
| `surface` | `#FFFFFF` | `#1C1C1A` | cards, rows, circle buttons |
| `surfaceSunken` | `#F2F2EF` | `#262622` | wells in a card: credit badge, the Reviews chip |
| `text` | `#17170F` | `#F4F4EF` | primary text |
| `textMuted` | `#5E5E54` | `#BDBDB2` | captions, eyebrows, secondary numbers |
| `divider` | `#EBEBE4` | `#2A2A26` | hairlines, chart grid, slider track |
| `outline` | `#D6D6CD` | `#3A3A34` | unselected pills and inputs |
| `icon` | `#45453C` | `#D8D8CD` | icons and labels on outlined pills |
| `inverse` / `onInverse` | `#17170F` / `#F6F6F2` | `#F4F4EF` / `#0D0D0C` | selected pill, primary button |
| `hero` / `onHero` / `onHeroMuted` | `#B4DED0` / `#17170F` / `#24564A` | `#CDE8C8` / `#14210F` / `#14210F` | the one mint card per screen, the selected nav item |
| `navBackground` / `navIcon` | `#17170F` / `#B0B0A4` | `#1C1C1A` / `#ADADA2` | nav pill and rail |
| `ahead` / `behind` | `#1F5240` / `#8A4B2A` | `#7FC9A8` / `#E0A272` | class-average deltas (with an arrow and a word, never colour alone) |
| `accent` | `#1F5C4D` | `#CDE8C8` | links (`a` colour on the boards) |
| `noticeTone` | fill `#FAEFD8`, text `#7A5410` | fill `#3B2F16`, text `#F1C77A` | the amber notice (§3.10) |
| `mutedTone` | `#ECECE6` / `#6E6E63` | `#232320` / `#ADADA2` | ungraded chips, "ALL n" badges |

**Colours on the boards with no role yet.** Add these as palette roles when a screen first
needs them; never hard-code them.
- **Faint text** — `#84847A` light, `#9C9C92` dark, lifted to `#ADADA2` where it must read.
  Used for dropped parts, chart axis labels and disabled captions.
- **Dashed outline** — `#C6C6BC` light, `#3A3A34` dark: ungraded and excluded cards (with
  `DashedOutline`).
- **Translucent fills** — `rgba(255,255,255,0.55)` over the ground for a "not counted" card.
  Write it as `surface.withValues(alpha: .55)`.
- **Mint wash** — `#E4F2EC` fill with `#1F5240` text, for an official value in an input.
  `#DCEFE6` fill with `#1F5240` text, for a "BEST n/m" badge.
- **Chart** — actual line ink; forecast `#7BB8A4`, dashed 6/5; target `#C77D4A`, dashed 5/4.
- **Offshoot / Logo yellow** — `#F2E7A8`, an accent on ink (the rail logo, headings on ink).

**Grade tones** (`AppPalette.gradeTone(letter)`):
- Light:
  - A `#CDE8D8`/`#1F5240`
  - A- `#DBEBDF`/`#29614C`
  - B `#E4E9F2`/`#33445E`
  - B- `#EDE7F5`/`#4A3372`
  - C/C- `#F4EBD3`/`#6B5217`
  - D/E/NC `#F6E2D6`/`#8A4B2A`
  - anything else: the muted tone
- Dark: the lifted versions in `palette.dart`.

**Dark mode is one design with two palettes.** DarkMain and DarkOffshoot are the only dark
boards. Every grey is lifted a step (`#9C9C92 → #BDBDB2`, `#8E8E84 → #ADADA2`). Dark
differences to reproduce:
- Numbers on stat cards are weight 800 (700 in light).
- The nav pill has a 1 px `divider` border.
- The hero card is `#CDE8C8` with `#14210F` text.

DarkMain also draws a few sizes a touch smaller than Main: an 18 px gutter, 38 px credit
badges and 40 × 32 grade chips. **Departure**: one set of sizes for both modes (the light
ones). A theme switch must not reflow the page.

### 2.2 Type — Montserrat (`TypeScale.family = 'MontserratFull'`, bundled)

| Token | Size / weight / tracking / line | Used for |
|---|---|---|
| `display` | 38 / 700 (800 dark) / −1.6 / 1.05 | stat-card numbers |
| `title` | 25 / 700 / −0.7 / 1.1 | the home name, top-level screen titles |
| (page title) | 22 / 700 / −0.7 / 1.12 | pushed-screen titles (`PageHeader`) |
| `editorial` | 23 / 500 / −0.6 / 1.24 | the home summary sentence (bold span 800) |
| `section` | 15 / 700 / −0.3 | "8 courses", "Plan the rest" (14.5 on Stats) |
| `body` | 13.5 / 600 / 1.25 | row titles, input text |
| `button` | 13 / 500 | pill labels (selected 700) |
| `gradeChip` | 14.5 / 700 | grade chips |
| `label` | 11 / 700 / +0.4, upper case | card eyebrows: SGPA, SECURED SO FAR |
| `caption` | 11 / 500 | secondary lines |

**Smaller sizes on the boards.** When one of these repeats, add it as a token rather than
writing it at the call site:
- 12.5/700: nav label, card headings
- 10.5/500: captions inside cards
- 10/500: sub-captions
- 9.5/700 +0.4: field labels ("COMPONENT NAME")
- 8.5/700: column heads
- 7.5/600: credit-badge "CRED"

**Rules:**
- Never `TextScaler.noScaling`; every screen must survive 200% text at 320 px.
- Ellipsize every single-line label; wrap multi-line copy.
- Numbers in a column use tabular figures only where they align (the scores on Marks).

### 2.3 Space, radii, sizes (`tokens.dart`)
- **Space**: xxs 2, xs 4, sm 8, md 12, lg 16, xl 20, xxl 24, xxxl 32. The gutter is 20; the
  boards use 18 on dense screens (Marks, Edit evaluative).
- **Radii**:
  - check 7
  - chip 12
  - badge 14
  - row 22: course rows
  - card 26: stat cards, chart
  - hero 30
  - nav 33
  - Also on the boards, to add as tokens: 20 (evaluative rows, section cards, sheets) and
    16 (notices, small cards, the "Taken by" strip).
- **Sizes**:
  - minTouch 44
  - iconButton 46: header circle buttons
  - pill 36: semester pills
  - pillSmall 34: section-row pills
  - gradeChip 42 × 34
  - creditBadge 40
  - nav 66, navItem 50
  - Also on the boards: 48 primary button, 38 count pills and segmented tabs, 30 chevron
    buttons, 28 tag chips.
- **Motion**:
  - fast 120 ms, base 220 ms, slow 380 ms
  - `easeOutCubic` in, `easeInCubic` out
  - Route change is the circle reveal (`circle_reveal.dart`).
  - Every animation is transform or opacity only, and stops under `MediaQuery.disableAnimations`.

### 2.4 Icons
The boards draw Lucide-style 24-grid stroke icons (stroke 2, round caps). Use the closest
Material rounded icon:

| Board icon | Material |
|---|---|
| calendar | `Icons.calendar_today_rounded` |
| stats (axes + line) | `Icons.show_chart_rounded` |
| moon / sun | `Icons.dark_mode_outlined` / `Icons.light_mode_outlined` |
| settings (gear) | `Icons.settings_outlined` |
| back arrow | `Icons.arrow_back_rounded` |
| close ✕ | `Icons.close_rounded` |
| plus | `Icons.add_rounded` |
| sort (three bars) | `Icons.sort_rounded` |
| export (tray + down) | `Icons.download_rounded` |
| pencil | `Icons.edit_outlined` |
| copy | `Icons.copy_rounded` |
| house | `Icons.home_rounded` |
| bars (Expected) | `Icons.bar_chart_rounded` |
| diagonal arrows (Compare) | `Icons.open_in_full_rounded` |
| medal (Offshoot) | `Icons.workspace_premium_outlined` |
| three dots (More) | `Icons.more_horiz_rounded` |
| chevron › | `Icons.chevron_right_rounded` |
| arrow up / down (delta) | `Icons.arrow_upward_rounded` / `Icons.arrow_downward_rounded` |
| info ⓘ (notice) | `Icons.info_outline_rounded` |
| grad cap (Taken by) | `Icons.school_outlined` |
| search | `Icons.search_rounded` |
| star | `Icons.star_rounded` / `Icons.star_border_rounded` |
| ⋯ on a resource | `Icons.more_horiz_rounded` |
| link / external | `Icons.link_rounded` / `Icons.open_in_new_rounded` |
| drag handle | `Icons.drag_indicator_rounded` |

The **Pointer mark** is Logo concept 04 "Tassel", already `lib/shared/widgets/pointer_mark.dart`:
a flat cap rhombus `M24 9l16 8-16 8-16-8z`, a tassel stroke `M40 17v11` at 3.4, and a dot at
(40, 33) r 4.4. The cap body is drawn at 32% opacity only at large sizes. Colour ink on ground,
mint or `#F2E7A8` on ink.

### 2.5 Layout and responsiveness (board `Responsive`, ARCHITECTURE §15)

**Breakpoints**, from `LayoutBuilder` constraints (`lib/shared/layout/breakpoints.dart`), never
from a device guess:

| Width | Layout |
|---|---|
| compact < 720 | one column; nav is the floating pill |
| medium ≥ 720 | stat cards move to a right rail (120 → 190 px wide); the course list takes the gained width; the pill centres at max 420 |
| expanded ≥ 1100 | the pill becomes a 96 px left rail (Pointer mark on top); the body caps at 1180 and centres |

**Rules:**
- Heights are fixed or intrinsic, never a fraction of the viewport; widths flex.
- Every row is `Expanded` plus ellipsis, and every fixed element is non-shrinking. Nothing
  overflows at 320 px wide and 200% text.
- Pushed screens (`PageFrame`) cap at 640 wide and centre.
- **Safe areas** come from `SafeArea` and `MediaQuery.padding`, never hard-coded. The boards
  keep 56 px clear at the top and float the bar 44 px off the bottom.

**Floating bars (§16.4).** A floating bar sits over the scroll view. The last item pads by
`MediaQuery.paddingOf(context).bottom`, which `Scaffold(extendBody: true)` sets to the bar's
height. Under the bar is a plain gradient from transparent to `background` (stop 0.6); it
ignores pointers.

### 2.6 Performance (old phones and laptops)
- No `BackdropFilter`, no blur, no `saveLayer`: no `Opacity` over a subtree, `ShaderMask` or
  `ClipPath` with antialiasing on large areas. Translucency is colour alpha, and fades are
  plain `LinearGradient`s.
- One scroll view per screen; lists longer than a screen use builders or slivers.
- Wrap charts and anything that repaints alone (sliders, the grade wheel) in a `RepaintBoundary`.
- No layout work in `build` beyond a `TextPainter` measure where a fit decision needs it
  (always merge `DefaultTextStyle.of(context).style`).
- Hive first, Firestore behind: a screen renders from local data and never waits on the network.

### 2.7 Accessibility, for every screen
- Touch targets ≥ 44 × 44. A visually smaller control, such as a 30 px chevron or a 34 px chip,
  pads its hit area to 44.
- Icon-only buttons carry a tooltip, which is also their semantics label.
- Text contrast is ≥ 4.5 : 1. Colour is never the only signal: deltas have an arrow and a word,
  and dropped parts have a "DROPPED" word.
- Grouped content is a `Semantics(container)` with one readable label. Reordering exposes
  Move up / Move down custom actions.
- `prefers-reduced-motion` (`MediaQuery.disableAnimations`) stops every looping animation.

---

## 3 · Shared components

The boards reuse a small set of parts. Most secondary boards define them as CSS classes
(`.card`, `.lbl`, `.pill.on/.off`, `.sc`, `.tier`, `.row`, `.hr`, `.note`, `.field`, `.src`).
Build each part once in `lib/shared/widgets/` and use it everywhere.
**Exists** = already in the code; **New** = to write.

| # | Part | Spec from the boards | Widget |
|---|---|---|---|
| 3.1 | **Circle icon button** | 44 round (46 in the Home header), `surface` fill, 17–20 px icon in `text`. Tooltip = semantics label | `CircleIconButton` — exists |
| 3.2 | **Page header** | Eyebrow 11/700 +0.4 upper case `textMuted`; title 22/700 −0.7, max 2 lines; actions, then the Back (or Close ✕) circle button on the right. Setup screens: eyebrow 11/700 +0.5, title 27/800 −1 | `PageHeader` — exists. Add a `close` variant (✕, tooltip "Close") for sheets such as Edit evaluative |
| 3.3 | **Card** (`.card`) | `surface`, radius 20, padding 13/15, column gap 10 | `AppCard` — exists (default radius 22: pass 20) |
| 3.4 | **Card label** (`.lbl`) | 10.5/700 +0.5 upper case `#6B6B60` (≈ `textMuted`) | `FieldLabel` — exists, but its padding is for forms. Add `CardLabel` with no padding |
| 3.5 | **Pill** (`.pill.on/.off`) | 36 tall, radius 18, padding 0 14, 12.5 px. On: ink fill, `onInverse` 700. Off: transparent, 1 px `outline`, `icon` 600. Setup uses 38 tall | `PillButton` — exists (selected = on) |
| 3.6 | **Mint count pill** | 38 tall, radius 19, `hero` fill, 700: the selected "Best 2 of 3" | New: `PillButton(tone: hero)` |
| 3.7 | **Segmented pair** | Two equal buttons 44 tall, radius 14. Selected ink, other outlined (One mark / Several parts). Stats' Progression / Degree tabs are the pill form at 38 | New: `SegmentedPair` |
| 3.8 | **Scope chip** (`.sc`) | 26 tall, radius 13, padding 0 10, `hero` fill, 11/700, optional 12 px icon (Goa, ELEC · A3, 2023 batch) | New: `ScopeChip` |
| 3.9 | **Tier / source badge** (`.tier`, `.src`) | 22 (or 20) tall, radius 11, 10/800 (9.5/800) +0.3 upper case. Tones: OFFICIAL mint-wash, YOURS amber, UPDATED mint, FROM PARTS neutral, DROPPED faint | New: `TagBadge(tone)` |
| 3.10 | **Notice** (amber) | `noticeTone` fill, radius 16 (13 on setup), padding 9/12, ⓘ 14 px icon, then 10–10.5/500 text, 1.45 line, with a bold key phrase | New: `Notice` (Marks already draws one inline; move it here) |
| 3.11 | **Hero (mint) card** | `hero` fill, radius 20–24, padding 13–17. Eyebrow 10.5/700 `onHeroMuted`, big number 19–36/800. One per screen | Inline per screen; share `HeroCard` if a third copy appears |
| 3.12 | **Stat card** | Radius 26, padding 16/16/14. Label, 38 number, caption. Hero or surface | `StatCard` — exists |
| 3.13 | **Row** (`.row` + `.hr`) | 46–54 tall list row inside a card: leading badge or icon, title (12.5–13/600–700, ellipsis), trailing value or chevron. 1 px `divider` between rows, inset 13 | New: `CardRow` + `CardDivider` |
| 3.14 | **Code badge** | 38 × 28–30, radius 9–10, 12–12.5/800. Neutral `#F0F0EA`/`#45453C`; selected ink with mint text; first degree mint | New: `CodeBadge` |
| 3.15 | **Credit badge** | 40 × 40, radius 14, `surfaceSunken`: number 15/700, then "CRED" 7.5/600 | in `course_row.dart` — exists |
| 3.16 | **Grade chip** | ≥ 42 × 34, radius 12, 14.5/700, grade tone; ungraded shows "–" in the muted tone. Hit area 44 | `GradeChip` — exists |
| 3.17 | **Delta** | Arrow 9 px, stroke 3.4, then "4.2 behind" / "12.5 ahead" 10/700, in `behind`/`ahead` | in `course_row.dart` — exists |
| 3.18 | **Field** (`.field`) | 46 tall, radius 14, `background` fill (inside a card) or `surface` (on the ground), 1 px `outline`, padding 0 14, 13/600. Its label sits above as 9.5–10/700 +0.4 upper case | `AppTextField` — exists (labels float inside). Add a `labelAbove` style for board forms |
| 3.19 | **Compact field** | 36 tall, radius 11, `#F8F8F5` fill, centred 12/700: the part grid on Edit evaluative. An official value becomes a mint-wash box (value 12/800, plus "OFFICIAL" 7.5/800) | New |
| 3.20 | **Search box** | 46 tall, radius 23, `surface`, 16 px search icon, then placeholder 13/500 in faint text | New: `SearchBox` |
| 3.21 | **Primary button** | 48 tall (56 on sign-in and setup), stadium, ink, `onInverse` 13.5–15/700, optional leading icon. Disabled: ink at 40% | `PrimaryButton` — exists (add a `tall` variant, 56) |
| 3.22 | **Outlined button** | 42 tall, radius 21, 1.5 px ink border, 12.5/700 ink, optional trailing icon | New |
| 3.23 | **Dashed card** | Radius 20, 1 px dashed `#C6C6BC`, fill `surface` at 55%: an ungraded evaluative, an excluded semester, the 2+2 pill | `DashedOutline` — exists |
| 3.24 | **Bottom action over a fade** | The CTA pinned 44–76 px above the safe bottom, over a 118–150 px gradient to `background` (stop 0.58–0.62), with an optional 10.5 caption under it | New: `BottomAction` (the same fade as the floating nav) |
| 3.25 | **Nav pill / rail** | See Group 1 (§13) | `AppNav` — exists |
| 3.26 | **Checkbox** | 20 px, ink when on; the label is the semester | Material `Checkbox` themed |
| 3.27 | **Slider** | 6 px track in `divider`, ink fill, an 18 px white thumb with a 2.5 ink ring | themed `Slider` with `_RingThumb` — exists in `progression_view.dart` |
| 3.28 | **Star rating** | 5 stars, filled ink or mint, 18–22 px; input stars 44 hit | New (Reviews group) |
| 3.29 | **Strip** (role / offline) | Full-width, 32–36 tall. Offline: neutral. "Viewing as": ink with mint text and a Back action | `OfflineStrip` — exists; role strip new |

Build a part when the first screen needs it, with a screenshot test in `test/ui/`.

### 3.30 Global fixes found by the audit — do these before any screen group
These show up on many screens at once. Each is small, and fixing it first makes every later
screenshot comparison meaningful.

**G1 · The Material theme is always light, and has no font** (`AppPalette.materialTheme`,
`lib/app/theme/palette.dart:108`). It is `ThemeData(colorScheme:
ColorScheme.fromSeed(seedColor: accent))`, with no brightness, no text colour and no
font family. So:
- **In dark mode, any `Text` without an explicit colour draws near-black on the dark
  surface.**
  - Seen live on Controls (every row title invisible), President home, Course structures,
    Representatives (course names), Course reviews (course names), Resources (programme
    names, "No resources here yet"), Owners (names), Public contact (switch label, the
    preview).
  - `NavRow`'s title (`lib/admin/widgets.dart:95`) is the most common case.
- **Material buttons (`TextButton`, `OutlinedButton`, `FilledButton`, `FilterChip`) fall
  back to the platform font.** Seen live: "Draft a change to a course", "Change", "Add",
  "Pick from department resources", "Volunteer", "Find your representatives" all render
  in Roboto. In widget tests the same labels draw as boxes.
- **Fix**: build the theme per palette, with:
  - `brightness: isDark ? Brightness.dark : Brightness.light`
  - `ColorScheme.fromSeed(seedColor: accent, brightness: …)`, overriding `surface`,
    `onSurface`, `primary` from the palette
  - `fontFamily: TypeScale.family`
  - `textTheme` / `primaryTextTheme` `.apply(bodyColor: text, displayColor: text)`
  - `scaffoldBackgroundColor: background`
  - button themes whose `textStyle` uses `TypeScale.button`
- **Tests**: a dark screenshot of Controls in which every row title is readable; a
  `TextButton` label in `MontserratFull`.

**G2 · `ChoicePills` and `TierTag` stretch to the full width** (`lib/admin/widgets.dart`).
A `Container` with `alignment` inside a `Wrap` grows to the widest constraint. Seen live
on:
- Course reviews: Courses / Your reviews.
- Maintainers: All / Goa / Hyd / Pilani / Expiring.
- Roster: two tab rows.
- Merge professors: campuses.
- Appoint: tiers.
- Public contact: WhatsApp / Phone / Email.
- Course structures: All / No scheme.
- Owners, Terms: OWNER / CR / PRESIDENT / ADMIN tags.

Fix: `Center(widthFactor: 1, heightFactor: 1)` around the label, or no `alignment`. Then
add the `equal` layout (`Row` of `Expanded`) for tab rows (§10.1.2).

**G3 · Unknown routes show GoRouter's raw error page.** `/admin/roster/volunteers` is in
`Routes` (`routes.dart:33`) but not registered in the router. It shows "Page Not Found —
GoException: no routes for location" in red Roboto with yellow underlines. Fix:
- Register the route, opening Roster on its Volunteers tab.
- Add an `errorBuilder` that shows a `PageFrame` with "This page doesn't exist" and a
  Home button.

**G4 · Raw backend errors are shown as text with no Material ancestor.** Department →
Reviews (`/maintain/goa/CS/reviews`) shows "That did not work: [cloud_firestore/
failed-precondition] The query requires an index. You can create it here: https://…"
in yellow-underlined text, full screen. Two fixes:
- **Add the missing composite index** to `firestore.indexes.json`: the one the Reviews
  moderation query needs. Take the fields from the query in `lib/admin/dept_reviews.dart`
  and the link in the error. The user deploys it.
- **Show errors with the shared `Note`** inside the screen's `PageFrame`: a short sentence
  ("Reviews couldn't load. Try again.") with a Retry button. Log the detail with
  `debugPrint`; never draw a console URL.

**G5 · A non-BITS owner never gets their roles.** See §10.0.

**G6 · Amber vs mint badges.** Count badges for **work waiting** are amber (`noticeTone`):
"12" courses without a scheme, "3" reported reviews, "14" changes to publish. The live
President home shows "58" in mint. Mint badges are only for a state that's on ("ON").

---

# Part 2 — Screens

Each screen has these parts:
- **Board**: the board file and its size.
- **Code**: where the screen lives.
- **Layout**: top to bottom.
- **Behaviour**: what each control does.
- **Audit**: what the current build shows, and how it was seen.
- **Fixes**: the numbered work to reach the board.
- **Status**, one of:
  - ✅ **Correct**: matches the board; nothing to do.
  - 🟡 **Built locally**: matches in code on `pointer-bits-pilani.pages.dev`'s next deploy, but
    the live site is older.
  - 🔧 **Fix**: the listed fixes are needed.
  - ⬜ **Missing**: not built at all.

**How each screen was audited (27 Sep 2026).**
- The live site (`pointer-bits-pilani.pages.dev`) runs `master` at `3061a67`, which is
  `1c6f0c0` plus the merge: the build from **before** commit `fd3f390`. It still shows labels
  under every nav icon and has no Add pill. Where the local code is newer than the live site,
  the audit says so. The manager screens are identical to the live site (§14).
- Screens that need a signed-out or first-run account (Sign in, setup, import) can't be
  reached live without signing the user out. They were rendered from the current code with
  a temporary screenshot test at 390 × 844, light and dark, with the real fonts.

**Status at a glance** (details in each section):

| Status | Boards |
|---|---|
| ✅ Correct | Landing 4.1 · GradeMenu 6.1 (label fix) · Offshoot 8.1 (checkbox fix) · DarkOffshoot 9.2 · Logo 9.4 |
| 🟡 Built locally, not deployed | Main 4.7 · Calendar 6.4 · Stats 7.1 (axes fix) · StatsDegree 7.2 (names, order) · Settings 7.3 (discipline label) · DarkMain 9.1 · Responsive 9.3 (768 strip scroll) |
| 🔧 Fix | Loading 4.2 · SignIn 4.3 · Discipline 4.4 · DisciplinePick 4.5 · Import 4.6 · Marks 5.1 · MarksSetup 5.3 · Diverged 5.5 · AverageSources 5.6 · AddCourse 6.2 · AddManual 6.3 · More 8.2 · Representatives 8.3 · every Reviews board 8.4–8.10 · Resources, ReportLink, ResourcesEmpty 8.11–8.13 · every manager board 10.2–10.22 (Publish copy already matches) |
| ⬜ Missing / rebuild | MarksAdd 5.2 (rebuild) · the scheme editor 5.4 · OwnerSetup for owners 10.21 · the RosterVolunteers route (G3) |
| Blocking | 10.0 non-BITS owner roles (G5) |

## 4 · Row 1 — Getting in

### 4.1 Landing — `Landing` 1280 × 900 · ✅ Correct
- **Code**: `landing/index.html`: static HTML served at the site root, not Flutter, and crawlable.
- **Layout**:
  - Nav:
    - 40 ink tile holding the mint mark, then "Pointer" 19/800.
    - Right: "BITS Pilani · Goa · Hyderabad · Dubai" 13/500, then an "Open app" ink pill
      (42 tall, radius 21).
  - Hero:
    - Eyebrow "FOR BITS STUDENTS" 11.5/700 +1.2 in `#2C7A62`.
    - H1 62/500 −2.6 in `#6B6B60`: "Your pointer," then "and everything behind it." at 800 ink.
    - Paragraph 15.5/500, max width 430.
    - A 52 tall "Continue with Google" button, then "Free, and works offline once it loads."
  - A 300 × 430 phone mock-up of Home.
  - Four feature cards (radius 22, padding 20, 36 icon tile): Forecast, Marks, Offshoot, Calendar.
  - Footer: "Built By Siddharth Mishra" 11.5/800 left; "Grades stay on your device and in
    your own account." right.
- **Behaviour**:
  - Every button opens `/calculator/`.
  - An installed app that lands on `/` goes straight into the app.
- **Audit** (live, 1280 wide): same structure and the same copy word for word. Dark mode and
  breakpoints (1000 / 760 / 480) exist in the CSS.
- **Fixes**: none.

### 4.2 Loading — `Loading` 390 × 844 · 🔧 Fix
- **Code**: `web/index.html` `#ptr-loading`: pure CSS, painted before Flutter boots, and faded
  out on `flutter-first-frame`.
- **Layout**, centred column, padding 0 32:
  - A 96 px mark that floats (translateY −6 px, 3.2 s), with a tassel that swings ±11°
    around (40, 17), 1.9 s.
  - Wordmark: "Point" 34/800 plus "er" 34/400 `#45453C`, −1.4.
  - Tagline 13.5/500 `#55554C`, max width 270, 30 below.
  - A 148 × 4 bar (`#E2E2DA`) with a 34% `#2C7A62` sweep, 1.5 s.
  - "Loading" 11.5/600 `#6E6E63` with three 3 px dots fading in turn (0 / .18 / .36 s).
  - Footer, 40 from the bottom and centred:
    - "Built By Siddharth Mishra" 11.5/700 ink.
    - "Your grades stay private to your account." 10.5/500 `#6E6E63`, 14 below.
    - Then the SEO `h1` 11.5/600 `#8A8A7E` and paragraph 10.5/500 `#9E9E92`.
  - `prefers-reduced-motion` stops all three animations and shows the bar full at 45%.
- **Audit** (source): the mark, wordmark, tagline, bar, dots, motion and SEO block all match.
  The footer's first two lines are missing.
- **Fixes**:
  1. In `.ptr-seo`, before the `h1`, add `<p class="ptr-by">Built By Siddharth Mishra</p>` and
     `<p class="ptr-private">Your grades stay private to your account.</p>`, styled as above.
     Keep the dark-mode variables.

### 4.3 Sign in — `SignIn` 390 × 844 · 🔧 Fix
- **Code**: `lib/features/auth/sign_in_view.dart`; test `test/auth/sign_in_test.dart`.
- **Layout**, padding 56 (safe top) / 26 sides:
  - A 60 × 60 radius-20 ink tile with the mark, 32 px.
  - 30 gap, then "Pointer" 52/800 −2.4, line 0.98.
  - 14 gap, then the pitch 15/500 1.5 `#55554C`.
  - 22 gap, then four feature lines, 8 apart. Each is a 32 × 32 radius-11 white tile with a
    16 px icon, then 13/500 `#45453C`. The fourth tile is **mint**, with its text 600 ink:
    "Import every past semester from your ERP sheet".
  - 12 gap, then a dashed note: 1 px dashed `#C6C6BC`, radius 16, padding 10/13, a 15 px
    `accent` icon, and 11/500 text.
  - **Flexible space**, so the action sits at the bottom on any height.
  - "Continue with Google": 56 tall, stadium, ink. A 26 px ground-coloured circle holds a
    "G" 14/800 in `accent`; the label is 15/600.
  - 14 gap, then "Use your BITS campus ID — Pilani, Goa, Hyderabad or Dubai." 11/500
    centred `#6B6B60`.
  - 10 gap, then two lines 10.5/500 centred: "Your grades stay private to your account." and
    "Reviews you write never carry your name."
  - 8 gap, then "Built By Siddharth Mishra" 11/700 ink.
- **Behaviour**:
  - Button → Google sign-in (a popup, or a redirect on an iPhone home-screen app). While busy,
    a spinner replaces the G and the button is disabled.
  - What follows sign-in: a first sign-in goes to setup, later ones to Home; someone newly
    appointed goes to Before you start.
- **Audit** (local render): the mark, title, pitch, features and dashed note all match. Three
  differences:
  - The whole column is **vertically centred**, leaving about 130 px above the mark, and the
    button follows the note directly instead of sitting at the bottom.
  - The **two privacy lines** are missing.
  - The **Built By** footer is missing.
- **Fixes**:
  1. Replace the `Center` around the column with `Align(topCenter)`. Give the column
     `ConstrainedBox(minHeight: c.maxHeight)` so its `Spacer` pushes the button to the
     bottom. Top padding: `Space.xxl` inside the SafeArea, which is about 56 with the status
     bar.
  2. Under the campus line, add the two privacy lines (10.5/500 `textMuted`, centred), then
     "Built By Siddharth Mishra" (11/700 `text`).
  3. Test: at 390 × 844 the button's bottom is within 120 px of the screen bottom, and both
     privacy strings are present.

### 4.4 Set up your degree — `Discipline` 390 × 844 · 🔧 Fix
- **Code**: `lib/features/setup/degree_setup_page.dart` (it replaces the legacy
  overlays_extension screen); test `test/setup/setup_test.dart`.
- **Layout**, padding 56/20, gap 11:
  - Header:
    - "ONE-TIME SETUP" 11/700 +0.5.
    - "Your degree" 27/800 −1.
    - 12.5/500 lead: "Campus and batch come from your BITS address and are fixed. One
      question left: what you are reading."
  - **From your sign-in** card:
    - `.lbl` "FROM YOUR SIGN-IN".
    - The address, 12.5/600 `#45453C`, ellipsized.
    - Two **scope chips** (3.8): 32 tall, radius 16, mint, 13 px icon plus 12/700 — a
      map-pin "Goa" and a calendar "2023 batch".
  - **Programme** card:
    - `.lbl` "PROGRAMME".
    - Pills, 38 tall: "Single degree" (on), "Dual degree" (off, **outlined, transparent**),
      "2+2" (dashed `#C6C6BC`, `#9A9A8F` text, 600).
    - Below them an **amber notice** (3.10, radius 13, padding 9/11, 14 px icon): "2+2
      programmes are still being built. Pick the degree you are reading and add your courses
      by hand for now — nothing else about the app changes."
  - **What you are reading** card:
    - `.lbl` "WHAT YOU ARE READING".
    - One row per degree, 46 tall: a **code badge** (38 × 30, radius 10, 12.5/800), then an
      eyebrow 9.5/700 ("FIRST DEGREE" / "SECOND DEGREE") over the name 13/700 (ellipsized),
      then a 17 px chevron `#84847A`.
    - The first degree's badge is mint with ink text; the second's is ink with mint text.
    - A 1 px divider between rows.
  - **This adds** (mint, radius 20, padding 13/15):
    - Left: "THIS ADDS" 10.5/700 `onHeroMuted`, then "48 core courses across 10 semesters"
      13/700.
    - Right: "226" 19/800 plus " credits" 11/700.
  - **Bottom action** (3.24): a 132 tall fade, then a 56 tall ink button
    "Set up B3 A7" 14.5/700, 76 from the bottom. Under it, 44 from the bottom:
    "Changing your first degree later clears your grades." 10.5/500 centred.
- **States**:
  - Nothing picked: the badge is an empty dashed 38 × 30, the name reads "Choose a
    programme", and the button reads "Pick what you are reading" and is disabled.
  - Single degree: one row, eyebrow "YOUR PROGRAMME".
  - An h or p address: no single/dual question.
  - An address with no campus or batch (a non-BITS owner): the Owner setup screen instead (§10).
- **Behaviour**:
  - Tap a pill: sets single or dual.
  - Tap 2+2: shows the notice and changes nothing.
  - Tap a degree row: Pick a programme.
  - Tap the button: seeds the courses and goes to Import.
- **Audit** (local render): the header, the sign-in card and the programme card are close.
  Differences:
  - The scope chips have **no icons** and are about 28 tall.
  - **"Dual degree" is a grey filled pill** where the board has an outlined one.
  - The 2+2 notice is **bare orange text** with no amber box or icon.
  - The empty programme row has **no code badge**.
  - The button sits **inline under the card**, 52 tall, rather than pinned at the bottom over
    a fade; the caption also scrolls with the content.
  - "This adds" appears only after a pick (correct).
- **Fixes**:
  1. Use `ScopeChip` (3.8) with `Icons.place_outlined` and `Icons.calendar_today_rounded`,
     32 tall.
  2. Programme pills: `PillButton` at height 38, on/off exactly as 3.5. 2+2 is a
     `DashedOutline` pill.
  3. Put the 2+2 message in `Notice` (3.10).
  4. Degree rows: a `CodeBadge` (mint for the first, ink for the second; dashed and empty
     when unset), eyebrow over name, and a chevron. `CardDivider` between rows.
  5. Pin the button with `BottomAction` (3.24): a 56 tall `PrimaryButton.tall`, with the
     caption under it. The scroll view pads its bottom by the action's height.
  6. Test: at 320 × 640 and 200% text there is no overflow, and the button stays on screen.

### 4.5 Pick a programme — `DisciplinePick` 390 × 844 · 🔧 Fix (small)
- **Code**: `lib/features/setup/programme_pick_page.dart`.
- **Layout**:
  - Header row: a 44 Back circle, then eyebrow "SECOND DEGREE · GOA" 10.5/700 over the title
    "Pick a programme" 19/700 −0.5.
  - **Search box** (3.20): "Code or name — A7, mechanical…".
  - One card (radius 20) listing rows 52 tall with padding 0 13:
    - A code badge 38 × 28 (radius 9, `#F0F0EA`/`#45453C`, 12/800).
    - The name 12.5/600, ellipsized.
    - The semester count "10 sem" 10.5/600 `#6B6B60`.
    - Dividers inset 13.
    - **Selected** row: 54 tall, mint fill, badge ink with mint text, name 800, a 15 px
      check in `ahead`.
    - **AJ**: 58 tall, top-aligned, with a second line 10/600 `#9A6510` "Common core only —
      branch courses not in the list yet".
  - Footer note 10.5/500: "Nine programmes run at Goa. A2 Civil, A5 B.Pharm. and
    Pharmaceutical Engineering are Hyderabad only — change campus to see them."
- **Behaviour**:
  - Typing filters by code or any word of the name.
  - Tapping a row returns it and pops.
  - Back pops with nothing chosen.
- **Audit** (local render): matches the board, including the row sizes, badges, selected row
  and AJ line.
- **Fixes**:
  1. Check that the list for the *second* degree of a dual holds only the B.E. (A-series)
     programmes that the board shows. The render listed B1–B4 M.Sc. under "SECOND DEGREE"
     only because the temporary test passed every Goa programme, so confirm with a test on
     the real call in `degree_setup_page.dart`.

### 4.6 Import from ERP — `Import` 390 × 870 · 🔧 Fix
- **Code**: `lib/features/import/erp_import_page.dart`, with the preview in
  `import_preview.dart`. Install lives in `settings/install_guide.dart`.
- **Layout**, padding 56/20, gap 12:
  - Header:
    - "SETUP · 2 OF 2" eyebrow.
    - "Bring your grades in" 27/800 −1.
    - A 44 Back circle.
  - Lead 12.5/500: "Pointer reads your ERP **performance sheet** and fills in every semester
    you have already done." One sentence; drop the extra line.
  - **How to get it** card (padding 14/15, gap 11):
    - Three steps, each a 20 px ink number disc (10.5/800) plus 12.5/500 text, with the
      menu path in 700.
    - Then an **outlined button** (3.22): "Open My Academics in ERP", ↗ icon, 42 tall, 1.5
      ink border, 12.5/**700**.
  - **Drop zone**: 2 px dashed `#9CC9BA`, fill `hero` at 34%, radius 22, padding 16, centred
    column, gap 7:
    - A 44 white tile (radius 15) with an upload icon.
    - "Drop your performance sheet" 14/700.
    - "or choose a file · PDF" 11.5/500 `onHeroMuted`.
    - A lock icon 12 plus "Read on your device · never uploaded" 10.5/600 `accent`,
      **inside** the zone.
  - **What it fills in** card: `.lbl`, then two 12/500 lines.
  - **Install card**: **ink** fill, radius 20, padding 12/14:
    - A 36 mint tile (radius 12) with an install icon.
    - "Install Pointer" 12.5/700 `#F4F4EF` over "Own icon, full screen, works offline"
      10.5/500 `#B0B0A4`.
    - A **mint** "Install" button, 36 tall, 12/700.
    - The card grows to 1.035 and the button shakes (±6°) once every 4.5 s. Both are off
      under reduced motion, and the whole card is hidden once the app is installed.
  - **Bottom action**: a 118 fade, "Skip — I will enter grades myself" 13/700 `#45453C`
    centred 70 from the bottom, then "You can import any time from Settings → Your data."
    10.5/500 at 44.
- **Behaviour**:
  - Open My Academics: opens SIS in a new tab.
  - Drop zone: tap to pick a file, or drop a PDF on the web. It shows the import preview
    (what is created, changed, left alone) and nothing is saved before confirming.
  - Install: `promptInstall()` where supported, otherwise the install guide.
  - Skip: finishes setup and goes to Home.
- **Audit** (local render): the header, steps and "What it fills in" match. Differences:
  - The lead has an extra sentence.
  - The ERP button text is 500, not 700.
  - The drop zone reads "Choose your performance sheet / Works in the web app", with the
    privacy line **outside** the zone and a darker border.
  - The install card is **white** with a black button and different copy ("Keep Pointer on
    your home screen"), and it has no nudge animation.
  - Skip scrolls at the end instead of being pinned, and it has no "import any time" caption.
- **Fixes**:
  1. Trim the lead to the board's sentence.
  2. ERP button → `OutlinedButton` (3.22).
  3. Drop zone: the board's copy on the web ("Drop your performance sheet / or choose a file
     · PDF"; on a phone, "Choose your performance sheet / PDF"). Move the lock line inside,
     and set the border and fill as specified.
  4. Install card: ink card, mint tile, mint button, board copy. Add the nudge as an
     `AnimationController` (4.5 s repeat) driving `Transform.scale` and `Transform.rotate`:
     no rebuild of the subtree, and off when `MediaQuery.disableAnimations` is set.
  5. `BottomAction` with Skip and the caption. In Settings mode (no `onDone`) there is no
     Skip; the page pops when done.
  6. Tests: the nudge controller is not running under `disableAnimations`; Skip calls
     `onDone`; no overflow at 320 and 200%.

### 4.7 Home — `Main` 390 × 844 (and `DarkMain`) · 🟡 Built locally
- **Code**:
  - `lib/features/semester/semester_page.dart` (`SemesterView`)
  - `widgets/course_row.dart`, `semester_pills.dart`, `grade_menu.dart`, `grade_scrubber.dart`
  - `lib/shared/layout/responsive.dart` and `lib/shared/widgets/app_nav.dart`
  - `lib/home_page.dart`, the legacy host
- **Layout**, padding 56/20, gap 15:
  - Greeting row:
    - "Good evening" 12.5/500 `textMuted` over the name 25/700 −0.7.
    - Four 46 circle buttons, 8 apart: Calendar, Stats (line chart), theme (moon in light,
      sun in dark), Settings.
  - Editorial line (`editorial`) with an 800 ink span: "This semester you are **1.46 above**
    your running CGPA."
  - Two stat cards on flex-basis 0, 11 apart:
    - SGPA: hero; "24 credits · 4-1".
    - CGPA: surface; "158 credits".
  - Semester strip: the pills (36 tall; selected ink 700, others outlined 500) in a clipped
    horizontal scroller, then two 30 px round chevron buttons. The left one is at 40% and
    disabled at the start.
  - Section row: "8 courses" (`section`), then the pills **+ Add** (ink, 34), **Credits**
    sort (outlined, sort icon) and **Export** (34 round, download icon).
  - Course rows, 9 apart:
    - Surface card, radius 22, padding 13/15.
    - A credit badge.
    - Title 13.5/600 (up to 2 lines), then the code 11/500 `textMuted` with a **delta**
      (3.17) when the course has marks.
    - Grade chip.
  - A floating nav pill over a 150 tall fade.
- **Behaviour**: see the grey BEHAVIOUR note on the board. In short:
  - Tap a row: Marks.
  - Tap the chip: grade menu. Hold the chip: grade wheel.
  - Drag the handle: reorder (sort becomes Custom).
  - Pull down past 60 px and hold 1 s: clear the semester (Actual and Expected).
  - Swipe: change profile.
  - Compare: tap a stat card to pick its profile.
- **Audit**:
  - **Live**: the nav shows **labels under every icon**; there is no **+ Add** pill; the
    Stats icon is a boxed bar chart.
  - All three are fixed locally in `fd3f390`:
    - The selected nav item is a mint stadium with its label; the others are 50 px icons.
    - The Add pill is in the section row, and the dashed add card appears only when the
      semester is empty.
    - The Stats icon is `show_chart`.
    - Compare uses the diagonal arrows.
    - The pill floats over a fade.
  - The rest matches the board: header, editorial line, stat cards, semester strip with
    chevrons, sort and export pills, credit badges, and grade chips (ungraded "–" muted).
- **Departures**:
  - A drag handle, 22 wide, sits left of each row. The board has none; reordering needs it,
    and it is the only way to reach Custom order.
  - One size set for light and dark (§2.1).
- **Fixes**: none beyond deploying `fd3f390`. After the deploy, check on the live site that
  the pill's fade covers the last row, and that the semester strip scrolls the selected pill
  fully into view: the live strip clips a pill at its **left** edge, where the board clips on
  the right.

## 5 · Row 2 — Marks

All six screens share one header: eyebrow `"<CODE> · <n> CREDITS"` (11/700 +0.4, upper case,
`textMuted`) over the course title 22/700 −0.7, with 44 px circle buttons on the right. The
gutter is 18 on Marks and Edit evaluative, 20 on the rest. **Common fix**: the code writes
"3 credits" in lower case; write the whole eyebrow in upper case, as the boards do.

### 5.1 Marks — `Marks` 390 × 1060 (scrolls) · 🔧 Fix (small)
- **Code**: `lib/features/marks/marks_page.dart`, `widgets/evaluative_card.dart`,
  `widgets/taken_by.dart`, `widgets/divergence.dart`.
- **Layout**, padding 56/18, gap 12:
  1. Header. Two circle buttons, 8 apart: **pencil** (17 px, tooltip "Edit the official
     scheme"), then **Back**.
  2. **Taken by** strip: surface, radius 16, padding 9/13, gap 10. Grad-cap icon 15, then a
     column: "TAKEN BY · 2026-27 SEM 1" 9.5/700 +0.4 `#6B6B60`, and the professor 12.5/700
     (ellipsis). On the right a **Reviews** chip: 28 tall, radius 14, padding 0 11,
     `surfaceSunken` fill, 10.5/700 ink. Hidden when no professor is set. Read-only: the CR
     or president sets it.
  3. **Hero**: mint, radius 24, padding 15/17, content bottom-aligned with the grade chip.
     - "SECURED SO FAR" 10.5/700 `onHeroMuted`.
     - "11.36" 36/800 −1.6, then "/ 45" 15/600 `onHeroMuted`, on one baseline.
     - "45% of the course graded · 55% pending" 10.5/500 `onHeroMuted`.
     - Above a 1 px ink-13% rule (9 px top margin): an arrow 11 + "1.56 ahead of the class"
       12/800; a 5 px bar (ink-13% track, ink fill at your share, a 2 × 11 ink-45% tick at
       the class share); "You 11.36 · class average 9.80 · **edit**" 10/600, a link to
       Course setup.
     - A 26 px chip (ink-9% fill, tune icon 11, "Weighted · out of 100" 10/700): opens
       Course setup.
     - Grade chip on the right: min 42 × 34, radius 12, ink fill, mint 17/800.
  4. Averages line, padding 0 4: "class avg 9.80 · official" 10.5/600 `textMuted`, and on
     the right "Averages ›" 11/700 `accent` (min 32 tall) → Average sources.
  5. Evaluative rows, 7 apart (see 3.13 and the board):
     - Surface, radius 20. The tappable part (padding 10/0/10/14) holds the name 13/700,
       the caption 10/500 `textMuted` ("2 parts · class avg 5.10"), a count badge ("ALL 2"
       muted; "BEST 2/3" mint-wash `#DCEFE6`/`#1F5240`, 9.5/700, radius 9), the weight
       10.5/600, and the score 14/800 right-aligned in 40 px.
     - A 44 px **Duplicate** button (copy icon 16 `textMuted`) on every row, graded or not.
     - A group row expands to its parts: a 4 px dot, the name 11.5/500, "8 / 10". A
       dropped part has a dashed hollow dot, faint text and "· DROPPED" 9.5/700.
     - Ungraded ("not yet"): 55% surface with a 1 px dashed `#C6C6BC` border, name in
       `#55554C`, "—" 11.5/600.
     - After diverging, a row can carry a `.src` badge: **YOURS** (ink / `onInverse`),
       **UPDATED** (mint), **NOT OFFICIAL** (`#EFEFE9` / `#55554C`), between the name and
       the weight (board `Diverged`).
  6. Amber notice (3.10): "Changing a component's **weight, out of, average or date** makes
     it yours: …".
  7. **Add evaluative**: primary 48, plus icon 15.
- **Behaviour** (grey note `b_Marks`):
  - Back → Home. Pencil → the scheme editor (§5.4).
  - Taken by › Reviews → the course's reviews.
  - The hero chip and the "edit" link → Course setup. Averages › → Average sources.
  - A row → Edit evaluative. Duplicate → a copy with the next name (Quiz 1 → Quiz 2), the
    same weight, parts and Best-of rule, and no marks, dates or averages.
  - "Use the official …" (after diverging) → reattaches that component.
- **Audit**:
  - **Live** (CS F301, old build): no pencil; the Taken-by row is a plain line with a text
    button; evaluative rows use the older layout.
  - **Local** render (`marks_light.png`): hero, averages line, rows, count badges, dropped
    part, dashed ungraded rows and the Duplicate buttons all match the board.
- **Fixes**:
  1. Upper-case eyebrow (common fix).
  2. **Pencil always shown.** Today it appears only when the legacy host passes
     `onEditCourse`, and it opens the old course card. Point it at the scheme editor (§5.4),
     tooltip "Edit the official scheme". Keep the old card (credits, delete) reachable from
     the scheme editor.
  3. **Taken by**: rebuild `taken_by.dart` as the strip above (surface r16, cap icon, two-line
     label, 28 px `surfaceSunken` Reviews chip padded to a 44 hit area). Replace the
     `TextButton`.
  4. Add "· **edit**" to the class-average caption in the hero, as a link to Course setup.
  5. **UPDATED** badge: the code only has YOURS and NOT OFFICIAL (`marks_page.dart:139`).
     Add UPDATED for a component whose official values changed since the student last
     opened the course and that is not detached. It clears when the course is opened again.
  6. Test: extend `marks_test.dart` with the pencil route, the Reviews chip and the three
     badges.
- **Departure**: at 390 the captions "4 dated parts · no class avg yet" wrap to two lines
  (the badge is wider in Montserrat than on the board). Keep the wrap; don't ellipsize,
  because 200% text must stay readable.

### 5.2 Edit evaluative — `MarksAdd` 390 × 990 (scrolls) · ⬜ Rebuild
- **Code**: `lib/features/marks/add_evaluative_page.dart` (681 lines). One screen adds and
  edits. The board note says: "The built app still has the older layout: build this one."
- **Layout**, padding 56/18, gap 10:
  1. Header, centred vertically: eyebrow "CS F372 · EDIT COMPONENT" ("ADD COMPONENT" when
     new); the component's name as the title (22/700, "New component" when empty). On the
     right: a **Bin** circle (editing only, tooltip "Delete component") and a **Close** ✕
     (17 px).
  2. **Amber notice**, only when the component is official, above the first field: "**Official
     component.** Your marks are always yours. Changing the weight, an out of, a date or an
     average makes this component yours, and it stops updating."
  3. **Card** (surface, r20, padding 12/14, gap 9):
     - "COMPONENT NAME" 9.5/700 +0.4 `#55554C` over a 40 tall input (r11, `#F8F8F5`, 1 px
       outline, padding 0 12, 13.5/600).
     - A row, bottom-aligned, gap 10: "WEIGHT" over a 60 × 40 input 13.5/700 plus "%"
       13/700 `icon`; then "CLASS AVERAGE" (flex) over either a typeable 40 tall input, or
       a mint-wash box (`#E4F2EC`, r12, "12.40" 13.5/800 `#1F5240` and "of 20 · from parts"
       or "of 20 · official" 10/600 `#2C7A62`) when it's derived or published.
     - Total-marks courses: the WEIGHT field reads "OUT OF" and has no "%".
  4. **Card**, shape:
     - `SegmentedPair` (3.7): **One mark** / **Several parts**, 44 tall, r14.
     - With parts: "HOW MANY COUNT", then 38 px pills: "All 3", "Best 2 of 3", "Best 1 of 3".
       Selected = mint count pill (3.6).
     - With one mark: a row of "YOU", "OUT OF", "DATE" compact fields instead.
  5. **PARTS card** (several parts only), gap 8:
     - Column heads: "PARTS" (flex, 9.5/700) then "DATE" 52, "YOU" 36, "OUT OF" 36, "AVG"
       46, each 8.5/700 `#6B6B60`, centred.
     - Each part is two lines, 6 apart:
       - Line 1: the name input (flex, 36 tall, r11, 12/600), a **Duplicate** 36 button (copy
         16), and a **Remove** 36 button (✕ 15; shown only with three or more parts).
       - Line 2: "PART n" 9.5/700 faint (flex), then the compact fields (3.19): date 52
         (10.5/600, "8 Sep"), you 36, out of 36, and the average 46. A published average is
         the mint-wash box: value 12/800 over "OFFICIAL" 7.5/800, tooltip "Published by the
         CR".
       - A dropped part: every field has a 1 px dashed `#C6C6BC` border, `#FAFAF7` fill and
         faint text.
     - Footer row: the caption 10/500 `#6E6E63` ("Averages fill in by themselves when the CR
       publishes them. Concurrency is dropped. The copy button adds the next part below.")
       and a **+ Part** pill: 36 tall, r18, 1 px dashed `#B6B6AC`, 11.5/600.
  6. **Live result**, mint, r20, padding 11/15: "THIS COMPONENT GIVES YOU" 10/700 over
     "best 2 of 3 · class 12.40" 10.5/500 (`onHeroMuted`); on the right "14.0" 24/800 −1 and
     "/ 20" 12/600.
  7. **Save**: primary 48.
- **Behaviour** (`b_MarksAdd`):
  - Close: leaves without saving. Bin: deletes; an official component asks first.
  - One mark / Several parts: switches the shape (the parts are kept in memory until Save).
  - How many count: All N or Best k of N.
  - Part date: a date picker; a × inside the field clears it.
  - Duplicate (every part): inserts a copy right below, with the next name and the same out
    of, and blank marks, date and average.
  - ✕ (with three or more parts): removes that part. + Part: a blank part.
  - Typing anywhere updates the live result.
  - Save: stays disabled until the name, the weight and every out of are filled.
  - Changing an official weight, out of, date or average asks once with the divergence
    sheet (§5.4) on Save.
- **Audit (live, old build and local code)**: floating labels inside each field, "Save
  evaluative" as the button label, a bin in the body, a text preview "all counted → 12 of
  21…", no cards, no segmented pair, parts as a single wide row, no live-result card.
- **Fixes**: rebuild the page to the layout above, keeping `_PartFields` and the save logic.
  1. Header with the close variant of `PageHeader` and the Bin.
  2. Notice, then the three cards, built from `CardLabel`, the `labelAbove` field and the
     compact field (3.18, 3.19).
  3. `SegmentedPair` and mint count pills.
  4. The two-line part row, with Duplicate on every part and the dashed dropped style.
  5. The mint live-result card; delete the text preview.
  6. "Save" (not "Save evaluative").
  7. Tests: shape switch, Best k of N, duplicate part inserts below with blank marks, remove
     hidden under three parts, Save disabled until filled, and a shot at 390 × 990 and
     320 at 200% text.

### 5.3 Course setup — `MarksSetup` 390 × 970 (scrolls) · 🔧 Fix
- **Code**: `lib/features/marks/course_setup_page.dart`.
- **Layout**, padding 56/18, gap 12. Every section is a surface card, r22, padding 14:
  1. Header: "CS F342 · 4 CREDITS" / "Course setup", with a **Close** ✕ (42 px).
  2. **HOW THIS COURSE IS GRADED** (9.5/700 +0.4 `#55554C`): two equal buttons, 46 tall,
     r14, each two lines: "Weighted" over "each part has a %", and "Total marks" over "one
     big total" (12.5 title; 9.5/500 caption). Selected is ink with a `#B0B0A4` caption;
     the other is outlined.
  3. Card (Total marks only first line): **COURSE IS MARKED OUT OF**, an 86 × 40 input
     (r12, `#F8F8F5`, 14/700) with "Your evaluatives add up to 300 marks." beside it
     (10.5/500). Then **SHOW IT OUT OF**: 38 px pills "100", "200", "300", "Custom" —
     selected mint (3.6). Custom opens an 86 px input in place. Note: "Marks stay entered
     exactly as your instructor gives them. Only the display is rescaled."
  4. **RIGHT NOW** mint card, r22, padding 15/17: two numbers 25/800 −1 ("247" / "of 300
     entered", "82.3" / "shown out of 100", captions 10/600 `onHeroMuted`) with a 22 px arrow
     between them, then "247 × 100 ÷ 300. The same factor is applied to every component."
     10/500.
  5. **EACH COMPONENT'S SHARE** card: one row per component, gap 8: name 12/600 (with
     "· best 8 of 11" 500 muted), "160 / 200" 11.5/500 muted, and the share 12.5/800
     right-aligned in 46 px. A divider, then "Total" 700 · "247 / 300" · "82.3" 13.5/800.
  6. **CLASS AVERAGE** card: an 86 × 40 input with "For the **components that have happened
     so far** — not the whole course." beside it; then a mint-wash strip (`#EAF4EF`, r14,
     padding 10/12): arrow 13 + "You are **1.56 ahead** · 11.36 against 9.80" 11.5/600
     `ahead`; then "Leave it blank and the comparison simply does not appear." 10/500.
  7. **Save setup**: primary 48.
- **Audit (local render `audit_setupcourse_light_390.png`)**:
  - No cards: every section sits on the ground.
  - The grading choice is two pills, and "Weighted · each has a %" is cut to "Weighted ·
    each h…" at 390.
  - The selected "show out of" pill is ink, not mint, and Custom is a text field, not a pill.
  - "RIGHT NOW" is one line in a white card, not the mint card with two big numbers.
  - No EACH COMPONENT'S SHARE card and no CLASS AVERAGE card (the code comment says the
    average is entered on Marks).
  - A back arrow, not a close ✕.
- **Fixes**:
  1. Wrap each section in a surface card (r22, p14) with `CardLabel` headings.
  2. Replace the grading pills with the two-line `SegmentedPair` (46 tall).
  3. Mint selected pills; Custom as a pill that reveals an 86 px input.
  4. The mint RIGHT NOW card with two numbers and an arrow.
  5. Add EACH COMPONENT'S SHARE from the existing marks maths (each share from the
     component's own out of, never a fixed divisor).
  6. Add CLASS AVERAGE, writing the same stored value that Average sources calls "Your
     course average"; the delta strip uses arrow and word (3.17). Move the input off
     Average sources (§5.6).
  7. Close ✕, and upper-case eyebrow.
  8. Test: both modes, custom scale, share rows sum to the total, blank average hides the
     strip; shot at 390 × 970.

### 5.4 Scheme editor and first divergence — `Divergence` 390 × 844 · ⬜ Missing (sheet 🔧)
- **Code**: new `lib/features/marks/scheme_editor_page.dart`; the sheet is
  `confirmDivergence` in `widgets/divergence.dart`.
- **Scheme editor layout**, padding 56/20, gap 12:
  1. Header with **Back**.
  2. Column heads, padding 0 12: "COMPONENT" (flex), "WEIGHT" 62, "CLASS AVG" 56 (`.lbl`).
  3. One row per component, 7 apart: surface, r18, padding 8/12, gap 8.
     - Name 13/700 (ellipsis) over a tag 9.5/700 +0.3 `#6B6B60`: "OFFICIAL", "OFFICIAL ·
       EDITING", "YOURS" or "NOT OFFICIAL".
     - Weight: a 46 × 36 compact input (r11, 12.5/700, centred) + "%" 11/700.
     - Class average: a 56 × 36 compact input, placeholder "—".
     - The focused input has a 2 px ink border.
  4. (Below the rows, not on the board) the old course card's actions: credits and Delete
     course, as a plain `CardRow` list. This keeps what the pencil used to open.
- **Divergence sheet** (over a 42% ink scrim): surface, top radius 28, padding 12/20/40, gap 12.
  - A 40 × 4 handle (`outline`), "YOU ARE CHANGING AN OFFICIAL VALUE" (`.lbl`), the title
    "Make Mid Semester yours?" 19/800 −0.5.
  - Body 12.5/500, 1.5, `icon`: "Weight 25% → 30%. Official changes to **Mid Semester** will
    stop arriving and you keep it current. The other components, the credits and your own
    marks are not affected."
  - A `background`-filled box (r14, padding 10/12): "You can switch back any time with **Use
    the official version**." (`.note`).
  - Two equal buttons, 52 tall, r26, gap 8: **Keep official** (outlined) and **Make it mine**
    (ink).
- **Behaviour**: weights and averages are typeable in place. The first change to an official
  value opens the sheet once per component. Keep official restores the value; Make it mine
  detaches that component alone.
- **Audit**: the scheme editor doesn't exist (the pencil opens the old course card). The
  sheet exists but is on the `background` colour with Material's drag handle, uses the 25 px
  `title` style, colours its eyebrow with the notice tone, and shows the "switch back" line as
  plain text.
- **Fixes**:
  1. Build the scheme editor and route the Marks pencil to it (§5.1 fix 2).
  2. Sheet: `surface` fill, radius 28, own 40 × 4 handle; title 19/800; eyebrow `.lbl`; the
     "switch back" line in the grey box; 52 px buttons.
  3. Test: editing an official weight opens the sheet once; Keep official reverts; Make it
     mine tags the row YOURS and leaves others OFFICIAL.

### 5.5 After diverging — `Diverged` 390 × 844 · 🔧 Fix
- **Code**: `DivergedCard` and `UseOfficialButton` in `widgets/divergence.dart`, shown on
  Marks.
- **Layout** (on Marks, above the rows):
  1. A line, gap 7: the YOURS `.src` badge, then "Mid Semester edited by you on 19 Sep.
     Official updates to it are paused; the rest keep updating." (`.note`).
  2. When official values changed since: an amber card, r20, padding 13/15, gap 9:
     "OFFICIAL MID SEMESTER CHANGED · 2 DAYS AGO" 10.5/700 `#7A5410`; the body 12.5/600 1.45
     `#4A3408` ("The official Mid Semester is now 35%. Yours stays at 30% until you choose.
     Compre updated on its own; In-Lab Quiz left the official scheme."); two equal 40 px
     buttons: **Review** (ink) and **Keep mine** (outlined, amber 35%).
  3. The rows carry YOURS / UPDATED / NOT OFFICIAL badges (§5.1).
  4. Below the rows: "Use the official Mid Semester" 12.5/700 `accent` (min 44 tall), then
     "In-Lab Quiz holds your marks, so it stays until you clear it." (`.note`, centred) for
     a component the CR removed.
- **Behaviour**: Review opens the scheme editor with the changed component focused. Keep mine
  dismisses the notice until the next official change. Use the official … reattaches that
  one component.
- **Audit (local render `audit_diverged_light_390.png`)**: the amber card exists, but its
  heading is the generic "THE OFFICIAL SCHEME CHANGED" with no component or age; it has only
  **Keep mine** (no Review); there is no YOURS line when nothing changed (the card instead
  titles itself "YOURS"). "Use the official …" is a text button with a refresh icon.
- **Fixes**:
  1. Split the two states: the YOURS badge line (always, while detached) and the amber card
     (only after an official change).
  2. Name the component and the age in the heading; body in 12.5/600 `#4A3408`.
  3. Add **Review**; two equal 40 px buttons.
  4. "Use the official …" as a plain 12.5/700 accent link (no icon), and the removed-component
     note.
  5. Test: the notice names the component; Review routes to the editor; Keep mine hides it.

### 5.6 Average sources — `AverageSources` 390 × 844 · 🔧 Fix
- **Code**: `lib/features/marks/widgets/average_sources.dart` (`AverageSourcesPage`).
- **Layout**, padding 56/20, gap 12:
  1. Header with **Back**.
  2. "CLASS AVERAGES" (`.lbl`).
  3. One `.card` with no padding holding rows separated by an inset `.hr`. Each row, padding
     11/15, gap 10:
     - Left: the level "COURSE" / "COMPONENT" / "PART" 9.5/700 +0.4 `#6B6B60`; the name
       13/700; the source line (`.note`): "Published by your CR", "You typed this; the
       official 13.90 is not used", "Worked out from the three part averages".
     - Right, end-aligned, gap 4: the value 15/800 ("9.80", "14.20 / 25") over a `.src`
       badge.
  4. **WHICH NUMBER WINS** card (surface r20, padding 13/15, gap 8): the three badges
     joined by "then" — **YOURS** (ink / `onInverse`), **OFFICIAL** (mint / ink), **FROM
     PARTS** (`#EFEFE9` / `#45453C`) — and the note "Decided separately for the course, each
     component and each part. Clear a number you typed and the official one comes back."
- **Behaviour**: read-only. Tapping a row opens where that number is typed: the course row →
  Course setup's CLASS AVERAGE; a component or part → its Edit evaluative. (Not on the board;
  it replaces the input the page has today.)
- **Audit (local render `audit_avgsources_light_390.png`)**:
  - The value is an ink pill with no source badge; the source is only in the caption.
  - A "Your course average" input and a **Save** button sit below the card.
  - WHICH NUMBER WINS is plain bold text on the ground, not badges in a card.
- **Fixes**:
  1. Value 15/800 plain text over a `TagBadge` (3.9) for its source.
  2. Remove the input and Save (the average moves to Course setup, §5.3 fix 6); make rows
     tappable as above with a trailing chevron.
  3. WHICH NUMBER WINS as a card with the three badges.
  4. Test: each level shows the right badge for yours / official / from parts.

**Test-render note.** In the widget-test renders, the labels of Material `TextButton`,
`OutlinedButton` and `FilledButton` draw as boxes ("Keep mine", "Save"): the test theme
doesn't give buttons the bundled font. It is a test artefact, not an app bug. Build these
screens with the shared `PrimaryButton` / outlined button (3.21, 3.22), which set the family
explicitly, and the shots will read.

## 6 · Row 3 — Grades, adding courses, calendar

### 6.1 Grade menu — `GradeMenu` 390 × 844 · ✅ Correct (one small fix)
- **Code**: `lib/features/semester/widgets/grade_menu.dart`; the chip's tap handling is in
  `course_row.dart`.
- **Board**: a design note more than a screen. It fixes three things:
  - **Two targets on one row.** The row (everything left of the chip, credits tile
    included) opens Marks. The chip opens the menu and **stops the tap**: its own
    `GestureDetector` with `HitTestBehavior.opaque`. The chip is 46 × 34 and reaches 44 with
    padding.
  - **The menu**, anchored to the chip: 216 wide, surface, radius 20, padding 11, shadow
    `0 14 34` ink 18% (the one shadow in the app; cheap because it is small). "CHANGE GRADE"
    9.5/700 `#6E6E63`; a 4-column grid, gap 5, of 32 tall radius-11 cells, 13/700: A A− B B−
    / C C− D E, the current grade ink. A 1 px rule, then NC RC W GD in 11.5 `icon`, the
    caption "RC and W drop the credits from your CGPA. GD keeps them but not the points."
    9.5/500, then a full-width "Not graded yet".
  - Tapping outside closes with no change; holding the chip opens the grade wheel instead.
- **Audit (live, 309 px pane)**: matches. The menu flips above the chip when there's no
  room below, which is right. The app also offers **Ongoing** beside "Not graded yet", with
  its own caption ("Ongoing counts toward your degree, not your CGPA, until it is graded.").
- **Departure**: keep **Ongoing** (a real grade code the boards predate).
- **Fix**: at 309 px "Not graded yet" wraps to two lines inside its half-width button. Label
  it **"Not yet"** (as Add course does) with the tooltip "Not graded yet", so both buttons
  stay one line down to 280 px and at 200% text wrap cleanly.

### 6.2 Add a course — `AddCourse` 390 × 844 (sheet 700 tall) · 🔧 Fix (small)
- **Code**: `lib/features/semester/add_course_sheet.dart`.
- **Layout**: a bottom sheet over a 34% ink scrim; fill `#F6F6F2` (`onInverse` in light,
  `surface` in dark), top radius 30, padding 10/20.
  1. A 38 × 4 handle `#D2D2C8`.
  2. Title row: "Add a course" **21/700 −0.5** over "to semester 4 − 1 · Actual" 11.5/500
     `textMuted` (ellipsis); on the right a **Close** 34 px circle (`#E8E8E1`, ✕ 14 `icon`,
     44 hit).
  3. Search: 48 tall, radius 16, surface, **1.5 px ink border** when focused, search icon 16,
     the query 14/600, and "3 found" 10/600 faint.
  4. Results, 7 apart: surface, radius 17, padding 11/14. Title 13.5/700 (ellipsis), then
     "AN F311 · 3 credits · Open Elective" 10.5/500. Trailing: "+" 19/400 faint; the chosen
     one has a 1.5 px ink border and a 22 px ink tick circle. A course already in another
     semester is at 55% with "already in 3 − 2" and an "ADDED" 10/700 tag, not tappable.
  5. The chosen course expands to a **mint card**, radius 22, padding 14, gap 11:
     "SELECTED" (`.lbl` `onHeroMuted`), the title 15/700, and a **"3 cr" chip** (ink 12%
     fill, padding 4/9, radius 11, 11/700); "COUNTS AS" over a 38 tall white select (r13);
     "GRADE" over a wrap of 31 tall pills (radius 16): A…E white, NC RC W GD and "Not yet"
     at white 50%, the chosen one ink.
  6. "Not in the list? Enter it manually" 12/600 `accent`, min 32 tall.
  7. The CTA, 54 tall, **radius 19** (not a stadium): "Add to 4 − 1" 14.5/700 and "SGPA 9.17 →
     9.22" 500 mint.
- **Behaviour**: typing filters by code or name; tap a result to select it; the CTA adds
  and closes; Close or a tap on the scrim closes with nothing added.
- **Audit**: live and the local render (`add_course_light_390.png`) agree, and match the
  board in structure, copy, colours and the SGPA preview ("SGPA – → 10.00"). Differences:
  - The title uses `TypeScale.title` (25 px) instead of 21.
  - There is **no Close button**.
  - "3 cr" is plain text, not a chip.
  - The CTA is a stadium, not radius 19.
  - **Ongoing** is an extra grade pill (keep it, as in 6.1).
- **Fixes**:
  1. Title 21/700 −0.5 (add a `sheetTitle` token: it's also used by 6.3).
  2. Add the 34 px Close circle (tooltip "Close").
  3. The "3 cr" chip.
  4. CTA radius 19.
  5. Test: Close adds nothing; an ADDED course can't be picked.

### 6.3 Enter it manually — `AddManual` 390 × 844 · 🔧 Fix
- **Code**: the manual branch of `add_course_sheet.dart`.
- **Layout**: the same sheet (padding 10/20, gap 14):
  1. Handle; then a row: a **Back** 34 px circle (`#E8E8E1`, arrow 15) and "Enter it manually"
     **20/700 −0.5** over "for courses not in the BITS list" 11/500.
  2. "COURSE CODE" (`.lbl` 10/700 +0.4 `#6E6E63`): two white **filled** fields (`.fld`: 46
     tall, radius 15, white, no border, padding 0 14, 14/600): department 108 wide, number
     flex. Hint 10/500 `#8A8A7E`: "Department, then number — like AN and F311."
  3. "TITLE": a white box, min 46 tall, radius 15, padding 12/14, 14/600, 1.35 line,
     **wrapping to two lines** (never truncated or scrolled).
  4. "CREDITS": a stepper — two 42 × 42 white radius-14 buttons ("−", "+" 19/600 `icon`,
     tooltips "Fewer credits" / "More credits") with a flex white 42 tall box between them
     showing the number 17/700.
  5. "COUNTS AS": a `.fld` select with a chevron 12; the hint lists the options.
  6. "GRADE": a **6-column grid**, gap 5, of 31 tall radius-16 white cells, 12.5/600; NC RC W
     GD in `icon`; the chosen one ink 700.
  7. Amber note (radius 16, padding 11/13): "A manual course is not in the BITS list, so
     Degree progress counts it only under the category you pick here."
  8. The same CTA as 6.2.
- **Audit (live, 309 px)**:
  - The title is 25 px and wraps to **two lines** ("Enter it / manually"); the Back button is
    a large white circle.
  - Fields are **outlined** (transparent, ink border), not white-filled.
  - The credits stepper is two round buttons and a bare number.
  - Grades are outlined rounded squares about 44 tall; **"Ongoing" is squeezed into one
    grid cell** in tiny text on its own row.
  - The amber note and the "Leave it blank…" hint are fine.
- **Fixes**:
  1. Title 20/700 on one line (the `sheetTitle` token), 34 px Back circle.
  2. `.fld` style: white fill, no border, radius 15, 46 tall — add it as the `filled` style of
     `AppTextField` (on the sheet's `#F6F6F2` a border isn't needed).
  3. The stepper as three 42 tall white boxes.
  4. Grade grid of 31 tall pills; put **Ongoing** and **Not yet** on a final row as two
     half-width pills, not in a grid cell.
  5. Title field `maxLines: 2`, `minLines: 1`.
  6. Test: 320 px at 200% text, no overflow; credits stay within 0.5–20.

### 6.4 Calendar — `Calendar` 390 × 844 · 🟡 Built locally (uncommitted)
- **Code**: `lib/features/calendar/calendar_page.dart`, `calendar_controller.dart`;
  `lib/shared/widgets/offline_strip.dart`.
- **Layout**, padding 56/18, gap 13:
  1. "What is coming" 12/500 over "September 2026" 24/700 −0.7; on the right 40 px circles:
     ‹ › and (from the behaviour note) Back.
  2. Month card: surface, radius 24, padding 14/12. Weekday heads 9.5/700 faint. Day cells
     38 tall, 12.5/500 `icon`: past days faded (`#B0B0A4`, 700), today a 32 px ink disc
     (800), the next eval a 32 px mint disc, eval
     days a 4 px dot under the number.
  3. "Next up" 14.5/700 with "5 remaining" 10.5/600.
  4. Agenda rows, 8 apart: surface, radius 20, padding 12/14, gap 12. A 44 wide date column
     (day 17/800 over "SEP" 9/700), a 1 × 30 divider, then the eval 13/700 over "Operating
     Systems · CS F372" 10.5/500, and on the right the weight "15%" 10/600 — or, for the next
     one, a 1.5 px ink border and an "IN 3 DAYS" chip (`#F2E7A8`/`#4A3D0E`, 9.5/700, radius 10).
  5. Offline: a floating 54 tall strip, radius 22, white with a 1 px `#E4E4DC` border, 42 px
     above the bottom: a 30 px yellow disc with a cloud icon, "Working offline" 12/700 over
     "Everything is saved on this device · 3 changes will sync" 10/500.
- **Behaviour** (`b_Calendar`): ‹ › change month; tap a day to filter the agenda to it (tap
  again, or Show all, to clear); tap an eval → its Marks; Back → Home.
- **Audit**:
  - **Local** render (`calendar_light_390.png`) matches the board.
  - **Live** (old build): the same layout, but past days are not faded, and with no dated
    evals it shows the empty line "Dates you add to parts in Marks show up here." (keep it:
    the board has no empty state).
  - The only local change is the past-day fade (uncommitted, Group 2).
- **Fix**: none beyond committing Group 2. Check the offline strip against item 5 when it
  next appears (it is shared with Home).

## 7 · Row 4 — Stats and Settings

### 7.1 Stats · Progression — `Stats` 390 × 980 (scrolls) · 🟡 Built locally (one fix)
- **Code**: `lib/features/stats/stats_page.dart`, `stats_controller.dart`,
  `widgets/progression_view.dart`, `widgets/cgpa_chart.dart`.
- **Layout**, padding 56/20, gap 14:
  1. "Progression" 12.5/500 over "Where you land" 25/700 −0.7; Back 44.
  2. Tabs: two equal 38 tall stadium pills, "Progression" / "Degree" (on = ink 700).
  3. **Chart card**: surface, radius 26, padding 18/16/12. "CGPA by semester" 12.5/700 with
     a legend (13 × 3 swatches, 9.5/600 `#55554C`): Actual ink, Forecast `#7BB8A4`, Target
     `#C77D4A`. The chart is 170 tall:
     - Y axis: **only the whole numbers the data spans**, one grid line each, labelled
       "9.0" / "8.0" / "7.0", 8 px faint.
     - X axis: **four labels only**: the first semester, a landmark (PS1), the current one
       and the last (7.5 px faint).
     - Actual: solid ink with filled points; the current point larger with its value
       ("7.71" 9.5/700). Forecast: dashed 6/5 `#7BB8A4`, hollow points, its end value in
       `#2C7A62`. Target: dashed 5/4 `#C77D4A`, **no label on the chart** (the legend names
       it; removed at the user's request, v67).
  4. **The ask**, mint, radius 24, padding 12/12/17/18: "TO REACH 8.00" 11/700 +0.4 with −
     and + 44 px circles (ink 10%, tooltips "Lower target" / "Raise target"); "You need
     **8.66** average across your remaining **68 credits**." 20/500 −0.5; then the verdict
     11/500 `onHeroMuted`.
  5. "Plan the rest" 14.5/700 with "Tick what to forecast" 10.5/500.
  6. One card per future semester, 8 apart: surface r20, padding 13/15, gap 9. A 20 px
     checkbox + "4 - 2 · 25 credits"; "9.00" 17/800 + "SGPA" 10/600 on the right; the slider
     (3.27); "CGPA moves to **7.91**" 10.5/500. An unticked semester: 55% surface, dashed
     `#C6C6BC` border, 80% opacity in colour (not an `Opacity` widget), "Not in this
     forecast · tick to include".
  7. A floating ink bar (62 tall, radius 26, 44 off the bottom, over a 140 fade): "ON THIS
     PLAN YOU FINISH AT" 9.5/600 `#B0B0A4` over "8.10 CGPA" 19/800 mint; on the right a 34
     tall `#2C2C26` chip with an arrow and "+0.39" 11.5/700 mint.
- **Behaviour** (`b_Stats`): tabs switch view; − / + move the target by 0.10 within 4–10;
  the tick puts a semester in or out of the forecast (remembered on this device); the slider
  sets that semester's SGPA, 4–10 in 0.05 steps, and the CGPA after it updates live; the
  chart is display only.
- **Audit**:
  - **Live** (old build): no tick boxes, a "drag to adjust" caption, a y axis from 6 to 10
    with five labels, six x labels, and the target labelled on the chart.
  - **Local** (`stats_light_progression.png`, uncommitted Group 2): ticks, dashed excluded
    cards, the emphasised current point, hollow forecast points, the mint footer value and
    the removed target pill all match.
- **Fix** (local): the axes. The y axis still runs 6–10 with five labels ("6", "7"…), and
  the x axis labels every other semester. Fit y to the data's whole numbers (at least two
  lines), label them with one decimal, and label x with first / landmark / current / last
  only. Update `stats_test.dart` for the label counts.

### 7.2 Stats · Degree — `StatsDegree` 390 × 890 (scrolls) · 🟡 Built locally (two fixes)
- **Code**: `stats_page.dart` (Degree tab), `lib/core/storage/stats.dart`.
- **Layout**, padding 56/20, gap 13:
  1. "B3 A7 · dual degree" 12.5/500 over "Degree progress" 25/700; Back.
  2. The same tabs, Degree on.
  3. **Credits earned** mint card, radius 26, padding 17/18: "CREDITS EARNED"; "158" 38/800
     −1.7 + "of 226" 16/600; a 7 px bar (ink 13% track, ink fill); "Includes 40 credits of
     common core · 68 credits left" 10.5/500.
  4. "By requirement" 14.5/700.
  5. One card per requirement, 8 apart: surface, radius 18, padding 11/14, gap 7.
     - Name 12.5/700 with a muted 500 suffix ("B3 Core · CDC1"), and "38 / 48 cr" 11/700.
     - A 5 px bar (`divider` track, ink fill; complete = `#2C7A62` fill, a check icon and
       the figure in `ahead`).
     - "11 of 14 courses · 10 credits to go" 10/500 (or "· complete", "· 2 to choose").
     - Not started: 55% surface, dashed border, muted text, "· not started".
     - A requirement with no credit target (Humanity, Open): one line, name · "10 courses"
       · "23 cr", no bar.
  6. Floating ink bar (58 tall, radius 24): "STILL TO CLEAR" over "3 core · 2 disciplinary ·
     4 DEl 2" 13/700; "70%" 19/800 mint.
- **Behaviour** (`b_StatsDegree`): tap the total card to edit the credits the degree needs;
  tap a requirement to open or close its course list.
- **Audit (local `stats_light_degree.png`)**: matches the card styles, bars, dashed
  not-started card, complete state and the footer. Differences:
  - **Names**: "CDC (A7)", "Disciplinary Electives (A7)". The board writes "A7 Core · CDC2"
    and "Disciplinary Elective 1".
  - **Order**: the second degree's requirements (A7) come first. The board lists the first
    degree (B3, CDC1) first, then the second, then Humanity and Open.
- **Fixes**:
  1. Name requirements "<code> Core" with the muted "· CDC1/CDC2" suffix, and electives
     "Disciplinary Elective 1/2" (the eyebrow already says which degree is which).
  2. Order by first degree, second degree, then the common categories.
  3. Test: order and names for a dual-degree fixture.

### 7.3 Settings — `Settings` 390 × 1030 (scrolls) · 🟡 Built locally
- **Code**: `lib/features/settings/settings_view.dart` (uncommitted Group 2).
- **Layout**, padding 56/18, gap 11:
  1. "Settings" 25/700 −0.7; Close ✕ 42.
  2. Account (mint, radius 22, padding 13/14): a 44 px ink square (radius 15) with the
     initial 18/800 mint; the name 14/700 over the email 10.5/500 (ellipsis); a 32 tall ink
     **Sign out** pill 11.5/700.
  3. Section heads 10/700 +0.9 `#6B6B60`: YOUR ROLES (only for an owner or a live grant),
     ACADEMICS, APPEARANCE, GRADE PROFILES, (APP), YOUR DATA.
  4. Each section is a surface card (radius 20, padding 4/14) of 40–44 tall rows with 1 px
     `#EFEFE9` dividers: label 13/600, value 12.5/700 `accent` (or 600 `#55554C` when it
     can't change), a chevron when it opens something.
  5. Under Academics: "Changing the first discipline clears your grades." 9.5/500 `behind`.
  6. Appearance: two 44 tall radius-16 buttons, Light / Dark with icons (on = ink).
  7. Grade profiles: an 18 px radius-6 swatch in the profile's tone, the name, the role.
  8. Your data: Export grades ".csv", Import backup ".json", Import from old site ›.
  9. Two 44 tall radius-16 outlined buttons: **Report a bug** and **Reset courses** (border
     `#D8B49B`, text `behind` 700 — outlined, not red).
  10. Footer 9/500 faint, centred: "**Built By Siddharth Mishra** · your grades stay private
      to your account".
- **Behaviour** (`b_Settings`): Close → back; Working as → Switch role (Open as for an
  owner); Contact details → Before you start; Discipline / second discipline → the picker
  (changing the first asks first); Light / Dark set the theme; a profile name → rename;
  Install, Export, Import… run; Report a bug opens a report.
- **Audit**:
  - **Live** (old build, 309 px pane): the labels wrap mid-word ("Disciplin / e", "Dual /
    degree"), there is no YOUR ROLES section, and the footer is missing.
  - **Local** (`settings_light_390.png`, `_320`): matches the board, labels no longer wrap,
    and the footer is present. The app adds an **APP** section (Install app) and shows all
    five profiles (three "Compare only"); both are real features (keep).
- **Fix** (small): at 320 the discipline values truncate ("B.E. Computer Scienc…",
  "M.Sc. Economics (…"). The board shows the bare code, but codes must carry their names.
  Show **"A7 · Computer Science"** (code first, degree prefix dropped), ellipsized, with the
  full name as the tooltip and semantics label.
- **Departures**: the APP section and five profile rows (features the board predates).

## 8 · Row 5 — Offshoot and the More hub

**How row 5 was audited.**
- **First pass**: signed in with a non-BITS account, Representatives, Course reviews and
  Resources showed only "Sign in with your BITS account to …". So they were rendered from the
  current code in a temporary widget test that reuses the fixtures of
  `test/reviews/reviews_screens_test.dart` (fake Firestore, sample professors and reviews).
- **Second pass**: signed in with a BITS account, in dark mode, they were checked live. Live
  shows the same layouts, plus G1 (§3.30): **course names on Representatives and Course
  reviews, the programme names on Resources and the "No resources here yet" title are
  invisible in dark mode**, and "Volunteer" / "Find your representatives" are Roboto
  `TextButton`s.
- More and Offshoot were checked live and locally.

**Two bugs that affect the whole row** (fix them first; they are one-line fixes each):
1. **`ChoicePills` stretches every pill to the full width** (`lib/admin/widgets.dart:237`).
   Its `Container` has `alignment: Alignment.center` inside a `Wrap`, and a Container with an
   alignment grows to the widest constraint. So "Courses / Your reviews", the TAUGHT BY
   professors and the Helpful / Recent / Highest / Lowest sort all render as stacked,
   full-width rows. Wrap the label in `Center(widthFactor: 1, heightFactor: 1, …)` or drop
   the alignment. Then build the boards' two forms on top of it (see 8.4 and 8.7): the
   segmented track and the equal-width sort row.
2. **`TierTag` stretches the same way** ("TAKE IT" fills the card width in review cards).
   Same fix.

**Shared header for the More pages.** Every row-5 board puts **Back on the left**: a 44
circle, then a column with the eyebrow (`.lbl`) and the title **21/700 −0.5** (19 on a
course's reviews, ellipsized). The code uses `PageHeader` with Back on the right and a 22 px
title. Add a `leading` variant of `PageHeader` and use it for More's pages.

**The nav stays on the hub.** More, Representatives, the Courses tab of Course reviews and
Resources show the floating nav pill with **More** selected (boards `More`,
`Representatives`, `ReviewsSearch`, `Resources`). Deeper screens (a course's reviews, write,
edit, a professor, report) hide it and use a bottom action instead. Today every More page is
a pushed route without the nav.

### 8.1 Offshoot — `Offshoot` 390 × 950 (and `DarkOffshoot`) · ✅ Correct (one fix)
- **Code**: `lib/features/offshoot/`, shown as the fourth grade profile on Home.
- **Layout**, padding 56/20, gap 16:
  1. "Finance offshoot" 13/500 over "Your total" 27/700 −0.8; the header circles.
  2. Mint hero, radius 30, padding 24/22: "47" 62/800 −3 with "/ 50" 22/600; a 7 px bar;
     "Best 5 of 6 graded courses · dropping ECON F412" 12/500.
  3. Two 46 tall stadium buttons: "Best 5 · / 50" (on) and "All 6 · / 60".
  4. "Grades come from your Actual profile. Untick any course a company does not ask for."
  5. Course rows, 8 apart: surface, radius 20, padding 13/15, 1.5 px ink border when
     counted; a 22 px radius-7 checkbox; the code 12.5/700 over the title 10.5/500; the
     grade chip 38 × 31 radius 11 in its grade tone. The dropped course: 55% surface, dashed
     border, **an empty checkbox outline**, muted text "Not counted · lowest of the six", a
     muted grade chip.
  6. The nav pill with **Offshoot** selected (all five items stay 50 px: bar padding 8,
     active pill padding 13).
- **Audit**: live and local (`sem_light_offshoot_390.png`) match the board.
- **Fix**: the dropped row draws a **ticked, faded** checkbox. Draw the empty outline
  (1.5 px `#A9A99E`) the board shows, since "dropped" means not counted.
- **Departure**: the header keeps the Calendar circle (the board shows three circles).
  The header is shared by all profiles, so its icons don't jump when you swipe between
  them.

### 8.2 More — `More` 390 × 844 · 🔧 Fix
- **Code**: `lib/features/more/more_page.dart`.
- **Layout**, padding 56/20, gap 13 — **a tab, not a pushed page** (no Back):
  1. Eyebrow `.lbl` "GOA · B3 A7 · 2026-27 SEM 1" over "More" **27/800 −1**.
  2. Three separate cards, 9 apart: surface, radius 22, **76 tall**, padding 0 16. A 44 px
     mint tile (radius 15) with the icon, then the title 14/700 over the description
     10.5/500 1.35 `#6B6B60`, and a chevron:
     - "Representatives" — "Your department president and the CR for each course"
     - "Course reviews" — "Search any course, filter by the professor teaching it"
     - "Resources" — "Drive links, notes and papers, by degree"
  3. "Everything here is for **Goa** only. Reviews, resources and representatives differ per
     campus because the teaching does." 10.5/500.
  4. The nav pill with **More** selected, over the 150 fade.
- **Audit (live and local, same code)**: eyebrow "POINTER"; title 22/700; a Back button;
  one grouped card with three short rows and grey icon tiles; other descriptions; no
  campus line; no nav pill.
- **Fixes**:
  1. Render More inside the Home shell as the fifth nav destination (the bar's More opens
     it in place, More selected), with no Back.
  2. The eyebrow from campus · degrees · current term; title 27/800.
  3. Three 76 px cards with mint tiles and the board's descriptions.
  4. The campus line.
  5. Test: More is selected in the bar; each card routes; eyebrow text.

### 8.3 Representatives — `Representatives` 390 × 844 · 🔧 Rebuild layout
- **Code**: `lib/features/more/representatives_page.dart`.
- **Layout**, padding 56/20, gap 11:
  1. Leading-Back header: "GOA · A7" / "Representatives".
  2. Intro 11.5/500 `#55554C`: "Who maintains your courses on your campus. Names always show;
     each contact detail appears only if that person chose to share it."
  3. "DEPARTMENT" then a `.card`: a 38 px mint code tile (radius 13, "A7" 13/800), the name
     13/700 over "Department president · email and phone shared" 10.5/500; then a row of
     36 tall stadium contact pills (`surfaceSunken`, icon + "Email" / the phone, 11.5/700);
     during a handover a 20 px amber tag "HANDOVER IN 12 DAYS" and "Nikhil Bhat is taking
     over".
  4. "YOUR COURSES THIS SEMESTER" then one `.card` of 58 tall rows with inset dividers: the
     course "CS F301 · Programming Languages" 12.5/700 over "Rohan Shetty · email and phone"
     10.5/500; on the right 32 px round `surfaceSunken` contact buttons (mail, phone).
     No CR: "No CR appointed yet" and a 28 tall dashed "Volunteer" chip (withdrawable).
  5. For a CR: an ink card (radius 20, padding 12/15): "You are a CR for CS F301" 12/700 over
     "Choose what this page shows about you" 10.5/500 `#B0B0A4`, and a 32 px mint "Edit"
     chip → Before you start.
  6. The nav pill, More selected.
- **Audit (local render, empty data)**: section labels "PRESIDENT · COMPUTER SCIENCE" and
  "CLASS REPRESENTATIVES"; each course is a heading above its **own card**; the volunteer
  action is a text button; a closing note; Back on the right; no nav.
- **Fixes**:
  1. Leading header, intro line, nav.
  2. DEPARTMENT card with the code tile, contact pills and the handover tag.
  3. One grouped card of course rows with round contact buttons and the dashed Volunteer
     chip.
  4. The CR card.
  5. Keep the existing data flow (`_Data`, `_volunteer`); this is layout only.
  6. Test: contact pills only for shared details; Volunteer toggles; CR card only for a CR.

### 8.4 Course reviews · search — `ReviewsSearch` 390 × 844 · 🔧 Fix
- **Code**: `lib/features/reviews/reviews_home.dart`.
- **Layout**, padding 56/20, gap 11:
  1. Leading header: "GOA" / "Course reviews".
  2. **Segmented track**: 40 tall, radius 20, `#E4E4DC` fill, padding 3; the selected half is
     ink (radius 17, 12/700), the other `icon` 600: "Courses" / "Your reviews · 3".
  3. Search: 46 tall, radius 23, surface, search icon, placeholder "Course code, name or
     professor" 13/500 faint (3.20). Focused: 1.5 px ink border.
  4. "YOUR COURSES THIS SEMESTER" then one `.card` of 64 tall rows: "CS F301 · Programming
     Languages" 12.5/700 (**one line, ellipsis**), then small stars and "71% take it · Dr. R.
     Menon" 10/600 (the professor teaching now, or "not set yet"); chevron. **No leading
     icon.**
  5. "MOST REVIEWED AT GOA", same rows with "88% take it · 124 reviews".
  6. The per-professor note 10.5/500.
  7. The nav pill, More selected.
- **Audit (local render)**: the tabs are two stacked full-width pills (the `ChoicePills` bug);
  the search is an outlined, 12-radius field with no icon and the placeholder "Course or
  professor"; rows have a leading icon tile and wrap titles to two lines; rows show review
  counts but no stars and no current professor; Back on the right; no nav.
- **Fixes**: segmented track (new `SegmentedTrack` built on the fixed pills), `SearchBox`,
  rows without icons and with stars + professor, one-line titles, leading header, nav.

### 8.5 Search a professor — `ReviewsSearchProfessor` 390 × 844 · 🔧 Fix
- **Layout**: the search screen with a query ("menon"): "PROFESSORS" then a card of 64 px
  rows (a 34 px `#E4E4DC` tile with a person icon, the name 12.5/700 over the department
  10/600); then "COURSES" with a card saying "No course code or name matches “menon”."; the
  note "One box for both. Any word of a name finds a professor, and their old names too after
  a merge. …".
- **Audit (local)**: works and lists professors; same header, search box and tab issues as
  8.4. When no course matches, the COURSES section is omitted instead of showing the
  no-match card.
- **Fixes**: as 8.4, plus the no-match card and the note.

### 8.6 Professor — `ProfessorReviews` 390 × 844 · 🔧 Fix
- **Code**: `lib/features/reviews/professor_reviews.dart`, `review_widgets.dart`
  (the summary card).
- **Layout**: leading header "COMPUTER SCIENCE · GOA" / "Dr. R. Menon" (ellipsis). A white
  **summary card** (`.card`, padding 12/15, gap 8): "4.0" 24/800 −0.9 + "/ 5" 10.5/600, the
  stars, and on the right "74%" 15/800 over "WOULD TAKE IT" 9/700 +0.3; a 6 px bar (track
  `#4A4A40`, mint fill); "Across 3 courses, 52 reviews." 10/500. Then "COURSES TAUGHT" and a
  card of 64 px rows: "CS F301 · Programming Languages" over "2025-26 Sem 2, 2024-25 Sem 2 ·
  18 reviews". A closing note.
- **Audit (local)**: the summary card is **ink** with a 30 px number and no bar; its "/ 5"
  uses a bare `TextStyle` (it renders with no family in tests: give it a `TypeScale`
  style); course rows carry a leading icon tile and wrap titles.
- **Fixes**: white summary card with the bar (shared with 8.7); rows without icons, one-line
  titles; leading header.

### 8.7 A course's reviews — `Reviews` 390 × 880 · 🔧 Fix
- **Code**: `lib/features/reviews/course_reviews.dart`.
- **Layout**, padding 56/20, gap 10, **no nav**:
  1. Leading header: "CS F301 · GOA" / the course title **19/700**, ellipsized.
  2. "TAUGHT BY": a 40 tall search field (radius 14, 1 px outline, "Search a professor, even
     past ones"); a wrap of 32 tall pills: the current professor (on, with a small "now"
     mark), other professors, "All"; then "Teaching this semester · 18 of 41 reviews"
     10/600 `accent`.
  3. The summary card (8.6), with "Dr. R. Menon only. The whole course sits at 3.8 across
     both professors."
  4. Sort: four **equal-width** 30 tall pills (11 px): Helpful (default on), Recent, Highest,
     Lowest.
  5. Review cards (`.card`, gap 8): stars and, on the right, a 22 tall "TAKE IT" mint tag (or
     "SKIP IT" `#E4E4DC`); 20 tall chips "2025-26 SEM 2", "DR. R. MENON" (`#F0F0EA`); the text
     12.5/500 1.45 `#2B2B24`; then a 26 tall outlined "Helpful · 12" chip and a plain
     "Report".
  6. A bottom action over a 120 fade: "Review CS F301" (56 tall stadium).
- **Audit (local)**: the professor pills, "All" and the sort are full-width stacked rows
  (`ChoicePills`), the TAKE IT tag stretches (`TierTag`), the summary card is ink, there's no
  professor search field, and the header title wraps to two lines at 22 px.
- **Fixes**: the two widget bugs; the search field; the white summary card; equal-width sort;
  tags as chips; 19 px one-line title; the bottom action.

### 8.8 Write a review — `ReviewWrite` 390 × 844 · 🔧 Fix
- **Code**: `lib/features/reviews/review_form.dart`.
- **Layout**, gap 12:
  1. Leading header: "CS F301 · GOA" / "Your review".
  2. `.card` "YOU TOOK IT": two scope chips (3.8) "2025-26 SEM 2" (`#E4E4DC`) and "Dr. R.
     Menon" (mint); the note "From your grades and that term's professor. Your review counts
     toward Dr. Menon, not the course as a whole."
  3. `.card`: "OVERALL" and **five 48 × 48 radius-14 star buttons** spread across the width
     (filled ones mint, the rest `background`); "WOULD YOU TAKE IT AGAIN, FROM THEM?" and two
     equal 44 tall stadium buttons, Yes / No.
  4. `.card`: "WHAT SHOULD THE NEXT BATCH KNOW?", a textarea (radius 14, `#F8F8F5`, 1 px
     outline, placeholder "Grading, workload, what the exams look like, what actually
     helped."), "0 / 600" 10/600.
  5. The note: "Posted without your name or ID. One review per course; you can edit it
     later." (**The board says "edit or delete"; reviews are never deleted (decided 27 Sep
     2026), so drop "or delete".**)
  6. Bottom action "Post review", 56 tall; disabled until stars and an answer are set.
- **Audit (local, edit form)**: YOU TOOK IT is a card but shows the term and professor as
  two bold lines, not chips; stars are bare 28 px icons, not 48 px buttons; Yes / No are
  stacked full-width (`ChoicePills`); the text field has a floating "Optional" label and the
  counter sits outside the card; the button is inline, not a bottom action. With no term
  recorded, the page shows only a note (keep that state).
- **Fixes**: scope chips; the star buttons (a `StarPicker` with 48 px targets); Yes / No as
  equal buttons; the card-wrapped textarea with its label above; the bottom action; copy.

### 8.9 Your reviews — `YourReviews` 390 × 844 · 🔧 Fix
- **Layout**: the search screen with the second tab on: the search box becomes "Search your
  reviews" (40 tall, radius 14), the summary card is gone, the sort row is "Recent" (on) /
  Helpful / Highest / Lowest, and cards gain a mint course chip ("CS F301") before the term
  and professor, "12 found it helpful" and a 30 px round edit button. No bottom action. Tap a
  card → Edit your review.
- **Audit (local)**: the tabs and sort are stacked full-width pills; there's no search box
  on this tab.
- **Fixes**: the widget bugs; "Search your reviews"; course chip and helpful count on each
  card.

### 8.10 Edit your review — `ReviewEdit` 390 × 844 · 🔧 Fix
- **Layout**: Write a review, filled in, titled "Edit your review"; the note "Still without
  your name or ID. Posted 14 May 2026; an edit keeps its helpful votes and says “edited”.
  Reviews are edited, never deleted."; the bottom action "Save changes". No Delete.
- **Audit (local render)**: correct copy and no Delete; the same layout issues as 8.8.
- **Fixes**: as 8.8; add the posted date to the note.

### 8.11 Resources — `Resources` 390 × 980 · 🔧 Fix
- **Code**: `lib/features/resources/resources_page.dart`.
- **Layout**, gap 11:
  1. Leading header: "GOA · DUAL DEGREE" / "Resources".
  2. Per degree: a heading row — a 30 × 24 radius-8 code tile (first degree mint; second
     ink with mint text, 11/800) and the programme name 13.5/700. Then one `.card` (no
     padding):
     - "DEPARTMENT · 12" (`.lbl`, padding 10/15/6).
     - 52 tall link rows: a 28 px `#F0F0EA` tile with the kind icon, the title 12/700 over the
       domain 9.5/500, and a 44 px **⋯** button (tooltip "More options for this link") →
       Report this link.
     - "COURSES" with two 24 tall mini pills "This semester" (on) / "All".
     - Course links; a link rolled up from a course carries an 18 px ink tag "FROM CS F301"
       (mint text).
  3. The nav pill, More selected.
- **Audit**: live shows only the sign-in note, with the eyebrow **"· DUAL DEGREE"** (a stray
  separator when the campus is unknown). Locally the structure is there: degree headings,
  department and course sections, This semester / All, the FROM tag. Differences from code:
  the report action is a **flag** icon, not ⋯; the degree code is a `TierTag`, not the
  30 × 24 tile; the sections are separate, not inside one card per degree.
- **Fixes**:
  1. Build the eyebrow from the non-empty parts only (fixes "· DUAL DEGREE").
  2. ⋯ button; code tiles; one card per degree with in-card labels; 24 px mini pills.
  3. Leading header and nav.
  4. Test: eyebrow with and without a campus; rolled-up tag; This semester filter.

### 8.12 Report this link — `ReportLink` 390 × 844 · 🔧 Fix (small)
- **Layout**: a sheet over a 42% scrim: surface, top radius 28, padding 12/20/40, gap 11: a
  40 × 4 handle; "Report this link" 19/800; the link line (`.note` 11.5); four full-width 44
  tall radius-14 left-aligned reason buttons ("It doesn't open" on, "Wrong course",
  "Shouldn't be shared", "Something else"); an optional note `.field`; "Send report" 52 tall
  stadium; the note "Goes to the owners and your department president. The link stays up
  until one of them acts."
- **Audit**: `_ReportSheet` exists with "Send report"; not rendered with data. Check it
  against the list above when Resources is rebuilt; the reasons must be the 44 tall
  radius-14 buttons, not chips.

### 8.13 Empty resources — `ResourcesEmpty` 390 × 844 · 🔧 Fix (small)
- **Layout**: under the degree heading, a surface card (radius 22, padding 26/20, centred,
  gap 12): a 52 px `#F0F0EA` tile (radius 18) with a folder icon, "No resources here yet"
  14.5/700, the explanation 12/500 1.5 centred, and an ink 42 tall "Find your
  representatives" button → Representatives. Then the amber **Public contact** block (radius
  20, padding 14/15): "ARE YOU THE DEPARTMENT PRESIDENT?" 10.5/800 `#8A5D12`, the text
  12/500, and an ink 44 tall row with a 28 px mint disc, "Message <name>" 12.5/700 over the
  role 9.5/500. The number is never drawn. The closing note about when the block hides.
- **Audit**: `ResourcesEmpty` has the card, copy, button and the Public contact block, but
  left-aligned, with no icon tile. The button shows only when `onRepresentatives` is passed:
  the `/resources` route passes it, but More pushes `const ResourcesPage()`
  (`more_page.dart:50`), so from More the button is hidden.
- **Fixes**: centre the card and add the tile; open Resources from More through the route
  (`context.push(Routes.resources)`), so the button is always wired.

## 9 · Row 6 — Dark mode, responsiveness, logo

### 9.1 Dark Home — `DarkMain` 390 × 844 · 🟡 Built locally
- **Spec**: the Home layout (4.7) on the dark palette (§2.1). Dark differences to keep: stat
  numbers 800, the nav pill's 1 px `divider` border, the hero `#CDE8C8` / `#14210F`, the
  selected semester pill and the **+ Add** pill drawn in `inverse` (light on dark).
- **Audit (local `sem_dark_actual_390.png`)**: matches — header circles with the sun icon,
  light Add pill, lifted greys, grade tones, bordered nav pill. The live site has the old
  nav (see 4.7).
- **Departure** (§2.1): the board's slightly smaller dark sizes (18 gutter, 38 badges, 40 ×
  32 chips) are not copied; one size set for both modes.
- **Fix**: none. Deploy.

### 9.2 Dark Offshoot — `DarkOffshoot` 390 × 950 · ✅ Correct
- Offshoot (8.1) on the dark palette; `sem_dark_offshoot_390.png` matches. The 8.1 checkbox
  fix applies here too.

### 9.3 Responsive — `Responsive` (schematic) · 🟡 Built locally
- **Spec** (§2.5): one column under 720; at ≥ 720 the stat cards move to a right rail
  (120 → 190 wide) and the pill centres (max 420); at ≥ 1100 the pill becomes a 96 px left
  rail (radius 16 on the board, Pointer mark on top) and the body caps at 1180. Heights
  fixed or intrinsic; ellipsis everywhere; `TextScaler.noScaling` removed.
- **Audit (local `sem_light_actual_768.png`, `_1440.png`)**: correct at all three widths:
  the right rail at 768 and 1440, the centred pill at 768, the left rail with the mark and
  five labelled destinations at 1440, and the body capped and centred. No overflow at 320
  or at 200% text in the existing shots.
- **Fix**: at 768 the semester strip opens scrolled so the leftmost visible pill is cut in
  half ("3 - 1"). Scroll so the selected pill is fully visible with one whole pill before
  it (the same fix as 4.7's live note).
- **Note**: `light_tablet_768.png` / `light_desktop_1440.png` come from the layout test's
  stub content (no header circles, four destinations). They test the shell only; judge the
  screen from the `sem_*` shots.

### 9.4 Logo — `Logo` · ✅ Correct
- **Spec**: concept 04 "Tassel" (§2.4), single colour, flat; legible at 32 px; ink on ground,
  mint or `#F2E7A8` on ink. The board also draws a horizontal lockup ("CGPA" /
  "Calculator", two weights) for the landing page.
- **Audit**: `pointer_mark.dart` draws the mark; the rail shows it mint on ink at 1440; the
  landing page and the loading screen (`web/index.html`) draw the same path. `web/favicon.png`
  and `web/icons/` are PNGs: confirm they are the Tassel mark when icons are next touched.
- **Fix**: none.

## 10 · Page 2 — Managers (owners, admins, presidents, CRs)

The canvas's second page has one row per role. The two left columns of each row show how
that role gets in.
- **Owner only**: Owners, Publish, site analytics.
- **Owners and admins**: Open as (Owner setup first, for an owner who isn't on a BITS
  address), then Controls, Maintainers, Appoint, Grant terms and Public contact.
- **Getting in as a representative, and shared screens**: Before you start, Switch role,
  Audit log, Roster, Volunteers, Merge professors.
- **Department president**: President home, Course structures, Reviews, Resources
  (+ Reported), Professors, Succession (+ Confirm), Pick a department / course.
- **Course manager (CR)**: the course page.

**How page 2 was audited (27 Sep 2026).**
- **Live**: signed in as an owner on a BITS account, in **dark mode**, in the 309 px browser
  pane. Screens captured: Controls, Maintainers, Appoint, Grant terms, Public contact, Audit
  log, Owners, Publish, Merge, Roster, Open as, Work as, President home (Goa · CS), Course
  structures, Reviews, Resources, Professors, Hand over, and the CS F301 course page.
- The live data is nearly empty: no grants, nothing to publish, no reports. So lists show
  their empty states.
- Under a non-BITS owner account none of this is reachable (10.0).
- **Code**: each screen was also compared from its code (`lib/admin/`,
  `lib/features/roles/`). As a first pass, the board's
copy was matched against the source: most fixed strings exist, and the misses are mainly
sample data. The screens' behaviour is covered by `test/roles/step11_screens_test.dart` and
`test/reviews/reviews_screens_test.dart` (steps 10 and 11). What remains is **G1 and G2
(§3.30), which break almost every manager screen in dark mode**, and then layout: the same
set of gaps on nearly every screen, listed in 10.1. So the statuses below are **🔧
layout** unless stated. **Before building each screen, render it with a screenshot test**
(reuse the step-11 fixtures) and compare it with its board. The per-screen notes list what
the code visibly lacks.

### 10.0 Blocking: a non-BITS owner never gets their roles · 🔧 Fix first
- **What happens**: signed in as an owner on a non-BITS Google account, `/calculator/admin`
  (and every `/admin/…` URL) redirects to Home. Settings has no YOUR ROLES section, and
  Reviews, Resources and Representatives say "Sign in with your BITS account…".
- **Why**: `lib/main.dart:94` creates `roleStore` and calls `refreshMyRoles()` only when
  `isBitsAddress(email)`. For any other account `myRoles` stays `MyRoles.none` (or the cached
  value), so `_staff()` / `_ownerOnly()` in `lib/app/router.dart` fail and redirect to Home.
- **The boards say otherwise**: `Owners` — "Any verified Google account" can be an owner;
  `OwnerSetup` — a non-BITS owner answers campus and batch once, then carries on.
- **Fix**: always create the `RoleStore` for a signed-in account and load roles. Keep the
  BITS-only parts: `recordSignIn` only runs for a BITS address, because it needs
  `campusOfAddress`. A non-BITS account without an owner document stays a student with no
  privileged routes (the rules decide, not the client). Then route a non-BITS owner with no
  campus through Owner setup (10.21). Test: a non-BITS owner reaches `/admin`; a non-BITS
  non-owner is redirected. Don't touch the sign-in flow itself (the iPhone
  `redirect_uri_mismatch` rule).
- Until this ships, the owner screens can only be seen in widget tests or with a BITS owner
  account.

### 10.1 What every manager screen needs (from the boards' shared CSS)
1. **Fix `ChoicePills` and `TierTag`** (§8, row-5 preamble). Tabs and filters (Maintainers'
   All / Goa / Hyd / Pilani / Expiring, Open as's campus, Reviews' All / Reported /
   Hidden, Roster's tabs) currently stack full width.
2. **Equal-width tabs**: tab rows are pills with `flex-grow: 1; flex-basis: 0` (36 tall,
   12–12.5 px). A tab can be amber ("Reported 2", `noticeTone` with a 7 px `#D99728` dot
   that pulses while a report is open, even under reduced motion — the board says so
   explicitly; the pulse is an opacity animation on the dot only).
3. **Headers**:
   - Home screens (Controls, Your department) have an eyebrow (`.lbl`), a title 25–27/800,
     and **Back to Pointer** on the right.
   - Pushed screens use the **leading-Back** header (§8), with the title 21/700 −0.5.
4. **The scope is always visible** (`DeptHome` note): President screens show scope chips
   (3.8, 30 tall here) under the title: campus with a pin icon, "ELEC · A3", the term. The
   widget exists (`ScopeChip`, `widgets.dart:162`); make sure every `/maintain/…` screen
   shows it.
5. **Rows** in a `.card` with inset `.hr`: 48–58 tall, a 30–32 px radius-10/11 icon tile
   (`#F0F0EA`; mint for the primary action, amber for a hand-over), the title 13/700 over a
   **live** subtitle 10.5/500, and a chevron — or a count badge (24 tall, radius 12,
   10.5/800; amber for work waiting, mint "ON" for a switch). The code's `NavRow` has
   static subtitles ("Every grant: presidents, course managers, admins"). The boards show
   live counts ("3 presidents · 24 course managers · 1 admin", "14 changes waiting · last
   published 3 days ago", "31 courses · 12 have no scheme yet"). Feed them from the stores
   and add the badges.
6. **Tier badges** (`.tier`, 22 tall, 10/800): OWNER mint, ADMIN ink / mint text,
   PRESIDENT mint, CR ink / `onInverse`.
7. **Bottom actions** (56 tall stadium over a 120 fade) for the one primary action: Appoint
   someone, Add a link, Grant — president, ELEC Goa.
8. **Amber rows** for things about to lapse (EXPIRES IN 4 DAYS) and red-brown refusal boxes
   (`#F6E3DA` / `#8A4B2A`).

### 10.2 Controls — `AdminHome` 390 × 900 · 🔧 layout
- **Code**: `lib/admin/admin_home.dart`.
- **Board**:
  - Header: "POINTER · ADMIN" / "Controls" 27/800, Back to Pointer.
  - An **ink card**: the OWNER tier badge; "<name> — every campus, every department"
    13/600; and the explanation 10.5/500 `#B0B0A4`.
  - PEOPLE: Maintainers (live counts), Appoint someone (mint tile).
  - OWNERS AND ADMINS: Grant terms ("CR 1 semester · president 1 year · admin 2 years"),
    Public contact (with a mint **ON** badge), Merge professors, Audit log.
  - OWNER ONLY: Owners ("2 active · you cannot remove yourself"), Publish catalogue (amber
    count badge "14"), **Site analytics**.
  - The footnote about what an admin sees.
- **Code differs**:
  - Subtitles are static and there are no badges.
  - It adds **Roster** and **Open Pointer as** rows. Keep both: Roster is shared, and Open as
    is the owner's entry point (`RolePick` note).
  - **Site analytics** has no screen. Show the row disabled with "Coming later" until one
    exists; don't invent a board.
  - **Live**: every row title is invisible in dark mode (G1); only the subtitles show. The
    OWNER card is drawn in `inverse`, which is light in dark mode, and its OWNER tag
    stretches across the card (G2). Draw it in `navBackground` (ink in both modes), as the
    board shows.

### 10.3 Maintainers — `AdminPeople` 390 × 844 · 🔧 layout
- **Code**: `lib/admin/people.dart`.
- **Board**:
  - Leading header "28 PEOPLE" / "Maintainers".
  - Five equal filter pills: All, Goa, Hyd, Pilani, and a non-flexing "Expiring".
  - One card of grant blocks (padding 12/15, gap 7): a tier badge, scope chips (campus with a
    pin, "ELEC · for A3"), and "no expiry" / the expiry on the right; the name 13/700 with
    the email 11/500 (ellipsis); an activity line ("9 edits this week · expires 31 Dec").
  - A grant 4 days from lapsing is amber, with "EXPIRES IN 4 DAYS" and "Renewing is
    deliberate. Do nothing and the grant lapses on its own."
  - Footnote; bottom action **Appoint someone**.
- **Live**: "0 PEOPLE", the five filters stacked full width (G2), "Nobody here yet.", and
  Appoint someone as an inline light button, not a bottom action.
- **Code differs**: the filter labels are "Hyderabad" (the board says "Hyd", to fit five
  equal pills at 320 — use the short labels); the pills stack (10.1.1). EXPIRES IN is
  present. Check the grant block layout and the bottom action.

### 10.4 Appoint — `AdminGrant` 390 × 1130 · 🔧 layout
- **Code**: `lib/admin/grant_form.dart`.
- **Board**: four cards, then the bottom action "Grant — president, ELEC Goa":
  1. BITS STUDENT ADDRESS: a 46 tall field (focused 1.5 px ink); chips for the campus read
     from the address (lock icon) and "Student · 2023"; a mint-wash confirmation "✓ Meera
     Iyer uses Pointer"; the rule text (with **Can not be found** in `#9A2F14`); a
     red-brown box "Refused on this form: faculty addresses…, alumni addresses and non-BITS
     accounts. Presidents and CRs are students."
  2. TIER: pills Admin (owners only) / Department president / Course manager.
  3. SCOPE · ONE PER GRANT: a 44 tall select "ELEC · Electronics"; APPOINTED FOR: equal
     32 tall pills A3 / A8 / AA / AC; the ELEC note.
  4. EXPIRES: "Full term · 1 year" / "Earlier date"; "Ends 27 September 2027…" with a
     Grant terms link.
- **Live**: the address card has a tall empty gap where the found-user confirmation goes;
  the tier pills stack (G2); the address field is labelled "Email" (board: the label is
  above, "BITS STUDENT ADDRESS").
- **Code differs**: most copy is present. Check the refusal box, the found-user
  confirmation and the equal-width pills. The primary button must name the grant it will
  make.

### 10.5 Grant terms — `Terms` · 🔧 layout (small)
- **Code**: `lib/admin/config_pages.dart`.
- **Board**: three rows, CR / president / admin, each with a length and "Given today → ends
  27 Mar 2027"; "Only owners change the admin term".
- **Live**: the title is "How long a grant lasts" under "CONFIG · GRANT TERMS"; the preview
  lines "Given today → ends 29 Mar 2027" **are present**. But each tier tag stretches (G2)
  and the length between − and + is invisible in dark (G1). *(Corrected in §15 N30: the
  board's title is "How long a grant lasts", as the code has; keep it.)*

### 10.6 Public contact — `PublicContact` · 🔧 layout (small)
- **Code**: `config_pages.dart`.
- **Board**: the name, the method, the target (the number is shown masked, "+91 98xxx
  xxxxx"); "Last changed by <name> (admin), 2 days ago. Every change is logged"; a preview
  of the student-facing "Message Siddharth" button.
- **Live**: the on/off switch's title is invisible and its caption faint (G1); WhatsApp /
  Phone / Email stack (G2); the STUDENTS SEE preview's heading is unreadable (G1).
- **Code differs**: add the last-changed line.

### 10.7 Merge professors — `ProfessorMerge` · 🔧 layout
- **Code**: `lib/admin/professors.dart`.
- **Board**: two professor cards (reviews · courses · added date), the survivor's name
  "Ramesh Menon · 17 reviews", "Also known as Dr. R. Menon. Every review…", the warning "It
  rewrites 3 reviews and 2 offerings and cannot be undone", and the confirm.
- **Live**: "OWNERS, ADMINS, PRESIDENTS" / "Merge duplicates"; the four campuses stacked
  (G2); a Material dropdown with an invisible "Department" hint (G1); "Pick a department."
- **Code differs**: show the counts and the exact rewrite sentence before confirming. *(The
  board's title is "Merge duplicates", as the code has; see N30.)*

### 10.8 Audit log — `AuditLog` · 🔧 layout
- **Board**: entries grouped by day. Each has the actor (name + tier badge, never
  anonymous), what changed ("Changed the Midsem weight in EEE F211") and when; filter
  pills.
- **Live**: "APPEND-ONLY" / "Audit log", a "Filter by course" field with a filter icon,
  "Nothing logged here yet." and the note. Matches in structure; no entries to compare.
- **Code**: see the audit page in `config_pages.dart`. Check the grouping and that every
  entry names its actor; fix the pills (10.1.1).

### 10.9 Owners — `Owners` · 🔧 layout (small)
- **Code**: `config_pages.dart`.
- **Board**: "2 ACTIVE"; each owner with name and email; "You · first owner, set in the
  Firebase console"; "You can't remove yourself" on your own row; add an owner by address.
- **Live**: two owners, each with a stretched OWNER tag (G2) and an **invisible name**
  (G1); "You · you can't remove yourself" on your own row; "Remove" in `accent` on the
  other; "Set in the Firebase console" under the first owner. Add-an-owner form and the
  footnote match.
- **Fix**: G1, G2, and a 44 px "Remove" target.

### 10.10 Publish — `Publish` · ✅ Copy matches, 🔧 layout
- **Code**: `lib/admin/publish_page.dart`.
- **Board**:
  - "DRAFT → LIVE · 14 CHANGES".
  - MOVES CGPAs · 2 (with a **CONFIRM** tag): each course with "Credits 3 → 4. The CGPA of
    everyone holding a grade in it changes."
  - RETIRED · 1; Titles and default tags · 11 (cosmetic).
  - The headcount note.
  - A checkbox "I have read the 2 credit changes. They move CGPAs."
  - Bottom action "Publish 14 changes".
- **Code**: all of this copy exists. Build the three groups as cards, the checkbox gating
  the bottom action.
- **Live** (nothing waiting): "DRAFT → LIVE · 0 CHANGES", "Live is v1.", a disabled
  "Publish 0 changes" inline, and "Draft a change to a course" as a Roboto `TextButton`
  (G1). Make Publish the bottom action.

### 10.11 President home — `DeptHome` 390 × 844 · 🔧 layout
- **Code**: `lib/admin/maintain.dart`.
- **Board**:
  - "DEPARTMENT PRESIDENT" / "Your department" 25/800, Back to Pointer.
  - Scope chips (10.1.4).
  - The sharing sentence ("You share it, as equals, with the A8, AA and AC presidents…").
  - One card of five 58 px rows with live subtitles and badges: Course structures (amber
    "12"), Resources, Reviews (amber "3"), Professors, People.
  - A separate **Hand over to your successor** row (amber tile, "They start now · you keep
    access for 20 days").
  - An ink **THIS WEEK** card ("9 by you · 6 by other presidents · 14 by CRs" + a mint "Audit
    log" link).
- **Live** (Goa · CS): the scope chips are there (Goa with a pin, CS, "2026-27 Sem 1" as
  plain text, not a chip); all row titles are invisible (G1); "58 courses · 58 have no
  scheme yet" carries a **mint** "58" (G6: amber); Hand over is a row inside the list; a
  7th row with a mint tile has no visible title; THIS WEEK exists below.
- **Code differs**: static subtitles elsewhere; add the separate hand-over row; the term as
  a third chip.

### 10.12 Course structures — `DeptCourses` 390 × 844 · 🔧 layout
- **Code**: `maintain.dart` (list, extraction prompt), `bulk_upload.dart`.
- **Board**:
  - Leading header "GOA · A7 · 2026-27 SEM 1".
  - A **dashed mint drop card** "Upload schemes as JSON" (2 px dashed `#9CC9BA`, mint 34%
    fill).
  - An EXTRACTION PROMPT card: a 30 px ink "Copy" pill, the explanation, and a quoted
    preview with "Show".
  - A 42 tall search "Search 31 courses" with a "No scheme" filter link.
  - One card of course rows with 20 tall chips: "4 components" mint, "100% assigned"
    (amber when under 100%), "avg 3 of 4", "CR: f2023…", or a dashed "No scheme yet" / "No
    CR" / "Project — no default scheme".
  - The catalogue footnote.
- **Live**: the upload card's title is invisible (G1); EXTRACTION PROMPT with a green
  "Copy" text button; "Choose a file" (light pill) and "Paste"; "Search 58 courses"; All /
  No scheme stacked (G2).
- **Code differs**: the drop card is a plain card, not the dashed mint drop zone. Add the
  zone, a filter link instead of stacked pills, and the chip row per course.

### 10.13 Reviews moderation — `DeptReviews` 390 × 844 · 🔧 layout
- **Code**: `lib/admin/dept_reviews.dart`.
- **Board**:
  - "GOA ONLY · A7" / "Reviews".
  - A summary card for the course ("CS F301 · GOA · 41 REVIEWS", "this campus only", 3.8 / 5,
    71% WOULD TAKE IT, a 7 px bar).
  - Three equal tabs "All 214" / "Reported 3" / "Hidden 7".
  - Review cards: course chip (ink), term chip, "2 REPORTS" 10/800 `#8A5D12`, "4 of 5", a
    TAKE IT / DON'T tag, the text, "Anonymous to students · attributable to you", and 32 tall
    **Keep** (outlined) / **Hide** (ink).
  - An amber note: "Hiding is reversible and never a delete…".
- **Live**: **the page shows only a raw Firestore error** (a composite index is missing):
  G4. Nothing else renders.
- **Code differs**: the eyebrow is "A7 · GOA" (board: "GOA ONLY · A7", which states the
  sandbox); the three views exist as `ChoicePills` "All / Reported / Hidden" but have **no
  counts**, and there is no summary card. The copy for Keep / Hide / reason
  exists. Add the counts to the tab labels, the summary card, and the per-card report count
  and footer line.

### 10.14 Resources — `DeptResources` 390 × 860 and `DeptResourcesReported` · 🔧 layout
- **Code**: `lib/admin/dept_resources.dart`.
- **Board**:
  - Three equal tabs: "Dept 46", "By course", and the amber **Reported 2** with its pulsing
    dot.
  - Link rows with 30 px tiles. A rolled-up link has a white tile on a mint-wash row, an
    18 px ink "ROLLED UP" tag, "from CS F301 · by its CR", and an "Unpin" link.
  - An ink ROLLUP explainer card.
  - Bottom action "Add a link".
  - **Reported**: an amber card "2 LINKS REPORTED · DEPARTMENT AND ROLLED-UP COURSE LINKS";
    per link, the reason · count · origin, and 34 tall **Fix the link** (ink) / **It works ·
    dismiss** (amber outline).
- **Live**: the tabs are Material `FilterChip`s (square-ish, a check on the selected one,
  Roboto): "Dept 0", "By course", "Reported"; they wrap to two lines at 309. Replace them
  with the three equal pills. "Add a link" is inline, not a bottom action.
- **Code differs**: the tabs and "Reported n" exist. Check the pulse, the rolled-up row
  style, the ROLLUP card and the bottom action.

### 10.15 Professors — `DeptProfessors` · 🔧 layout
- **Code**: `lib/admin/professors.dart`.
- **Board**: "GOA · A7 · 2026-27 SEM 1"; "Search 24 professors"; rows with name and
  "CS F301, CS F372 · teaching now" or "last taught 2024-25 Sem 2"; add, rename, merge.
- **Live**: "Search 0 professors", the empty-state help, a "Join them into one" row, WHO CAN
  CHANGE THIS, and a disabled "Search first, then add". Close to the board.
- **Code differs**: "· teaching now" exists; add "last taught <term>" for the others, and
  the count in the search placeholder.

### 10.16 Roster — `Roster` and `RosterVolunteers` · 🔧 layout
- **Code**: `lib/admin/roster.dart`, `lib/admin/volunteers.dart`.
- **Board**:
  - "31 PEOPLE" / "Roster".
  - Two equal tabs "Maintainers" / "Volunteers · 3".
  - Grant rows with the staff phone ("+91 90000 00001").
  - Volunteers grouped by course, with name, email and when; a **clipboard** button per
    offer (copies the election or objection notice); **Appoint as CR** and **Dismiss**.
- **Live**: "0 PEOPLE"; **two stacked tab rows** — Maintainers / Volunteers, then All /
  Presidents / CRs / Expiring (G2); "Nobody here yet."; Appoint someone inline.
- **Code differs**: the copy exists (the board's staff phone came from commit 5bbd4f3).
  Fix the tabs (10.1.1) and put the counts in the labels.

### 10.17 Hand over — `Succession` and `SuccessionConfirm` · 🔧 layout
- **Code**: `lib/admin/succession.dart`.
- **Board, step 1**:
  - "STEP 1 OF 3 · GOA · A7" / "Hand over".
  - The lead sentence.
  - THEIR BITS ADDRESS field, and a confirmation chip "Goa address — 2024 batch".
  - The same-campus rule.
  - A **WHAT HAPPENS** timeline: **Today.** They become president… / **For 20 days.** You
    both have full access… / **16 October.** Your access ends…
  - The cancel rule.
  - Bottom action "Review the handover".
- **Board, step 3**:
  - "STEP 3 OF 3" / "Confirm".
  - A HANDING OVER card (FROM → TO, "A7 Computer Science", "11 CRs move too").
  - TYPE THE DEPARTMENT CODE TO CONFIRM, with "Typed, not tapped…".
  - AFTER YOU CONFIRM: three lines.
  - "Hand A7 Goa to f20240391", plus "Not yet".
- **Live** (owner on Goa · CS, not a president): only "Only a president of CS can hand it
  over." That's correct for an owner.
- **Code differs**: the logic and much of the copy exist ("Look up", "Can not be found",
  typed confirmation, cancel). The **step labels**, the **WHAT HAPPENS** timeline and the
  **AFTER YOU CONFIRM** list are missing. Add them. The primary button names both sides.

### 10.18 Course page — `CrHome` · 🔧 layout
- **Code**: `lib/admin/maintain.dart` (course page), `lib/admin/scheme_editor.dart`.
- **Board**:
  - The course header with scope chips.
  - The eval scheme, with components and "avg 12.4" chips (dashed when no average — a real
    state), and "100% assigned · a part inside a component…".
  - The professor, picked from the list.
  - Course resources, with a pulsing amber "1 LINK REPORTED" row that opens Reported for
    this course, and "Pick from department resources" (links, never copies).
- **Live** (CS F301 as owner): "COURSE MANAGER" / "CS F301", Goa and term chips, the title;
  TAKEN BY, THIS TERM with a green "Change" `TextButton` (G1) and an empty card;
  EVALUATION SCHEME "No scheme yet…" with "Add"; COURSE RESOURCES with "Add" and "Pick from
  department resources". The actions are Roboto text buttons. Make them 28–32 tall chips
  (the board's style) in Montserrat.
- **Code differs**: check the dashed no-average pills and the reported row; the scheme
  editor shares widgets with §5.4 (build the student scheme editor to reuse them).

### 10.19 Before you start — `RepProfile` · 🔧 layout
- **Code**: `lib/features/roles/rep_profile.dart`.
- **Board**:
  - "YOU'VE BEEN APPOINTED" and a tier + scope line ("PRESIDENT · ELEC · GOA").
  - "Appointed by Aditya Kulkarni. Other maintainers…".
  - YOUR NAME, AS STUDENTS SEE IT; PHONE NUMBER · REQUIRED.
  - What students see, with at least one channel.
  - Save and continue → Switch role.
  - Not skippable; Sign out is the only way off.
- **Code differs**: the "appointed by" line and the tier + scope heading.

### 10.20 Switch role — `RoleSwitch` · 🔧 layout (small)
- **Code**: `lib/features/roles/role_switch_page.dart`.
- **Board**:
  - "YOUR ROLES · GOA".
  - Student, then every live grant with its expiry ("ELEC · A3 · until 27 Sep 2027",
    "CS F301 · until 27 Mar 2027").
  - "Your contact details" row.
  - The chosen role persists, with the strip (3.29) to switch back.
- **Live** ("Work as", as an owner with no grants): YOUR ROLES / "Work as", only Student
  (NOW), and the two notes. For an owner, Settings should lead to Open as, not here (board
  note). *(The board's title is "Work as", as the code has; see N30.)*
- **Code differs**: the expiry is there but as "until 27/9/2027"; write it as "until 27 Sep
  2027" (the app's date style).

### 10.21 Owner setup — `OwnerSetup` · 🔧 Missing for owners
- **Board**:
  - "ONE-TIME SETUP · OWNER".
  - "Your sign-in isn't a BITS address, so Pointer can't read your campus or batch…".
  - SIGNED IN AS.
  - Campus, and batch ("The year you joined. It sets which semesters…").
  - "Both are final once set, as they are for…".
- **Code**: `degree_setup_page.dart:201` already asks campus and batch under "ONE-TIME
  SETUP" for a non-BITS address. With 10.0 fixed, use it for owners too, with the owner
  eyebrow and copy.

### 10.22 Open as — `RolePick`, `ViewAsDept`, `ViewAsCourse` · 🔧 layout
- **Code**: `lib/admin/open_as.dart`.
- **Board `RolePick`**: five role rows (Owner, Admin, Department president, CR, Student)
  with tier tags; "Signed in as an owner"; "Only owners ever see this screen…".
- **Boards `ViewAsDept` / `ViewAsCourse`**: **full screens**.
  - "OPEN AS · DEPARTMENT PRESIDENT" / "Which department?": campus pills, then "GOA · 10
    DEPARTMENTS", a list with the presidents per department ("A7 · 2 presidents"; ELEC as
    one entry "A3 · A8 · AA · AC"), the last opened on top.
  - The course picker: "GOA · OFFERED 2026-27 SEM 1", searchable, each course with its
    professor and CR count.
  - A course not offered this term opens read-only on its last offering.
- **Live**: five role rows whose **titles are invisible** (G1); only the subtitles show.
- **Code differs**: the pickers are inline — a department **dropdown** and a free-text
  **course code** field inside a card on the Open as page. Replace them with the two picker
  screens (lists, search, last-opened first). The campus `ChoicePills` stack (10.1.1).

---

# Part 3 — Order, done, and the log

## 11 · Build order

One group at a time. Each group ends with a local commit (specific files only); the user
pushes and deploys. Groups 3–9 are not started. **Build from the task cards in §20**, which
break each group below into steps with files, code and tests, and add the second audit's
findings (N1–N30).

| Group | Contents | Sections |
|---|---|---|
| **2 · finish** | Uncommitted work (see 13.2). Then: the Stats axes (7.1), Degree names and order (7.2), the Settings discipline label (7.3). Delete `test/ui/zz_audit_shots_test.dart` and `test/reviews/zz_audit_reviews_test.dart` (audit-only, never commit). Commit. | 7.1–7.3, 6.4, 5.1 (done parts) |
| **3 · global** | G1 theme brightness, text colour and font; G2 pills and tags; G3 router error page and the volunteers route; G4 the Firestore index and friendly errors; G5 non-BITS owner roles; G6 badge tones. Then the new shared parts from §3 that later groups need: `CardLabel`, `SegmentedPair`, `SegmentedTrack`, `TagBadge`, `Notice`, `CardRow`, `CodeBadge`, `SearchBox`, `BottomAction`, the compact field, the `labelAbove` / `filled` field styles, `PageHeader.leading` and `.close`, `PrimaryButton.tall`. | §3.30, §3, 10.0 |
| **4 · getting in** | Loading lines, Sign in, Setup, Pick a programme check, Import. | 4.2–4.6 |
| **5 · a course** | Marks fixes; Edit evaluative rebuild; Course setup; the scheme editor and divergence sheet; After diverging; Average sources. | 5.1–5.6 |
| **6 · adding** | Grade menu label; Add a course; Enter it manually. | 6.1–6.3 |
| **7 · More** | More as a nav destination; the leading header; Representatives; Course reviews (search, professor, course, write, yours, edit); Resources, report, empty; the Offshoot checkbox. | 8.1–8.13 |
| **8 · managers** | Page 2, in the canvas's role order: owner only; owners and admins; shared; president; CR. | 10.1–10.22 |
| **9 · last pass** | Every screen in dark at 390 and 320; 768 and 1440 for Home, Stats, Marks and More; 200% text at 320; the old-device frame check (§1.4); the landing and loading screens against the live deploy. | §2.5–2.7 |

## 12 · Tests and the definition of done

A screen is done when all of these hold:
1. **Board match**: its screenshots (light and dark, 390 and 320, full length for scrolling
   boards) match the board, and every difference is written as a **Departure** with a
   reason.
2. **Behaviour**: every control in the board's BEHAVIOUR note works, with a widget test for
   each tap / hold / drag that changes state. Storage is covered by unit tests, not by UI
   taps (the Hive rule, §1.3).
3. **Layout rules**: no overflow at 320 × 640 with `textScale: 2`; every touch target ≥ 44;
   icon buttons have tooltips; nothing sized from the screen height.
4. **Dark mode**: every text readable (G1) — check the dark shot, not only the light one.
5. **Performance**: no blur, `saveLayer` or `Opacity` over a subtree; charts and sliders
   inside a `RepaintBoundary`; lists as builders.
6. **Checks**: `flutter analyze` shows only the 7 existing infos; `flutter test` passes;
   `cd test/rules && npm test` passes when rules or storage changed.
7. **Log**: a **Built** entry in §13 naming the files and any departure.

**Screenshot tests.** Put one per screen group in `test/ui/` (as `board_shots_test.dart`
does) using `shoot()`, with the sizes the board is drawn at. Fixtures for the Firestore-backed
screens: reuse `test/reviews/reviews_screens_test.dart` and
`test/roles/step11_screens_test.dart` (fake Firestore, a `RoleStore`, sample professors,
reviews and grants).

## 13 · Build log

### 13.1 Group 1 — tokens and shared widgets (`Main`, `DarkMain`, `Responsive`) · committed `fd3f390`

**Nav pill** — `lib/shared/widgets/app_nav.dart`. Board `Main` / `More`: a 66 px ink pill,
8 px inner padding, items spaced between.
- **Selected**: a mint stadium, 50 tall, 13 px side padding, 17 px icon, 7 px gap, label
  12.5/700.
- **Unselected**: 50 × 50 round icon buttons in `navIcon`; the label is the tooltip and the
  semantics label (the old build showed every label under every icon).
- **Narrow phones** (< 360 wide): icons drop to the 44 px touch minimum and the side margin
  to 16, so the selected label still fits at 320.
  - The selected label is measured with a `TextPainter`. If it can't fit whole (200% text,
    a long custom profile name), the pill shows its icon only rather than squeezing the
    others.
  - *Departure*: the board has no 320 px pill; this rule keeps §15's 44 px and no-overflow
    checks.
- **Rail** (≥ 1100): the Pointer mark on top, then icon-over-label items. The rail keeps
  every label; it has the room.
- Pill max width 420 (was 480), centred on tablets.

**Floating bar** — `lib/shared/layout/responsive.dart`. The pill floats over the page:
`Scaffold.extendBody`, the pill inset 20 (16 on narrow phones) and `Space.md` above the safe
area, over a fade from transparent to the ground that ignores pointers. Lists under it pad
by the bar's height (`SemesterView`, `OffshootPanel`, `MinorPanel`).

**Home header and section row** — `lib/features/semester/semester_page.dart`.
- The **+ Add** pill sits in the section row beside sort and export.
  - The dashed add card at the foot of the list shows only while the semester is empty.
  - Test `the Add pill fires` replaces `add card is reachable and fires`.
- The row wraps: count left, pills right while they fit; at 320 or large text the pills
  drop to their own line.
- Stats uses `Icons.show_chart_rounded`; Compare uses `Icons.open_in_full_rounded`.

**Stat cards** — `lib/shared/widgets/stat_card.dart`: the number is 800 in dark, 700 in light.

**`PillButton`** gains `padding` (default 15); the header pills use 13.

### 13.2 Group 2 — Stats, Settings, Calendar, Marks rows · built locally, **not committed**
Files changed: `lib/core/storage/stats.dart`, `lib/features/calendar/calendar_page.dart`,
`lib/features/marks/marks_page.dart`, `lib/features/marks/widgets/evaluative_card.dart`,
`lib/features/settings/settings_view.dart`, `lib/features/stats/{stats_controller,
stats_page}.dart`, `lib/features/stats/widgets/{cgpa_chart,progression_view}.dart`,
`lib/shared/widgets/app_nav.dart`, `test/calendar/calendar_test.dart`,
`test/stats/stats_test.dart`, and new `test/helpers/shots.dart`,
`test/ui/board_shots_test.dart`.
- **Stats · Progression** (`Stats`):
  - A tick box on every future semester, stored per device (`statsSkipped` /
    `setStatsSkipped` in `core/storage/stats.dart`).
  - Unticked cards are dashed at 55% surface with "Not in this forecast · tick to include".
  - The current point is emphasised; forecast points are hollow.
  - The footer value is mint 19/800.
  - **The chart's "Target: 8.0" pill was removed** at the user's request (board v67): the
    legend names the target line. `tag()` in `cgpa_chart.dart` now only labels points.
- **Settings** (`Settings`): regrouped as the board — account card, YOUR ROLES (owner or
  live grant only), Academics with the clear-grades warning, Appearance, Grade profiles,
  Your data, Report a bug / Reset courses, and the Built By footer. *Departures*: the APP
  section (Install) and five profile rows.
- **Calendar**: past days fade to `navIcon`, dots included.
- **Marks**:
  - The amber notice replaces the grey caption, with the bold "weight, out of, average or
    date".
  - The hero gains the you-vs-class bar (`_VersusBar`) and says "class average".
  - **Every evaluative row has a Duplicate button** (copy icon, 44 px) at the user's request:
    a copy with the next name, the same weight, parts and Best-of rule, and no marks, dates
    or averages. `evaluative_card.dart` matches the board rows (count badges, dropped
    parts, dashed ungraded rows).
- **Screenshot helper**: `test/helpers/shots.dart` (`shoot()`); `test/ui/board_shots_test.dart`
  shoots Settings, `test/stats/stats_test.dart` the three Stats views and
  `test/marks/marks_test.dart` the Marks page.
- **Still to do in this group**: see §11, Group 2.


### 13.3 Second audit and the fix guide (27 Sep 2026) · UI.md only, no code changed
- At the user's request no Dart code was changed. A Stats-axes patch was written, tested (19
  passed, analyze clean) and reverted; it is written out in §20 T2.1.
- Rendered 40 screens with fake data (manager screens with a fake Firestore) and 59 boards
  with Chromium, and compared each pair. The new findings are N1–N30 in §15.
- Mapped boards ↔ code (§16, §17), checked every navigation target (§18), and searched for
  dead code (§19): nothing is dead. The legacy `thm` layer and the Home dialogs are
  redundant.
- Found the exact G4 index (N10) and two overflows at 320 with 2× text (N27).
- The audit harnesses `test/ui/zz_audit_managers_test.dart` and `zz_audit_students_test.dart`
  stay untracked; §14 has the recipe.

### 13.4 Expected: a permanent "Copy from Actual" button (27 Sep 2026)
- **Why**: at the user's request. The copy button on Expected hid itself two seconds after
  the tab opened (`setfab()`'s timer). It now stays for as long as Expected is open.
- **Files**:
  - new `lib/features/semester/widgets/copy_profile_button.dart`: a 56 px round ink FAB with
    a 22 px copy icon and no text. Its tooltip and semantics label is "Copy every <Actual>
    grade into <Expected>". The confirm dialog is in the palette and Montserrat.
  - `lib/home_page.dart`: `_showFab` and `setfab()` removed. The button shows whenever
    `selectedprofile == 2`, and the body's bottom padding grows by 72 on Expected so the
    list clears it.
  - new `test/semester/expected_copy_test.dart` (5 tests):
    - it stays after 5 s
    - it has no text, only the tooltip
    - Cancel copies nothing
    - Import copies once
    - it is ink, round and ≥ 44 px
- **Board**: the canvas gained `Expected` beside Home's behaviour note, with a note of its
  behaviour (canvas v68). The icon-only button followed in v69.
- **Departure**: none. The board was drawn from the code.


### 13.5 The fake-data harness and the full guide (27 Sep 2026)
- **New test files**:
  - `test/helpers/fake_data.dart`
  - `test/ui/manager_screens_test.dart`, `student_screens_test.dart`,
    `sheet_screens_test.dart`
- **What it covers**: every page renders over full fake data (§14.1). Seeding found seven
  bugs the empty screens hid (N31–N37). Each is held in its test's `known` map until fixed.
- **UI.md**: the Group 4–8 cards were rewritten step by step, each with named behaviour tests
  and its render-test rows. No app code changed.
---

# Part 4 — Second audit and the fix guide

Written 27 Sep 2026 after a second, code-level audit. **Part 4 is the work list.** Part 2
says what each screen must look like; Part 4 says what is wrong in the code today, where, and
how to fix it, in an order that a smaller model can follow one task at a time.

- §14: how this audit was done, and how to repeat it.
- §15: new findings (N1–N30). They add to G1–G6 (§3.30).
- §16: every board mapped to its Dart file, with whether it renders today.
- §17: everything a user can reach, with its board or "no board".
- §18: button and route check.
- §19: code that is loaded but redundant.
- §20: the task cards, in build order. **Start here when building.**

## 14 · How the second audit was done

**Live code.** The deployed site is `master` at `3061a67`: PR 11 merged from `1c6f0c0`,
deployed by `.github/workflows/deploy.yml` on 27 Sep 2026. `pointer-rebuild` is two commits
ahead (`fd3f390`, `8037abc`), and both touch student screens only (17 files). **Nothing under
`lib/admin/`, `lib/features/roles/`, Reviews, Resources, More or `main.dart` differs from the
live site**, so every manager screen rendered below is exactly what is live. (§Part 2's intro
says the live build is "older than `fd3f390`"; it is `1c6f0c0` plus the merge commit.)

**Screens.** Every screen was rendered from the current code with fake data, and nothing was
changed in `lib/`. Two untracked test files did this:
- `test/ui/zz_audit_managers_test.dart`: 28 manager and More-row screens.
- `test/ui/zz_audit_students_test.dart`: 12 Page 1 screens with no screenshot test.

Each screen was pumped into a `MaterialApp` with `palette.materialTheme`, the global
`roleStore` set to `RoleStore(FakeFirebaseFirestore(), me: …)` and `myRoles` set to the role
under test. The shots are light and dark at 390, dark at 320, and light at 320 with 2× text.
The seed data:
- five grants: an admin on Hyderabad; presidents of ELEC and CS on Goa, the CS one 9 days from
  expiry; CRs for CS F372 and MATH F211
- one owner, four `people` rows, a directory entry, four audit entries, and two professors
  ("Dr. R. Menon", "R. Menon")

Hive was opened with `Sync.openBoxes()`, `marksBox` and `cacheBoxes`. Any Flutter error was
recorded instead of failing. **To repeat it**, recreate the files from this recipe (they must
never be committed); `test/roles/step11_screens_test.dart` shows the same seeding.

```dart
// in audit(t, name, screen, roles:, me:):
final db = FakeFirebaseFirestore();
await t.runAsync(() => seed(db));            // grants, owners, people, directory, audit, professors
roleStore = RoleStore(db, me: me, myName: 'Me');
myRoles.value = roles;                        // e.g. MyRoles(email: owner, owner: true)
t.view.physicalSize = size * 2; t.view.devicePixelRatio = 2;
await t.pumpWidget(RepaintBoundary(child: MaterialApp(theme: palette.materialTheme,
    builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(
        textScaler: TextScaler.linear(scale)), child: child!), home: screen())));
for (var i = 0; i < 6; i++) {                 // not pumpAndSettle: PulsingTab never settles
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
  await t.pump(const Duration(milliseconds: 100));
}
// then captureImage(...) as test/helpers/shots.dart does
```

**Boards.** Each board file was read with the Artifact tool and rendered by headless Chromium
at 2×, with the repo's Montserrat injected by `@font-face`. Each render was put beside its
four app renders to compare.

**Limits.** These screens can't be seen this way:
- G5 needs a real non-BITS sign-in.
- G4 needs real Firestore; the fake one doesn't enforce indexes.
- The publish draft, reported reviews and volunteer offers were not seeded, so those screens
  show their empty states.

Confirm those on the live site with a signed-in browser (Claude in Chrome, or the Desktop
app's preview).

### 14.1 The committed harness (use this, not the recipe above)
- **`test/helpers/fake_data.dart`** fills a fake world through the app's own stores:
  - **People**: an owner, an admin, two Goa presidents (ELEC; CS, 4 days from expiry), two
    CRs and a student. Each has a `people` row, staff phone and directory entry.
  - **Firestore**:
    - four professors, including a duplicate pair
    - CS F372's published scheme this term (best-of parts, averages, dates, a professor) and
      an EEE F211 scheme
    - six reviews: two reported, one hidden
    - four resources: department links, a course link, one reported
    - two volunteer offers
    - two publish drafts: a credit change and a title
    - four audit entries
    - the public contact
  - **The student's device**: a B3 A7 dual degree, batch 23, at Goa:
    - 16 courses over eight semesters, with graded, NC and this-term courses, and Expected
      differing from Actual
    - six Offshoot courses
    - marks on CS F372 through the offering cache: official parts with marks, one own
      component, and the class average
- **`seedAll()`** once in `setUpAll`. It runs in real time and fills one shared fake
  Firestore. **Seeding inside a widget test can stall**, so don't.
- Then **`renderScreen(t, name, builder, who: As.cr, tall: 900, open: …)`**, which returns
  the errors, and **`expectRender(name, errors, known)`**, which checks them.
  - `As` picks the role: owner, admin, president, president2, cr, student.
  - `launcher` + `tapLauncher` open a sheet or dialog.
- The three test files cover **54 renders**: 30 manager, 17 student, 7 sheets and dialogs.
  Each renders light and dark at 390 and 320, and light at 320 with 2× text. The known
  issues are N27 and N31–N37. The full suite: 397 passed, 50 skipped in this container
  (private fixtures absent).
- To add a screen: add a row to the right file. To add data: add it in `seedFirestore` or
  `seedDevice`, through a store where one exists.

## 15 · New findings (N1–N37)

Each finding gives what is seen, the cause with file and line (at `8037abc`), and the fix.
Task cards in §20 reference them.

### Global (every screen or many)
- **N1 · G1 confirmed on every manager screen in dark.** Every `NavRow` title, name, row
  title and dropdown hint is invisible. Material widgets (`TextButton`, `SwitchListTile`,
  `DropdownButtonFormField`, `FilterChip`, `CheckboxListTile`, `AlertDialog`) draw their
  labels in no font: boxes in tests, Roboto on the web. The full list of such widgets, by
  file, is in §20 T3.1. After G1 they render in Montserrat. **Each still needs restyling to the
  board's chip or button** in its screen's task.
- **N2 · The mint tags are drawn in dark green.** `TierTag` (PRESIDENT), `ScopeChip` (the
  campus chip) and `NavRow(accent: true)` (the Appoint tile) fill with `p.accent` (`#1F5C4D`
  in light) and draw ink `p.onHero` text on it. That is unreadable in light: see the
  PRESIDENT tags on Maintainers and Roster, and the "Goa" chips everywhere. The boards use
  mint (`hero`). Cause: `lib/admin/widgets.dart:84`, `:87`, `:145`, `:175`, `:182`, `:190`.
  Fix: `p.hero` fill with `p.onHero` text (T3.3).
- **N3 · Titles break mid-word at 320 with 200% text.** Seen as "Maintaine/rs", "Your
  depa/rtment", "Professor/s", "Represen/tatives", "Resource/s" and "Course manag/er".
  Cause: `PageHeader` (`lib/shared/widgets/page_header.dart:39-44`) gives the title
  `maxLines: 2` in an `Expanded` beside a 42 px Back button; one long word can't fit a line,
  so Flutter breaks it. The boards also put Back **on the left** for pushed screens (the
  leading header, §10.1.3), and **on the right** only for top-level screens (Controls, Your
  department, Stats, Marks). Fix: T3.8.
- **N4 · A label beside a wide action wraps one word per line at 200% text.** Seen on:
  - CrHome: "TAKEN BY, / THIS / TERM" beside "Change"
  - DeptCourses: "EXTRA / CTION / PROMP / T" beside Copy
  - Terms: the row title and "183 / d" squeezed between − and +
  - Merge: the campus pills

  Cause: `Row(Expanded(label), trailing)` where the trailing is a `TextButton` or a stepper
  that doesn't shrink. Fix: the `LabelRow` pattern in T3.9, which stacks the trailing under
  the label when the label would get less than 96 px.
- **N5 · Email addresses wrap mid-address** ("f20220003@goa.bits- / pilani.ac.in") on
  Maintainers and Roster, and at 200% the name is cut to "Owner O…" on Audit log while the
  email keeps its room. The boards keep the name whole (`flex-shrink: 0`) and cut the email
  to one line (`.ell`). Fix: the `NameEmail` widget in T3.9.
- **N6 · "1 hours ago"**. `ago()` in `lib/admin/widgets.dart:302-303` never uses the
  singular. Fix: "1 minute ago", "1 hour ago", "1 day ago" (T3.9).
- **N7 · Raw errors reach the screen.** `problem()` (`widgets.dart:331`) returns `That did
  not work: $e`, which is how G4 shows a Firestore console URL. Fix in T3.5.
- **N8 · Switches and dialogs are Material green.** `SwitchListTile` on Public contact,
  Before you start and the Publish draft sheet uses the seed colour; the boards draw an ink
  track with a white or mint thumb (RepProfile). Date pickers
  (`grant_form.dart:383`, `scheme_editor.dart:210`, `add_evaluative_page.dart:257`) and all
  `AlertDialog`s use Material defaults. Fix: `switchTheme`, `dialogTheme` and
  `datePickerTheme` in the G1 theme (T3.1).
- **N9 · A bare `TextStyle` with no font.** `review_widgets.dart:116` (" / 5") and the "/"
  between Marks and Out of on Add evaluative draw as boxes in tests (Roboto on the web).
  G1's `fontFamily` fixes both; also use `TypeScale` styles there.

### G4, exactly
- **N10 · Department Reviews needs a collection-group index on (campus, department, hidden,
  reports desc).** The screen opens on **Reported**, which calls
  `moderation(hidden: false, reportedOnly: true)` (`dept_reviews.dart:32-37`). That runs
  `collectionGroup('entries')` with `campus ==`, `department ==`, `hidden == false`,
  `reports > 0`, ordered by `reports desc` (`review_store.dart:293-314`).
  `firestore.indexes.json` has (campus, department, reports desc) **without** `hidden`, so the
  query fails.
  - Add a `COLLECTION_GROUP` index on `entries`: campus ASC, department ASC, hidden ASC,
    reports DESC.
  - The user deploys it with `firebase deploy --only firestore:indexes`.
  - The All and Hidden tabs' indexes already exist.

### Manager screens (Page 2), seen with data
- **N11 · Controls**:
  - The owner card drops the name: it reads "Every campus, every department", where the
    board has "<name> — every campus, every department".
  - The card is `inverse`, so it turns light in dark mode.
  - The OWNER tag stretches (G2).
  - The Appoint tile is dark green (N2).
  - The rows are 46 tall with 11 px titles; the board has 48–56 tall rows and 13/700 titles.
- **N12 · Maintainers**:
  - The five filters stack full width (G2).
  - The tier tags stretch (G2).
  - EXPIRES IN n DAYS sits inline in the chip row. The board puts it right-aligned, followed
    by "Renewing is deliberate…".
  - The activity line reads "Appointed by X · until 5 Jan 2027", not the board's live "9
    edits this week · expires 31 Dec". Keep the code's line unless an edit count exists.
    Departure.
  - No bottom "Appoint someone" action (it is inline).
- **N13 · Roster**:
  - **Missing the "WHO APPOINTS · EVERY CAMPUS" section** (the owners and admins, with their
    staff phones) above the campus groups.
  - Maintainers / Volunteers are two stacked pills. The board has a `SegmentedTrack`: a
    40 px grey track with the selected half in ink, labelled "Volunteers · 3".
  - The four filters stack (G2).
  - No bottom "Appoint a CR".
- **N14 · Grant terms**:
  - The lengths are in **days** ("183 d", "365 d", "730 d"), and − / + change a day at a time
    (`config_pages.dart:189-240`). The board has a boxed number plus a unit: "1 semester",
    "1 year", and a locked "🔒 2 years" for an admin looking at the admin term.
  - Missing: the two rule chips ("Admins change CR and president terms" in mint, "Only
    owners change the admin term" in grey), and the amber notice.
  - The title is "How long a grant lasts" and the board agrees; §10.5's "use Grant terms" is
    wrong (see N30).
  - In dark the value and the − / + icons are invisible (G1).
- **N15 · Public contact**:
  - The toggle is a `SwitchListTile` whose text draws in no font (G1).
  - The preview's "Message …" button is a `FilledButton` (G1).
  - WhatsApp / Phone / Email stack (G2).
  - No "Last changed by …" line.
  - The save button says "students see it at once", and the code does read `config/public`
    live (`resources_page.dart:281`). The board and ARCHITECTURE §10.5 say it travels in the
    catalogue ("after the next publish"). **ARCHITECTURE decides behaviour**: either move the
    contact into the published catalogue, or record the live read as a Departure and keep the
    code's copy. **Ask the user.**
- **N16 · Owners**:
  - The OWNER tag stretches, and the names are invisible in dark.
  - "Add an owner" asks for an email **and** a name; the board asks for the address only.
    Keep the name field, since `RoleStore.addOwner(email, name)` needs it and a new owner may
    never have signed in. Departure.
  - The board's INACTIVE rows and 32 px "Remove" button need data to check.
  - There is no bottom "Add owner" action.
- **N17 · Open as**:
  - No ink identity card ("S · <name> · Signed in as an owner").
  - Icons instead of tier tags (OWNER / ADMIN / PRES / CR / STUDENT, each 58 wide).
  - The warning is plain text; the board has an amber notice with a bold lead.
  - The titles are invisible in dark.
- **N18 · Appoint someone**:
  - The address card has an empty gap with a `TextButton` ("Look up") drawn in no font.
  - There is no red-brown refusal box.
  - The tier pills stack.
  - With no address the disabled button reads "Grant — CR, …" (ellipsized). It should read
    "Grant" until an address resolves, then "Grant — course manager, CS F372 Goa".
  - The button is inline; the board has a bottom action.
- **N19 · Audit log**:
  - Missing the scope chips.
  - Missing the "Anyone" actor dropdown.
  - The course filter is a field plus a filter icon; the board has an ink chip "EEE F211 ✕"
    once one is set.
  - Missing the before → after value chips ("30%" struck in red-brown → "35%" in mint).
  - The actor's email should be the short form ("f20230456@goa").
  - "1 hours ago" (N6).
- **N20 · Your department**:
  - The badge "131" is mint (G6).
  - There is a 7th "Appoint a CR" row the board doesn't have. The board reaches it through
    People → Roster → Appoint a CR; remove the row or record a Departure.
  - "Hand over" is inside the list; the board has a separate card with an amber tile, "Hand
    over to your successor".
  - The **THIS WEEK ink card is missing**; the code shows an "Audit log" row instead.
  - The term is plain text; the board has a third chip.
- **N21 · Course structures**:
  - The extraction-prompt card is **nested inside** the upload card; the board has them as
    separate cards.
  - The upload card is plain; the board has a dashed mint drop zone.
  - Each course row has a leading radio or check icon (`maintain.dart:304-305`) that the
    board doesn't have. The board has a row of chips instead ("4 components", "100%
    assigned", "avg 3 of 4", "CR: f2023…", or dashed "No scheme yet").
  - All / No scheme stack; the board has a "No scheme" link in the search box.
- **N22 · Professors**:
  - A person icon; the board uses a graduation cap.
  - The "never type a name twice" warning is plain text; the board has an amber notice
    with ⚠.
  - Subtitles read "Not teaching this term"; the board has "CS F301, CS F372 · teaching now"
    or "… · last taught 2024-25 Sem 2".
  - The button is "Search first, then add" (disabled until a search). The board has a bottom
    "Add a professor". Keep the search-first rule (it is the point of the screen). Departure.
- **N23 · Resources (department)**:
  - The tabs are Material `FilterChip`s. In dark they are **light chips on the dark ground**,
    with a tick on the selected one, and at 320 they wrap to two lines.
  - "Add a link" is inline; the board has a bottom action.
  - No ROLLUP ink card.
- **N24 · Hand over (step 1)**:
  - Only the address field and a "Look up" `TextButton` exist.
  - Missing:
    - the lead sentence
    - the "✓ Goa address — 2024 batch" line
    - the same-campus rule
    - the WHAT HAPPENS timeline, three numbered steps (mint, mint, ink)
    - the amber cancel notice
    - the bottom "Review the handover"
  - The eyebrow is "ELEC · GOA"; the board has "STEP 1 OF 3 · GOA · A7".
- **N25 · Course page (CR)**:
  - **No COURSE AVERAGE card.** The board has an input "out of 100" with "Stored against
    this term and this component set…". Check ARCHITECTURE §13.3 for whether a CR enters it
    here; if so, build it.
  - "Change", "Add" and "Pick from department resources" are `TextButton`s. The board has
    "Change" / "Add" as text links in accent 700, and "Pick from department resources" as a
    dashed full-width button.
  - The scheme components have no "10%" / "avg 12.4" chips.
- **N26 · Work as / Before you start**:
  - Work as draws the current role as an **inverted card** with "NOW" in `accent`. In dark
    that is pale green on near-white, which can't be read (`role_switch_page.dart:92`). The
    board has a plain row with a mint "✓ NOW" chip.
  - Work as has no amber-mint "This is really you" notice and no "Your contact details" row.
  - Before you start (non-forced, as "Contact details"):
    - no ink "appointed" card with tier + scope chips and "Appointed by …"
    - Material floating-label fields; the board has labels above
    - Email / Phone switches; the board has BITS email / WhatsApp / Phone call
    - the privacy note is plain; the board has an amber notice
    - the Save button is inline

### Student screens (Page 1), seen with data
- **N27 · Course reviews and Professor reviews overflow at 320 with 200% text** (110 px). The
  summary card (`StatsCard`, `review_widgets.dart:105-139`) is a `Row` of a 30 px number, "
  / 5", a `Spacer` and a column with no flex. Fix: wrap the right column in `Flexible` with a
  `FittedBox(fit: BoxFit.scaleDown)`, and give " / 5" a `TypeScale` style (N9). The board's
  summary card is also **white** with a mint "would take it" bar (§8.7); the code's card is
  `inverse`.
- **N28 · Marks, empty course**: the hero reads "0.00 / 0 · 0% of the course graded · 100%
  pending". With nothing weighted yet it should read "No marks yet" (or "—"), not a
  zero-over-zero figure. The eyebrow is "CS F372 · 4 credits" in lower case (§5 common
  fix).
- **N29 · A legacy floating button on Expected.** `home_page.dart:153-210` shows an elevated
  Material FAB (legacy `thm` colours, `'Montserrat'` SemiBold) on the Expected profile that
  opens a legacy `AlertDialog` "Import from <Actual>?". No board has it: `Main` has no FAB,
  and the boards give copying profiles to Settings → Grade profiles and the empty-profile
  prompt. See §17 and T6.4.
  - **Resolved 27 Sep 2026, at the user's request**:
    - The button stays (it used to hide itself two seconds after Expected opened).
    - It is now a permanent `CopyProfileButton`
      (`lib/features/semester/widgets/copy_profile_button.dart`): a round ink button with
      only a copy icon (the text was removed at the user's request, canvas v69), named by
      its tooltip "Copy every Actual grade into Expected", with a palette-styled confirm
      dialog.
    - The list on Expected pads 72 px more so the last row scrolls clear of it.
    - The canvas gained the board **`Expected`** (x 4650, y 0) with a note, canvas version 68.

### Found with the seeded data (N31–N37)
These appear only when the screens have data. The empty-state audit could not see them. The
render tests in §14.1 hold each one in a `known` map until it is fixed.

- **N31 · Reported tab (department Resources)**: each reported link's "Fix the link" / "It
  works · dismiss" `TextButton`s sit in a `Row` that overflows **even at 390** (up to 621 px
  at 320 with 2× text). Cause: the two buttons in `dept_resources.dart:502-530` with no
  flex. Fix: a `Wrap` of two 34 tall pills (T8.13).
- **N32 · Department Resources tabs**: the `FilterChip` holding "Reported" and its
  `PulsingTab` overflows at 320 with 2× text. Fix: equal pills (T8.13).
- **N33 · Department Reviews**: the review card's header row overflows by 2.8 px at 320 with
  2× text, and the TAKE IT tag stretches (G2). Fix: T3.2 + T8.13.
- **N34 · Marks at 320, normal text**: a component card's trailing cluster (badge, weight,
  score, copy) squeezes the title to one word a line ("Kernel As/signmen…") and overflows
  0.85 px. Fix: T5.1 step 3.
- **N35 · Marks at 200% text**: the TAKEN BY row gives its label about 60 px, so it wraps a
  word a line ("TAKE/N BY"). Fix: `LabelRow` (T3.9, T5.1).
- **N36 · Divergence sheet**: the sheet doesn't scroll; it overflows 600 px at 320 with 2×
  text. Its buttons are Material `TextButton`s (G1). Fix: T5.4 step 1.
- **N37 · Report this link sheet**: it doesn't scroll (399 px overflow at 320 with 2× text),
  and its reasons are `RadioListTile`s drawn in no font (G1). Fix: T7.4 step 1.
- **Seeded Marks also shows**:
  - "no class avg yet" under the hero, while the hero compares against the class average
    9.80 the student typed. The line reads the official course average, not the student's.
    Say which it is ("class avg 9.80 · yours" / "· official"), as the board does. Part of
    T5.1.
  - The eyebrow is still lower case (T5.1).

### Corrections to Part 2
- **N30**:
  - **§10.7** says to use the title "Merge professors"; the board's title is **"Merge
    duplicates"**, which the code already uses. No change.
  - **§10.20** says "Switch role"; the board's title is **"Work as"**, which the code
    already uses. No change.
  - **§10.5** says to use "Grant terms"; the board's title is **"How long a grant lasts"**
    under "CONFIG · GRANT TERMS", which the code uses. No change.
  - **§10.3** says to change "Hyderabad" to "Hyd": the code already labels it "Hyd"
    (`people.dart:171`).
  - **Privacy**: `lib/features/settings/settings_page.dart:73` hard-codes the owner's personal
    email in a `mailto:` for Report a bug. Move it to `config/public` (or a const read from
    the catalogue) so no personal address sits in source (§1.3). Don't copy the address into
    any doc or test.

## 16 · Every board → its Dart file, and whether it renders today

"Renders" means it pumps with no exception. For shots marked A, that was checked at 390 and
320, light and dark, and at 320 with 2× text. For the others it comes from the existing test,
which passes, but not every existing test pumps at 320 with 2× text. "Shot" names the render: an existing test (`test/…`) or the audit (A). "Match" is the
board comparison: ✅ matches, 🟡 close, 🔧 needs work, ⬜ not built.

| Board | Dart | Renders | Shot | Match | Section |
|---|---|---|---|---|---|
| Landing | `landing/index.html` (static) | n/a | live | ✅ | 4.1 |
| Loading | `web/index.html #ptr-loading` (CSS) | n/a | source | 🔧 footer | 4.2 |
| SignIn | `features/auth/sign_in_view.dart` | ✅ | A | 🔧 | 4.3 |
| Discipline | `features/setup/degree_setup_page.dart` | ✅ | A | 🔧 | 4.4 |
| DisciplinePick | `features/setup/programme_pick_page.dart` | ✅ | A | ✅ | 4.5 |
| Import | `features/import/erp_import_page.dart` | ✅ | A | 🔧 | 4.6 |
| Main, DarkMain | `features/semester/semester_page.dart` in `home_page.dart` | ✅ | `semester_screenshots_test` | 🟡 | 4.7, 9.1 |
| Expected (added v68) | `home_page.dart` on profile 2 + `features/semester/widgets/copy_profile_button.dart` | ✅ | `test/semester/expected_copy_test.dart` | ✅ | N29 |
| Marks | `features/marks/marks_page.dart` | ✅ | `marks_test`, A | 🔧 (N28) | 5.1 |
| MarksAdd | `features/marks/add_evaluative_page.dart` | ✅ | A | ⬜ rebuild | 5.2 |
| MarksSetup | `features/marks/course_setup_page.dart` | ✅ | A | 🔧 | 5.3 |
| Divergence | `features/marks/widgets/divergence.dart` (sheet) | not pumped | — | ⬜ editor, 🔧 sheet | 5.4 |
| Diverged | state of `marks_page.dart` | not pumped | — | 🔧 | 5.5 |
| AverageSources | sheet from Marks "Averages ›" | not pumped | — | 🔧 | 5.6 |
| GradeMenu | `features/semester/widgets/grade_menu.dart` | ✅ | `semester_test` | ✅ | 6.1 |
| AddCourse | `features/semester/add_course_sheet.dart` | ✅ | `add_course_screenshots_test` | 🔧 | 6.2 |
| AddManual | the manual tab of `add_course_sheet.dart` | ✅ | `add_course_screenshots_test` | 🔧 | 6.3 |
| Calendar | `features/calendar/calendar_page.dart` | ✅ | `calendar_test` | 🟡 | 6.4 |
| Stats | `features/stats/stats_page.dart` + `widgets/progression_view.dart` | ✅ | A (`stats_test` shots need the private transcript) | 🟡 axes | 7.1 |
| StatsDegree | `features/stats/widgets/degree_view.dart` | ✅ | `stats_test` | 🟡 names, order | 7.2 |
| Settings | `features/settings/settings_view.dart` (+ `settings_page.dart`) | ✅ | `board_shots_test` | 🟡 label | 7.3 |
| Offshoot, DarkOffshoot | `features/offshoot/offshoot_panel.dart`, `minor_panel.dart` | ✅ | `semester_screenshots_test` | ✅ | 8.1, 9.2 |
| More | `features/more/more_page.dart` | ✅ | A | 🔧 | 8.2 |
| Representatives | `features/more/representatives_page.dart` | ✅ | A | 🔧 | 8.3 |
| ReviewsSearch, YourReviews | `features/reviews/reviews_home.dart` (`yours:`) | ✅ | A | 🔧 | 8.4, 8.9 |
| ReviewsSearchProfessor | search mode of `reviews_home.dart` | ✅ | `reviews_screens_test` | 🔧 | 8.5 |
| ProfessorReviews | `features/reviews/professor_reviews.dart` | ❌ **overflow** at 320 2× (N27) | A | 🔧 | 8.6 |
| Reviews | `features/reviews/course_reviews.dart` | ❌ **overflow** at 320 2× (N27) | A | 🔧 | 8.7 |
| ReviewWrite, ReviewEdit | `features/reviews/review_form.dart` (`existing:`) | ✅ | A | 🔧 | 8.8, 8.10 |
| Resources, ResourcesEmpty | `features/resources/resources_page.dart` | ✅ | A | 🔧 | 8.11, 8.13 |
| ReportLink | `_ReportSheet` in `resources_page.dart:125` | not pumped | — | 🔧 | 8.12 |
| Responsive | `shared/layout/responsive.dart`, `breakpoints.dart` | ✅ | `nav_screenshots_test`, `responsive_test` | 🟡 | 9.3 |
| Logo | `shared/widgets/pointer_mark.dart` | ✅ | — | ✅ | 9.4 |
| Owners | `admin/config_pages.dart` `OwnersPage` | ✅ | A | 🔧 (N16) | 10.9 |
| Publish | `admin/publish_page.dart` | ✅ (empty state) | A | 🔧 | 10.10 |
| OwnerSetup | none for owners (`degree_setup_page.dart:201` asks campus/batch for a non-BITS address) | — | — | ⬜ | 10.21 |
| RolePick | `admin/open_as.dart` | ✅ | A | 🔧 (N17) | 10.22 |
| ViewAsDept, ViewAsCourse | none: inline dropdown and text field in `open_as.dart:104` | — | — | ⬜ | 10.22 |
| AdminHome | `admin/admin_home.dart` | ✅ | A | 🔧 (N11) | 10.2 |
| AdminPeople | `admin/people.dart` `AdminPeople` | ✅ | A | 🔧 (N12) | 10.3 |
| AdminGrant | `admin/grant_form.dart` | ✅ | A | 🔧 (N18) | 10.4 |
| Terms | `admin/config_pages.dart` `TermsPage` | ✅ (but N4 squeeze) | A | 🔧 (N14) | 10.5 |
| PublicContact | `admin/config_pages.dart` `PublicContactPage` | ✅ | A | 🔧 (N15) | 10.6 |
| RepProfile | `features/roles/rep_profile.dart` | ✅ | A | 🔧 (N26) | 10.19 |
| RoleSwitch | `features/roles/role_switch_page.dart` | ✅ | A | 🔧 (N26) | 10.20 |
| AuditLog | `admin/config_pages.dart` `AuditLogPage` | ✅ | A | 🔧 (N19) | 10.8 |
| Roster | `admin/roster.dart` | ✅ | A | 🔧 (N13) | 10.16 |
| RosterVolunteers | `admin/volunteers.dart` `VolunteersTab` (a tab) | ✅ as a tab; **its route 404s** (G3) | A (empty) | 🔧 | 10.16 |
| ProfessorMerge | `admin/professors.dart` `ProfessorMerge` | ✅ | A | 🔧 | 10.7 |
| DeptHome | `admin/maintain.dart` `DeptHome` | ✅ | A | 🔧 (N20) | 10.11 |
| DeptCourses | `admin/maintain.dart` `DeptCourses`, `bulk_upload.dart` | ✅ | A | 🔧 (N21) | 10.12 |
| DeptReviews | `admin/dept_reviews.dart` | ✅ in tests; **fails live** (N10) | A (empty) | 🔧 | 10.13 |
| DeptResources | `admin/dept_resources.dart` | ✅ | A | 🔧 (N23) | 10.14 |
| DeptResourcesReported | Reported tab of `dept_resources.dart` | ✅ as a tab | — | 🔧 | 10.14 |
| DeptProfessors | `admin/professors.dart` `DeptProfessors` | ✅ | A | 🔧 (N22) | 10.15 |
| Succession | `admin/succession.dart` `Succession` | ✅ | A | 🔧 (N24) | 10.17 |
| SuccessionConfirm | `admin/succession.dart` `SuccessionConfirm` | ✅ | A | 🔧 | 10.17 |
| CrHome | `admin/maintain.dart` `CrHome`, `scheme_editor.dart` | ✅ | A | 🔧 (N25) | 10.18 |

**Summary.**
- 63 boards: 59 have a Dart file.
- **Four have none**: OwnerSetup (for owners), ViewAsDept, ViewAsCourse, and the student scheme
  editor half of Divergence.
- **Two screens don't render cleanly**: Reviews and ProfessorReviews overflow at 320 with 2×
  text (N27).
- **One fails live**: DeptReviews (N10).
- **One route is missing**: RosterVolunteers (G3).

## 17 · Everything a user can reach → its board

Routes, pushed pages, sheets and dialogs, found by searching `lib/` for `openRoute`,
`context.go` / `push`, `MaterialPageRoute`, `showDialog`, `showModalBottomSheet`,
`showGeneralDialog`, `showDatePicker`, `showMenu` and `launchUrl`. **"No board"** rows have no
board on the canvas; each needs one (ask the user to add it), or a decision to style it with
the shared parts and record a Departure.

**Full screens with no board**:

| Screen | Reached from | Code | Proposal |
|---|---|---|---|
| **Compare** view of Home | nav pill → Compare | `semester_page.dart` (two stat cards, profile picker sheet `:466`) | needs a board; `Main` only shows its nav icon |
| **Person** (one maintainer: what they changed, revoke) | Maintainers or Roster → a row | `admin/people.dart:215` `PersonPage` | needs a board; the AdminPeople note describes it ("Tap anyone to see what they have changed, and revoke from that same screen") |
| **Bulk upload preview** (created / changed / untouched, then confirm) | Course structures → Choose a file / Paste | `admin/bulk_upload.dart` | needs a board; the DeptCourses note describes it |
| **Scheme editor** (president / CR) | Course page → Add / edit scheme | `admin/scheme_editor.dart` | shares §5.4; draw it from `Divergence` + `MarksAdd` parts |
| **Install guide** | Import → Install, Settings → Install app | `settings/install_guide.dart` (sheet) | needs a board, or restyle with Notice / steps as on `Import` |
| **Import preview** (what the sheet creates or changes) | Import → a PDF | `import/import_preview.dart` (sheet) | needs a board (the Import note describes it) |
| **Edit course** (title, credits, category, remove) | Marks → pencil | `semester/edit_course_sheet.dart` | needs a board; `Marks` draws the pencil but no target |
| **Minor picker** | Offshoot → Minor | `offshoot/minor_panel.dart:95` (sheet) | reuse the `DisciplinePick` list style |
| **Site analytics** | none (no row in the code) | — | the `AdminHome` board has the row; show it disabled, "Coming later" (§10.2) |

**Sheets and dialogs with no board** (restyle each with the shared parts after G1):
- **Settings**:
  - the discipline picker is a generic list sheet (`settings_page.dart:112-160`). **The board
    note says the picker is `DisciplinePick`**: open `ProgrammePickPage` instead.
  - the other Settings dialogs:
    - the confirm-change dialog `:170`
    - rename profile `:234`
    - Import from old site `:365`
    - Report a problem `:409`
- **Stats**: "Credits your degree needs" (`stats_page.dart:51`; StatsDegree's BEHAVIOUR note
  says tap the total card to edit — no board for the dialog).
- **Home**:
  - "Over n credits" confirm (`add_course_sheet.dart:424`)
  - "Remove this course?" (`edit_course_sheet.dart:84`)
  - category `showMenu` (`course_fields.dart:108`)
- **Legacy, on Home** (`home_page.dart`), all Material `AlertDialog`s with the legacy `thm`
  colours and the SemiBold-only `'Montserrat'`:
  - ~~"Import from <profile>?"~~: now `CopyProfileButton`, on the `Expected` board (N29)
  - "Start <profile> from…" (`:249`)
  - "Clear Grades" (`:480`, the pull-to-clear confirm)
- **ERP import**: its confirm (`erp_import_page.dart:173`).
- **Managers**:
  - revoke (`people.dart:227`)
  - Paste JSON (`maintain.dart:214`)
  - "Write n schemes?" (`bulk_upload.dart:88`)
  - add or rename a professor (`professors.dart:30`)
  - the course picker sheet (`professors.dart:469`)
  - hide reason (`dept_reviews.dart:53`)
  - add a link (`dept_resources.dart:33`)
  - pick from department resources (`dept_resources.dart:576`)
  - draft a change (`publish_page.dart:68`)
- **Date pickers**: `grant_form.dart:383`, `scheme_editor.dart:210`,
  `add_evaluative_page.dart:257`. Theme them in G1 (N8).

**Screens that have a board but are drawn differently from how the code reaches them**:
- Open as → President / CR: the code has inline pickers; the boards have `ViewAsDept` and
  `ViewAsCourse` screens (10.22).
- Settings → Discipline: the code has a list sheet; the board has `DisciplinePick`.

## 18 · Button and route check

Every `context.go` / `push` / `openRoute` / `stripNavigate` target was traced to a
registered `GoRoute` (`lib/app/router.dart`):
- ✅ `stats`, `calendar`, `settings`, `resources`, `more`, `representatives`, `welcome`,
  `roles`, `reviews`, `reviews/professor/:id`, `reviews/:courseId`, `course/:id`
- ✅ every `admin/…` child: people, grant, owners, terms, contact, audit, roster, open-as,
  publish, professors/merge
- ✅ `maintain/:campus/course/:courseId`
- ✅ `maintain/:campus/:dept` and its courses, professors, reviews, resources, succession,
  succession/confirm

Broken or risky:
1. **`Routes.adminVolunteers` (`/admin/roster/volunteers`) has no `GoRoute`** (G3). Nothing
   in the code links to it today, but a typed or shared URL shows GoRouter's red error page,
   because the router has no `errorBuilder`. Fix: T3.4.
2. **Any unknown path** (a mistyped `/maintain/goa`, an old bookmark) shows the same raw
   error page (G3).
3. **`course/:id` with an id that isn't in the user's courses** (a shared link, or a course
   removed in another tab) redirects Home without a word (`router.dart:90`). That's safe;
   T3.4 adds a snackbar ("That course isn't in your list") so the user knows why.
4. **Role redirects send people Home silently**: `/admin` for a non-staff account, or
   `/maintain/…` for the wrong scope. That's correct (the RolePick note), but with G5 a
   non-BITS owner is sent Home too. Fix G5 first (T3.6).
5. **Settings → Controls** passes `() => const SizedBox()` as the no-router fallback
   (`settings_page.dart:105`). In the app the router exists, so it works, but a widget test
   that taps it shows a blank page. Pass `() => const AdminHome()` via the deferred loader,
   or drop the row in tests.
6. **External links** (`launchUrl`): Representatives' email / phone / WhatsApp, Resources'
   links, the ERP link, Report a bug's `mailto:` (N30 privacy). These are fine, apart from
   Report a bug's hard-coded address.
7. **New routes the boards imply** (ARCHITECTURE §16.1): `admin/open-as/department`,
   `admin/open-as/course`, `setup/owner`, `maintain/…/resources/reported`. Add them with
   their screens (T8.x). **Each new top-level segment needs a line in `landing/_redirects`**
   (only `setup` is new at top level; `admin` and `maintain` already exist). Check with
   `test/app/routes_test.dart`.

## 19 · Loaded but redundant

An import graph from `lib/main.dart` was built over all 147 Dart files. Every file is reached:
the two web-only files come in through conditional imports. Every one of the 161 widget
classes is constructed somewhere, and no top-level function is dead; `earnedCredits` and
`earnedCourses` in `requirements.dart` are used only by tests. **So nothing can simply be
deleted.** What is redundant is the legacy layer that still loads and still draws:

| What | Where | Why it's redundant | Fix |
|---|---|---|---|
| The legacy `thm` global and its colour aliases `backcolor`, `textcolor`, `sepcolor`, `highcolor`, `cardcolor`, `bordcolor` | `script.dart:280`, `palette.dart:156-161`; used 17 times in `main.dart`, `home_page.dart`, `script.dart` | a second, older name for `AppPalette` | replace each use with `AppPalette.of(context)` roles, then delete the aliases (T9.2) |
| The `'Montserrat'` font family (SemiBold only) | `pubspec.yaml`; used by the sign-in snackbar (`main.dart:242`) and the legacy dialogs in `home_page.dart` | `MontserratFull` has every weight | move those to `TypeScale`, then drop the family from `pubspec.yaml` (same file, so no size change; it removes a second font name) |
| Legacy Home dialogs | `home_page.dart` "Start … from…" and "Clear Grades" | not on any board | replace with a shared `ConfirmDialog` (T6.4). The Expected copy button is done (N29, §13.4) |
| `saveDataAsImage` (a PNG of the semester) | `script.dart:366`; called by Home's Export pill (`home_page.dart:305` → `_exportSemester` `:443`) | **not redundant**: it is what the board's Export pill does. Its result snackbar uses the legacy font | keep; restyle the snackbar with `TypeScale` (T9.2) |
| `setnavcolor()` | `script.dart:232`, called from `home_page.dart:90`, `:436` | sets the legacy system nav bar colour; the new nav has its own colours | keep until the theme work (T9.2) moves it to `SystemUiOverlayStyle` from the palette |
| Generic list picker in Settings | `settings_page.dart:112-160` | duplicates `ProgrammePickPage` for disciplines | use `ProgrammePickPage` for the two degree rows; keep `_pick` for Campus and Batch |

Retired features have no leftovers: the retired-tag tests (`test/shared/retired_test.dart`)
cover the one intentional legacy state.

## 20 · Task cards, in build order

### 20.0 How to work a card
Every card has **Goal**, **Files**, **Steps**, **Tests**, **Check** and **Done**. Do one card
at a time, in order: later cards assume the shared parts from earlier ones. Don't start a
group until the previous group is committed.

**Setup, once per session**:
- `export PATH=<flutter>/bin:$PATH`: Flutter **3.47.5**, Dart 3.7. If git complains about
  "dubious ownership" of the SDK, run `git config --global --add safe.directory <flutter dir>`.
- `flutter pub get`.
- Baseline at `8037abc`:
  - `flutter analyze`: 7 infos, all in legacy files: `home_page.dart:20`, `script.dart`
    (217, 229, 310, 311), `add_course_test.dart:16`, `edit_course_test.dart:11`. Any new
    issue is yours.
  - `flutter test`: 345 passed, 43 skipped. The skips need private fixtures, which are
    gitignored.

**The loop for each card**:
1. Read the card, the Part 2 section it names, and the board (Artifact tool, `path:
   project/<Board>.dc.html`). The board wins unless a Departure is written down.
2. Change only the files the card names. If you must touch another file, say why in the log.
3. Write the tests the card lists.
4. Run `flutter analyze` and `flutter test <the files you touched>`. At the end of each group,
   run `flutter test` in full. Run `cd test/rules && npm test` when `firestore.rules`,
   `storage.rules` or `firestore.indexes.json` changed.
5. Shoot: `SHOTS_DIR=<scratch dir> flutter test <the screen's shot test>`. Look at light and
   dark at 390 and 320, and at 320 with `textScale: 2`, beside the board.
6. Add a line to §13 (the build log): the card id, the files, and any Departure.

**Rules that bind every card** (§1.3 and the user's rules):
- Dart 3.7: no null-aware elements (`?x` inside a list literal).
- `dart format` only on new files or files already formatted at HEAD; never on CRLF or legacy
  files (`home_page.dart`, `script.dart`, `course.dart`, `mastercourselist.dart`, `sync.dart`,
  `main.dart`). Check a file with `dart format --output=none --set-exit-if-changed <file>` at
  HEAD first.
- Widget tests never trigger Hive writes through the UI. Test storage in unit tests; where a
  UI test must save, wrap the tap in `t.runAsync` as `marks_test.dart` does.
- A new top-level route segment needs a line in `landing/_redirects`.
- No real emails in code, docs or tests. Use made-up BITS-style addresses
  (`f20230802@goa.bits-pilani.ac.in`).
- Don't touch sign-in for the iPhone `redirect_uri_mismatch` issue.
- **Git**:
  - Stage named files only (never `git add -A`).
  - Never commit `test/fixtures/transcript.csv`, `test/fixtures/performance_sheet.json`, any
    `*.pdf`, `PLAN.md`, `idthp`, screenshots or `test/ui/zz_*`.
  - Commit once per group, with the trailer `Co-Authored-By: Claude Opus 5.5
    <noreply@anthropic.com>`.
  - The user pushes, merges and deploys.
- **Stop and ask the user** when a card says **Ask**, when a board and ARCHITECTURE disagree
  on behaviour, or when a fix would change stored data.

---

### Group 2 · finish (Stats, Settings)

**T2.1 · Stats axes (§7.1)**
- **Goal**: y shows only the whole numbers the data spans, labelled "9.0"; x labels only
  first, current, last and a landmark (Practice School).
- **Files**: `lib/features/stats/widgets/cgpa_chart.dart`, `test/stats/stats_test.dart`.
- **Steps** (this exact change was tested on 27 Sep 2026 and then reverted, as the user asked
  for a guide first; re-apply it):
  1. Add two top-level functions above `_ChartPainter`:
     ```dart
     /// The y axis: the whole numbers the [values] span, at least one apart,
     /// within 0–10.
     (double, double) yRange(Iterable<double> values) {
       final lo = math.max(0.0, values.reduce(math.min).floorToDouble());
       final hi = math.min(10.0, values.reduce(math.max).ceilToDouble());
       if (hi - lo >= 1) return (lo, hi);
       return hi < 10 ? (lo, lo + 1) : (hi - 1, hi);
     }

     /// The x labels, most important first: the first semester, the current one
     /// ([current], -1 with none), the last, and a landmark (Practice School).
     List<int> xLabels(List<String> sems, int current) {
       final ps = sems.indexWhere((s) => s.trim().toUpperCase().startsWith('PS'));
       final out = <int>[];
       for (final i in [0, current, sems.length - 1, ps]) {
         if (i >= 0 && i < sems.length && !out.contains(i)) out.add(i);
       }
       return out;
     }
     ```
  2. In `paint`:
     - Replace the `lo` / `hi` lines with `final (lo, hi) = yRange(values);`.
     - Set the paddings to `left = 22, bottom = 16`.
     - Change `text()` to take a size: `TextPainter text(String s, [Color? c, double size =
       9.5])`, with weight `c == null ? w500 : w700`.
  3. Grid: step 0.5 while `hi - lo <= 3`, else 1. Label only whole numbers, with
     `v.toStringAsFixed(1)` at size 8.
  4. X labels: `for (final i in xLabels(sems, actual.length - 1))`, at size 7.5. Clamp each
     label inside the chart, and skip one whose rect (inflated by 3) overlaps a label already
     drawn. That keeps first, current and last when they are close.
  5. Board strokes:
     - target: 2 wide, dashes 5 on / 4 off (`d += 9`, `d + 5`)
     - actual and forecast: 2.6 wide
     - forecast: dashes 6 on / 5 off (`d += 11`, `d + 6`)
  6. `tag()` calls `text(v.toStringAsFixed(2), c)`.
- **Tests**: add a group `chart axes (board Stats)`:
  - `yRange([8.76, 7.28, 7.71, 8.10, 8.0]) == (7.0, 9.0)`
  - `yRange([8.2, 8.4]) == (8.0, 9.0)`
  - `yRange([9.0, 9.0]) == (9.0, 10.0)`
  - `yRange([10.0]) == (9.0, 10.0)`
  - With `sems = ['1 - 1','1 - 2','2 - 1','2 - 2','PS 1','3 - 1','3 - 2','4 - 1','4 - 2','5 - 1']`:
    `xLabels(sems, 7) == [0, 7, 9, 4]` and `xLabels(['1 - 1','1 - 2'], -1) == [0, 1]`.
- **Check**: the Stats shot. Four x labels at most, and y labels like "8.0".
- **Done**: `flutter test test/stats` passes (19 at the time of writing) and analyze is clean.

**T2.2 · Degree names and order (§7.2)**
- **Goal**:
  - Order: the first degree (B…, `cdc1` / `del1`), then the second (A…, `cdc2` / `del2`),
    then Humanity and Open.
  - Names: "B3 Core" with a muted " · CDC1" suffix, "A7 Core · CDC2", "Disciplinary
    Elective 1" / "Disciplinary Elective 2".
  - A single degree: "A7 Core" and "Disciplinary Electives", with no suffix and no number.
- **Files**: `lib/core/grading/requirements.dart` (the `cards` list at `:378-414`),
  `lib/features/stats/widgets/degree_view.dart` (titles at `:236` and `:264`), and these tests:
  - `test/grading/requirements_test.dart` (102, 103, 108, 126, 141, 142, 267, 295)
  - `test/stats/stats_test.dart` (214, 275, 308, 312, 360, 363, 455, 460)
  - `test/shared/retired_test.dart:136`
- **Steps**:
  1. In `cards`, move the `if (hasB) ...[...]` block **above** `if (hasA) ...[...]`.
  2. Labels:
     - `hasB` core: `'$first Core · CDC1'`
     - `hasA` core: `dual ? '$second Core · CDC2' : '$second Core'`
     - electives: `dual ? 'Disciplinary Elective 1' : 'Disciplinary Electives'` for `del1`,
       and the same with "2" for `del2`
     - The sheet-based `'Core courses (CDC)'` card is unchanged.
  3. In `degree_view.dart`, split the title on `' · '`: the first part in the title style,
     and `· CDC1` in the same size at w500 `textMuted` (`Text.rich`). The label stays one
     string for semantics.
  4. Leave `categoryLabel` in `add_course_controller.dart` as it is (a different screen).
- **Tests**:
  - Update the listed expectations to the new strings.
  - Add `test('dual degree order and names')`: for `'B3A7'` the labels start `['B3 Core ·
    CDC1', 'Disciplinary Elective 1', 'A7 Core · CDC2', 'Disciplinary Elective 2',
    'Humanity Electives', 'Open Electives']`.
  - For `'--A7'`: `['A7 Core', 'Disciplinary Electives', 'Humanity Electives', 'Open
    Electives']`.
- **Check**: the StatsDegree shot: B3 first, suffix muted.

**T2.3 · Settings discipline value (§7.3)**
- **Goal**: "A7 · Computer Science": the code first, the degree prefix dropped, ellipsized,
  with the full name as tooltip and semantics.
- **Files**: `lib/features/settings/settings_controller.dart`,
  `lib/features/settings/settings_view.dart:160-166`, `test/settings/settings_test.dart`.
- **Steps**:
  1. Add `String shortProgrammeLabel(String code)` to `settings_controller.dart`:
     - `'--'`, `'B-'` or empty → the existing "None" / "Other" text
     - anything else → `'$code · ${programmeName(code).replaceFirst(RegExp(r'^(B\.E\.|M\.Sc\.|B\.Pharm\.)\s*'), '')}'`.
       Today's names start with "B.E." (11), "M.Sc." (6) or "B.Pharm." (1).
  2. Use it for both `value:` lines. Wrap the value `Text` in `Tooltip(message:
     disciplineLabel(...))` and give it `semanticsLabel` with the full name.
     `maxLines: 1, overflow: ellipsis` (it already ellipsizes).
- **Tests**:
  - Unit: `shortProgrammeLabel('A7') == 'A7 · Computer Science'` and
    `shortProgrammeLabel('B3')` starts with `'B3 · '`.
  - Widget: at 320 the value `Text` shows `A7 · Computer Science`.
- **Check**: the Settings shot at 320: no "Scienc…".

**T2.4 · Close Group 2**
- Delete nothing tracked. Leave `test/ui/zz_audit_*.dart` untracked, or delete them.
- Add §13.2's final entry: T2.1–T2.3, files, and "Departures: none".
- Run the whole suite, then commit:
  ```
  git add lib/features/stats/widgets/cgpa_chart.dart lib/core/grading/requirements.dart \
    lib/features/stats/widgets/degree_view.dart lib/features/settings/settings_controller.dart \
    lib/features/settings/settings_view.dart test/stats/stats_test.dart \
    test/grading/requirements_test.dart test/shared/retired_test.dart \
    test/settings/settings_test.dart UI.md
  git commit -m "UI group 2: Stats axes, degree names and order, discipline label"
  ```
  with the trailer. Hand the user: `git push -u origin pointer-rebuild`.

---

### Group 3 · global fixes and shared parts

**T3.1 · G1 + N8: one Material theme per palette**
- **Goal**: in dark mode, every `Text` without a colour is readable. Every Material widget is
  in Montserrat. Switches, dialogs, sheets, snackbars and date pickers use the palette.
- **Files**: `lib/app/theme/palette.dart` (`materialTheme`, `:108-117`),
  `test/theme/palette_test.dart`.
- **Steps**: replace the getter with:
  ```dart
  ThemeData get materialTheme {
    final b = isDark ? Brightness.dark : Brightness.light;
    final scheme = ColorScheme.fromSeed(seedColor: accent, brightness: b).copyWith(
      primary: inverse, onPrimary: onInverse, secondary: accent,
      surface: surface, onSurface: text, onSurfaceVariant: textMuted,
      outline: outline, outlineVariant: divider, error: behind,
    );
    final base = ThemeData(
      brightness: b, colorScheme: scheme, fontFamily: TypeScale.family,
    );
    TextStyle btn(Color c) =>
        TypeScale.button.copyWith(fontWeight: FontWeight.w700, color: c);
    return base.copyWith(
      scaffoldBackgroundColor: background,
      textTheme: base.textTheme.apply(
        fontFamily: TypeScale.family, bodyColor: text, displayColor: text),
      primaryTextTheme: base.primaryTextTheme.apply(fontFamily: TypeScale.family),
      iconTheme: IconThemeData(color: icon),
      dividerColor: divider,
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(
        foregroundColor: accent, textStyle: btn(accent),
        minimumSize: const Size(Sizes.minTouch, Sizes.minTouch))),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
        backgroundColor: inverse, foregroundColor: onInverse,
        textStyle: btn(onInverse), shape: const StadiumBorder())),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
        foregroundColor: text, side: BorderSide(color: text, width: 1.5),
        textStyle: btn(text), shape: const StadiumBorder())),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? hero : surface),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? inverse : divider),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent)),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? inverse : null),
        checkColor: WidgetStatePropertyAll(onInverse)),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.row)),
        titleTextStyle: TypeScale.section.copyWith(color: text),
        contentTextStyle: TypeScale.body.copyWith(
          color: textMuted, fontWeight: FontWeight.w500)),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: background, dragHandleColor: outline),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: inverse, behavior: SnackBarBehavior.floating,
        contentTextStyle: TypeScale.body.copyWith(color: onInverse)),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: surface, headerForegroundColor: text),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TypeScale.body.copyWith(color: textMuted, fontWeight: FontWeight.w500),
        labelStyle: TypeScale.body.copyWith(color: textMuted)),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: text),
      extensions: [this],
      pageTransitionsTheme: base.pageTransitionsTheme, // keep the existing builders map
    );
  }
  ```
  - Keep the existing `PageTransitionsTheme` with `CircleRevealTransitionsBuilder`; don't
    drop it.
  - If a named parameter doesn't exist in 3.47 (for example `DialogThemeData`), use
    whatever `flutter analyze` suggests.
  - `palette.dart` imports `tokens.dart` (it may already).
- **Tests** (`test/theme/palette_test.dart`):
  - `AppPalette.dark.materialTheme.brightness == Brightness.dark`
  - `...textTheme.bodyMedium!.color == AppPalette.dark.text`
  - `...textTheme.bodyMedium!.fontFamily == TypeScale.family`
  - pump a `TextButton(child: Text('x'))` under the dark theme and check the `RenderParagraph`
    font family is `MontserratFull`
- **Check**: re-shoot Controls (`AdminHome`) in dark: every row title is readable. The
  audit's `m_admin_home_dark_390` showed them missing.
- **Material widgets to restyle later**. After T3.1 they are readable; each screen's card
  replaces them with board parts:
  - `admin/bulk_upload.dart:98,102`
  - `admin/config_pages.dart:106,370,422`
  - `admin/dept_resources.dart:393,502,518,624,697`
  - `admin/dept_reviews.dart:110,120,128,192,196`
  - `admin/grant_form.dart:224,307`
  - `admin/maintain.dart:231,235,391,428,446,508`
  - `admin/open_as.dart:104`
  - `admin/people.dart:238,242`
  - `admin/professors.dart:64,68,304,489,553`
  - `admin/publish_page.dart:185,209,328`
  - `admin/scheme_editor.dart:301,332,343,412`
  - `admin/succession.dart:174`
  - `admin/volunteers.dart:171,193`
  - `features/roles/rep_profile.dart:135,231`
  - `features/roles/role_switch_page.dart:171,182`
  - `features/more/representatives_page.dart:182,248`
  - `features/reviews/course_reviews.dart:262`
  - `features/reviews/review_widgets.dart:216,221`
  - `features/resources/resources_page.dart:207,273`

**T3.2 · G2: pills and tags hug their text; equal tab rows**
- **Files**: `lib/admin/widgets.dart` (`TierTag :128-159`, `ChoicePills :237-294`),
  `test/shared/widgets_test.dart`.
- **Steps**:
  1. `TierTag`: remove `alignment: Alignment.center` from the `Container`, and wrap the
     `Text` in `Center(widthFactor: 1, heightFactor: 1, child: …)`.
  2. `ChoicePills`: the same for the inner `Container` (`:273-287`). Add `final bool equal;`
     (default false). When `equal` is true, build a `Row` of `Expanded` children with 6 px
     gaps instead of the `Wrap`. Also add `final String Function(T)? count` (optional),
     rendered after the label as " 214".
  3. Use `equal: true` for tab rows:
     - Maintainers' five filters (`people.dart:169`)
     - Roster's filters
     - DeptReviews' All / Reported / Hidden
     - Open as' campuses
     - Merge's campuses

     Leave choice rows (tiers on Appoint, methods on Public contact) as a hugging `Wrap`.
- **Tests**:
  - A `TierTag('OWNER')` inside a 300-wide `Wrap` is narrower than 100.
  - `ChoicePills(equal: true)` with 4 values in 320 gives 4 children of equal width.
- **Check**: Maintainers and Roster shots: one row of filters, tags hugging.

**T3.3 · N2: mint, not dark green**
- **Files**: `lib/admin/widgets.dart:84,87` (NavRow tile), `:145,154` (TierTag),
  `:175,182,190` (ScopeChip).
- **Steps**: replace `p.accent` with `p.hero` for those fills; keep `p.onHero` for their
  text and icons. Then set `TierTag`'s tones from the boards:
  - `strong` (OWNER, ADMIN, CR): `navBackground` fill (ink in both modes) with `hero` text
  - PRESIDENT: `hero` with `onHero`

  In dark, `navBackground` on `surface` needs a 1 px `divider` border so the tag's edge shows.
  Board variants (RolePick's blue ADMIN, grey CR) are a Departure: one tone set.
- **Tests**: `TierTag(strong: false)`'s `BoxDecoration.color == AppPalette.light.hero`.
- **Check**: the Maintainers light shot: PRESIDENT is mint with ink text.

**T3.4 · G3: router error page, the volunteers route, and the missing-course message**
- **Files**: `lib/app/router.dart:28-32` and the `admin` routes (`:104-129`),
  `lib/admin/roster.dart` (add `initialVolunteers`), `test/app/routes_test.dart`.
- **Steps**:
  1. `GoRouter(errorBuilder: (c, s) => const NotFoundPage())`. `NotFoundPage` is a new
     widget in `lib/shared/widgets/page_header.dart` or its own file: a `PageFrame` with
     eyebrow "POINTER", title "This page doesn't exist", a `Note` "The link may be old, or
     the page moved.", and a `PrimaryButton` "Home" → `context.go(Routes.home)`. No red
     text, no exception string.
  2. `RosterPage` gains `this.initialVolunteers = false`; in `initState`,
     `_volunteers = widget.initialVolunteers`.
  3. Register `_admin('roster/volunteers', () => admin.RosterPage(initialVolunteers:
     true, volunteersTab: (c) => admin.VolunteersTab(campus: c)), _staff)` **before**
     `'roster'`. `admin` is already in `_redirects`, so no new line is needed.
  4. `course/:id` redirect (`:90`): keep the redirect Home, and also show a snackbar "That
     course isn't in your list." once. Use the root `ScaffoldMessenger` via a global key
     already used in `main.dart`, or skip this step if none exists and record it.
- **Tests**:
  - `appRouter` resolves `/admin/roster/volunteers` to `RosterPage` with
    `initialVolunteers` (with `myRoles` = owner).
  - `/nope` builds `NotFoundPage`.
- **Check**: `routes_test.dart` passes; the `_redirects` test still passes.

**T3.5 · G4 + N7 + N10: the missing index and friendly errors**
- **Files**: `firestore.indexes.json`, `lib/admin/widgets.dart` (`problem()`, `Loaded`),
  `test/rules` (only if the emulator loads indexes).
- **Steps**:
  1. Add to `indexes`:
     ```json
     { "collectionGroup": "entries", "queryScope": "COLLECTION_GROUP",
       "fields": [ {"fieldPath": "campus", "order": "ASCENDING"},
                   {"fieldPath": "department", "order": "ASCENDING"},
                   {"fieldPath": "hidden", "order": "ASCENDING"},
                   {"fieldPath": "reports", "order": "DESCENDING"} ] }
     ```
     Keep the 2-space JSON style of the file.
  2. `problem(e)`:
     - keep the two plain messages
     - otherwise `debugPrint('$e')` and return `"Couldn't load this. Try again."`
     - if `'$e'.contains('failed-precondition')`, return `"This list needs a database update
       an owner has to deploy. Try again later."`
     - never include `$e`
  3. `Loaded`'s error branch: show that text with the palette's `noticeTone` in a `Notice`
     (T3.10), plus a 44 px "Try again" button that calls `reload`.
- **Tests**:
  - `problem(Exception('[cloud_firestore/failed-precondition] … https://console…'))`
    contains no "http".
  - A widget test: `Loaded(load: () async => throw …)` shows "Try again", and tapping it
    calls `load` again.
- **Hand the user**: `firebase deploy --only firestore:indexes` (the index takes minutes to
  build). The user runs deploys.

**T3.6 · G5: a non-BITS owner gets their roles (§10.0)**
- **Files**: `lib/main.dart:93-107`, `test/roles/…` (new test file
  `test/roles/non_bits_owner_test.dart` for the pure part).
- **Steps**:
  1. Pull the block into a function in `lib/core/roles/session.dart`:
     `@visibleForTesting RoleStore startRoles(FirebaseFirestore db, {required String email,
     required String name})`. It creates the `RoleStore` for **any** signed-in email.
     `recordSignIn` runs only when `campusOfAddress(email)` is non-null, as now. Then call
     `refreshMyRoles().then((_) => checkProfile())` for everyone.
  2. Keep `mayUseApp` as it is (`auth_util.dart:33`): a non-BITS account is let in only if
     `isOwner`. So this change affects owners only.
  3. `main.dart` is legacy-formatted: edit by hand, don't `dart format` it.
- **Tests**: with a `FakeFirebaseFirestore` holding `owners/{x@example.com}` active, and
  `startRoles(db, email: 'x@example.com', name: 'X')`, then `await refreshMyRoles()`:
  `myRoles.value.owner == true`, `roleStore != null`, and no `people` doc was written.
- **Check**: a manual check on the live site after deploy. **Ask the user** to sign in with
  the non-BITS owner account and open `/calculator/admin`.
- **Then**: OwnerSetup (T4.6).

**T3.7 · G6: amber badges for waiting work**
- **Files**: new `lib/shared/widgets/count_badge.dart`; `lib/admin/maintain.dart` (the
  scheme count on DeptHome) and `admin_home.dart` (Publish, when T8.1 feeds it).
- **Steps**: `CountBadge(String text, {CountTone tone = CountTone.waiting})` with the tones:
  - `waiting`: `noticeTone.fill` / `.text`
  - `on`: `hero` / `onHero` ("ON")
  - `neutral`: `mutedTone`

  Size 24 tall, radius 12, padding 0 10, 10.5/800. Replace the mint badge on DeptHome
  ("131 have no scheme") with `waiting`.
- **Tests**: `CountBadge('3')` decoration colour `== noticeTone.fill`.

**T3.8 · N3: the leading header, and titles that never break mid-word**
- **Files**: `lib/shared/widgets/page_header.dart`, `test/shared/widgets_test.dart`.
- **Steps**:
  1. `PageHeader` gains `final bool leading;` (default **true** for pushed screens) and
     `final bool close;`.
     - `leading: true` lays out `[Back 44] 12 [eyebrow / title]`.
     - `leading: false` keeps today's `[eyebrow / title] [actions] [Back]` (top-level
       screens: Controls, Your department, Stats, Marks).
     - `close: true` draws ✕ (`Icons.close_rounded`, tooltip "Close") instead of the arrow
       (Course setup, Edit evaluative).
  2. Title at 21/700 −0.5 for pushed screens (board `.lbl` + 21px), and 22 for the rest as
     today.
  3. Words never break: wrap the title in a `LayoutBuilder`. Measure the **longest word** with
     a `TextPainter` using the title style merged into `DefaultTextStyle.of(context).style`,
     at `MediaQuery.textScalerOf(context)`. If it is wider than `constraints.maxWidth`, wrap
     the title in `MediaQuery(data: …copyWith(textScaler:
     TextScaler.linear(fit)))`, where `fit = maxWidth / longestWordWidthAtScale1` (floored
     at 1.0). The title still wraps between words.
  4. Don't add a new widget per screen. Pushed screens pick the leading layout by default.
     Check each `PageHeader(` call (`grep -rn "PageHeader(" lib`) and pass `leading: false`
     only for the four top-level screens.
- **Tests**: at 320 wide and `textScale: 2`, `PageHeader(title: 'Maintainers')` renders the
  title on **one** line (`RenderParagraph.didExceedMaxLines == false` and one line).
  "Representatives" likewise.
- **Check**: re-run the audit shots at 320 2×: no split words.

**T3.9 · N4, N5, N6: small helpers**
- **Files**: `lib/admin/widgets.dart`, and the call sites named.
- **Steps**:
  1. **`ago()`**: `'${n} minute${n == 1 ? '' : 's'} ago'`, the same for hours; "1 day ago"
     is covered by "Yesterday".
  2. **`LabelRow(label: Widget, trailing: Widget)`**: a `LayoutBuilder`. If `maxWidth -
     trailingIntrinsicWidth < 96`, show a `Column(label, 6, Align(right, trailing))`;
     otherwise a `Row(Expanded(label), 8, trailing)`. Use it for:
     - CrHome's section heads with Change / Add (`maintain.dart` near `:508`)
     - DeptCourses' EXTRACTION PROMPT head (`:391`)
     - each Terms row (`config_pages.dart:189-240`)
  3. **`NameEmail(name, email)`**: `Row(Text(name, 13/700, maxLines 1), 8, Flexible(Text(email,
     11/500 textMuted, maxLines: 1, overflow: ellipsis, softWrap: false)))`. The name keeps its
     width up to 60% of the row (`ConstrainedBox(maxWidth: c.maxWidth * .6)`) and ellipsizes
     past that. Use it in:
     - Maintainers' and Roster's grant blocks (`people.dart`, `roster.dart`)
     - Owners (`config_pages.dart`)
     - Audit log (`AuditTile`)

     Add `shortEmail(e)` = the part before `.bits-pilani.ac.in` ("f20230456@goa") for the
     Audit log only.
- **Tests**:
  - `ago(now - 1h) == '1 hour ago'`
  - `LabelRow` at 200 wide with a 150-wide trailing stacks
  - `NameEmail` at 320 × 2× text: the email is one line

**T3.10 · The shared parts from §3 that later groups need**

Build each in `lib/shared/widgets/`, with a widget test and one `shoot()` in
`test/ui/board_shots_test.dart`. APIs:

| Part (§3) | API | Notes |
|---|---|---|
| `CardLabel` (3.4) | `CardLabel(String text)` | 10.5/700 +0.5, upper case, `textMuted`, no padding |
| `SegmentedPair` (3.7) | `SegmentedPair<T>({required (T,String) a, required (T,String) b, required T value, required ValueChanged<T> onChanged, double height = 44})` | two equal buttons, radius 14; selected ink |
| `SegmentedTrack` (Roster, ReviewsSearch) | `SegmentedTrack<T>({required List<(T,String)> tabs, required T value, required ValueChanged<T> onChanged})` | 40 tall, radius 20, `mutedTone.fill` track, padding 3, selected ink radius 17 |
| `TagBadge` (3.9) | `TagBadge(String text, {TagTone tone})`; tones `official`, `yours`, `updated`, `fromParts`, `dropped`, `confirm` | 20–22 tall, radius 10–11, 9.5–10/800 +0.3 upper case |
| `Notice` (3.10) | `Notice({required InlineSpan text, IconData icon = Icons.info_outline_rounded, bool warning = false})` | `noticeTone`; radius 16; padding 9/12; move Marks' inline notice here |
| `CardRow` + `CardDivider` (3.13) | `CardRow({Widget? leading, required String title, String? subtitle, Widget? trailing, VoidCallback? onTap, double minHeight = 52})` | the admin `NavRow` becomes a thin wrapper over it (tile + CardRow) |
| `CodeBadge` (3.14) | `CodeBadge(String code, {CodeTone tone})`; tones `neutral`, `first` (mint), `second` (ink / mint), `selected`, `empty` (dashed) | 38 × 28–30, radius 9–10 |
| `SearchBox` (3.20) | `SearchBox({required TextEditingController controller, required String hint, Widget? trailing})` | 46 tall, radius 23, surface, 16 px search icon; `trailing` for the "No scheme" link |
| `BottomAction` (3.24) | `BottomAction({required Widget child, String? caption, double fade = 132})` | a `Stack` overlay: fade gradient `IgnorePointer`, then the child 44 above the safe bottom; the scroll view pads by `BottomAction.heightOf(context)` |
| compact field (3.19) | `CompactField({required TextEditingController c, String? hint, bool official = false})` | 36 tall, radius 11 |
| `AppTextField` label-above style (3.18) | `AppTextField(labelAbove: true)` | label 9.5–10/700 +0.4 upper case above a 46 tall box |
| `PrimaryButton.tall` (3.21) | `PrimaryButton(tall: true)` | 56 tall, 14.5/700 |
| `OutlinedPill` (3.22) | `OutlinedPill({required String label, IconData? trailing, required VoidCallback? onPressed})` | 42 tall, 1.5 px ink border |
| `CountBadge` | T3.7 | |

**T3.11 · Close Group 3**
- Re-run both audit harnesses (§14) and compare with the board sheets. In dark, every text
  must be readable.
- Log T3.1–T3.10 in §13, commit, and hand the user the push command and
  `firebase deploy --only firestore:indexes`.

---

### How the cards in Groups 4–8 are checked

Each card names its **render test**: a row in one of three committed files. All three read the
fake data in `test/helpers/fake_data.dart` (§14.1):

| File | What it renders |
|---|---|
| `test/ui/student_screens_test.dart` (`s_…`) | the student screens |
| `test/ui/sheet_screens_test.dart` (`d_…`) | sheets and dialogs, opened from a launcher |
| `test/ui/manager_screens_test.dart` (`m_…`) | manager screens, each as its role |

Each row renders light and dark at 390 and 320, and 320 at 200% text, and fails on any layout
error. A screen with a known bug sits in that file's `known` map with its N-number. **When you
fix it, its test fails until you delete its `known` line**; that is the proof the fix
landed. Look at the shots with:

```
SHOTS_DIR=/tmp/shots flutter test test/ui/<file>_test.dart --plain-name <row name>
```

Put them beside the board: Artifact `read` of `project/<Board>.dc.html`, rendered in a
browser, or look at the canvas.

Every card also adds **behaviour tests** in the screen's own test file. The card names them
and gives their key `expect`s.

### Group 4 · getting in (§4)

**T4.1 · Loading footer** (§4.2)
- **Files**: `web/index.html` only.
- **Steps**: inside `.ptr-seo`, before the `h1`, add `<p class="ptr-by">Built By Siddharth
  Mishra</p><p class="ptr-private">Your grades stay private to your account.</p>`. Style them
  11.5/700 ink and 10.5/500 `#6E6E63`, 14 apart, with dark-mode colours in the existing
  `@media (prefers-color-scheme: dark)` block.
- **Test**: none in Dart; check by opening `web/index.html` in a browser.

**T4.2 · Sign in** (§4.3)
- **Files**: `lib/features/auth/sign_in_view.dart`, `test/auth/sign_in_test.dart`.
- **Steps**:
  1. Replace the outer `Center` with a `LayoutBuilder` →
     `SingleChildScrollView(child: ConstrainedBox(minHeight: c.maxHeight, child:
     IntrinsicHeight(child: Column(…))))`, and put a `Spacer()` between the dashed note and
     the button.
  2. Top padding: `Space.xxl`.
  3. After the campus line add `Text('Your grades stay private to your account.\nReviews
     you write never carry your name.', textAlign: center, 10.5/500 textMuted)`, 10 below
     it. Then `Text('Built By Siddharth Mishra', 11/700 text)`, 8 below that.
  4. The button uses `PrimaryButton(tall: true)` (T3.10).
- **Tests** (`sign_in_test.dart`):
  - `'the button sits at the bottom'`: at 390 × 844,
    `t.getBottomLeft(find.text('Continue with Google')).dy > 844 - 120`.
  - `'privacy lines and footer'`: `find.textContaining('never carry your name')` and
    `find.text('Built By Siddharth Mishra')` each `findsOneWidget`.
- **Render test**: `s_sign_in`.

**T4.3 · Your degree** (§4.4)
- **Files**: `lib/features/setup/degree_setup_page.dart`, `test/setup/setup_test.dart`.
- **Steps**, following §4.4's six fixes in order:
  1. The address chips: `ScopeChip(campus, icon: Icons.place_outlined)` and
     `ScopeChip('$year batch', icon: Icons.calendar_today_rounded)`, height 32 (add a
     `height` parameter to `ScopeChip`).
  2. The programme pills: `PillButton(height: 38)` for single and dual. 2+2 is
     `DashedOutline(color: outline, radius: 19)` around a 62-wide label in faint text.
  3. Tapping 2+2 shows `Notice(warning: true, text: …)` with §4.4's copy, and changes
     nothing.
  4. Each degree row is `CodeBadge(code, tone: first ? CodeTone.first : CodeTone.second)`,
     then eyebrow and name, then a chevron. Unset: `CodeTone.empty` and "Choose a
     programme".
  5. `BottomAction(child: PrimaryButton(tall: true, label: 'Set up $first $second'),
     caption: 'Changing your first degree later clears your grades.')`. Disabled with "Pick
     what you are reading" until every degree row is picked.
- **Tests**:
  - `'2+2 shows the notice and keeps the choice'`: tap `2+2` → `find.byType(Notice)`
    `findsOneWidget`, and the Single pill is still selected.
  - `'button waits for the programme'`: with nothing picked, `PrimaryButton.onPressed ==
    null`, and its label is 'Pick what you are reading'.
- **Render test**: `s_setup`.

**T4.4 · Pick a programme** (§4.5)
- **Files**: `lib/features/setup/degree_setup_page.dart:103` (the call).
- **Steps**: when picking the **second** degree of a dual, pass only
  `programmesAt(campus).where((p) => !p.isMsc)`.
- **Test** (`setup_test.dart`): `'second degree lists only B.E.'`: open the second-degree
  picker; `find.text('B3')` `findsNothing`, and `find.text('A7')` `findsOneWidget`.
- **Render test**: `s_pick`.

**T4.5 · Import** (§4.6)
- **Files**: `lib/features/import/erp_import_page.dart`, new
  `test/import/erp_import_page_test.dart`.
- **Steps** (§4.6 fixes 1–5):
  1. Trim the lead to one sentence.
  2. `OutlinedPill('Open My Academics in ERP', trailing: Icons.open_in_new_rounded)`.
  3. The drop zone:
     - a `DashedOutline(color: Color(0xFF9CC9BA), width: 2, radius: 22)` over
       `hero.withValues(alpha: .34)`
     - a 44 white tile with an upload icon, the title, and the sub
     - the lock line **inside** the zone
     - web copy "Drop your performance sheet / or choose a file · PDF"; `!kIsWeb` copy
       "Choose your performance sheet / PDF"
  4. The install card: `navBackground` fill, a 36 mint tile holding `PointerMark`, "Install
     Pointer" / "Own icon, full screen, works offline", and a mint 36-tall "Install" button.
     Nudge: one `AnimationController(duration: 4.5 s)..repeat()`, driving
     `Transform.scale` of the card (1 → 1.035 → 1 over 76–90%) and `Transform.rotate` of the
     button (±6°, 80–95%). Build it only when `!MediaQuery.disableAnimationsOf(context)`.
     Hide the card when `installable == false`.
  5. `BottomAction` with "Skip — I will enter grades myself" (13/700 `icon` colour, a text
     button 44 tall) and the caption "You can import any time from Settings → Your data."
     Only when `onDone != null`.
- **Tests**:
  - `'no nudge under reduced motion'`: pump with `MediaQuery(disableAnimations: true)`;
    `find.byType(AnimatedBuilder)` inside the install card `findsNothing`.
  - `'Skip calls onDone'`.
  - `'Settings mode has no Skip'`: `ErpImportPage()` without `onDone`; `find.textContaining('Skip')`
    `findsNothing`.
- **Render test**: `s_import`.

**T4.6 · Owner setup** (§10.21; needs T3.6)
- **Files**: `lib/app/router.dart`, `lib/app/routes.dart`, `landing/_redirects`, new
  `lib/features/setup/owner_setup_page.dart`, new `test/setup/owner_setup_test.dart`.
- **Steps**:
  1. `Routes.ownerSetup = '/setup/owner'`, registered, plus
     `/calculator/setup/* /calculator/index.html 200` in `landing/_redirects`.
  2. The page follows the `OwnerSetup` board:
     - eyebrow "ONE-TIME SETUP · OWNER", the title and the lead
     - SIGNED IN AS with an OWNER `TierTag`
     - CAMPUS as a 2 × 2 grid of `PillButton(height: 38)`
     - BATCH as a label-above number field
     - `BottomAction` "Continue" with "Both are final once set, as they are for everyone
       else."

     It saves campus and batch exactly as `degree_setup_page.dart:201` does (reuse that
     code; don't copy the storage calls).
  3. In `main.dart`'s start-up (by hand, no format): when `myRoles.value.owner` and
     `campusOfAddress(email) == null` and no campus is stored, open `ownerSetup` first.
- **Tests**:
  - `'owner setup saves campus and batch'`: a unit test on the save function, not through
    the UI, because of the Hive rule.
  - `'a non-BITS owner lands on owner setup'`: the redirect function returns
    `/setup/owner`.
  - `routes_test` passes (the `_redirects` line).

### Group 5 · a course (§5)

**T5.1 · Marks** (§5.1, N28, N34, N35)
- **Files**: `lib/features/marks/marks_page.dart`,
  `lib/features/marks/widgets/evaluative_card.dart`, `test/marks/marks_test.dart`.
- **Steps**:
  1. The eyebrow: `'${code} · ${credits} CREDITS'.toUpperCase()`.
  2. **N28**: when the course has no weighted component, the hero shows "No marks yet"
     (`TypeScale.display` at 30) and hides "/ 0" and the graded / pending line.
  3. **N34**: in `evaluative_card.dart`, when the card is narrower than 340 (`LayoutBuilder`)
     or the text scale is above 1.3, put the title on its own line and the badge · weight ·
     score · copy row under it. Otherwise keep one row, with the title `Expanded`,
     `maxLines: 2` and ellipsized.
  4. **N35**: the TAKEN BY row uses `LabelRow` (T3.9) with the "Reviews" pill as trailing.
  5. The "Reviews" `TextButton` becomes `PillButton(height: 34)`.
- **Tests**:
  - `'empty course says No marks yet'`: a course with no evaluatives →
    `find.text('No marks yet')` and `find.textContaining('/ 0')` `findsNothing`.
  - `'eyebrow is upper case'`: `find.text('CS F372 · 4 CREDITS')`.
- **Render test**: `s_marks`. **Delete its `known` line** when N34 and N35 are fixed.

**T5.2 · Edit evaluative, rebuild** (§5.2)
- **Files**: `lib/features/marks/add_evaluative_page.dart` (rewrite the build; keep the save
  logic and its callers), new widgets in `lib/features/marks/widgets/parts_grid.dart`,
  `test/marks/marks_test.dart`.
- **Steps**, top to bottom as the `MarksAdd` board:
  1. `PageHeader(close: true, eyebrow: '$code · EDIT COMPONENT' | '$code · NEW
     COMPONENT', title: name or 'New component')`.
  2. `Notice` "**Official component.** Your marks are always yours. Changing the weight, an
     out of, a date or an average makes this component yours, and it stops updating." Only
     when `official != null`.
  3. A card:
     - COMPONENT NAME (label-above field)
     - a row: WEIGHT (86 wide) and "%"; CLASS AVERAGE as a mint-wash value when official
       ("12.40 of 20 · from parts"), otherwise a field
  4. A card: `SegmentedPair` One mark / Several parts; HOW MANY COUNT as `PillButton`s "All
     n" / "Best k of n", with the selected one in the mint count-pill tone.
  5. A PARTS card with column heads DATE · YOU · OUT OF · AVG (8.5/700). Each part:
     - a name field with copy and ✕ icon buttons (44)
     - a row "PART n" · date chip · you · out of · avg, all `CompactField`
     - the official avg as `TagBadge(official)` with the value
     - a dropped part dashed and faint

     At a width under 340 or a text scale above 1.3, each part's fields wrap onto a second
     line (`Wrap`).
  6. "+ Part" as a dashed pill.
  7. The mint hero "THIS COMPONENT GIVES YOU", with "best 2 of 3 · class 12.40" and
     "14.0 / 20".
  8. `BottomAction(PrimaryButton(label: 'Save'))`.
- **Tests** (`marks_test.dart`, taps in `t.runAsync` where they save):
  - `'official shows the notice'`
  - `'Best 2 of 3 counts two parts'`: set three parts 8, 6, 3 of 10, pick Best 2 → the
    hero reads '14.0'.
  - `'copy adds the next part below'`
  - `'a dropped part is marked DROPPED'`
- **Render tests**: `s_add_eval`, `s_edit_eval`.

**T5.3 · Course setup** (§5.3)
- **Files**: `lib/features/marks/course_setup_page.dart`.
- **Steps**:
  1. `PageHeader(close: true)`.
  2. HOW THIS COURSE IS GRADED: `SegmentedPair` 46 tall, with sublines ("each part has a
     %" / "one big total").
  3. COURSE IS MARKED OUT OF: an 86 wide field with a helper.
  4. SHOW IT OUT OF: pills 100 / 200 / 300 / Custom, the selected one mint.
  5. The mint RIGHT NOW card (entered → shown, and the formula line).
  6. EACH COMPONENT'S SHARE rows, then a Total row.
  7. CLASS AVERAGE: a field plus the mint-wash "You are 1.56 ahead…" line.
  8. The "Save setup" `PrimaryButton`.
- **Tests**: `'Total marks shows the rescale'`: select Total marks, total 300, show out of
  100 → `find.textContaining('shown out of 100')`.
- **Render test**: `s_course_setup`.

**T5.4 · Scheme editor and first divergence** (§5.4, N36)
- **Files**: `lib/features/marks/widgets/divergence.dart`, new
  `lib/features/marks/scheme_editor_page.dart` (student), shared parts with
  `lib/admin/scheme_editor.dart`.
- **Steps**:
  1. **N36 first**: wrap the sheet's column in `SingleChildScrollView`; pass
     `isScrollControlled: true`. Restyle it as the `Divergence` board (eyebrow in
     `noticeTone.text`, title, body, and two 44 pills: outlined "Keep it official", ink
     "Make it mine").
  2. Build the student scheme editor from the `Divergence` board. Its component rows reuse
     T5.2's `parts_grid.dart`.
- **Tests**: `'divergence sheet scrolls at 200% text'`, covered by removing `d_divergence`
  from `known` (the render test then must pass). Plus `'Make it mine returns true'`.
- **Render test**: `d_divergence`.

**T5.5 · After diverging** (§5.5) and **T5.6 · Average sources** (§5.6)
- **Files**: `marks_page.dart` (the diverged state),
  `lib/features/marks/widgets/average_sources.dart`.
- **Steps**: as §5.5 and §5.6. Each source is a `CardRow` with a `TagBadge` (OFFICIAL /
  YOURS / FROM PARTS) and the value in a 28 tall ink or mint pill.
- **Render test**: `d_average_sources`, and `s_marks` (the diverged state comes from the
  seed's detached component, once T5.4 lets you detach one in the seed).

### Group 6 · adding (§6)

**T6.1 · Grade menu** (§6.1)
- **Files**: `lib/features/semester/widgets/grade_menu.dart`.
- **Steps**: §6.1's label fix.
- **Render test**: `d_grade_menu`.

**T6.2 · Add a course** and **T6.3 · Enter it manually** (§6.2, §6.3)
- **Files**: `lib/features/semester/add_course_sheet.dart`, `widgets/course_fields.dart`.
- **Steps**:
  - Follow §6.2 and §6.3.
  - Replace the category `showMenu` (`course_fields.dart:108`) with a sheet of `CardRow`s,
    or with `ChoicePills` when there are five or fewer.
  - The "Over n credits" confirm becomes `ConfirmDialog` (T6.4).
- **Tests** (`add_course_test.dart`): `'manual needs code, title and credits'` (Save
  disabled until all three are set).
- **Render test**: `d_add_course`.

**T6.4 · The remaining Home dialogs** (`home_page.dart`, legacy, edit by hand)
- **Files**: new `lib/shared/widgets/confirm_dialog.dart`, `home_page.dart` (`:249`, `:480`),
  `edit_course_sheet.dart:84`, `add_course_sheet.dart:424`, `settings_page.dart:170`.
- **Steps**: build `Future<bool> confirmDialog(BuildContext c, {required String title,
  required String body, required String action, bool danger = false})`:
  - `surface` fill, radius 22
  - the title in `section` and the body in `body` w500 `textMuted`
  - two 44 tall pills: outlined Cancel, and ink `action` (or `behind` text on an outlined
    pill when `danger`)

  Use it at every listed call site.
- **Tests** (new `test/shared/confirm_dialog_test.dart`): Cancel → false; the action →
  true; dark theme text colour == `AppPalette.dark.text`.
- **Render test**: add a `d_confirm` row to `sheet_screens_test.dart`.

**T6.5 · Settings → Discipline opens Pick a programme** (§17)
- **Files**: `lib/features/settings/settings_page.dart:190-215`.
- **Steps**: replace `_pick(…)` with `Navigator.push` of `ProgrammePickPage(heading: dual ?
  'Dual degree' : 'Discipline', options: …, selected: half)`, using the same options
  filter as T4.4.
- **Test** (`settings_test.dart`): `'Discipline opens the programme picker'` → after the
  tap, `find.byType(ProgrammePickPage)` `findsOneWidget`.

**T6.6 · Edit course sheet** (no board, §17)
- **Files**: `lib/features/semester/edit_course_sheet.dart`.
- **Steps**:
  - Until the user supplies a board, restyle only: the "Counts as" `DropdownButton` becomes
    a `CardRow` opening a sheet of choices.
  - "Remove" is an outlined pill with `behind` text, and "Save" an ink pill.
  - Record a Departure.
- **Render test**: `d_edit_course`.

### Group 7 · More and Reviews (§8)

**T7.1 · More** (§8.2)
- **Files**: `lib/features/more/more_page.dart`.
- **Steps**:
  - The header eyebrow is "GOA · B3 A7 · 2026-27 SEM 1" (campus, discipline, term) over
    "More" 27/800.
  - Three 76 tall rows: surface, radius 22, a 44 mint tile with a 21 px icon, the title
    14/700 and the subtitle 10.5/500.
  - Then the "Everything here is for **Goa** only…" note.
- **Test** (`test/roles/step11_screens_test.dart` already pumps More):
  `find.textContaining('GOA ·')`.
- **Render test**: add `s_more` (it exists).

**T7.2 · Representatives** (§8.3)
- **Files**: `lib/features/more/representatives_page.dart`.
- **Steps**:
  - Leading header "GOA · A7" / "Representatives", and the lead copy.
  - DEPARTMENT card: a 38 mint code tile, the name and "Department president · email and
    phone shared", and two 36 tall pills (Email; the phone masked "98xxx 41xxx").
  - A HANDOVER IN n DAYS `TagBadge` when a successor exists.
  - YOUR COURSES THIS SEMESTER card rows: 32 round icon buttons for each shared channel, or
    a dashed "Volunteer" pill.
  - The ink "You are a CR for …" card with a mint Edit pill, for CRs only.
  - Replace the `TextButton.icon` links (`:182`, `:248`).
- **Tests**:
  - `'president card shows shared channels'` (seeded directory: email + WhatsApp).
  - `'no CR shows Volunteer'`.
- **Render test**: `m_representatives` (it renders as a student).

**T7.3 · The Reviews family** (§8.4–§8.10, N27)
- **Files**:
  - `lib/features/reviews/review_widgets.dart` (`StatsCard`, `ReviewTile`)
  - `reviews_home.dart`, `course_reviews.dart`, `professor_reviews.dart`,
    `review_form.dart`
- **Steps**:
  1. **N27 first**:
     - Rebuild `StatsCard` as the `Reviews` board's white summary card: "CS F301 · GOA · 41
       REVIEWS" label, "this campus only", "3.8 / 5" plus stars, "71% WOULD TAKE IT", and
       a 7 px mint / ink bar.
     - The right column is `Flexible` with `FittedBox(fit: BoxFit.scaleDown)`.
     - Delete `s_course_reviews` and `s_prof_reviews` from `known`.
  2. `ReviewsHome`:
     - `SegmentedTrack` "Courses" / "Your reviews · n"
     - `SearchBox` "Course code, name or professor"
     - YOUR COURSES THIS SEMESTER and MOST REVIEWED AT GOA card rows, each with 11 px stars,
       "71% take it · Dr. R. Menon" and a chevron
  3. `ReviewTile`:
     - a course chip (ink) and a term chip
     - stars and "4 of 5"
     - a TAKE IT (mint, ✓) or DON'T (grey, ✕) tag
     - the text
     - Helpful and Report as 32 tall pills (replace `:216`, `:221`)
  4. `review_form.dart`: follow the `ReviewWrite` and `ReviewEdit` boards; input stars 44
     hit, take-it `SegmentedPair`, the text field, and a `BottomAction`.
  5. `professor_reviews.dart`: follow the `ProfessorReviews` board.
- **Tests** (`reviews_screens_test.dart`):
  - `'summary card fits at 320 with 2x text'`: covered by the render test.
  - `'Your reviews tab counts mine'`: seed two reviews by `myUid` → 'Your reviews · 2'.
- **Render tests**: `s_reviews_home`, `s_your_reviews`, `s_course_reviews`,
  `s_prof_reviews`, `s_review_form`.

**T7.4 · Resources, Report this link, Empty** (§8.11–§8.13, N37)
- **Files**: `lib/features/resources/resources_page.dart`.
- **Steps**:
  1. **N37 first**: the report sheet (`_ReportSheet`) scrolls; `isScrollControlled: true`.
     Its `RadioListTile`s become 44 tall `CardRow`s with a radio dot. Delete `d_report_link`
     from `known`.
  2. The page follows §8.11: programme pills, link rows (a 30 px tile, the title, "domain ·
     added by", and ⋯), the ROLLUP explainer, and the `BottomAction` "Add a link" for
     maintainers.
  3. The empty state follows §8.13, with the public contact button from `config/public`
     (hidden when off).
- **Tests**:
  - `'report needs a reason'`: Send disabled until a reason is picked.
  - `'empty department shows the contact'`: from seeded `config/public`.
- **Render tests**: `s_resources`, `d_report_link`.

**T7.5 · Offshoot checkbox** (§8.1)
- **Files**: `lib/features/offshoot/offshoot_panel.dart`.
- **Steps**: §8.1's one fix.
- **Render test**: `semester_screenshots_test.dart` (the offshoot mode).

### Group 8 · managers (§10), in the canvas's role order

For every card:
- Replace the file's Material widgets (T3.1 list) with board parts.
- The render test is already in `manager_screens_test.dart` over seeded data.
- Behaviour tests go in `test/roles/step11_screens_test.dart`, next to the S1–S14 tests,
  using its `signIn` / `seedGrant` helpers.

**T8.1 · Controls** (`admin_home.dart`; §10.2, N11)
- **Steps**:
  1. The ink card uses `navBackground`: an OWNER / ADMIN `TierTag` (T3.3 tones), "$name —
     every campus, every department" 13/600 `onInverse`, and the explanation 10.5/500
     `#B0B0A4` (add `onInverseMuted` to the palette if missing).
  2. Rows are `CardRow` with live subtitles, each loaded once in `initState` with a
     `Future.wait`:
     - Maintainers: "n presidents · n course managers · n admins", from `roleStore.roster()`
     - Grant terms: "CR n semester · president n year · admin n years", from `terms()`
     - Public contact: "name · method · shown on empty pages", with `CountBadge('ON',
       tone: on)`, from `publicContact()`
     - Owners: "n active · you cannot remove yourself", from `owners()`
     - Publish catalogue: "n changes waiting", with `CountBadge('n')` amber, from
       `CatalogStore.drafts()`
  3. Site analytics: a disabled row, "Coming later".
  4. Keep the Roster and Open Pointer as rows (a Departure, already recorded).
- **Tests**:
  - `'Controls counts maintainers'`: with the seed → '1 president' appears (as owner:
    ELEC plus CS = 2 presidents; match the seed).
  - `'Publish shows waiting changes in amber'`.
- **Render tests**: `m_admin_home`, `m_admin_home_admin`, `m_admin_home_pres`.

**T8.2 · Owners** (`config_pages.dart` `OwnersPage`; §10.9, N16)
- **Steps**:
  - Owner blocks with `TierTag('OWNER')`, `NameEmail`, and the "You · first owner…" or
    "Added by …, 14 Sep" note.
  - A 30 tall grey "You can't remove yourself" chip on your own row, and a 32 tall outlined
    "Remove" pill (`behind` text) on the others.
  - INACTIVE owners, from `active: false`.
  - ADD AN OWNER with a label-above field, keeping the Name field (Departure, N16).
  - `BottomAction` "Add owner".
- **Tests**: `'Remove is 44 px'`: the hit area is ≥ 44 even though it is drawn 32 tall.
- **Render test**: `m_owners`.

**T8.3 · Publish** (`publish_page.dart`; §10.10)
- **Steps**:
  - Three cards from the drafts:
    - MOVES CGPAs · n: `noticeTone` fill, with a CONFIRM `TagBadge`
    - RETIRED · n
    - a "Titles and default tags · n" `CardRow`
  - The headcount note.
  - A `CheckboxListTile`-free checkbox row "I have read the n credit changes. They move
    CGPAs." that gates the `BottomAction` "Publish n changes".
  - "Draft a change to a course" as an `OutlinedPill`.
- **Tests**: `'publish waits for the credit-change checkbox'` (with the seeded CS F211
  credits draft).
- **Render test**: `m_publish`.

**T8.4 · Open as + ViewAsDept + ViewAsCourse** (`open_as.dart`; §10.22, N17)
- **Steps**:
  1. Build the `RolePick` layout: the ink identity card, then five rows with
     58-wide `TierTag`s, then an amber `Notice` and the footnote.
  2. Add the routes `admin/open-as/department` and `admin/open-as/course` under `admin`
     (no `_redirects` line). Two full pages follow the `ViewAsDept` / `ViewAsCourse`
     boards:
     - campus `ChoicePills(equal: true)`
     - a searchable list of departments (ELEC as one entry "A3 · A8 · AA · AC", with
       president counts) or of this term's offerings
     - the last opened on top, stored in `deviceBox`
  3. Remove the inline dropdown and course field.
- **Tests**: `'President row opens the department picker'`; `'last opened sits on top'`
  (unit test on the stored order).
- **Render test**: `m_open_as`. Add `m_view_as_dept` and `m_view_as_course` rows.

**T8.5 · Maintainers + Person** (`people.dart`; §10.3, N12)
- **Steps**:
  - `ChoicePills(equal: true)` filters.
  - Grant blocks: `TierTag`, `ScopePills`, and expiry on the right; `NameEmail`; the
    activity line.
  - A grant expiring within 7 days is a `noticeTone` block with "EXPIRES IN n DAYS" on the
    right and "Renewing is deliberate…".
  - `BottomAction` "Appoint someone".
  - Person: restyle with `CardRow`s and record a Departure until a board exists (§17).
- **Tests**: `'expiring grant is amber'`, using the seed's CS president with 4 days left.
- **Render tests**: `m_people`, `m_person`.

**T8.6 · Appoint** (`grant_form.dart`; §10.4, N18)
- **Steps**:
  1. BITS STUDENT ADDRESS: a label-above field. Look up on change (debounced 400 ms)
     instead of a "Look up" button.
  2. On a hit: `ScopeChip(campus, icon: lock)` and `ScopeChip('Student · 2023')`, plus a
     mint-wash "✓ Meera Iyer uses Pointer".
  3. The rule text, with **Can not be found** in `#9A2F14`. Add a `behind` role variant if
     needed.
  4. The red-brown refusal box.
  5. TIER: hugging pills, with Admin only for owners.
  6. SCOPE · ONE PER GRANT: a select-style `CardRow` opening a sheet (not a Material
     dropdown). APPOINTED FOR as equal 32 tall pills.
  7. EXPIRES: "Full term · n" / "Earlier date", then the "Ends …" line.
  8. `BottomAction(label: grantLabel(tier, scope, campus))`: "Grant" until an address
     resolves.
- **Tests**:
  - `'grant button names the grant'` → 'Grant — president, ELEC Goa'.
  - `'unknown address says Can not be found'`.
- **Render tests**: `m_grant`, `m_grant_pres`.

**T8.7 · Grant terms** (`TermsPage`; §10.5, N14)
- **Steps**:
  - Rows show a boxed number plus a unit. The CR row shows semesters, `(days / 182).round()`,
    and − / + add ±182 days. President and admin rows show years with ±365 days.
  - For an admin, the admin row is locked: a lock icon and "2 years" in a grey pill.
  - The two rule chips, then a `Notice`.
  - Each row uses `LabelRow` so it stacks at 2× text (N4).
- **Tests**:
  - `'CR term shows semesters'`: seed 183 days → '1' and 'semester'.
  - `'admin cannot change the admin term'`: as admin, the admin row has no buttons.
- **Render tests**: `m_terms`, `m_terms_admin`.

**T8.8 · Public contact** (`PublicContactPage`; §10.6, N15; **ask the user first**)
- **Steps**:
  - A switch row "Show on empty pages" / "Off hides the whole block, everywhere." (themed
    switch).
  - NAME ON THE BUTTON field.
  - HOW: equal pills WhatsApp / Phone / Email.
  - The target field.
  - "Last changed by <name> (role), n days ago."
  - STUDENTS SEE: a dashed preview card with the "Message <name>" ink pill.
  - `BottomAction` save, with its label per the user's answer.
- **Tests**: `'preview names the contact'`.
- **Render test**: `m_contact`.

**T8.9 · Before you start, Work as** (`rep_profile.dart`, `role_switch_page.dart`; §10.19,
§10.20, N26)
- **Steps**:
  - RepProfile follows its board:
    - YOU'VE BEEN APPOINTED eyebrow and "Before you start" title
    - an ink card with tier + scope chips and "Appointed by …"
    - YOUR NAME and PHONE NUMBER · REQUIRED cards (label-above)
    - SHOWN TO STUDENTS · AT LEAST ONE: themed switches BITS email / WhatsApp / Phone call
    - an amber `Notice`
    - `BottomAction` "Save and continue"
    - Sign out as a text link in the header when forced
  - Work as:
    - "YOUR ROLES · GOA" / "Work as"
    - rows: a `TierTag`, the title and "ELEC · A3 · until 27 Sep 2027" (`shortDay(year:
      true)`)
    - the current row gets a mint "✓ NOW" chip (N26), not an inverted card
    - a mint-wash `Notice` and a "Your contact details" `CardRow`
- **Tests**: `'current role shows NOW chip'`; `'expiry reads 27 Sep 2027'`.
- **Render tests**: `m_rep_profile`, `m_role_switch`.

**T8.10 · Audit log** (`AuditLogPage`; §10.8, N19)
- **Steps**:
  - `ScopePills` for a president.
  - An "Anyone" actor select row, then a course filter shown as an ink chip with ✕ once set.
  - Entries: `TierTag` + `NameEmail(shortEmail)`, what changed 13/600, before → after chips
    when the entry has `before` / `after`, and `ago()`.
- **Tests**: `'1 hour ago'` (T3.9); `'president sees their campus'`.
- **Render tests**: `m_audit`, `m_audit_pres`.

**T8.11 · Roster + Volunteers** (`roster.dart`, `volunteers.dart`; §10.16, N13)
- **Steps**:
  - `SegmentedTrack` "Maintainers" / "Volunteers · n".
  - WHO APPOINTS · EVERY CAMPUS (owners from `owners()`, admins from grants, with
    `staffPhones()`).
  - Campus groups of grant blocks with a phone on the right.
  - `ChoicePills(equal: true)` filters.
  - `BottomAction` "Appoint a CR".
  - Volunteers: grouped by course, with the clipboard icon button, "Appoint as CR" (ink
    pill) and "Dismiss" (outlined).
- **Tests**:
  - `'volunteers tab counts offers'`: the seed has 2 on EEE F212 → 'Volunteers · 2'.
  - `'/admin/roster/volunteers opens the tab'` (with T3.4).
- **Render test**: `m_roster`. Add `m_roster_volunteers`, opened with
  `RosterPage(initialVolunteers: true)`.

**T8.12 · Merge duplicates** (`ProfessorMerge`; §10.7)
- **Steps**:
  - A president sees `ScopePills` and the professors directly. Owners and admins pick a
    department with T8.4's picker, not a dropdown.
  - Two radio rows with a KEEP tag.
  - A mint AFTER card: "Ramesh Menon · n reviews" and "Also known as …".
  - The rewrite sentence ("It rewrites n reviews and n offerings…").
  - `BottomAction` "Merge into <name>".
- **Tests**: `'merge names the survivor'`: the seed's p1 / p2 → 'Merge into Ramesh Menon'.
- **Render tests**: `m_merge`, `m_merge_pres`.

**T8.13 · Your department, Course structures, Reviews, Resources (+ Reported), Professors**
(`maintain.dart`, `dept_reviews.dart`, `dept_resources.dart`, `professors.dart`;
§10.11–10.15, N20–N23, N31–N33)
- **Steps**:
  1. **DeptHome**:
     - scope chips including the term
     - the sharing sentence
     - five `CardRow`s with live subtitles and amber `CountBadge`s
     - a separate "Hand over to your successor" card with an amber tile
     - the ink THIS WEEK card: counts from `audit()`, grouped by you / other presidents /
       CRs, with a mint "Audit log" link
     - **Ask** about the Appoint a CR row
  2. **DeptCourses**:
     - a dashed mint drop zone
     - a separate EXTRACTION PROMPT card with a 30 px ink Copy pill and a quoted preview
       with Show
     - `SearchBox` with a "No scheme" link
     - course rows with 20 tall chips, and the leading icon removed
  3. **DeptReviews** (N33, N10):
     - a summary card
     - equal tabs with counts "All n / Reported n / Hidden n"
     - review cards: course chip, term chip, "n REPORTS", stars, TAKE IT tag, text,
       "Anonymous to students · attributable to you", 32 tall Keep / Hide pills
     - the amber Notice
     - delete `m_dept_reviews` from `known`
  4. **DeptResources** (N23, N31, N32):
     - tabs as equal pills; Reported in `noticeTone` with a pulsing 7 px dot
     - link rows; the rolled-up row on mint-wash with a ROLLED UP tag and an "Unpin" link
     - the ink ROLLUP card
     - `BottomAction` "Add a link"
     - Reported: an amber header card, then per link the reason · count · origin and two
       34 tall pills (Fix the link ink / It works · dismiss amber outline) in a `Wrap`, so
       they never overflow
     - delete `m_dept_resources` and `m_dept_reported` from `known`
  5. **DeptProfessors**:
     - `SearchBox` "Search n professors"
     - rows with a graduation-cap tile and "CS F301, CS F372 · teaching now" or "… · last
       taught <term>"
     - an amber ⚠ `Notice`
     - a mint Merge row
     - WHO CAN CHANGE THIS card
     - keep search-first (Departure)
- **Tests**:
  - `'reported tab counts reports'`: the seed has 2 reported → 'Reported 2'.
  - `'Fix / dismiss fit at 320'`: covered by the render test.
  - `'THIS WEEK counts CR edits'`.
- **Render tests**: `m_dept_home`, `m_dept_courses`, `m_dept_reviews`,
  `m_dept_resources`, `m_dept_reported`, `m_dept_profs`.

**T8.14 · Hand over + Confirm** (`succession.dart`; §10.17, N24)
- **Steps**:
  - Step 1:
    - eyebrow "STEP 1 OF 3 · GOA · A7" and the lead sentence
    - THEIR BITS ADDRESS field with a debounced check line "✓ Goa address — 2024 batch"
    - the same-campus rule
    - WHAT HAPPENS: three numbered rows (mint, mint, ink discs)
    - the amber cancel `Notice`
    - `BottomAction` "Review the handover"
  - Step 3:
    - "STEP 3 OF 3" / "Confirm"
    - HANDING OVER card (FROM → TO, "A7 Computer Science", "11 CRs move too")
    - TYPE THE DEPARTMENT CODE TO CONFIRM field
    - AFTER YOU CONFIRM list
    - `BottomAction` "Hand A7 Goa to <id>", plus a "Not yet" text button
- **Tests**:
  - `'confirm needs the typed code'` (the button is disabled until "ELEC" is typed; this
    already exists as S-tests; keep them green).
  - `'timeline names the end date'`.
- **Render tests**: `m_succession`, `m_succession_confirm`.

**T8.15 · Course page (CR)** (`CrHome`, `scheme_editor.dart`; §10.18, N25)
- **Steps**:
  - TAKEN BY, THIS TERM: `LabelRow` with a "Change" link, and the professor row with a mint
    cap tile.
  - EVALUATION SCHEME rows: name, a weight pill, and "avg 12.4" mint or a dashed "no avg"
    pill, from the seeded offering.
  - The "100% assigned · …" note.
  - COURSE AVERAGE card, if the user says yes (N25).
  - COURSE RESOURCES: the pulsing amber "n LINK REPORTED · Open ›" row opening
    `DeptResources(course:, initialTab: 2)`, IN DEPT tags, and a dashed "Pick from
    department resources" button.
- **Tests**: `'scheme shows averages'`: the seeded CS F372 offering → 'avg 12.4'.
- **Render test**: `m_cr_home`.

### Group 9 · last pass

- **T9.1**: §11 row 9. Every screen in dark at 390 and 320; 768 and 1440 for Home, Stats,
  Marks and More; 200% text at 320; the old-device frame check (§1.4); landing and loading
  against the live deploy.
- **T9.2 · Legacy layer (§19)**:
  - Replace every `thm.<x>color` with `AppPalette.of(context)` roles.
  - Move `setnavcolor()` to a `SystemUiOverlayStyle` from the palette.
  - Drop the `'Montserrat'` SemiBold family from `pubspec.yaml` once nothing names it
    (`grep -rn "'Montserrat'" lib` is empty).
  - Delete the six colour aliases in `palette.dart:156-161`.
  - Move the Report-a-bug address out of `settings_page.dart:73` (N30).
- **T9.3 · Unboarded screens (§17)**: send the user the list in §17 and ask for boards, or
  for approval to style each with the shared parts. Until then, each gets only the T3.1 theme
  and the shared dialog.

### 20.1 · Questions for the user (collected)
1. Public contact: live read (the code) or catalogue-carried (the board and ARCHITECTURE)?
   (N15)
2. ~~The Expected FAB~~: answered. Keep it, permanent (N29, done).
3. DeptHome's extra "Appoint a CR" row: keep it as a Departure or remove it? (N20)
4. The CR course page's COURSE AVERAGE card: build it now? (N25)
5. Boards for the §17 screens: Compare, Person, Bulk upload preview, Import preview, Edit
   course, Install guide, Minor picker, and the dialogs. Draw them, or approve shared-part
   styling?
6. Owners: keep the Name field on Add owner? (N16)
