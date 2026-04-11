#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"

echo "Starting Marveen..."

if [[ "$OS" == "linux" ]] && command -v systemctl >/dev/null 2>&1; then
  systemctl --user start marveen-dashboard.service marveen-channels.service 2>/dev/null || true
  echo "systemd user services started"
elif [[ "$OS" == "darwin" ]] && command -v launchctl >/dev/null 2>&1; then
  launchctl load "$HOME/Library/LaunchAgents/com.marveen.dashboard.plist" 2>/dev/null || true
  launchctl load "$HOME/Library/LaunchAgents/com.marveen.channels.plist" 2>/dev/null || true
  echo "launchd services loaded"
else
  mkdir -p "$INSTALL_DIR/store"
  nohup node "$INSTALL_DIR/dist/index.js" >> "$INSTALL_DIR/store/dashboard.log" 2>&1 &
  echo $! > "$INSTALL_DIR/store/marveen.pid"
  nohup bash "$INSTALL_DIR/scripts/channels.sh" >> "$INSTALL_DIR/store/channels.log" 2>&1 &
  echo $! > "$INSTALL_DIR/store/channels.pid"
  echo "fallback processes started"
fi

echo "Dashboard: http://localhost:3420"
