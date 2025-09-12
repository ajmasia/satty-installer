#!/usr/bin/env bash
# Satty Installer + Capture Script + GNOME Shortcut
# -------------------------------------------------
# 1. Downloads and installs the latest Satty release into /opt/satty
#    and creates a symlink in /usr/local/bin/satty.
# 2. Installs the capture script (capture.sh) into ~/.local/bin/capture.
#    If not found locally, downloads it from the repo.
# 3. Creates a GNOME custom keyboard shortcut for the capture script,
#    asking the user which keybinding to use (default: <Shift><Super>P).

set -euo pipefail

# --- App and repo information ---
APP="satty"
REPO="gabm/Satty"
API_URL="https://api.github.com/repos/${REPO}/releases/latest"

OPT_DIR="/opt/$APP"
BIN_LINK="/usr/local/bin/$APP"

# --- Capture script installation ---
CAPTURE_SCRIPT="capture"
USER_BIN="$HOME/.local/bin"
CAPTURE_LOCAL="capture.sh"
CAPTURE_REMOTE="https://raw.githubusercontent.com/ajmasia/satty-installer/main/capture.sh"

# --- GNOME keybinding settings ---
GNOME_KEY="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings"
GNOME_SCHEMA="org.gnome.settings-daemon.plugins.media-keys.custom-keybinding"

# --- Helper functions ---
need() { command -v "$1" >/dev/null 2>&1 || {
  echo "⚠️ Missing dependency: '$1'. Please install it and try again." >&2
  exit 1
}; }

cleanup() { rm -rf "$TMP"; }

create_shortcut() {
  local name="satty-capture"
  local binding="${1:-<Shift><Super>P}"
  local command="$CAPTURE_SCRIPT"
  local key_path="$GNOME_KEY/$name/"
  local existing new

  existing=$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings)

  # Normalize empty list
  if [[ "$existing" == "@as []" || "$existing" == "[]" ]]; then
    new="['$key_path']"
  else
    # Avoid duplicates
    if [[ "$existing" == *"$key_path"* ]]; then
      echo "⚠️  Shortcut '$name' already exists → $binding"
      return
    fi
    # Append new path
    new=$(echo "$existing" | sed "s/]$/, '$key_path']/")
  fi

  echo ">> Registering GNOME custom shortcut '$name' ..."
  gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "$new"

  gsettings set "$GNOME_SCHEMA:$key_path" name "$name"
  gsettings set "$GNOME_SCHEMA:$key_path" command "$command"
  gsettings set "$GNOME_SCHEMA:$key_path" binding "$binding"

  echo "✅ Custom shortcut created: $binding → $command"
}

# --- Must be run as root ---
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Use: sudo bash $0" >&2
  exit 1
fi

# --- Required dependencies ---
need tar
need curl
need install
need gnome-screenshot

if command -v curl >/dev/null 2>&1; then
  DL="curl -fsSL"
elif command -v wget >/dev/null 2>&1; then
  DL="wget -qO-"
else
  echo "Missing 'curl' or 'wget'." >&2
  exit 1
fi

# --- Install Satty ---
TMP="$(mktemp -d)"
trap cleanup EXIT

if [[ -d "$OPT_DIR" ]]; then
  echo "⚠️  Satty is already installed in $OPT_DIR."
else
  echo ">> Fetching latest release info..."
  JSON="$($DL "$API_URL")"

  if command -v jq >/dev/null 2>&1; then
    ASSET_URL="$(printf "%s" "$JSON" | jq -r '.assets[].browser_download_url | select(test("x86_64.*unknown-linux-gnu.*\\.tar\\.gz$";"i"))' | head -n1)"
  else
    ASSET_URL="$(printf "%s" "$JSON" |
      grep -oE '"browser_download_url":\s*"[^"]+"' |
      grep -oE 'https://[^"]+' |
      grep -iE 'x86_64.*unknown-linux-gnu.*\.tar\.gz' |
      head -n1)"
  fi

  [[ -z "${ASSET_URL:-}" ]] && {
    echo "Could not find tar.gz asset for x86_64-unknown-linux-gnu." >&2
    exit 1
  }

  ARCHIVE="$TMP/$APP.tar.gz"

  echo ">> Downloading: $ASSET_URL"
  $DL "$ASSET_URL" >"$ARCHIVE"

  echo ">> Extracting into $OPT_DIR..."
  rm -rf "$OPT_DIR"
  mkdir -p "$OPT_DIR"
  tar -xzf "$ARCHIVE" -C "$OPT_DIR" --strip-components=1

  BIN_PATH="$(find "$OPT_DIR" -type f -name "$APP" -perm -111 | head -n1 || true)"
  [[ -z "$BIN_PATH" ]] && {
    echo "Could not find '$APP' executable in $OPT_DIR." >&2
    exit 1
  }

  echo ">> Creating symlink: $BIN_LINK -> $BIN_PATH"
  ln -sfn "$BIN_PATH" "$BIN_LINK"

  INSTALL_VERSION="$("$BIN_PATH" --version 2>/dev/null | head -n1 || true)"
  echo "✅ $INSTALL_VERSION installed in $OPT_DIR"
fi

# --- Install capture script ---
echo ">> Installing capture script into $USER_BIN/$CAPTURE_SCRIPT"
mkdir -p "$USER_BIN"

if [[ -f "$CAPTURE_LOCAL" ]]; then
  echo ">> Found local capture.sh"
  install -m 755 "$CAPTURE_LOCAL" "$USER_BIN/$CAPTURE_SCRIPT"
else
  echo ">> Downloading capture.sh from repository..."
  curl -fsSL "$CAPTURE_REMOTE" -o /tmp/capture.sh
  install -m 755 /tmp/capture.sh "$USER_BIN/$CAPTURE_SCRIPT"
fi

# --- Check extra dependencies for capture.sh ---
# for dep in gnome-screenshot wl-copy; do
#   if ! command -v "$dep" >/dev/null 2>&1; then
#     echo "⚠️  Warning: '$dep' is required by the capture script but not installed."
#   fi
# done

# --- Configure GNOME shortcut ---
read -rp "Choose GNOME shortcut (default: <Shift><Super>P): " user_binding
binding="${user_binding:-<Shift><Super>P}"

create_shortcut "$binding"

# --- Final summary ---
echo
echo "🎉 Installation complete."
echo "   - Satty installed: $BIN_LINK"
echo "   - Capture script:  $USER_BIN/$CAPTURE_SCRIPT"
echo "   - GNOME shortcut:  $binding"
