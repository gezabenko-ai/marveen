#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"

echo "Stopping Marveen..."

if [[ "$OS" == "linux" ]] && command -v systemctl >/dev/null 2>&1; then
  systemctl --user stop marveen-dashboard.service marveen-channels.service 2>/dev/null || true
elif [[ "$OS" == "darwin" ]] && command -v launchctl >/dev/null 2>&1; then
  launchctl unload "$HOME/Library/LaunchAgents/com.marveen.dashboard.plist" 2>/dev/null || true
  launchctl unload "$HOME/Library/LaunchAgents/com.marveen.channels.plist" 2>/dev/null || true
fi

tmux kill-session -t marveen-channels 2>/dev/null || true
for session in $(tmux list-sessions -F '#{session_name}' 2>/dev/null | grep '^agent-' || true); do
  tmux kill-session -t "$session" 2>/dev/null || true
done

if [ -f "$INSTALL_DIR/store/marveen.pid" ]; then
  kill "$(cat "$INSTALL_DIR/store/marveen.pid")" 2>/dev/null || true
  rm -f "$INSTALL_DIR/store/marveen.pid"
fi

if [ -f "$INSTALL_DIR/store/channels.pid" ]; then
  kill "$(cat "$INSTALL_DIR/store/channels.pid")" 2>/dev/null || true
  rm -f "$INSTALL_DIR/store/channels.pid"
fi

echo "Marveen stopped"
