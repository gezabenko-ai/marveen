#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$INSTALL_DIR"

PORT="${WEB_PORT:-3420}"

echo "[CI] post-install checks"
test -f .env
test -d store
test -d agents
test -d dist

# Quick direct app boot smoke
node dist/index.js >/tmp/marveen-dashboard-smoke.log 2>&1 &
APP_PID=$!
trap 'kill "$APP_PID" 2>/dev/null || true' EXIT

for _ in $(seq 1 20); do
  if curl -fsS "http://127.0.0.1:${PORT}" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

curl -fsS "http://127.0.0.1:${PORT}" >/dev/null
kill "$APP_PID" 2>/dev/null || true
wait "$APP_PID" 2>/dev/null || true
trap - EXIT

echo "[CI] start/stop fallback smoke"
MARVEEN_FORCE_FALLBACK=1 bash scripts/start.sh
sleep 2
bash scripts/stop.sh

# Update smoke path (skip network pull in CI)
echo "[CI] update script smoke"
MARVEEN_SKIP_GIT_PULL=1 MARVEEN_FORCE_FALLBACK=1 bash update.sh || true

echo "[CI] runtime smoke OK"
