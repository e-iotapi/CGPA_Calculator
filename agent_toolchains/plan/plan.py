#!/usr/bin/env python3
"""Read the plan by its numbers instead of reading the whole file.

  python3 agent_toolchains/plan/plan.py list [FILE]      # index: id, lines, title
  python3 agent_toolchains/plan/plan.py get ID [ID...]   # exact text, e.g. T7.3 8.4 N27 O0.2
                                                         # FILE:ID when both files have it (UI_OPT.md:1.1)
  python3 agent_toolchains/plan/plan.py check            # prove the parse is sound

Parsed fresh from UI.md and UI_OPT.md on every call (milliseconds), so it
can never be stale. Items, all by structure:
  headings   '#'..'######' outside ``` fences; id = the leading number
             ("8.3", "O0.2", "13.2.10") or, if none, the whole title
  cards      a line starting '**T7.2 ·' (UI.md build cards)
  findings   a line starting '- **N27 ·' (UI.md §15)
An item runs to the line before the next item of its own kind or of any
heading at its level or above; `get` prints the file's own lines, never a
rewrite. An id that matches nothing, or more than one item, is an error:
nothing is guessed.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FILES = ['agent_instructions/deprecated/UI.md', 'agent_instructions/deprecated/UI_OPT.md',
         'agent_instructions/PERF_TEST_PLAN.md']
HEAD = re.compile(r'^(#{1,6}) (.*)$')
CARD = re.compile(r'^\*\*(T\d+\.\d+)\b')
FIND = re.compile(r'^- \*\*(N\d+)\b')
NUM = re.compile(r'^((?:[A-Z]\d+[a-z]?|\d+)(?:\.\d+)*)\b')


def parse(name):
    lines = open(os.path.join(ROOT, name), encoding='utf-8').read().split('\n')
    items, fence = [], False
    for i, line in enumerate(lines):
        if line.startswith('```'):
            fence = not fence
            continue
        if fence:
            continue
        if m := HEAD.match(line):
            title = m.group(2).strip()
            n = NUM.match(title)
            items.append(dict(kind='h', level=len(m.group(1)), id=n.group(1) if n else title,
                              title=title, start=i))
        elif m := CARD.match(line):
            items.append(dict(kind='card', level=7, id=m.group(1), title=line.strip('*'), start=i))
        elif m := FIND.match(line):
            items.append(dict(kind='find', level=8, id=m.group(1), title=line[2:].strip('*'), start=i))
    for k, it in enumerate(items):
        end = len(lines)
        for nxt in items[k + 1:]:
            if nxt['kind'] == 'h' and (it['kind'] != 'h' or nxt['level'] <= it['level']):
                end = nxt['start']
                break
            if nxt['kind'] == it['kind'] and it['kind'] != 'h':
                end = nxt['start']
                break
            if it['kind'] == 'find' and nxt['kind'] != 'find':
                end = nxt['start']
                break
        if it['kind'] == 'find':
            # A finding is one list item: stop at the first unindented line.
            for j in range(it['start'] + 1, end):
                if lines[j] and not lines[j].startswith(' '):
                    end = j
                    break
        while end > it['start'] + 1 and not lines[end - 1].strip():
            end -= 1
        it['end'], it['file'] = end, name
    return lines, items


def load():
    return {f: parse(f) for f in FILES if os.path.exists(os.path.join(ROOT, f))}


def main(argv):
    if not argv or argv[0] not in ('list', 'get', 'check'):
        print(__doc__)
        return 2
    docs = load()
    if argv[0] == 'list':
        for f, (_, items) in docs.items():
            if len(argv) > 1 and argv[1] not in (f, os.path.basename(f)):
                continue
            for it in items:
                pad = '  ' * (min(it['level'], 7) - 1) if it['kind'] == 'h' else '    '
                print(f"{f}:{it['start'] + 1}-{it['end']} {pad}{it['id']} | {it['title'][:70]}")
        return 0
    if argv[0] == 'get':
        rc = 0
        for want in argv[1:]:
            only, _, key = want.rpartition(':')  # UI_OPT.md:1.1 picks a file
            hits = [(f, lines, it) for f, (lines, items) in docs.items() for it in items
                    if it['id'] == key.lstrip('§') and only in ('', f, os.path.basename(f))]
            if len(hits) != 1:
                where = ', '.join(f"{f}:{it['start'] + 1}" for f, _, it in hits)
                print(f'ERROR {want}: {len(hits)} matches {where}'.rstrip(), file=sys.stderr)
                rc = 1
                continue
            f, lines, it = hits[0]
            print(f"=== {want}  {f}:{it['start'] + 1}-{it['end']}")
            print('\n'.join(lines[it['start']:it['end']]))
        return rc
    # check: each item's text is its file's own lines, ids of cards and
    # findings are unique, every card found by grep is found by the parser.
    bad = 0
    for f, (lines, items) in docs.items():
        seen = {}
        for it in items:
            if it['end'] <= it['start']:
                print(f"BAD {f}:{it['start'] + 1} {it['id']} is empty"); bad += 1
            if it['kind'] != 'h':
                if it['id'] in seen:
                    print(f"DUP {it['id']} at {f}:{seen[it['id']] + 1} and {it['start'] + 1}"); bad += 1
                seen[it['id']] = it['start']
        raw_cards = sum(1 for l in lines if CARD.match(l))
        raw_heads = sum(1 for l in lines if HEAD.match(l))
        got_cards = sum(1 for it in items if it['kind'] == 'card')
        got_heads = sum(1 for it in items if it['kind'] == 'h')
        if got_cards != raw_cards:
            print(f'BAD {f}: {got_cards} cards parsed, {raw_cards} by grep'); bad += 1
        print(f'{f}: {got_heads} headings ({raw_heads} lines start with #, fenced ones excluded), '
              f'{got_cards} cards, {sum(1 for it in items if it["kind"] == "find")} findings')
    print('ok' if not bad else f'{bad} problems')
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
