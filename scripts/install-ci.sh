#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"

echo "[CI] Marveen non-interactive install on: $OS"

for c in node npm git; do
  command -v "$c" >/dev/null 2>&1 || { echo "Missing required command: $c"; exit 1; }
done

cd "$INSTALL_DIR"
npm ci --silent
npm run build --silent

mkdir -p "$INSTALL_DIR/store" "$INSTALL_DIR/agents" "$INSTALL_DIR/.claude/channels/telegram"

if [ ! -f "$INSTALL_DIR/.env" ]; then
  cat > "$INSTALL_DIR/.env" <<ENVEOF
TELEGRAM_BOT_TOKEN=dummy-token
ALLOWED_CHAT_ID=0
OWNER_NAME=CI
ENVEOF
fi

if [[ "$OS" == "linux" ]]; then
  mkdir -p "$HOME/.config/systemd/user"
  cp "$INSTALL_DIR/deploy/systemd-user/marveen-dashboard.service" "$HOME/.config/systemd/user/"
  cp "$INSTALL_DIR/deploy/systemd-user/marveen-channels.service" "$HOME/.config/systemd/user/"
elif [[ "$OS" == "darwin" ]]; then
  PLIST_DIR="$HOME/Library/LaunchAgents"
  mkdir -p "$PLIST_DIR"
  NODE_PATH="$(command -v node)"

  cat > "$PLIST_DIR/com.marveen.dashboard.plist" <<PLIST1
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.marveen.dashboard</string>
  <key>ProgramArguments</key><array>
    <string>${NODE_PATH}</string>
    <string>${INSTALL_DIR}/dist/index.js</string>
  </array>
  <key>WorkingDirectory</key><string>${INSTALL_DIR}</string>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
</dict></plist>
PLIST1

  cat > "$PLIST_DIR/com.marveen.channels.plist" <<PLIST2
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.marveen.channels</string>
  <key>ProgramArguments</key><array>
    <string>${INSTALL_DIR}/scripts/channels.sh</string>
  </array>
  <key>WorkingDirectory</key><string>${INSTALL_DIR}</string>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
</dict></plist>
PLIST2

  if command -v plutil >/dev/null 2>&1; then
    plutil -lint "$PLIST_DIR/com.marveen.dashboard.plist"
    plutil -lint "$PLIST_DIR/com.marveen.channels.plist"
  fi
fi

echo "[CI] install complete"
