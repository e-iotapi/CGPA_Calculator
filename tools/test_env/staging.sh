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

firebase deploy --only firestore:rules,firestore:indexes --project staging

(cd tools/test_env && npm install --no-fund --no-audit)
node tools/test_env/seed.mjs --project staging

flutter build web --release \
  --dart-define=POINTER_ENV=staging \
  --dart-define=POINTER_TEST_PASSWORD="$STAGING_PASSWORD"

firebase deploy --only hosting:staging --project staging
