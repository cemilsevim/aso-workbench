# Security and privacy

ASO Workbench runs entirely on your Mac. There is no ASO Workbench server, no account and no telemetry.

## What leaves your Mac, and where to

The networking layer refuses any request to a host that is not on its allow-list. These are all the hosts the app talks to:

| Host | When | What is sent |
|---|---|---|
| `itunes.apple.com` | Always (no key) | Search terms, app IDs, country — public App Store search, lookup and reviews |
| `search.itunes.apple.com` | Always (no key) | Autocomplete prefixes |
| `appleid.apple.com`, `api.ads.apple.com`, `api.searchads.apple.com` | Apple Ads key set | A token signed on your Mac; search terms; read-only report queries |
| `app-ads.apple.com` | Only after you sign in to the Apple Ads website session | Your own browser session, inside an in-app browser |
| `api.appstoreconnect.apple.com` (+ Apple asset hosts for screenshots) | App Store Connect key set | A token signed on your Mac; reads; writes only after you press Apply and confirm |
| `openrouter.ai` | OpenRouter key set | Keyword text, your app's public name and description, your drafts |
| `api.revenuecat.com` | RevenueCat key set | Read-only metric queries |
| `api.github.com` | Once a day if "Check for updates automatically" is on | Nothing about you: an anonymous request for the latest release |

## Keys

- Stored in `~/Library/Application Support/ASO Workbench/credentials.json`, file mode `600`, folder `700`, written atomically.
- Private keys (`.p8`, `.pem`) are read once when you choose the file and kept only in that file; tokens are signed locally and expire within minutes (App Store Connect) or an hour (Apple Ads).
- Keys never appear in the data file, the log (`app.log`), CSV exports or crash messages. The connection diagnostics show only a public-key fingerprint.
- `.gitignore` excludes `*.p8`, `*.pem`, `*.p12`, `.env*`, `credentials.json` and local data files.

## Writing to Apple

- Nothing is written to App Store Connect unless you press **Publish ▸ Apply** (or *Apply all locales*) and confirm.
- Before writing, the listing is re-read; if it changed since your baseline, the write is refused. After writing, it is read back and logged in **Changes**.
- Nothing is ever submitted for review.
- AI output only ever lands in local drafts. Text from other apps' public descriptions can reach the writer model as context; it cannot trigger any action.

## Developer URL commands

`asoworkbench://lab/…` links drive the developer Lab (training, test runs). Because any web page can open such a link, the app ignores them unless it was launched with `ASO_LAB=1` or `--lab` (`make lab`). A normal launch never acts on them.

## Updates

The updater only reads GitHub's public release list and opens the release page or disk image in your browser; it never downloads or runs code itself. Before a new version first opens your data, the data file is copied to `Backups/` (five kept).

Release builds are signed ad hoc and are **not notarized** (see the README for how to open them). If you prefer, build from source: `make install`.

## Reporting a vulnerability

Please do not open a public issue for security problems. Use GitHub's **Report a vulnerability** (Security → Advisories) on the repository, or contact the maintainer privately. Include steps to reproduce; you will get an answer within a few days.
