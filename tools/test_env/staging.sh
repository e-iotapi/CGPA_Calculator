#!/usr/bin/env bash
# Deploys rules/indexes, seeds, and builds against the staging Firebase
# project (PERF_TEST_PLAN.md T5). Run from the repo root:
#   STAGING_PASSWORD=... GOOGLE_APPLICATION_CREDENTIALS=key.json tools/test_env/staging.sh
# Hosting goes to the "staging" target, which only the staging project maps
# (.firebaserc), so this can never deploy to production.
set -euo pipefail

cd "$(dirname "$0")/../.."

if [ -z "${STAGING_PASSWORD:-}" ]; then
  echo "STAGING_PASSWORD is not set. It comes from a secret, never the" >&2
  echo "test_env/accounts.json default (T5)." >&2
  exit 1
fi

# The CLI deploys as your `firebase login`; the service-account key is for
# the seed alone (it lacks deploy permissions and the CLI stalls on it).
fb() { env -u GOOGLE_APPLICATION_CREDENTIALS firebase "$@"; }

fb deploy --only firestore:rules,firestore:indexes --project staging

(cd tools/test_env && npm install --no-fund --no-audit)
node tools/test_env/seed.mjs --project staging

flutter build web --release \
  --dart-define=POINTER_ENV=staging \
  --dart-define=POINTER_TEST_PASSWORD="$STAGING_PASSWORD" \
  --build-number="$(date +%s)"

# Staging serves the app at /, not /calculator/ (prod's path, BUG-39) — the
# manifest is built assuming prod's path, so fix start_url/scope for here.
sed -i 's#"/calculator/"#"/"#g' build/web/manifest.json

fb deploy --only hosting:staging --project staging
