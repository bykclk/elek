#!/usr/bin/env bash
# One-command App Store release: bump build number, archive, export a
# distribution-signed .ipa, verify the signature, and upload via ascelerate.
#
# Usage:
#   scripts/release.sh <build-number>     e.g. scripts/release.sh 103
#
# Prerequisites (already set up):
#   - Apple Distribution cert + private key in the login keychain
#     (created once with: ascelerate certs create --type DISTRIBUTION)
#   - ASC API key in ~/.ascelerate/ (used for provisioning + upload)
set -euo pipefail

BUILD="${1:?usage: scripts/release.sh <build-number>}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build/release-$BUILD"

KEY="$HOME/.ascelerate/AuthKey_3QS26273FA.p8"
KID="3QS26273FA"
ISS="69489364-fd84-45ef-a0cc-c80172b14cd8"
TEAM="9DDG73TKPX"

cd "$ROOT"

echo "==> Setting build number to $BUILD"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" Elek/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" ElekProxy/Info.plist

echo "==> Archiving (Release, iOS device)"
rm -rf "$OUT"; mkdir -p "$OUT"
xcodebuild -project Elek.xcodeproj -scheme Elek -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$OUT/Elek.xcarchive" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$KEY" -authenticationKeyID "$KID" -authenticationKeyIssuerID "$ISS" \
  archive | grep -E "ARCHIVE SUCCEEDED|error:" || true
test -d "$OUT/Elek.xcarchive" || { echo "ERROR: archive failed"; exit 1; }

echo "==> Exporting App Store .ipa"
cat > "$OUT/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>export</string>
  <key>teamID</key><string>$TEAM</string>
  <key>signingStyle</key><string>automatic</string>
</dict></plist>
PLIST
xcodebuild -exportArchive -archivePath "$OUT/Elek.xcarchive" -exportPath "$OUT/export" \
  -exportOptionsPlist "$OUT/ExportOptions.plist" -allowProvisioningUpdates \
  -authenticationKeyPath "$KEY" -authenticationKeyID "$KID" -authenticationKeyIssuerID "$ISS" \
  | grep -E "EXPORT SUCCEEDED|error:" || true
IPA="$OUT/export/Elek.ipa"
test -f "$IPA" || { echo "ERROR: export failed"; exit 1; }

echo "==> Verifying signature (must be Apple Distribution, not ad-hoc)"
rm -rf "$OUT/verify"; mkdir -p "$OUT/verify"
unzip -q "$IPA" -d "$OUT/verify"
APP="$OUT/verify/Payload/Elek.app"
codesign -dvvv "$APP" 2>&1 | grep "Authority=Apple Distribution" \
  || { echo "ERROR: app is NOT distribution-signed"; exit 1; }
codesign -dvvv "$APP/PlugIns/ElekProxy.appex" 2>&1 | grep "Authority=Apple Distribution" \
  || { echo "ERROR: extension is NOT distribution-signed"; exit 1; }
echo "    signature OK, CFBundleVersion=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Info.plist"), UIDeviceFamily=$(/usr/libexec/PlistBuddy -c 'Print :UIDeviceFamily:0' "$APP/Info.plist")"

echo "==> Uploading to App Store Connect"
ascelerate builds upload "$IPA"

echo "==> Done. Next steps:"
echo "    ascelerate builds list --bundle-id com.bykclk.elek     # wait until Valid"
echo "    ascelerate apps build attach-latest com.bykclk.elek -y"
echo "    ascelerate apps review preflight com.bykclk.elek"
