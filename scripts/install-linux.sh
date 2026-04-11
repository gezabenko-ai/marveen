#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "Linux installer (Ubuntu/Debian friendly)"

missing=0
for c in node npm git tmux; do
  if ! command -v "$c" >/dev/null 2>&1; then
    echo "Missing: $c"
    missing=1
  fi
done
if [ "$missing" -ne 0 ]; then
  echo "Install missing deps first (example): sudo apt update && sudo apt install -y nodejs npm git tmux"
  exit 1
fi

if [[ "${MARVEEN_CI:-0}" != "1" ]] && ! command -v claude >/dev/null 2>&1; then
  echo "Missing Claude CLI: npm install -g @anthropic-ai/claude-code"
  exit 1
fi

cd "$INSTALL_DIR"
if [[ "${MARVEEN_CI:-0}" == "1" ]]; then
  npm ci --silent
else
  npm install --silent
fi
npm run build --silent
mkdir -p "$INSTALL_DIR/store" "$INSTALL_DIR/agents" "$INSTALL_DIR/.claude/channels/telegram"

if [ ! -f "$INSTALL_DIR/.env" ]; then
  cp "$INSTALL_DIR/.env.example" "$INSTALL_DIR/.env"
  echo "Created .env from template, please edit it."
fi

mkdir -p "$HOME/.config/systemd/user"
cp "$INSTALL_DIR/deploy/systemd-user/marveen-dashboard.service" "$HOME/.config/systemd/user/"
cp "$INSTALL_DIR/deploy/systemd-user/marveen-channels.service" "$HOME/.config/systemd/user/"

if [[ "${MARVEEN_CI:-0}" != "1" ]] && command -v systemctl >/dev/null 2>&1; then
  systemctl --user daemon-reload
  systemctl --user enable marveen-dashboard.service marveen-channels.service
  systemctl --user restart marveen-dashboard.service marveen-channels.service || true
fi

echo "Linux install done."
echo "Optional for reboot persistence: sudo loginctl enable-linger $(whoami)"
