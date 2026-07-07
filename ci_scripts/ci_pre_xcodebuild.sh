#!/bin/sh
# Xcode Cloud runs this right before xcodebuild. Give every build a unique,
# increasing build number — otherwise every build ships as "1" (the static
# CFBundleVersion baked into the Info.plists) and App Store Connect rejects the
# second upload because a build number can't be reused.
set -e

REPO="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$REPO"

if [ -z "$CI_BUILD_NUMBER" ]; then
  echo "ci_pre_xcodebuild: CI_BUILD_NUMBER not set; leaving build number unchanged."
  exit 0
fi

# Info.plists reference $(CURRENT_PROJECT_VERSION); updating the build setting
# updates the app and the extension identically.
sed -i '' "s/CURRENT_PROJECT_VERSION = [0-9.]*;/CURRENT_PROJECT_VERSION = ${CI_BUILD_NUMBER};/g" \
  Elek.xcodeproj/project.pbxproj

echo "ci_pre_xcodebuild: set build number to ${CI_BUILD_NUMBER}"
