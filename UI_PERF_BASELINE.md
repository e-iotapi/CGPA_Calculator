# UI_PERF_BASELINE

Numbers from UI_OPT.md §3 O0.4's device check, one table per phase. This
container has no phone; the on-device rows need the user to run them (build
with `flutter build web --release --dart-define=POINTER_FRAMES=1`, deploy
nowhere, open on-device, and read the `[Pointer frames]` console lines, or
use Chrome DevTools' CPU 6× throttle / Safari's Timelines as §3 O0.4
describes).

Columns: frames, frames over budget (>16.7 ms), worst build (ms), worst
raster (ms).

## O1 — theme switch, keeping the circle

| Row | Frames | Over budget | Worst build | Worst raster |
|---|---|---|---|---|
| theme switch light→dark (before) | — | — | — | — |
| theme switch light→dark (after) | — | — | — | — |
| theme switch dark→light (before) | — | — | — | — |
| theme switch dark→light (after) | — | — | — | — |

*(push Settings / pop / profile switch / DeptCourses typing / Stats slider
rows are added as their phases land — O2, O3, O5.)*
