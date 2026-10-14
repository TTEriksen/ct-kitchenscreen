#!/usr/bin/env bash
# Builds the iPad app for the App Store and uploads it to TestFlight.
#
#   tool/release_ios.sh            uses the Apple ID signed in under Xcode › Settings › Accounts
#
# Or with an App Store Connect API key (Users and Access › Integrations › Keys):
#   ASC_KEY_ID=ABC123 ASC_ISSUER_ID=xxxxxxxx-... ASC_KEY_PATH=~/AuthKey_ABC123.p8 tool/release_ios.sh
#
# Each upload needs a new build number: raise the number after "+" in pubspec.yaml
# (version: 1.0.0+2, +3, …) before running it again.
set -euo pipefail
cd "$(dirname "$0")/.."

# Archive (flutter's own export step may fail without an account; the export below does the upload).
rm -rf build/ios/archive
flutter build ipa --release 2>&1 | grep -E "Built .*xcarchive|Version Number|Build Number" || true
ARCHIVE=build/ios/archive/Runner.xcarchive
[ -d "$ARCHIVE" ] || { echo "No archive was built."; exit 1; }

# Flutter's native-assets frameworks (e.g. objective_c.framework) come without a
# dSYM, which App Store Connect asks for. Make one from each such framework so
# the UUIDs match.
for fw in "$ARCHIVE"/Products/Applications/*.app/Frameworks/*.framework; do
  name=$(basename "$fw" .framework)
  if [ -f "$fw/$name" ] && [ ! -d "$ARCHIVE/dSYMs/$name.framework.dSYM" ]; then
    dsymutil "$fw/$name" -o "$ARCHIVE/dSYMs/$name.framework.dSYM" 2>/dev/null || true
    echo "Added dSYM for $name.framework"
  fi
done

AUTH=()
if [ -n "${ASC_KEY_ID:-}" ]; then
  AUTH=(-authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID" -authenticationKeyPath "$ASC_KEY_PATH")
fi

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist ios/ExportOptions.plist \
  -exportPath build/ios/upload \
  -allowProvisioningUpdates ${AUTH[@]+"${AUTH[@]}"}

echo "Uploaded. The build appears in App Store Connect › TestFlight after Apple has processed it (usually 5–30 minutes)."
