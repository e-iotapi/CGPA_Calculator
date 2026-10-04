#!/usr/bin/env python3
"""Dump the old bits-course-reviews site's Supabase tables to JSON.

Usage: python3 tools/export_course_reviews.py [table ...]
Writes tools/course_reviews_out/<table>.json (gitignored: student-written data).
"""
import json, re, sys, urllib.request
from pathlib import Path

SITE = "https://bits-course-reviews.vercel.app"
TABLES = sys.argv[1:] or ["courses", "reviews", "projects"]
OUT = Path(__file__).parent / "course_reviews_out"
PAGE = 1000  # Supabase's default max rows per request


def get(url, headers=None):
    req = urllib.request.Request(url, headers={"User-Agent": "pointer-export", **(headers or {})})
    with urllib.request.urlopen(req) as r:
        return r.read().decode()


def supabase_config(bundle):
    url = re.search(r"https://[a-z0-9]+\.supabase\.co", bundle).group(0)
    key = re.search(r"sb_publishable_[\w-]+|eyJ[\w-]{10,}\.[\w-]+\.[\w-]+", bundle).group(0)
    return url, key


def main():
    js = re.search(r'src="(/assets/index-[^"]+\.js)"', get(SITE)).group(1)
    url, key = supabase_config(get(SITE + js))
    auth = {"apikey": key, "Authorization": f"Bearer {key}"}
    OUT.mkdir(exist_ok=True)
    for t in TABLES:
        rows = []
        # ponytail: unordered offset paging; fine for a frozen table, add order=<pk> if rows shift between pages
        while True:
            page = json.loads(get(f"{url}/rest/v1/{t}?select=*&limit={PAGE}&offset={len(rows)}", auth))
            rows += page
            print(f"\r{t}: {len(rows)} rows...", end="", flush=True)
            if len(page) < PAGE:
                break
        (OUT / f"{t}.json").write_text(json.dumps(rows, indent=2, ensure_ascii=False), encoding="utf-8")
        print(f"\r{t}: {len(rows)} rows   ")


if __name__ == "__main__":
    main()
