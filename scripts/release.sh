#!/usr/bin/env bash
# Builds the release zip that the in-app update checker points people to.
#
#   scripts/release.sh            build dist/ASO-Workbench-<version>.dmg (+ .zip) + checksums + release notes, print the gh command
#   scripts/release.sh --publish  …and create the GitHub release with `gh` (you must be logged in: gh auth login)
#
# Before running: bump VERSION, add a "## [x.y.z] - date" section to CHANGELOG.md, commit, and tag nothing,
# the script tags v<version> through gh when publishing.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
VERSION="$(tr -d '[:space:]' < VERSION)"

grep -q "^## \[$VERSION\]" CHANGELOG.md || { echo "✗ CHANGELOG.md has no '## [$VERSION]' section"; exit 1; }
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then echo "✗ Working tree is not clean; commit first"; exit 1; fi

scripts/bundle-app.sh release
mkdir -p dist
DMG="dist/ASO-Workbench-$VERSION.dmg"
ZIP="dist/ASO-Workbench-$VERSION.zip"
rm -f "$DMG" "$ZIP"

# Drag-to-install disk image: the app next to an Applications shortcut.
STAGE="$(mktemp -d)"
cp -R "build/ASO Workbench.app" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "ASO Workbench $VERSION" -srcfolder "$STAGE" -fs HFS+ -format UDZO -imagekey zlib-level=9 -ov "$DMG" >/dev/null
rm -rf "$STAGE"
# A zip too, for people who prefer it and for scripts.
ditto -c -k --sequesterRsrc --keepParent "build/ASO Workbench.app" "$ZIP"
( cd dist && shasum -a 256 "$(basename "$DMG")" "$(basename "$ZIP")" > "ASO-Workbench-$VERSION.sha256" )
# Release notes = this version's CHANGELOG section (the update window shows them to users).
awk -v v="$VERSION" '$0 ~ "^## \\[" v "\\]" {on=1; next} on && /^## \[/ {exit} on {print}' CHANGELOG.md > "dist/notes-$VERSION.md"

echo "→ $DMG"
echo "→ $ZIP"
cat "dist/ASO-Workbench-$VERSION.sha256"
CMD=(gh release create "v$VERSION" "$DMG" "$ZIP" "dist/ASO-Workbench-$VERSION.sha256" --title "ASO Workbench $VERSION" --notes-file "dist/notes-$VERSION.md")
if [ "${1:-}" = "--publish" ]; then
  "${CMD[@]}"
else
  echo "Publish with:"; printf ' %q' "${CMD[@]}"; echo
fi
