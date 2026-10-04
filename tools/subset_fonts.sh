#!/usr/bin/env bash
# UI_OPT O7.1: subsets fonts/*.ttf to the characters tools/font_chars.txt
# lists (built from lib/**/*.dart plus the printable ASCII and Latin-1
# ranges). Keeps every layout feature (kerning, ligatures) — only glyphs
# drop. Run from the repo root: tools/subset_fonts.sh
set -euo pipefail

cd "$(dirname "$0")/.."

for f in fonts/Montserrat-Regular.ttf fonts/Montserrat-Medium.ttf \
         fonts/Montserrat-SemiBold.ttf fonts/Montserrat-Bold.ttf \
         fonts/Montserrat-ExtraBold.ttf; do
  echo "Subsetting $f"
  pyftsubset "$f" \
    --unicodes-file=tools/font_chars.txt \
    --layout-features='*' \
    --output-file="$f"
done

du -sh fonts/
