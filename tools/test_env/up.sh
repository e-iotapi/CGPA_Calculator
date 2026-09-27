#!/usr/bin/env bash
# Starts the Auth + Firestore emulators, seeds them, and serves the app
# against them (PERF_TEST_PLAN.md T2). Run from the repo root:
#   tools/test_env/up.sh
set -euo pipefail

cd "$(dirname "$0")/../.."

HOST="${HOST:-localhost}"

wait_for_port() {
  local port=$1
  for _ in $(seq 1 60); do
    if (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null; then
      exec 3<&- 3>&-
      return 0
    fi
    sleep 1
  done
  echo "Timed out waiting for port $port" >&2
  exit 1
}

firebase emulators:start --only auth,firestore --project demo-pointer &
EMULATOR_PID=$!
trap 'kill "$EMULATOR_PID" 2>/dev/null || true' EXIT

wait_for_port 9099
wait_for_port 8085

(cd tools/test_env && npm install --no-fund --no-audit)
node tools/test_env/seed.mjs

echo
echo "Seeded. Open any of these once the app is serving:"
node --input-type=commonjs -e "
const {accounts} = require('./test_env/accounts.json');
for (const a of accounts) console.log(\`  http://$HOST:5000/?as=\${a.key}\`);
"
echo

flutter run -d web-server --web-port 5000 \
  --dart-define=POINTER_ENV=emulator \
  --dart-define=POINTER_EMULATOR_HOST="$HOST"
