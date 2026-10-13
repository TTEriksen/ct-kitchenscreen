#!/usr/bin/env bash
# Opens the kitchen screen full screen in Chromium (Raspberry Pi OS / Debian / Ubuntu).
# Autostart it from the desktop session, e.g. ~/.config/autostart/kitchenscreen.desktop:
#   [Desktop Entry]
#   Type=Application
#   Name=Kitchenscreen
#   Exec=/opt/ct-kitchenscreen/deploy/kiosk.sh

URL="${KDS_URL:-http://localhost:8080}"

# Wait for the server.
for _ in $(seq 1 60); do
  curl -fs "$URL/api/state" >/dev/null && break
  sleep 1
done

# No screen blanking.
xset s off 2>/dev/null
xset -dpms 2>/dev/null
xset s noblank 2>/dev/null

BROWSER=$(command -v chromium-browser || command -v chromium || command -v google-chrome)
exec "$BROWSER" \
  --kiosk "$URL" \
  --noerrdialogs \
  --disable-infobars \
  --disable-session-crashed-bubble \
  --disable-pinch \
  --overscroll-history-navigation=0 \
  --autoplay-policy=no-user-gesture-required \
  --check-for-update-interval=31536000
