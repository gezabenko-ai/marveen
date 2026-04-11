#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="$(cd "$(dirname "$0")/.." && pwd)"

say() { echo "$1"; }

ask_yes_no() {
  local prompt="$1"
  local default_yes="${2:-1}"
  local reply

  if [[ "${MARVEEN_CI:-0}" == "1" ]]; then
    [[ "$default_yes" == "1" ]] && return 0 || return 1
  fi

  if [[ "$default_yes" == "1" ]]; then
    read -r -p "$prompt (i/n) [i]: " reply || true
    reply=${reply:-i}
  else
    read -r -p "$prompt (i/n) [n]: " reply || true
    reply=${reply:-n}
  fi

  [[ "$reply" == "i" || "$reply" == "I" || "$reply" == "y" || "$reply" == "Y" ]]
}

run_pkg_install() {
  local pkgs=("$@")
  if command -v apt-get >/dev/null 2>&1; then
    if command -v sudo >/dev/null 2>&1; then
      sudo apt-get update && sudo apt-get install -y "${pkgs[@]}"
    else
      apt-get update && apt-get install -y "${pkgs[@]}"
    fi
  elif command -v dnf >/dev/null 2>&1; then
    if command -v sudo >/dev/null 2>&1; then
      sudo dnf install -y "${pkgs[@]}"
    else
      dnf install -y "${pkgs[@]}"
    fi
  elif command -v pacman >/dev/null 2>&1; then
    if command -v sudo >/dev/null 2>&1; then
      sudo pacman -Sy --noconfirm "${pkgs[@]}"
    else
      pacman -Sy --noconfirm "${pkgs[@]}"
    fi
  else
    return 1
  fi
}

say "Linux telepítő"

missing=()
for c in node npm git tmux; do
  if ! command -v "$c" >/dev/null 2>&1; then
    missing+=("$c")
  fi
done

if [[ ${#missing[@]} -gt 0 ]]; then
  say "Hiányzó függőségek: ${missing[*]}"
  if ask_yes_no "Telepítsem most csomagkezelővel?" 1; then
    if ! run_pkg_install nodejs npm git tmux; then
      say "Nem találtam támogatott csomagkezelőt (apt/dnf/pacman)."
      say "Telepítsd kézzel: node, npm, git, tmux"
      exit 1
    fi
  else
    say "Megszakítva. Telepítsd a hiányzó függőségeket, majd futtasd újra."
    exit 1
  fi
fi

# Node verzió ellenőrzés (minimum 20)
if command -v node >/dev/null 2>&1; then
  node_major="$(node -v | sed 's/^v//' | cut -d. -f1)"
  if [[ "$node_major" -lt 20 ]]; then
    say "A Node verzió túl régi: $(node -v), minimum: v20"
    if ask_yes_no "Próbáljak Node frissítést csomagkezelővel?" 1; then
      run_pkg_install nodejs npm || true
    fi
    node_major="$(node -v | sed 's/^v//' | cut -d. -f1)"
    if [[ "$node_major" -lt 20 ]]; then
      say "Node továbbra is túl régi. Frissíts legalább v20-ra."
      exit 1
    fi
  fi
fi

if [[ "${MARVEEN_CI:-0}" != "1" ]] && ! command -v claude >/dev/null 2>&1; then
  say "Hiányzik a Claude CLI"
  if ask_yes_no "Telepítsem most? (curl -fsSL https://claude.ai/install.sh | bash)" 1; then
    if command -v curl >/dev/null 2>&1; then
      curl -fsSL https://claude.ai/install.sh | bash || {
        say "Claude CLI telepítése nem sikerült. Próbáld kézzel: curl -fsSL https://claude.ai/install.sh | bash"
        exit 1
      }
    else
      say "A curl hiányzik. Telepítsd előbb a curl-t, majd futtasd: curl -fsSL https://claude.ai/install.sh | bash"
      exit 1
    fi
  else
    say "Megszakítva. Telepítsd a Claude CLI-t, majd futtasd újra."
    exit 1
  fi
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
  say "Létrehoztam: .env (template alapján)."
fi

mkdir -p "$HOME/.config/systemd/user"
cp "$INSTALL_DIR/deploy/systemd-user/marveen-dashboard.service" "$HOME/.config/systemd/user/"
cp "$INSTALL_DIR/deploy/systemd-user/marveen-channels.service" "$HOME/.config/systemd/user/"

if [[ "${MARVEEN_CI:-0}" != "1" ]] && command -v systemctl >/dev/null 2>&1; then
  systemctl --user daemon-reload
  systemctl --user enable marveen-dashboard.service marveen-channels.service
  systemctl --user restart marveen-dashboard.service marveen-channels.service || true
fi

say "Linux telepítés kész."
say "Opcionális reboot utáni autostart: sudo loginctl enable-linger $(whoami)"
