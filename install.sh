#!/usr/bin/env bash
# Satty Installer + Capture Script
# -------------------------------------------------
# 1. Downloads and installs the latest Satty release into /opt/satty
#    and creates a symlink in /usr/local/bin/satty (requires sudo).
# 2. Installs the capture script (capture.sh) into ~/.local/bin/capture.
# 3. At the end, shows instructions to manually create a GNOME or KDE shortcut.

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

# --- Helper functions ---
need() { command -v "$1" >/dev/null 2>&1 || {
  echo "⚠️ Missing dependency: '$1'. Please install it and try again." >&2
  exit 1
}; }

cleanup() {
  [[ -d "$TMP" ]] && rm -rf "$TMP"
}

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

# --- Create temporary workspace ---
TMP="$(mktemp -d)"
trap cleanup EXIT

# --- Install Satty ---
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

  echo ">> Extracting into $OPT_DIR (sudo required)..."
  sudo rm -rf "$OPT_DIR"
  sudo mkdir -p "$OPT_DIR"
  sudo tar -xzf "$ARCHIVE" -C "$OPT_DIR" --strip-components=1

  BIN_PATH="$(find "$OPT_DIR" -type f -name "$APP" -perm -111 | head -n1 || true)"
  [[ -z "$BIN_PATH" ]] && {
    echo "Could not find '$APP' executable in $OPT_DIR." >&2
    exit 1
  }

  echo ">> Creating symlink (sudo required): $BIN_LINK -> $BIN_PATH"
  sudo ln -sfn "$BIN_PATH" "$BIN_LINK"

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
  curl -fsSL "$CAPTURE_REMOTE" -o "$TMP/capture.sh"
  install -m 755 "$TMP/capture.sh" "$USER_BIN/$CAPTURE_SCRIPT"
fi

# --- Final summary ---
echo
echo "🎉 Installation complete."
echo "   - Satty installed: $BIN_LINK"
echo "   - Capture script:  $USER_BIN/$CAPTURE_SCRIPT"
echo
echo "💡 To finish setup, create a custom shortcut manually"
echo
echo "GNOME:"
echo "  Settings → Keyboard → Keyboard Shortcuts → Custom Shortcuts → Add"
echo "    Name:     Satty Capture"
echo "    Command:  capture"
echo "    Shortcut: <Shift><Super>P"
echo
echo "KDE Plasma:"
echo "  System Settings → Shortcuts → Custom Shortcuts"
echo "    New → Global Shortcut → Command/URL"
echo "    Trigger:   Meta+Shift+P"
echo "    Action:    capture"
