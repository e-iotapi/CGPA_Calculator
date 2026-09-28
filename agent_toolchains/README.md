# Agent toolchains

Tools for agents working on this repo. Their aim is to spend tokens only where
something needs looking at. Everything they write goes under `build/`, which
git ignores.

| Toolchain | What it does |
|---|---|
| `ui_check/` | Renders every screen, reports UI bugs as text, and diffs against the accepted run, so you open pixels only when a rule below says to. |
| `code/` | Surgical editing, one-line verify gates, and a commit helper that enforces this repo's rules. |
| `plan/` | Reads UI.md / UI_OPT.md by number (T7.3, 8.4, N27, O0.2): exact text, never a summary. |
| `progress_report/` | Builds the one-page progress report from `status.json` and the git log. |

Setup, once per container: `pip install pillow numpy`, and put flutter on
PATH (`export PATH=/opt/flutter/bin:$PATH`).

## ui_check

```
python3 agent_toolchains/ui_check/ui_check.py run --card s_more   # every screen
python3 agent_toolchains/ui_check/ui_check.py run --card s_more test/ui/student_screens_test.dart
python3 agent_toolchains/ui_check/ui_check.py accept              # after the look
python3 agent_toolchains/ui_check/ui_check.py sheet 's_*'         # thumbnails
python3 agent_toolchains/ui_check/ui_check.py show 's_more_*'     # full size
python3 agent_toolchains/ui_check/ui_check.py audit 4             # random clean ones
python3 agent_toolchains/ui_check/ui_check.py atlas               # ui_sheet/ for a person
```

A full run takes about a minute for about 300 renders: each screen in light and
dark at 390, 320, and 320 with 150% text (200% is not checked). The summary is in
`build/ui_check/summary.txt`, and every image it names comes with a token
estimate. The exit status is 0 for clean, 1 for something to look at, and
2 when the tooling itself is broken.

The pieces:

- `ui_checks.dart`: the code checks. `renderScreen` and `shoot` in
  `test/helpers/` call `recordRender` when `SHOTS_DIR` is set. It writes
  `<screen>_<light|dark>_<frame>.png` plus a `.json` holding layout errors and
  one line per issue. The kinds are listed at the top of the file:
  - `contrast`
  - `tap`
  - `unlabeled`
  - `dead`
  - `truncated`
  - `off-edge`
  - `stretch`
  - `anim`
- `canary_test.dart`: planted bugs, one per check, plus a clean screen that
  must report nothing. The clean screen includes the three cases that once
  raised false alarms: tightly boxed text, a disabled button, and text past the
  end of a scroll view.
- `ui_check.py`: runs the suites and checks the canaries. It diffs pixels and
  issue lines against `build/ui_check/base/`, crops what changed, and applies
  the rules below.

`atlas` is for people, not agents. After a full `run`, it writes one image,
`ui_sheet/ui_sheet.png`: every screen at 390 and 100% text, with light and dark
side by side at 1x under the screen's name. Rebuild and commit it when asked
for a manual pass. It is far too large to read yourself.

The baseline lives in `build/` and is never committed, because renders differ
slightly between machines. In a fresh container, start with `run`, do a
`sheet` sweep, then `accept`.

### Fallback rules

The tools are layered from cheapest to most thorough:

1. Code checks, which cost no image tokens.
2. Old | new crops of whatever changed.
3. A cheap-model sweep of thumbnail sheets.
4. You, looking at the full-size image.

Drop to the full-size image yourself whenever any rule below fires. The tools
narrow down where to look; they never decide that a screen is fine when a rule
says otherwise.

**The tooling is broken (the summary says TOOLING BROKEN, exit 2).** Trust
nothing in the report. Open the full-size image of every screen the card
touched, then fix the tooling before relying on it again. It counts as
broken when:

- **T1:** a render has no report, or a report has no render.
- **T2:** a canary did not trip its own check, or the clean canary reported
  anything.
- **T3:** a full run is missing a screen the baseline had.
- flutter test produced no result at all.

