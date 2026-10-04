#!/usr/bin/env python3
"""Surgical find-and-replace: exact text, an exact expected count, a hard
cap on how much may change, and a dry run by default.

  python3 agent_toolchains/code/edit.py --old 'A' --new 'B' --count 3 lib/x.dart lib/y.dart
  python3 agent_toolchains/code/edit.py --old-file o.txt --new-file n.txt --count 1 --write lib/x.dart
  python3 agent_toolchains/code/edit.py --regex --old 'Foo\\((\\w+)\\)' --new 'Bar(\\1)' --count 241 --write --glob 'lib/**/*.dart'

Refuses (and writes nothing) when:
  - the total number of matches is not exactly --count (a pattern that matches
    more than you expected is how thousands of lines get replaced by mistake);
  - more than --max-lines lines would change in all (default 40); raise it on
    purpose for a known sweep;
  - a file is PROTECTED (PLAN.md) or LEGACY, unless --allow names it;
  - a match would overlap another, or --old is empty.
All files are checked before any is written: it is all or nothing.
Without --write it prints what would change and exits.
"""
import argparse
import difflib
import glob
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rules import LEGACY, PROTECTED, ROOT, matches  # noqa: E402


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument('files', nargs='*')
    ap.add_argument('--glob', action='append', default=[])
    ap.add_argument('--old'); ap.add_argument('--new')
    ap.add_argument('--old-file'); ap.add_argument('--new-file')
    ap.add_argument('--regex', action='store_true')
    ap.add_argument('--count', type=int, required=True)
    ap.add_argument('--max-lines', type=int, default=40)
    ap.add_argument('--allow', action='append', default=[])
    ap.add_argument('--write', action='store_true')
    a = ap.parse_args(argv)

    old = open(a.old_file).read() if a.old_file else a.old
    new = open(a.new_file).read() if a.new_file else a.new
    if not old or new is None:
        sys.exit('refused: give --old/--old-file (non-empty) and --new/--new-file')
    pat = re.compile(old if a.regex else re.escape(old))

    files = list(a.files)
    for g in a.glob:
        files += [os.path.relpath(p, ROOT) for p in glob.glob(os.path.join(ROOT, g), recursive=True)]
    files = sorted(set(files))
    if not files:
        sys.exit('refused: no files')

    plan, total, changed_lines, problems = [], 0, 0, []
    for f in files:
        if (matches(f, PROTECTED) or matches(f, LEGACY)) and f not in a.allow:
            if pat.search(open(os.path.join(ROOT, f)).read()):
                problems.append(f'{f}: protected or legacy; pass --allow {f} if meant')
            continue
        src = open(os.path.join(ROOT, f)).read()
        hits = list(pat.finditer(src))
        if not hits:
            continue
        total += len(hits)
        out = pat.sub(new, src) if a.regex else src.replace(old, new)
        diff = [l for l in difflib.unified_diff(src.splitlines(), out.splitlines(), lineterm='', n=0)
                if l[:1] in '+-' and not l.startswith(('+++', '---'))]
        changed_lines += len(diff)
        plan.append((f, len(hits), out, diff))

    if total != a.count:
        problems.append(f'{total} matches, expected exactly {a.count}')
        for f, n, *_ in plan:
            problems.append(f'  {f}: {n}')
    if changed_lines > a.max_lines:
        problems.append(f'{changed_lines} changed lines, over --max-lines {a.max_lines}')
    if problems:
        print('REFUSED, nothing written:')
        print('\n'.join('  ' + p for p in problems))
        return 2

    for f, n, out, diff in plan:
        print(f'{f}: {n} match{"es" * (n != 1)}, {len(diff)} lines')
        for l in diff[:8]:
            print('   ' + l[:150])
        if len(diff) > 8:
            print(f'   … {len(diff) - 8} more')
    if not a.write:
        print(f'dry run: {total} matches in {len(plan)} files. Add --write to apply.')
        return 0
    for f, _, out, _ in plan:
        with open(os.path.join(ROOT, f), 'w') as fh:
            fh.write(out)
    print(f'written: {total} replacements in {len(plan)} files')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
