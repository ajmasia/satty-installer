#!/usr/bin/env bash
# Satty Installer + Capture Script
# -------------------------------------------------
# 1. Downloads and installs the latest Satty release into /opt/satty
#    and creates a symlink in /usr/local/bin/satty (requires sudo).
# 2. Installs the capture script (capture.sh) into ~/.local/bin/capture.
# 3. At the end, shows instructions to manually create a GNOME or KDE shortcut.

set -euo pipefail

# --- Installer version ---
INSTALLER_VERSION="1.0.0"

if [[ "${1:-}" == "--version" ]]; then
  echo "Satty Installer version $INSTALLER_VERSION"
  exit 0
fi

# --- Flags ---
AUTO_YES=false
if [[ "${1:-}" == "--yes" ]]; then
  AUTO_YES=true
fi

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

# --- Dependencies ---
DEPS=(tar curl install gnome-screenshot wl-clipboard)
MISSING_DEPS=()

need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "⚠️ Missing dependency: '$1'." >&2
    MISSING_DEPS+=("$1")
  fi
}

check_deps() {
  if [[ ${#MISSING_DEPS[@]} -gt 0 ]]; then
    echo
    echo "❌ Some dependencies are missing: ${MISSING_DEPS[*]}" >&2

    if command -v apt >/dev/null 2>&1; then
      echo "👉 They can be installed automatically with apt:" >&2
      echo "   sudo apt update && sudo apt install -y ${MISSING_DEPS[*]}" >&2
      echo

      local reply
      if $AUTO_YES; then
        reply="y"
      else
        # force interactive prompt even if running via curl | bash
        read -rp "Do you want to install them now? [Y/n]: " reply </dev/tty || true
      fi

      reply=${reply,,}
      if [[ -z "$reply" || "$reply" == "y" || "$reply" == "yes" ]]; then
        echo ">> Installing missing dependencies..."
        sudo apt update
        sudo apt install -y "${MISSING_DEPS[@]}"
        return
      fi
    fi

    echo "⚠️ Please install the missing dependencies manually and re-run this installer." >&2
    exit 1
  fi
}

cleanup() {
  [[ -d "$TMP" ]] && rm -rf "$TMP"
}

# --- Check dependencies ---
for dep in "${DEPS[@]}"; do
  need "$dep"
done
check_deps

# --- Select downloader ---
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
    ASSET_URL="$(printf "%s" "$JSON" | jq -r '.assets[].browser_download_url | select(test("x86_64.*unknown-linux-gnu.*\\.tar\\.gz$"; "i"))' | head -n1)"
  else
    ASSET_URL="$(printf "%s" "$JSON" |
      grep -oE '\"browser_download_url\":\\s*\"[^\"]+\"' |
      grep -oE 'https://[^\\\"]+' |
      grep -iE 'x86_64.*unknown-linux-gnu.*\\.tar\\.gz' |
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

# --- PATH check for ~/.local/bin ---
echo ">> Checking if $USER_BIN is in your PATH..."

if [[ ":$PATH:" != *":$USER_BIN:"* ]]; then
  echo "⚠️ Warning: $USER_BIN is not in your PATH."

  # Detect shell
  shell_name=$(basename "$SHELL")
  case "$shell_name" in
  bash) rc_file="$HOME/.bashrc" ;;
  zsh) rc_file="$HOME/.zshrc" ;;
  *) rc_file="" ;;
  esac

  if [[ -n "$rc_file" ]]; then
    echo "👉 You can fix this by adding the following line to $rc_file:"
    echo "   export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo

    read -rp "Do you want me to add it automatically to $rc_file? [Y/n]: " reply </dev/tty || true
    reply=${reply,,}

    if [[ -z "$reply" || "$reply" == "y" || "$reply" == "yes" ]]; then
      if ! grep -Fxq 'export PATH="$HOME/.local/bin:$PATH"' "$rc_file" 2>/dev/null; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >>"$rc_file"
        echo "✅ Added to $rc_file. Please reload your shell or run: source $rc_file"
      else
        echo "ℹ️ The PATH line already exists in $rc_file, skipping."
      fi
    fi
  else
    echo "👉 Add this line manually to your shell config (~/.bashrc, ~/.zshrc, etc.):"
    echo "   export PATH=\"\$HOME/.local/bin:\$PATH\""
  fi
else
  echo "✅ $USER_BIN is already in your PATH."
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
echo "    Command:  bash -c ~/.local/bin/capture"
echo "    Shortcut: <Shift><Super>P"
echo
echo "KDE Plasma:"
echo "  System Settings → Shortcuts → Custom Shortcuts"
echo "    New → Global Shortcut → Command/URL"
echo "    Trigger:   Meta+Shift+P"
echo "    Action:    bash -c ~/.local/bin/capture"
echo
echo "📦 Satty Installer version: $INSTALLER_VERSION"
