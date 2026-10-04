"""Repo rules the code tools enforce (see ../README.md)."""
import fnmatch
import os
import subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Never format these by hand or tool: they are unformatted at HEAD on purpose.
LEGACY = ['lib/main.dart', 'lib/home_page.dart', 'lib/script.dart',
          'lib/course.dart', 'lib/mastercourselist.dart', 'lib/sync.dart',
          'lib/features/settings/settings_page.dart',
          'test/settings/settings_test.dart']

# Never committed.
FORBIDDEN = ['test/fixtures/transcript.csv', 'test/fixtures/performance_sheet.json',
             '*.pdf', 'agent_instructions/deprecated/PLAN.md', 'sensitive_data_NO_COMMIT/*', 'idthp', '*.png', '*.jpg', 'test/ui/zz_*', 'build/*']

# Committed although they match FORBIDDEN: the UI sheet the user asked for
# (ui_check.py atlas), for their own manual pass.
ALLOWED = ['ui_sheet/ui_sheet.png']

# Never edited by the edit tool without --allow (docs of record).
PROTECTED = ['agent_instructions/deprecated/PLAN.md']

# The only analyze findings allowed: (file, rule) -> count.
KNOWN_ANALYZE = {
    ('lib/home_page.dart', 'unnecessary_import'): 1,
    ('lib/script.dart', 'empty_catches'): 2,
    ('lib/script.dart', 'non_constant_identifier_names'): 2,
    ('test/semester/add_course_test.dart', 'prefer_interpolation_to_compose_strings'): 1,
    ('test/semester/edit_course_test.dart', 'prefer_interpolation_to_compose_strings'): 1,
}

# Deprecated (cloud container): a Claude-Session line; local sessions add none.
def matches(path, patterns):
    return any(fnmatch.fnmatch(path, p) for p in patterns)


def sh(*cmd, check=False, **kw):
    env = dict(os.environ)
    env['PATH'] = os.path.expanduser('~/development/flutter/bin') + ':/opt/flutter/bin:' + env.get('PATH', '')
    return subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True,
                          check=check, env=env, **kw)


def changed_files():
    """Tracked files changed against HEAD plus untracked ones, repo-relative."""
    out = sh('git', 'status', '--porcelain', '--untracked-files=all').stdout
    files = []
    for line in out.splitlines():
        p = line[3:].split(' -> ')[-1].strip('"')
        if line[:2].strip() != 'D':
            files.append(p)
    return files
