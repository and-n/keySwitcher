#!/bin/bash
# Builds a Release keySwitcher.app and packages it into a distributable .dmg.
#
# Until an Apple Developer ID is available the app is ad-hoc signed (codesign -s -).
# That is enough to run locally after removing the quarantine attribute, but it
# is NOT notarized — see README for the Gatekeeper note. Once a Developer ID
# certificate exists, set DEVELOPER_ID and this script will sign + notarize.
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="keySwitcher"
BUILD_DIR="build"
EXPORT_DIR="$BUILD_DIR/export"
DMG_PATH="$BUILD_DIR/$APP_NAME.dmg"
DEVELOPER_ID="${DEVELOPER_ID:-}" # e.g. "Developer ID Application: Name (TEAMID)"

echo "==> Generating Xcode project"
xcodegen generate

echo "==> Building Release"
rm -rf "$EXPORT_DIR"
mkdir -p "$EXPORT_DIR"

if [[ -n "$DEVELOPER_ID" ]]; then
  xcodebuild -project "$APP_NAME.xcodeproj" -scheme "$APP_NAME" \
    -configuration Release -derivedDataPath "$BUILD_DIR" \
    OTHER_CODE_SIGN_FLAGS="--timestamp" \
    CODE_SIGN_IDENTITY="$DEVELOPER_ID" \
    -clonedSourcePackagesDirPath "$BUILD_DIR/spm" build
else
  xcodebuild -project "$APP_NAME.xcodeproj" -scheme "$APP_NAME" \
    -configuration Release -derivedDataPath "$BUILD_DIR" \
    CODE_SIGNING_ALLOWED=NO build
fi

APP_PATH="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"
[[ -d "$APP_PATH" ]] || { echo "Build product not found at $APP_PATH"; exit 1; }

cp -R "$APP_PATH" "$EXPORT_DIR/"

if [[ -z "$DEVELOPER_ID" ]]; then
  echo "==> Ad-hoc signing (no Developer ID set)"
  codesign --force --deep --sign - "$EXPORT_DIR/$APP_NAME.app"
fi

echo "==> Creating $DMG_PATH"
ln -sf /Applications "$EXPORT_DIR/Applications"
rm -f "$DMG_PATH"
hdiutil create -volname "$APP_NAME" -srcfolder "$EXPORT_DIR" \
  -ov -format UDZO "$DMG_PATH"

if [[ -n "$DEVELOPER_ID" && -n "${NOTARY_PROFILE:-}" ]]; then
  echo "==> Notarizing"
  xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG_PATH"
fi

echo "==> Done: $DMG_PATH"
