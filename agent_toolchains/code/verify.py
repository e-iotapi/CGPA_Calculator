#!/usr/bin/env python3
"""One-line-per-gate check before a commit. Prints details only on failure.

  python3 agent_toolchains/code/verify.py            # format, analyze, tests
  python3 agent_toolchains/code/verify.py --ui s_more  # + ui_check run --card
  python3 agent_toolchains/code/verify.py --fast     # skip the full test suite
  python3 agent_toolchains/code/verify.py --affected # only tests that import a changed file
  python3 agent_toolchains/code/verify.py --selftest # prove each gate still fails

Exit 0 only when every gate passes. Gates:
  format   changed .dart files (not LEGACY) that were formatted at HEAD, or are
           new, must still be formatted. A file unformatted at HEAD is left
           alone and reported as skipped, never reformatted.
  analyze  exactly the KNOWN_ANALYZE findings, counted by (file, rule), so a
           new finding cannot hide behind a fixed one.
  tests    flutter test, all passing; failures listed by name. With --affected,
           only the test files whose import closure reaches a changed file
           (the full suite when FULL_SUITE files changed).
  rules    when firestore.rules or test/rules/** changed: the rules tests,
           against the running emulator (up.sh) when port 8085 answers,
           else cold through `firebase emulators:exec`.
"""
import json
import os
import re
import sys
from collections import Counter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rules import KNOWN_ANALYZE, LEGACY, ROOT, changed_files, matches, sh  # noqa: E402

# A change here reaches every test, so --affected runs the full suite.
FULL_SUITE = ['lib/main.dart', 'lib/sync.dart', 'pubspec.yaml', 'pubspec.lock',
              'test/flutter_test_config.dart', 'analysis_options.yaml']
IMPORT = re.compile(r"""^\s*(?:import|export|part)\s+['"]([^'"]+)['"]""", re.M)

TEST_TIMEOUT = '60s'  # per test; the slowest real one takes a few seconds


def gate_format(files=None):
    files = [f for f in (files if files is not None else changed_files())
             if f.endswith('.dart') and os.path.exists(os.path.join(ROOT, f))]
    bad, skipped = [], []
    for f in files:
        if matches(f, LEGACY):
            skipped.append(f)
            continue
        at_head = sh('git', 'show', f'HEAD:{f}')
        if at_head.returncode == 0:
            r = sh('dart', 'format', '--output=none', '--set-exit-if-changed',
                   '--stdin-name', f, input=at_head.stdout)
            if r.returncode != 0:
                skipped.append(f + ' (unformatted at HEAD)')
                continue
        if sh('dart', 'format', '--output=none', '--set-exit-if-changed', f).returncode:
            bad.append(f)
    ok = not bad
    line = f'format   {"ok" if ok else "FAIL"}  {len(files)} changed dart files'
    if skipped:
        line += f', {len(skipped)} left alone'
    detail = [f'  needs `dart format {f}`' for f in bad]
    return ok, line, detail


def gate_analyze():
    out = sh('flutter', 'analyze', '--no-fatal-infos', '--no-fatal-warnings').stdout
    found = Counter()
    lines = {}
    for l in out.splitlines():
        m = re.match(r'\s*(error|warning|info) • (.*) • (\S+?):(\d+):\d+ • (\S+)', l)
        if m:
            key = (m.group(3), m.group(5))
            found[key] += 1
            lines.setdefault(key, []).append(f'  {m.group(1)} {m.group(3)}:{m.group(4)} {m.group(5)}: {m.group(2)[:100]}')
    if not found and 'No issues found' not in out and 'issues found' not in out:
        return False, 'analyze  BROKEN  no analyzer result', [out[-400:]]
    extra = []
    for key, n in found.items():
        if n > KNOWN_ANALYZE.get(key, 0):
            extra += lines[key]
    gone = [k for k, n in KNOWN_ANALYZE.items() if found.get(k, 0) < n]
    ok = not extra
    line = f'analyze  {"ok" if ok else "FAIL"}  {sum(found.values())} findings, {len(extra)} new'
    detail = extra[:30]
    if gone:
        detail.append(f'  note: known finding(s) fixed, update KNOWN_ANALYZE: {gone}')
    return ok, line, detail


def gate_tests(paths=()):
    # A hung test fails in TEST_TIMEOUT instead of Flutter's 10 minutes.
    r = sh('flutter', 'test', '--reporter', 'json', '--timeout', TEST_TIMEOUT, *paths)
    names, failed, errs, done, total = {}, [], {}, None, 0
    for l in r.stdout.splitlines():
        try:
            e = json.loads(l)
        except ValueError:
            continue
        if not isinstance(e, dict):
            continue
        t = e.get('type')
        if t == 'testStart':
            names[e['test']['id']] = e['test']['name']
        elif t == 'error':
            errs.setdefault(e['testID'], e['error'].strip().splitlines()[0][:140])
        elif t == 'testDone' and not e.get('hidden'):
            total += 1
            if e['result'] != 'success':
                failed.append(e['testID'])
        elif t == 'done':
            done = e.get('success')
    if done is None:
        return False, 'tests    BROKEN  no result', r.stderr.strip().splitlines()[-8:]
    ok = not failed and done
    line = f'tests    {"ok" if ok else "FAIL"}  {total} run, {len(failed)} failed'
    return ok, line, [f'  {names.get(i, i)}: {errs.get(i, "")}' for i in failed[:20]]


