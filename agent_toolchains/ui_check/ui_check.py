#!/usr/bin/env python3
"""UI check: render every screen, read the reports as text, and look at
pixels only where the fallback rules say to. See ../README.md.

  python3 agent_toolchains/ui_check/ui_check.py run [--card NAME] [TEST_FILES...]
  python3 agent_toolchains/ui_check/ui_check.py compare [--card NAME]
  python3 agent_toolchains/ui_check/ui_check.py accept
  python3 agent_toolchains/ui_check/ui_check.py sheet [GLOB] [--scale 0.33]
  python3 agent_toolchains/ui_check/ui_check.py show GLOB...
  python3 agent_toolchains/ui_check/ui_check.py audit [N]

Needs flutter on PATH and `pip install pillow numpy`. Everything it writes
goes under build/ui_check/ (UI_CHECK_DIR overrides), which git ignores:
new/ this run, base/ the accepted run, crops/, sheets/, show/,
summary.txt. Exit status: 0 clean, 1 something to look at, 2 the tooling
itself is broken (nothing it says can be trusted).
"""
import fnmatch
import json
import os
import random
import shutil
import subprocess
import sys

try:
    import numpy as np
    from PIL import Image, ImageDraw
except ImportError:
    sys.exit('ui_check needs Pillow and NumPy: pip install pillow numpy')

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
WORK = os.environ.get('UI_CHECK_DIR', os.path.join(ROOT, 'build', 'ui_check'))
NEW, BASE = os.path.join(WORK, 'new'), os.path.join(WORK, 'base')
CANARY_TEST = 'agent_toolchains/ui_check/canary_test.dart'
SUITES = ['test/ui', CANARY_TEST]

# What each canary must report (see canary_test.dart); '' = nothing at all.
CANARIES = {
    'canary_clean': '', 'canary_overflow': 'error',
    'canary_contrast': 'contrast', 'canary_tap': 'tap',
    'canary_unlabeled': 'unlabeled', 'canary_dead': 'dead',
    'canary_truncated': 'truncated', 'canary_off_edge': 'off-edge',
    'canary_stretch': 'stretch', 'canary_anim': 'anim',
}

PIXEL_NOISE = 16      # a channel must move more than this to count as changed
FULL_LOOK_SHARE = 0.30  # more of the screen than this changed: look at it all
RENDER_SCALE = 1      # captureImage writes logical pixels (pixelRatio 1)


def tokens(w, h):
    """Rough image cost, for budgeting what to open."""
    scale = min(1.0, 1568 / max(w, h))
    return int(w * scale * h * scale / 750)


def stems(d):
    if not os.path.isdir(d):
        return set()
    return {f[:-4] for f in os.listdir(d) if f.endswith('.png')}


def load(d, stem):
    return np.asarray(Image.open(os.path.join(d, stem + '.png')).convert('RGB'))


def report(d, stem):
    try:
        with open(os.path.join(d, stem + '.json')) as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


