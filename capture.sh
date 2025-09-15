#!/usr/bin/env bash
# shot-to-satty — Capture with gnome-screenshot, edit in Satty, save & copy to clipboard
# Shows system notifications, no logging.

set -euo pipefail

SATTY_ICON_PATH=/opt/satty/assets/satty.svg

notify() {
  notify-send "Satty Screenshot" "$*" -i $SATTY_ICON_PATH
}

need() { command -v "$1" >/dev/null 2>&1 || {
  notify "Missing dependency: $1"
  exit 1
}; }

need gnome-screenshot
need satty
need wl-copy

outdir="$HOME/Pictures/satty"
mkdir -p "$outdir"

outfile="$outdir/screenshot-$(date +%Y%m%d-%H%M%S).png"
tmp_in="$(mktemp --suffix=.png)"

# Take the screenshot (interactive area selection by default)
if gnome-screenshot -a -f "$tmp_in"; then
  satty --filename "$tmp_in" --output-filename "$outfile" --early-exit --copy-command 'wl-copy'
else
  notify "Screenshot canceled or failed."
  rm -f "$tmp_in"
  exit 1
fi

# Copy to clipboard if file exists
if [[ -f "$outfile" ]]; then
  if wl-copy <"$outfile"; then
    notify "Screenshot saved to $outfile and copied to clipboard."
  else
    notify "Screenshot saved to $outfile but clipboard copy failed."
  fi
else
  notify "Satty did not save a file."
fi

rm -f "$tmp_in"
