#!/usr/bin/env bash
# App Store screenshots from the real app on the 13" iPad simulator
# (2752 × 2064 landscape, the size App Store Connect asks for), saved in ../store/ios/.
#
#   tool/screenshots.sh [simulator-id] [one-shot-name]
#
# The app is built and installed once. For each shot it is stopped, given
# realistic tickets, a palette and the view to open (tool/screenshot_data.dart;
# the view file is only read by debug builds), started, and photographed.
set -euo pipefail
cd "$(dirname "$0")/.."

SIM="${1:-$(xcrun simctl list devices booted | grep -E 'iPad Pro 13' | grep -oE '[0-9A-F-]{36}' | head -1)}"
[ -n "$SIM" ] || { echo "Start an iPad Pro 13-inch simulator first."; exit 1; }
ONLY="${2:-}"
BUNDLE=dk.ctconsult.ctKitchenscreen
OUT=../store/ios
mkdir -p "$OUT"

# name           palette   mode   view
SHOTS=(
  "01-kitchen    ctpos     dark   none"
  "02-large      ctpos     dark   focus"
  "03-finished   ctpos     dark   recall"
  "04-colours    ctpos     dark   settings"
  "05-light      hav       light  none"
)

# Build and install once (flutter run builds for this exact simulator).
flutter run --debug -d "$SIM" --no-resident >/dev/null
DATA="$(xcrun simctl get_app_container "$SIM" "$BUNDLE" data)/Library/Application Support"

for shot in "${SHOTS[@]}"; do
  read -r name palette mode view <<<"$shot"
  [ -z "$ONLY" ] || [ "$ONLY" = "$name" ] || continue
  echo "== $name ($palette, $mode, $view)"
  xcrun simctl terminate "$SIM" "$BUNDLE" 2>/dev/null || true
  sleep 1
  dart run tool/screenshot_data.dart "$DATA" "$palette" "$mode" "$view" >/dev/null
  xcrun simctl launch "$SIM" "$BUNDLE" >/dev/null
  sleep 7 # start, load tickets, open the view, let animations settle
  # The simulator service may not write to external drives: shoot to a temp file.
  raw="$(mktemp -d)/raw.png"
  xcrun simctl io "$SIM" screenshot --type=png "$raw" >/dev/null 2>&1
  # Store landscape: turn the shot only if the simulator returned it portrait.
  w=$(sips -g pixelWidth "$raw" | awk '/pixelWidth/{print $2}')
  h=$(sips -g pixelHeight "$raw" | awk '/pixelHeight/{print $2}')
  if [ "$h" -gt "$w" ]; then sips -r 90 "$raw" --out "$OUT/$name.png" >/dev/null; else cp "$raw" "$OUT/$name.png"; fi
  rm -f "$raw"
  echo "   $(sips -g pixelWidth -g pixelHeight "$OUT/$name.png" | awk '/pixel/{printf "%s ", $2}')"
done
xcrun simctl terminate "$SIM" "$BUNDLE" 2>/dev/null || true
rm -f "$DATA/screenshot_view.txt"
echo "Saved in $OUT"
