#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="$(cd "$(dirname "$0")" && pwd)"
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
cd "$INSTALL_DIR"

echo "Marveen update..."
OLD_VERSION=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
if [[ "${MARVEEN_SKIP_GIT_PULL:-0}" == "1" ]]; then
  NEW_VERSION="$OLD_VERSION"
else
  git pull --ff-only origin main
  NEW_VERSION=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
fi

if [ "$OLD_VERSION" = "$NEW_VERSION" ]; then
  echo "Already up to date: $NEW_VERSION"
  exit 0
fi

if git diff "$OLD_VERSION" "$NEW_VERSION" --name-only | grep -q "package.json"; then
  npm install --silent
fi

npm run build --silent

if [[ "${MARVEEN_FORCE_FALLBACK:-0}" != "1" ]] && [[ "$OS" == "linux" ]] && command -v systemctl >/dev/null 2>&1; then
  systemctl --user restart marveen-dashboard.service marveen-channels.service
elif [[ "${MARVEEN_FORCE_FALLBACK:-0}" != "1" ]] && [[ "$OS" == "darwin" ]] && command -v launchctl >/dev/null 2>&1; then
  launchctl unload "$HOME/Library/LaunchAgents/com.marveen.dashboard.plist" 2>/dev/null || true
  launchctl load "$HOME/Library/LaunchAgents/com.marveen.dashboard.plist" 2>/dev/null || true
  launchctl unload "$HOME/Library/LaunchAgents/com.marveen.channels.plist" 2>/dev/null || true
  launchctl load "$HOME/Library/LaunchAgents/com.marveen.channels.plist" 2>/dev/null || true
else
  bash "$INSTALL_DIR/scripts/stop.sh" || true
  bash "$INSTALL_DIR/scripts/start.sh"
fi

echo "Updated: ${OLD_VERSION} -> ${NEW_VERSION}"
