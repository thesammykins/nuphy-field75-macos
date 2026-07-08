#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Field75Mapper"
BUNDLE_ID="dev.samanthamyers.Field75Mapper"
MIN_SYSTEM_VERSION="14.0"
CODESIGN_IDENTITY="${FIELD75_CODESIGN_IDENTITY:--}"
INSTALL_DIR="${FIELD75_INSTALL_DIR:-/Applications}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ICON_SOURCE="$ROOT_DIR/Assets/AppIcon.icns"
ICON_NAME="AppIcon.icns"
INSTALLED_APP_BUNDLE="$INSTALL_DIR/$APP_NAME.app"
INSTALLED_APP_BINARY="$INSTALLED_APP_BUNDLE/Contents/MacOS/$APP_NAME"

cd "$ROOT_DIR"
pkill -x "$APP_NAME" >/dev/null 2>&1 || true

build_bundle() {
swift build
BUILD_BINARY="$(swift build --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"
if [ -f "$ICON_SOURCE" ]; then
  cp "$ICON_SOURCE" "$APP_RESOURCES/$ICON_NAME"
fi

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleIconFile</key>
  <string>$ICON_NAME</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.utilities</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST
}

sign_bundle() {
  local bundle="$1"
  xattr -cr "$bundle"
  /usr/bin/codesign --force --deep --sign "$CODESIGN_IDENTITY" "$bundle"
}

install_bundle() {
  sign_bundle "$APP_BUNDLE"
  rm -rf "$INSTALLED_APP_BUNDLE"
  /usr/bin/ditto "$APP_BUNDLE" "$INSTALLED_APP_BUNDLE"
  sign_bundle "$INSTALLED_APP_BUNDLE"
  echo "Installed $INSTALLED_APP_BUNDLE"
  if [ "$CODESIGN_IDENTITY" = "-" ]; then
    echo "warning: ad-hoc signing may invalidate Input Monitoring/Accessibility grants on rebuild." >&2
    echo "         Set FIELD75_CODESIGN_IDENTITY to a stable local or Developer ID signing identity." >&2
  fi
}

open_app() {
  /usr/bin/open -n "$1"
}

reset_permissions() {
  /usr/bin/tccutil reset ListenEvent "$BUNDLE_ID" || true
  /usr/bin/tccutil reset Accessibility "$BUNDLE_ID" || true
  echo "Reset Input Monitoring and Accessibility grants for $BUNDLE_ID"
  echo "Re-add $INSTALLED_APP_BUNDLE in System Settings > Privacy & Security."
}

case "$MODE" in
  reset-permissions|--reset-permissions)
    reset_permissions
    ;;
  run|install-run|--install-run)
    build_bundle
    install_bundle
    open_app "$INSTALLED_APP_BUNDLE"
    ;;
  install|--install)
    build_bundle
    install_bundle
    ;;
  dev-run|--dev-run)
    build_bundle
    sign_bundle "$APP_BUNDLE"
    open_app "$APP_BUNDLE"
    ;;
  --debug|debug)
    build_bundle
    install_bundle
    lldb -- "$INSTALLED_APP_BINARY"
    ;;
  --logs|logs)
    build_bundle
    install_bundle
    open_app "$INSTALLED_APP_BUNDLE"
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    build_bundle
    install_bundle
    open_app "$INSTALLED_APP_BUNDLE"
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify|install-verify|--install-verify)
    build_bundle
    install_bundle
    open_app "$INSTALLED_APP_BUNDLE"
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|install|dev-run|reset-permissions|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
