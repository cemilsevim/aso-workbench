#!/usr/bin/env bash
# Builds the ASOWorkbench executable with SwiftPM and wraps it in a proper .app bundle
# so it gets a Dock icon, an app menu and its own Application Support folder.
#   scripts/bundle-app.sh [debug|release]
set -euo pipefail
CONFIG="${1:-debug}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# One source of truth for the version (VERSION); the build number counts commits when this is a git checkout.
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
BUILD="$(git -C "$ROOT" rev-list --count HEAD 2>/dev/null || echo 1)"
# Forks can publish under their own identity: ASO_BUNDLE_ID=… ASO_REPOSITORY=owner/repo scripts/bundle-app.sh release
BUNDLE_ID="${ASO_BUNDLE_ID:-com.mustafakendiguzel.asoworkbench}"
REPOSITORY="${ASO_REPOSITORY:-mustafakendiguzel/aso-workbench}"

swift build -c "$CONFIG" --product ASOWorkbench
BIN="$(swift build -c "$CONFIG" --show-bin-path)/ASOWorkbench"

APP="$ROOT/build/ASO Workbench.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/ASOWorkbench"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
PLIST="$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" -c "Set :CFBundleVersion $BUILD" \
  -c "Set :CFBundleIdentifier $BUNDLE_ID" -c "Set :CFBundleURLTypes:0:CFBundleURLName $BUNDLE_ID" "$PLIST"
/usr/libexec/PlistBuddy -c "Delete :ASORepository" "$PLIST" >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy -c "Add :ASORepository string $REPOSITORY" "$PLIST"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
# Trained popularity models (Resources/models/*.mlmodel) are compiled into the bundle so every user gets the estimate layer.
if ls "$ROOT"/Resources/models/*.mlmodel >/dev/null 2>&1; then
  for m in "$ROOT"/Resources/models/*.mlmodel; do
    xcrun coremlcompiler compile "$m" "$APP/Contents/Resources" >/dev/null
  done
  [ -f "$ROOT/Resources/models/report.json" ] && cp "$ROOT/Resources/models/report.json" "$APP/Contents/Resources/popularity-report.json"
  echo "→ bundled models: $(ls "$ROOT"/Resources/models/*.mlmodel | xargs -n1 basename | tr '\n' ' ')"
fi
echo -n "APPL????" > "$APP/Contents/PkgInfo"
# Ad-hoc signature: enough for local use; the app is not notarized (see README → Install).
codesign --force --sign - --identifier "$BUNDLE_ID" "$APP" >/dev/null 2>&1 || true
echo "→ $APP (v$VERSION build $BUILD)"