def _imports(path):
    """Repo-relative dart files [path] imports, exports or parts."""
    try:
        src = open(os.path.join(ROOT, path), encoding='utf-8').read()
    except OSError:
        return []
    out = []
    for u in IMPORT.findall(src):
        if u.startswith('package:cgpa_calculator/'):
            out.append('lib/' + u[len('package:cgpa_calculator/'):])
        elif not u.startswith(('package:', 'dart:')):
            out.append(os.path.normpath(os.path.join(os.path.dirname(path), u)))
    return out


def affected_tests(changed):
    """Test files that transitively import a changed file; None = run all."""
    if any(matches(f, FULL_SUITE) for f in changed):
        return None
    users = {}  # file -> files that import it
    for top in ('lib', 'test'):
        for dirpath, _, names in os.walk(os.path.join(ROOT, top)):
            for n in names:
                if n.endswith('.dart'):
                    f = os.path.relpath(os.path.join(dirpath, n), ROOT)
                    for d in _imports(f):
                        users.setdefault(d, set()).add(f)
    hit, todo = set(), [f for f in changed if f.endswith('.dart')]
    while todo:  # everything that reaches a changed file, cycles included
        f = todo.pop()
        if f not in hit:
            hit.add(f)
            todo.extend(users.get(f, ()))
    return sorted(f for f in hit if f.startswith('test/') and f.endswith('_test.dart'))


def gate_affected():
    picked = affected_tests(changed_files())
    if picked is None:
        ok, line, detail = gate_tests()
        return ok, line + '  (full: a FULL_SUITE file changed)', detail
    if not picked:
        return True, 'tests    ok  0 affected test files', []
    ok, line, detail = gate_tests(picked)
    return ok, line + f'  ({len(picked)} affected files)', detail


def gate_rules():
    if not any(f == 'firestore.rules' or f.startswith('test/rules/') for f in changed_files()):
        return True, 'rules    skip  unchanged', []
    import socket
    warm = socket.socket().connect_ex(('127.0.0.1', 8085)) == 0
    script = 'test:warm' if warm else 'test'
    r = sh('bash', '-lc', f'source ~/.nvm/nvm.sh >/dev/null; cd test/rules && npm run -s {script}')
    passed = re.search(r'# pass (\d+)', r.stdout)
    failed = re.search(r'# fail (\d+)', r.stdout)
    if not passed or not failed:
        return False, 'rules    BROKEN  no result', (r.stdout + r.stderr).strip().splitlines()[-8:]
    ok = failed.group(1) == '0' and r.returncode == 0
    bad = [l for l in r.stdout.splitlines() if l.lstrip().startswith('not ok')]
    return ok, f'rules    {"ok" if ok else "FAIL"}  {passed.group(1)} passed, {failed.group(1)} failed ({"warm" if warm else "cold"})', bad[:20]


def gate_ui(card):
    r = sh('python3', 'agent_toolchains/ui_check/ui_check.py', 'run', '--card', card)
    ok = r.returncode in (0, 1) and 'TOOLING BROKEN' not in r.stdout
    tail = [l for l in r.stdout.splitlines()
            if l.startswith(('  ', 'TOOLING', 'NEW', 'LOOK', 'CHANGED', 'TESTS'))]
    return ok, f'ui       {"see list" if ok else "BROKEN"}  (build/ui_check/summary.txt)', tail[:30]


def selftest():
    """Plant one problem per gate in a scratch file and require each gate to
    catch it; then remove the file and require the gates to pass again."""
    probe = 'lib/zz_verify_probe.dart'
    path = os.path.join(ROOT, probe)
    results = []
    try:
        with open(path, 'w') as f:
            f.write('int  zzProbe( ) {var unused = 1; return 2;}\n')
        results.append(('format catches an unformatted new file', not gate_format([probe])[0]))
        results.append(('analyze catches a new finding', not gate_analyze()[0]))
        test = os.path.join(ROOT, 'test', 'zz_verify_probe_test.dart')
        with open(test, 'w') as f:
            f.write("import 'package:flutter_test/flutter_test.dart';\n"
                    "void main() { test('planted', () => expect(1, 2)); }\n")
        try:
            results.append(('tests catch a failing test',
                            not gate_tests(['test/zz_verify_probe_test.dart'])[0]))
        finally:
            os.remove(test)
        hang = os.path.join(ROOT, 'test', 'zz_verify_hang_test.dart')
        with open(hang, 'w') as f:
            f.write("import 'package:flutter_test/flutter_test.dart';\n"
                    "void main() { test('hangs', () => Future<void>.delayed("
                    "const Duration(minutes: 5))); }\n")
        try:
            import time
            t0 = time.time()
            caught = not gate_tests(['test/zz_verify_hang_test.dart'])[0]
            results.append((f'a hung test fails at the timeout ({time.time() - t0:.0f}s)',
                            caught and time.time() - t0 < 180))
        finally:
            os.remove(hang)
    finally:
        os.remove(path)
    results.append(('analyze passes once the probe is gone', gate_analyze()[0]))
    for name, ok in results:
        print(f'{"ok  " if ok else "FAIL"} {name}')
    return 0 if all(ok for _, ok in results) else 2


def main(argv):
    if '--selftest' in argv:
        return selftest()
    gates = [gate_format, gate_analyze]
    if '--affected' in argv:
        gates.append(gate_affected)
    elif '--fast' not in argv:
        gates.append(gate_tests)
    gates.append(gate_rules)
    all_ok = True
    for g in gates:
        ok, line, detail = g()
        print(line)
        if not ok:
            print('\n'.join(detail))
        elif detail:
            print('\n'.join(detail))
        all_ok &= ok
    if '--ui' in argv:
        ok, line, detail = gate_ui(argv[argv.index('--ui') + 1])
        print(line)
        print('\n'.join(detail))
        all_ok &= ok
    return 0 if all_ok else 1


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
