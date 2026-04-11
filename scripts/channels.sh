#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SESSION="marveen-channels"

export PATH="$HOME/.local/bin:$HOME/.bun/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

CLAUDE_BIN="$(command -v claude || true)"
TMUX_BIN="$(command -v tmux || true)"

if [ -z "$CLAUDE_BIN" ]; then
  echo "ERROR: claude CLI not found in PATH"
  exit 1
fi
if [ -z "$TMUX_BIN" ]; then
  echo "ERROR: tmux not found in PATH"
  exit 1
fi

# Load local env if present
if [ -f "$INSTALL_DIR/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  source "$INSTALL_DIR/.env"
  set +a
fi

TELEGRAM_STATE_DIR="$INSTALL_DIR/.claude/channels/telegram"
mkdir -p "$TELEGRAM_STATE_DIR"

if [ -n "${TELEGRAM_BOT_TOKEN:-}" ]; then
  printf 'TELEGRAM_BOT_TOKEN=%s\n' "$TELEGRAM_BOT_TOKEN" > "$TELEGRAM_STATE_DIR/.env"
fi

if [ ! -f "$TELEGRAM_STATE_DIR/access.json" ]; then
  cat > "$TELEGRAM_STATE_DIR/access.json" <<JSON
{
  "dmPolicy": "allowlist",
  "allowFrom": ["${ALLOWED_CHAT_ID:-}"]
}
JSON
fi

if "$TMUX_BIN" has-session -t "$SESSION" 2>/dev/null; then
  while "$TMUX_BIN" has-session -t "$SESSION" 2>/dev/null; do sleep 5; done
  exit 0
fi

MODEL="${CLAUDE_MODEL:-claude-opus-4-6}"
EFFORT="${CLAUDE_EFFORT:-medium}"
CMD="cd \"$INSTALL_DIR\" && export TELEGRAM_STATE_DIR=\"$TELEGRAM_STATE_DIR\" && $CLAUDE_BIN --dangerously-skip-permissions --effort $EFFORT --model $MODEL --channels plugin:telegram@claude-plugins-official"

"$TMUX_BIN" new-session -d -s "$SESSION" "bash -lc '$CMD; echo Session ended; sleep 5'"
"$INSTALL_DIR/scripts/set-bot-menu.sh" >/dev/null 2>&1 || true

while "$TMUX_BIN" has-session -t "$SESSION" 2>/dev/null; do sleep 5; done
