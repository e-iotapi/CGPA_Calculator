# UI implementation log

What was built to make each screen match its board in the UI Directions artifact
(`https://claude.ai/artifact/K4H9w2Ad9cwdTqxPSAiWMW`). One section per group, newest last.
The boards are the spec; ARCHITECTURE.md §13–16 records the decisions behind them. This file
records **how** each board was built, and every place the build departs from a board and why.

## How screens are checked

- **Widget-test screenshots.** Tests that end in `_screenshots_test.dart` write PNGs when
  `SHOTS_DIR` is set, with the real Montserrat fonts:
  `SHOTS_DIR=/some/dir flutter test test/semester/semester_screenshots_test.dart`.
  They render at 320, 390 (the board width), 768 and 1440, light and dark.
- **The live site** (signed in by the user) shows the deployed build, i.e. the state *before*
  the local commits; sign-in does not work on localhost.
- Every group ends with `flutter analyze` (7 existing infos), `flutter test` and a local commit.

## Shared rules

- **Colours** come from `AppPalette` (`lib/app/theme/palette.dart`); **sizes, radii, type** from
  `lib/app/theme/tokens.dart`. The palette and type scale already matched `Main` and `DarkMain`
  hex for hex, so they were kept; new tokens are added there, never inline.
- **No blur, no `saveLayer`.** The boards' fades become plain `LinearGradient`s; translucent
  fills are colour alpha.
- **A floating bar clears the last item** (§16.4): the body pads its scroll view by
  `MediaQuery.paddingOf(context).bottom`, which `Scaffold.extendBody` sets to the bar's height.

---

## Group 1 — tokens and shared widgets (`Main`, `DarkMain`, `Responsive`)

### Nav pill — `lib/shared/widgets/app_nav.dart`
Board `Main`/`More`: a 66px ink pill, 8px inner padding, items spaced between.
- **Selected**: a mint stadium, 50px tall, 13px side padding, 17px icon, 7px gap, label 12.5/700.
- **Unselected**: 50×50 round icon buttons, `navIcon` colour; the label is the tooltip and the
  semantics label (the old build showed every label under every icon).
- **Narrow phones** (< 360px wide): icons drop to the 44px touch minimum and the side margin to
  16px, so the selected label still fits on a 320px screen. The selected label is measured with a
  `TextPainter`; if it cannot fit whole (200% text, a long custom profile name) the pill shows its
  icon only, rather than squeezing the others. *Departure:* the board has no 320px pill; this is
  the rule that keeps §15's 44px and no-overflow checks.
- **Rail** (≥ 1100px, `Responsive`): the Pointer mark on top, then icon-over-label items. The
  rail keeps every label; it has the room.
- Pill max width 420 (was 480), centred on tablets — "centres rather than stretching".

### Floating bar — `lib/shared/layout/responsive.dart`
The pill now floats **over** the page, as drawn: `Scaffold.extendBody`, the pill inset 20px
(16px on narrow phones) and `Space.md` above the safe area, over a 40px fade from transparent to
the page ground. The fade ignores pointers. Lists under it pad by the bar's height
(`SemesterView`, `OffshootPanel`, `MinorPanel`).

### Home header and section row — `lib/features/semester/semester_page.dart`
- The **Add** pill (ink, `+ Add`) sits in the section row beside sort and export, as on `Main`.
  The dashed "add" card at the foot of the list now shows only while the semester is empty
  ("No courses in 4 - 1 yet — add some"). Test `the Add pill fires` replaces
  `add card is reachable and fires`.
- The row wraps: count left, pills right while they fit; at 320px or large text the pills drop
  to their own line.
- Stats button uses a line-chart icon (`Icons.show_chart_rounded`) and Compare uses the board's
  diagonal arrows (`Icons.open_in_full_rounded`).

### Stat cards — `lib/shared/widgets/stat_card.dart`
The number is weight 800 in dark mode, 700 in light (`DarkMain` vs `Main`).

### `PillButton`
Gains `padding` (default 15); the header pills use 13 as drawn.
