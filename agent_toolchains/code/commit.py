#!/usr/bin/env python3
"""Commit named files (no co-author trailer: the owner's rule), then push. Refuses forbidden files,
files with no change, and (unless --no-verify) a failing verify.py.

  python3 agent_toolchains/code/commit.py -m "T7.2: …" lib/a.dart test/b_test.dart
  python3 agent_toolchains/code/commit.py -m "…" --no-push --no-verify UI.md

Never stages anything it was not given by name. Warns about other changed
files so nothing is forgotten, but does not add them.
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rules import ALLOWED, FORBIDDEN, changed_files, matches, sh  # noqa: E402

BRANCH = 'pointer-dev'


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument('files', nargs='+')
    ap.add_argument('-m', '--message', required=True)
    ap.add_argument('--no-verify', action='store_true')
    ap.add_argument('--fast', action='store_true', help='verify without the test suite')
    ap.add_argument('--no-push', action='store_true')
    a = ap.parse_args(argv)

    changed = set(changed_files())
    bad = [f for f in a.files if matches(f, FORBIDDEN) and f not in ALLOWED]
    stale = [f for f in a.files if f not in changed]
    if bad or stale:
        for f in bad:
            print(f'REFUSED: {f} must never be committed')
        for f in stale:
            print(f'REFUSED: {f} has no change')
        return 2
    if sh('git', 'rev-parse', '--abbrev-ref', 'HEAD').stdout.strip() != BRANCH:
        print(f'REFUSED: not on {BRANCH}')
        return 2
    if not a.no_verify:
        args = ['python3', 'agent_toolchains/code/verify.py'] + (['--fast'] if a.fast else [])
        r = sh(*args)
        print(r.stdout.rstrip())
        if r.returncode:
            print('REFUSED: verify failed')
            return 1
    sh('git', 'add', '--', *a.files, check=True)
    r = sh('git', 'commit', '-q', '-m', a.message)
    if r.returncode:
        print(r.stdout + r.stderr)
        return 1
    print(sh('git', 'log', '--oneline', '-1').stdout.strip())
    left = sorted(changed - set(a.files))
    if left:
        print(f'not committed (still changed): {", ".join(left[:10])}')
    if not a.no_push:
        for _ in range(4):
            if sh('git', 'push', '-q', 'origin', BRANCH).returncode == 0:
                print('pushed')
                break
        else:
            print('PUSH FAILED')
            return 1
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
