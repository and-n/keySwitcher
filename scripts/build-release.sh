#!/bin/bash
# Builds a Release keySwitcher.app and packages it into a distributable .dmg.
#
# With DEVELOPER_ID set (a "Developer ID Application: …" identity) the app is
# signed with hardened runtime; add NOTARY_PROFILE to also notarize and staple
# both the app and the DMG, producing a Gatekeeper-approved build. With neither
# set the app is ad-hoc signed — fine for local use after removing the
# quarantine attribute, but not distributable.
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="keySwitcher"
BUILD_DIR="build"
EXPORT_DIR="$BUILD_DIR/export"
DMG_PATH="$BUILD_DIR/$APP_NAME.dmg"
APP_EXPORT="$EXPORT_DIR/$APP_NAME.app"
DEVELOPER_ID="${DEVELOPER_ID:-}" # e.g. "Developer ID Application: Name (TEAMID)"

# Submit an artifact (zip/dmg) to the notary service and wait for the verdict.
# On CI the notary profile lives in the temporary signing keychain, so point
# notarytool at it explicitly; locally NOTARY_KEYCHAIN is unset and the profile
# is read from the login keychain.
notarize() {
  local args=(--keychain-profile "$NOTARY_PROFILE")
  [[ -n "${NOTARY_KEYCHAIN:-}" ]] && args+=(--keychain "$NOTARY_KEYCHAIN")
  xcrun notarytool submit "$1" "${args[@]}" --wait
}

echo "==> Generating Xcode project"
xcodegen generate

echo "==> Building Release"
rm -rf "$EXPORT_DIR"
mkdir -p "$EXPORT_DIR"

if [[ -n "$DEVELOPER_ID" ]]; then
  # Manual signing with an explicit Developer ID identity: no App Store Connect
  # login is available on CI, so Automatic style would fail. macOS Developer ID
  # distribution needs no provisioning profile. Hardened runtime comes from
  # ENABLE_HARDENED_RUNTIME in project.yml; --timestamp adds the secure timestamp
  # notarization requires. CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO drops the
  # com.apple.security.get-task-allow entitlement, which notarization rejects
  # (the app has no entitlements of its own).
  xcodebuild -project "$APP_NAME.xcodeproj" -scheme "$APP_NAME" \
    -configuration Release -derivedDataPath "$BUILD_DIR" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="$DEVELOPER_ID" \
    CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
    OTHER_CODE_SIGN_FLAGS="--timestamp" \
    -clonedSourcePackagesDirPath "$BUILD_DIR/spm" build
else
  xcodebuild -project "$APP_NAME.xcodeproj" -scheme "$APP_NAME" \
    -configuration Release -derivedDataPath "$BUILD_DIR" \
    CODE_SIGNING_ALLOWED=NO build
fi

APP_PATH="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"
[[ -d "$APP_PATH" ]] || { echo "Build product not found at $APP_PATH"; exit 1; }

cp -R "$APP_PATH" "$APP_EXPORT"

if [[ -n "$DEVELOPER_ID" && -n "${NOTARY_PROFILE:-}" ]]; then
  # Notarize the app itself (zip it — notarytool takes a zip/pkg/dmg), then
  # staple the ticket onto the .app so first launch works even offline.
  echo "==> Notarizing app"
  ZIP_PATH="$BUILD_DIR/$APP_NAME.zip"
  /usr/bin/ditto -c -k --keepParent "$APP_EXPORT" "$ZIP_PATH"
  notarize "$ZIP_PATH"
  rm -f "$ZIP_PATH"
  echo "==> Stapling app"
  xcrun stapler staple "$APP_EXPORT"
elif [[ -z "$DEVELOPER_ID" ]]; then
  echo "==> Ad-hoc signing (no Developer ID set)"
  codesign --force --deep --sign - "$APP_EXPORT"
fi

echo "==> Creating $DMG_PATH"
ln -sf /Applications "$EXPORT_DIR/Applications"
rm -f "$DMG_PATH"
hdiutil create -volname "$APP_NAME" -srcfolder "$EXPORT_DIR" \
  -ov -format UDZO "$DMG_PATH"

if [[ -n "$DEVELOPER_ID" && -n "${NOTARY_PROFILE:-}" ]]; then
  # The DMG needs its own ticket (the app's ticket doesn't cover it), so submit
  # the DMG too. Its stapled ticket lets the download open without a warning
  # even offline.
  echo "==> Notarizing DMG"
  notarize "$DMG_PATH"
  echo "==> Stapling DMG"
  xcrun stapler staple "$DMG_PATH"
fi

echo "==> Done: $DMG_PATH"
