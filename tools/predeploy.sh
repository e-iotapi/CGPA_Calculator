#!/usr/bin/env bash
# One command before every deploy (PERF_TEST_PLAN.md T7). Stops at the first
# failure. .github/workflows/check.yml runs only steps 1-4 and 6, to keep
# CI minutes down (§0.5); steps 5 and 7 need the emulators and run locally,
# or via the manual-dispatch-only e2e.yml.
set -euo pipefail
cd "$(dirname "$0")/.."

FLUTTER="${FLUTTER:-flutter}"

echo "== 1. flutter pub get =="
"$FLUTTER" pub get

echo "== 2. flutter analyze (no new issues vs. tools/analyze_baseline.txt) =="
analyze_out="$(mktemp)"
trap 'rm -f "$analyze_out"' EXIT
"$FLUTTER" analyze --no-fatal-infos > "$analyze_out" 2>&1 || true
cat "$analyze_out"
node tools/check_analyze_baseline.mjs < "$analyze_out"

echo "== 3. flutter test =="
"$FLUTTER" test

echo "== 4. firestore.rules tests =="
(cd test/rules && npm ci && npm test)

echo "== 5. seed snapshots + role-matrix/counters check, on fresh emulators =="
POINTER_SEED=1 "$FLUTTER" test tools/test_env/build_snapshots_test.dart
(cd tools/test_env && npm ci)
firebase emulators:exec --only auth,firestore --project demo-pointer \
  "node tools/test_env/seed.mjs && npm --prefix tools/test_env test"

echo "== 6. production build + prod guard =="
"$FLUTTER" build web --release --base-href /calculator/
if grep -q 'pointer-test-only' build/web/main.dart.js; then
  echo "Test-only sign-in leaked into the production build (T1's guard)." >&2
  exit 1
fi

echo "== 7. E2E, perf and quota specs, on fresh emulators =="
(cd tools/e2e && npm ci)
firebase emulators:exec --only auth,firestore --project demo-pointer "
  node tools/test_env/seed.mjs &&
  $FLUTTER build web --profile --dart-define=POINTER_ENV=emulator --dart-define=POINTER_EMULATOR_HOST=localhost &&
  npm --prefix tools/e2e test
"

echo "== predeploy checks passed =="
