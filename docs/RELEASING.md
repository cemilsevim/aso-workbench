# Versions, releases and updates

## How users get updates

1. The app knows its own version (`VERSION`, written into the app by `scripts/bundle-app.sh`).
2. Once a day (if *Check for updates automatically* is on) and whenever someone picks **ASO Workbench ▸ Check for Updates…**, it asks GitHub for the latest release of `AppInfo.repository` (default `mustafakendiguzel/aso-workbench`, set with `ASO_REPOSITORY` at build time).
3. If the release tag (`v1.2.0`) is newer, a note appears at the bottom of the sidebar. The update window shows that version's section of `CHANGELOG.md` and offers **Download** (the `.dmg` asset) and **Release page**. People can skip a version.
4. Installing = open the `.dmg`, drag the app onto Applications. Before the new version first opens the data, the data file is copied to `~/Library/Application Support/ASO Workbench/Backups/` (five kept). SwiftData migrates the schema automatically as long as new model fields have default values.
5. People building from source run `make update` (`git pull` + reinstall).

## Version numbers

[Semantic Versioning](https://semver.org): `MAJOR.MINOR.PATCH`.

| Change | Bump | Example |
|---|---|---|
| Fixes only | patch | 1.0.0 → 1.0.1 |
| New features, data stays compatible | minor | 1.0.1 → 1.1.0 |
| Data or workflow breaks, manual steps needed | major | 1.1.0 → 2.0.0 |

Pre-releases (`1.1.0-beta.1`) sort before the final version and are marked as pre-release on GitHub, so the updater (which reads `releases/latest`) ignores them.

## Making a release

```bash
# 1. bump the version
echo "1.1.0" > VERSION
# 2. describe it: add a "## [1.1.0] - YYYY-MM-DD" section at the top of CHANGELOG.md
# 3. commit
git commit -am "Release 1.1.0"
# 4. build dist/ASO-Workbench-1.1.0.dmg + .zip + checksums + notes, and publish with gh
make publish          # or `make dist` to build only and publish by hand
```

`scripts/release.sh` refuses to run with uncommitted changes or without a CHANGELOG section for the version. It builds an optimized app, a drag-to-install disk image (app + Applications shortcut), a zip, SHA-256 checksums and the release notes, then runs `gh release create v<version> …`.

## Data model changes

- Add new `@Model` properties **with a default value** (`var x: Int = 0`); SwiftData then migrates in place.
- New fields inside JSON-encoded structs need a tolerant `init(from:)` (`decodeIfPresent`), so older records keep loading.
- Removing or renaming stored properties is a major version: describe the manual steps in the CHANGELOG.

## Demo video

Record the screen (⇧⌘5), then `make demo VIDEO="~/Desktop/Screen Recording.mov"`. It writes `docs/media/demo.mp4` (H.264, bitrate chosen to stay under 10 MB so GitHub can also play it inline), `demo.gif` (the silent preview at the top of the README, first 20 seconds) and `demo-poster.png`. Recording metadata such as location is not copied. Check the frames for notifications or private windows before committing.

## Signing and notarization

Releases are signed ad hoc (no Apple Developer ID), so macOS shows a warning the first time. The README explains how to open the app. If the project later gets a Developer ID, sign with it in `scripts/bundle-app.sh` and notarize the disk image with `xcrun notarytool` before uploading.
