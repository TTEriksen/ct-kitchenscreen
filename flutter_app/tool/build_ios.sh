#!/usr/bin/env bash
# Builds the iOS release app and, if an iPad id is given, installs and starts it.
#
#   tool/build_ios.sh                       → build only
#   tool/build_ios.sh <device-id>           → build, install, launch
#
# Flutter's native-assets framework objective_c.framework is embedded with an
# ad-hoc signature, which iOS refuses to install ("integrity could not be
# verified"). This signs it with the app's own identity and re-seals the app.
set -euo pipefail
cd "$(dirname "$0")/.."

flutter build ios --release

APP=build/ios/iphoneos/Runner.app
# Sign with the exact certificate Xcode used (by SHA-1), since a keychain can
# hold several certificates with the same name, e.g. an old revoked one.
TMP=$(mktemp -d)
(cd "$TMP" && codesign -d --extract-certificates "$OLDPWD/$APP" 2>/dev/null)
IDENTITY=$(openssl x509 -inform DER -in "$TMP/codesign0" -noout -fingerprint -sha1 | sed 's/.*=//; s/://g')
rm -rf "$TMP"
# Re-sign every embedded framework: some come out ad-hoc or linker-signed.
for fw in "$APP"/Frameworks/*.framework; do
  codesign --force --sign "$IDENTITY" --timestamp=none "$fw"
done
codesign --force --sign "$IDENTITY" --timestamp=none --preserve-metadata=entitlements,identifier,flags "$APP"
codesign --verify --deep --strict "$APP"
echo "Signed with: $IDENTITY"

if [ -n "${1:-}" ]; then
  xcrun devicectl device install app --device "$1" "$APP"
  xcrun devicectl device process launch --terminate-existing --device "$1" dk.ctconsult.ctKitchenscreen
fi