**Look at the full size (listed under LOOK FULL SIZE, with a 1x copy in
`show/`):**

- **L1:** the render is blank or one colour, so it did not really render.
- **L2:** there's a layout error the baseline did not have.
- **L3:** the screen is new (no baseline), its size changed, or more than 30%
  of it changed. A crop would lose the context.
- **L4:** always look at the card's own screen: pass `--card <screen>` and
  compare `<screen>_light_390` with its board. Every card gets this one look,
  whatever the tools say.

**Read the crops (listed under CHANGED):** look at every old | new crop. If a
crop is ambiguous, `show` that screen at full size.

**Check the new issues (listed under NEW ISSUES):** fix each one, or decide it
is intended. If you can't tell from the line alone, look at the image.

**A cheap-model sweep (once per group, or on a first run with no baseline):**
run `sheet` and hand the sheets to a helper on a cheaper model, for example
`Agent(model: "haiku")`. Ask it to open each sheet and reply with one line per
problem, in the form "file — screen — problem", or "none". It replies in text,
so the images never enter your own context. Check its report with the rules
that follow:

- **H1:** open every screen it names at full size.
- **H2:** if it is unsure or vague, open that screen at full size too.
- **H3:** if its reply is not in the requested format, or skips sheets, treat
  the sweep as not done and sweep the sheets yourself.

**Audit the tools (once per group):** run `audit 4` and open the renders it
picks, which the tools called clean. If you find a bug they missed, add a
check for it, plus a canary that plants it and one that must not trip it.
Then log the new check in the next group's UI.md §13 entry.

**When to accept:** only after every LOOK, CHANGED and NEW ISSUES entry has
been dealt with. Accepting is how you say "this is right", and the next run
compares against it.

Three limits apply however much you look:

- Real devices and browsers: Safari, the notch, the installed app, real fonts.
- Data the fake set doesn't include.
- Moments between frames.

These are for users to find. When a user reports one, add it to the fake data
or the canaries so it is caught next time.

## code

These are surgical tools. They refuse rather than guess, and they write nothing unless every check passes.

- `verify.py` runs the gates before any commit and prints one line per gate:
  - `format`: changed files that were formatted at HEAD. Legacy files, and
    files unformatted at HEAD, are left alone.
  - `analyze`: only the known findings are allowed, counted by (file, rule).
  - `tests`: failing tests are listed by name.
  - Optional flags: `--ui <screen>` adds the ui_check run, `--fast` skips the
    tests, and `--selftest` plants one problem per gate and requires each
    gate to catch it. Run the self-test whenever you change the tool or the
    rules.
- `edit.py` does exact text or `--regex` replacement across files or
  `--glob`s. The rules:
  - It runs dry unless you pass `--write`.
  - The total match count must equal `--count` exactly.
  - At most `--max-lines` (default 40) lines may change.
  - PLAN.md and legacy files are refused unless you name them with `--allow`.
  - It applies all or nothing.
  - Read the dry run before adding `--write`.
- `commit.py -m "msg" files…` stages only the named files. It refuses
  forbidden files, files with no change, the wrong branch, and a failing
  verify. It adds the trailer, pushes, and lists the changed files it left out.
- `rules.py` holds the lists: legacy files, forbidden files, the known
  analyze findings and the trailer. Change a rule there, and only when the
  repo's rules change.

For symbol lookups (definition, references, signature) use the Dart MCP
server from the Dart and Flutter plugin instead of reading whole files.

## plan

`plan.py get T7.3 8.4 N27` prints those items exactly as the file has
them, so read a card and what it cites without reading the plan. `list`
is the index, and `check` proves the parse still matches the files, so run
it after the plan is edited. It parses on every call, so it is never stale.
An unknown or ambiguous id is an error, never a guess; use `UI_OPT.md:1.1`
when both files have the id.

## progress_report

Edit `status.json` (groups in build order, `done` cards, `current`, `note`).
Then run `python3 agent_toolchains/progress_report/build.py`, and publish
`build/progress_report/progress.html` with the Artifact tool, using the same
file path each time so it updates the same page.
