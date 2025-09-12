#!/usr/bin/env bash
# Satty Uninstaller
# -------------------------------------------------
# Removes Satty from /opt/satty, the symlink from /usr/local/bin/satty,
# and the capture script from ~/.local/bin/capture.
#
# Usage:
#   Local:   ./uninstall.sh
#   Remote:  curl -fsSL https://raw.githubusercontent.com/<your-username>/satty-installer/main/uninstall.sh | bash

set -euo pipefail

APP="satty"
OPT_DIR="/opt/$APP"
BIN_LINK="/usr/local/bin/$APP"
CAPTURE_SCRIPT="$HOME/.local/bin/capture"

echo ">> Starting Satty uninstallation..."

# Remove Satty install dir
if [[ -d "$OPT_DIR" ]]; then
  echo ">> Removing $OPT_DIR (sudo required)..."
  sudo rm -rf "$OPT_DIR"
else
  echo "⚠️  Satty folder not found in $OPT_DIR"
fi

# Remove symlink
if [[ -L "$BIN_LINK" || -f "$BIN_LINK" ]]; then
  echo ">> Removing symlink $BIN_LINK (sudo required)..."
  sudo rm -f "$BIN_LINK"
else
  echo "⚠️  Symlink not found in $BIN_LINK"
fi

# Remove capture script
if [[ -f "$CAPTURE_SCRIPT" ]]; then
  echo ">> Removing capture script $CAPTURE_SCRIPT"
  rm -f "$CAPTURE_SCRIPT"
else
  echo "⚠️  Capture script not found in $CAPTURE_SCRIPT"
fi

echo
echo "✅ Uninstallation complete."
echo "   - Removed: $OPT_DIR"
echo "   - Removed: $BIN_LINK"
echo "   - Removed: $CAPTURE_SCRIPT"
echo
echo "💡 Remember: if you created custom shortcuts in GNOME or KDE, please remove them manually."