def at_1x(img):
    w, h = img.size
    return img.resize((max(1, w // RENDER_SCALE), max(1, h // RENDER_SCALE)), Image.LANCZOS)


# ---- run ---------------------------------------------------------------------

def run(paths, card):
    shutil.rmtree(NEW, ignore_errors=True)
    os.makedirs(NEW)
    partial = bool(paths)
    if partial:
        open(os.path.join(NEW, '.partial'), 'w').close()
    targets = (paths or SUITES[:1]) + [CANARY_TEST]
    env = dict(os.environ, SHOTS_DIR=NEW)
    env['PATH'] = '/opt/flutter/bin:' + env.get('PATH', '')
    proc = subprocess.run(['flutter', 'test', '--reporter', 'json', *targets],
                          cwd=ROOT, env=env, capture_output=True, text=True)
    names, failed, errors, done = {}, [], {}, None
    for line in proc.stdout.splitlines():
        try:
            e = json.loads(line)
        except ValueError:
            continue
        if not isinstance(e, dict):
            continue
        t = e.get('type')
        if t == 'testStart':
            names[e['test']['id']] = e['test']['name']
        elif t == 'error':
            errors.setdefault(e['testID'], e['error'].strip().splitlines()[0][:160])
        elif t == 'testDone' and not e.get('hidden') and e['result'] != 'success':
            failed.append(e['testID'])
        elif t == 'done':
            done = e.get('success')
    tests = [n for i, n in names.items() if not n.startswith('loading ')]
    head = [f'TESTS    {len(tests)} run, {len(failed)} failed']
    for i in failed:
        head.append(f'  FAILED {names.get(i, i)}: {errors.get(i, "")}')
    broken = []
    if done is None:
        broken.append('flutter test produced no result; stderr tail:\n'
                      + '\n'.join(proc.stderr.strip().splitlines()[-8:]))
    return compare(card, head, broken)


# ---- compare -----------------------------------------------------------------

def compare(card=None, head=None, broken=None):
    head, broken = head or [], broken or []
    look, changed, new_issues, fixed = [], [], [], []
    partial = os.path.exists(os.path.join(NEW, '.partial'))
    new, base = stems(NEW), stems(BASE)
    crops = os.path.join(WORK, 'crops')
    shutil.rmtree(crops, ignore_errors=True)
    os.makedirs(crops)

    # Rule T1: every render has its report and every report its render.
    jsons = {f[:-5] for f in os.listdir(NEW) if f.endswith('.json')} if os.path.isdir(NEW) else set()
    for s in sorted(new ^ jsons):
        broken.append(f'{s}: png and json do not pair up')
    if not new:
        broken.append('no renders were written (is SHOTS_DIR reaching the tests?)')

    # Rule T2: every canary trips its own check, the clean one trips none.
    for name, kind in CANARIES.items():
        r = report(NEW, name + '_light_390')
        if r is None:
            broken.append(f'{name}: no report written')
        elif kind == '' and (r['issues'] or r['errors']):
            broken.append(f'{name}: false alarm {r["issues"] + r["errors"]}')
        elif kind == 'error' and not r['errors']:
            broken.append(f'{name}: layout error not caught')
        elif kind not in ('', 'error') and not any(i.startswith(kind + ':') for i in r['issues']):
            broken.append(f'{name}: {kind} not caught')

    # Rule T3: a full run renders every accepted screen.
    if base and not partial:
        for s in sorted(base - new):
            broken.append(f'{s}: rendered last time, missing now')

    screens = sorted(s for s in new if not s.startswith('canary_'))
    for s in screens:
        img = load(NEW, s)
        h, w = img.shape[:2]
        r = report(NEW, s) or {'errors': [], 'issues': []}
        # Rule L1: a render that is blank or one colour did not render.
        if img.std() < 1.0:
            look.append((s, 'blank or one colour: the render failed', w, h))
            continue
        # Rule L2: layout errors, unless the baseline already had them.
        if r['errors'] and r['errors'] != (report(BASE, s) or {}).get('errors'):
            look.append((s, 'layout error: ' + r['errors'][0][:100], w, h))
        if not base:
            continue
        if s not in base:
            look.append((s, 'new screen, no baseline', w, h))
            continue
        old = load(BASE, s)
        if old.shape != img.shape:
            look.append((s, f'size changed {old.shape[1]}x{old.shape[0]} -> {w}x{h}', w, h))
            continue
        mask = (np.abs(img.astype(int) - old.astype(int)) > PIXEL_NOISE).any(axis=2)
        share = mask.mean()
        if share > 0:
            ys, xs = np.nonzero(mask)
            pad = 16 * RENDER_SCALE
            x0, x1 = max(0, xs.min() - pad), min(w, xs.max() + pad + 1)
            y0, y1 = max(0, ys.min() - pad), min(h, ys.max() + pad + 1)
            if share > FULL_LOOK_SHARE:
                look.append((s, f'{share:.0%} of the screen changed', w, h))
            else:
                a = at_1x(Image.fromarray(old[y0:y1, x0:x1]))
                b = at_1x(Image.fromarray(img[y0:y1, x0:x1]))
                pair = Image.new('RGB', (a.width * 2 + 6, a.height), (255, 0, 255))
                pair.paste(a, (0, 0))
                pair.paste(b, (a.width + 6, 0))
                path = os.path.join(crops, s + '.png')
                pair.save(path)
                changed.append((s, share, path, pair.width, pair.height))
        old_r = report(BASE, s) or {'issues': []}
        for i in sorted(set(r['issues']) - set(old_r['issues'])):
            new_issues.append(f'{s}  {i}')
        for i in sorted(set(old_r['issues']) - set(r['issues'])):
            fixed.append(f'{s}  {i}')

    # Rule L4: the card's own screen always gets one full-size look.
    if card:
        stem = f'{card}_light_390'
        if stem in new:
            img = Image.open(os.path.join(NEW, stem + '.png'))
            look.append((stem, "the card's own screen (always)", img.width, img.height))
        else:
            broken.append(f'--card {card}: no render named {stem}')

    out = [f'UI CHECK  {len(screens)} renders, baseline {len([b for b in base if not b.startswith("canary_")]) or "none"}'
           + (' (partial run)' if partial else '')] + head
    if broken:
        out.append('TOOLING BROKEN - do not trust anything below; look at the images yourself:')
        out += [f'  {b}' for b in broken]
    else:
        out.append(f'TOOLING  ok: {len(CANARIES)}/{len(CANARIES)} canaries, every render has its report')
    if not base:
        out.append('NO BASELINE (first run): sweep everything with `sheet`, then `accept`.')
    if look:
        show = os.path.join(WORK, 'show')
        os.makedirs(show, exist_ok=True)
        out.append('LOOK FULL SIZE (1x copies in show/):')
        for s, why, w, h in look:
            at_1x(Image.open(os.path.join(NEW, s + '.png'))).save(os.path.join(show, s + '.png'))
            out.append(f'  {s}  - {why}  ~{tokens(w // RENDER_SCALE, h // RENDER_SCALE)} tok  show/{s}.png')
    if changed:
        out.append('CHANGED (old | new crops):')
        for s, share, path, w, h in changed:
            out.append(f'  {s}  {share:.1%}  ~{tokens(w, h)} tok  crops/{os.path.basename(path)}')
    if new_issues:
        out.append('NEW ISSUES:')
        out += [f'  {i}' for i in new_issues]
    if fixed:
        out.append('GONE ISSUES:')
        out += [f'  {i}' for i in fixed]
    quiet = len(screens) - len({s for s, *_ in look} | {s for s, *_ in changed})
    out.append(f'UNCHANGED {quiet}')
    text = '\n'.join(out)
    with open(os.path.join(WORK, 'summary.txt'), 'w') as f:
        f.write(text + '\n')
    print(text)
    if broken:
        return 2
    return 1 if (look or changed or new_issues or any('FAILED' in h for h in head)) else 0


# ---- accept / sheet / show / audit ------------------------------------------

def accept():
    if not stems(NEW):
        sys.exit('nothing to accept: run first')
    partial = os.path.exists(os.path.join(NEW, '.partial'))
    if not partial:
        shutil.rmtree(BASE, ignore_errors=True)
    os.makedirs(BASE, exist_ok=True)
    for f in os.listdir(NEW):
        if f.endswith(('.png', '.json')):
            shutil.copy2(os.path.join(NEW, f), os.path.join(BASE, f))
    print(f'accepted {len(stems(NEW))} renders' + (' into the baseline (partial)' if partial else ''))
    return 0


def pick(patterns):
    all_ = sorted(s for s in stems(NEW) if not s.startswith('canary_'))
    if not patterns:
        return all_
    return [s for s in all_ if any(fnmatch.fnmatch(s, p) for p in patterns)]


def sheet(patterns, scale):
    """Contact sheets: thumbnails at [scale] of 1x, named, packed into pages
    no bigger than an image is read at, so each page costs ~1.6k tokens."""
    out = os.path.join(WORK, 'sheets')
    shutil.rmtree(out, ignore_errors=True)
    os.makedirs(out)
    thumbs = []
    for s in pick(patterns):
        im = Image.open(os.path.join(NEW, s + '.png')).convert('RGB')
        f = scale / RENDER_SCALE
        thumbs.append((s, im.resize((max(1, int(im.width * f)), max(1, int(im.height * f))), Image.LANCZOS)))
    page, pages, x, y, row_h, W, H = None, [], 0, 0, 0, 1560, 1560
    label = 12

    def flush():
        if page is not None:
            path = os.path.join(out, f'sheet_{len(pages) + 1:02}.png')
            page.save(path)
            pages.append(path)

    for s, t in thumbs:
        cw, ch = t.width + 6, t.height + label + 6
        if page is None or x + cw > W:
            x, y, row_h = 0, y + row_h, 0
        if page is None or y + ch > H:
            flush()
            page, x, y, row_h = Image.new('RGB', (W, H), (128, 128, 128)), 0, 0, 0
        page.paste(t, (x, y + label))
        ImageDraw.Draw(page).text((x + 1, y), s[:int(t.width / 6)], fill=(255, 255, 0))
        x, row_h = x + cw, max(row_h, ch)
    flush()
    for p in pages:
        print(f'{p}  ~{tokens(1560, 1560)} tok')
    print(f'{len(thumbs)} renders on {len(pages)} sheets')
    return 0


def show(patterns):
    out = os.path.join(WORK, 'show')
    os.makedirs(out, exist_ok=True)
    for s in pick(patterns):
        im = at_1x(Image.open(os.path.join(NEW, s + '.png')))
        path = os.path.join(out, s + '.png')
        im.save(path)
        print(f'{path}  ~{tokens(im.width, im.height)} tok')
    return 0


def audit(n):
    """Rule A: open N renders the tools called clean, picked at random."""
    return show(random.sample(pick([]), min(n, len(pick([])))))


def main(argv):
    if not argv or argv[0] in ('-h', '--help'):
        print(__doc__)
        return 0
    cmd, rest = argv[0], argv[1:]
    card = None
    if '--card' in rest:
        i = rest.index('--card')
        card = rest[i + 1]
        rest = rest[:i] + rest[i + 2:]
    if cmd == 'run':
        return run(rest, card)
    if cmd == 'compare':
        return compare(card)
    if cmd == 'accept':
        return accept()
    if cmd == 'sheet':
        scale = 0.33
        if '--scale' in rest:
            i = rest.index('--scale')
            scale = float(rest[i + 1])
            rest = rest[:i] + rest[i + 2:]
        return sheet(rest, scale)
    if cmd == 'show':
        return show(rest)
    if cmd == 'audit':
        return audit(int(rest[0]) if rest else 4)
    print(__doc__)
    return 2


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
