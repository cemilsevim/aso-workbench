# Connections: which keys, why, and where they go

ASO Workbench works **without any key**. Each connection adds one thing. Add only what you need; you can remove any key at any time in **Connections** (sidebar) or **Settings → Connections**.

| Connection | Need | What it unlocks | Talks to | Cost |
|---|---|---|---|---|
| *(none)* | — | Rank tracking, autocomplete ideas, competitors, difficulty, ratings, reviews | itunes.apple.com, search.itunes.apple.com | free |
| [Apple Ads API](#apple-ads-api--recommended) | **Recommended** | Apple's own popularity, your campaign results | appleid.apple.com, api.ads.apple.com, api.searchads.apple.com | free, spends nothing |
| [App Store Connect API](#app-store-connect-api--optional) | Optional | Pull and publish your listing in every language | api.appstoreconnect.apple.com | free |
| [OpenRouter](#openrouter--optional) | Optional | AI writer, translations, brand and relevance checks, popularity estimates | openrouter.ai | pay per use, cents |
| [RevenueCat](#revenuecat--optional) | Optional | MRR and subscriptions on Overview | api.revenuecat.com | free |
| [Apple Ads website session](#apple-ads-website-session--advanced-optional) | Advanced | Apple's exact popularity index for terms missing from the lists | app-ads.apple.com | free |

## Where keys live

- In **one file on your Mac**: `~/Library/Application Support/ASO Workbench/credentials.json`, readable only by your macOS user (file `600`, folder `700`).
- Never in the data file, never in logs, never in CSV exports, never in this repository.
- Each key is sent **only to its own service**. The app has a host allow-list and refuses any request to a host that is not on it.
- **Remove** in Connections deletes the key from the file. Deleting the file removes all keys.

Why a file and not the Keychain? Builds from source are signed ad hoc, and every rebuild changes the signature, so the Keychain would ask for permission again after every build or update. The file is protected by your user account the same way your SSH keys are.

---

## Apple Ads API — Recommended

**Unlocks**
- Apple's own search popularity (1–100) per country, from the monthly *Search Term Rank* lists.
- Your campaigns' results per keyword and country: impressions, taps, installs, spend (Overview → Apple Ads, Keywords → Ads column).
- Popularity when trying your keywords in other countries.

**Why:** Apple publishes popularity only through Apple Ads. Read-only: no campaign is created, nothing is spent.

**How to get it** (about 5 minutes):
1. Create a key pair in Terminal (the private key never leaves your Mac):
   ```bash
   openssl ecparam -genkey -name prime256v1 -noout -out aso-ads-private.pem
   openssl ec -in aso-ads-private.pem -pubout -out aso-ads-public.pem
   ```
2. [ads.apple.com](https://app-ads.apple.com/cm/app) → **Account Settings → User Management** → invite an API user with the **API Account Read Only** role (or use an account that already has API access).
3. Signed in as that user: **Account Settings → API** → paste the contents of `aso-ads-public.pem` → Save. Apple shows the **Client ID** and **Key ID**.
4. The **Org ID** is in the account menu at the top right of ads.apple.com.
5. In ASO Workbench → Connections → Apple Ads API: fill Client ID, Key ID, Org ID, choose `aso-ads-private.pem`, press **Save**, then **Test connection**.

If you see `invalid_client`: the fingerprint shown under the fields must match the public key you uploaded — `openssl pkey -in aso-ads-private.pem -pubout -outform DER | shasum -a 256` (first 16 characters).

## App Store Connect API — Optional

**Unlocks**
- Pull your current listing (name, subtitle, keywords, description, What's New) for every language.
- Publish drafts back: missing languages are created, screenshots are copied from a language you choose, the next version can be created, and every write is re-read from Apple.
- Release detection and the privacy policy URL for the legal footer.

**Why:** metadata lives in App Store Connect. Nothing is written until you press **Publish ▸ Apply** and confirm; nothing is ever submitted for review.

**How to get it:**
1. [App Store Connect](https://appstoreconnect.apple.com/access/integrations/api) → **Users and Access → Integrations → App Store Connect API → Team Keys**.
2. Generate a key with the **App Manager** role (Developer is enough if you only want to read).
3. Download the `.p8` file — Apple lets you download it only once — and copy the **Key ID** and the **Issuer ID** shown above the table.
4. In ASO Workbench: fill Key ID and Issuer ID, choose the `.p8` file, press **Save**. Individual keys are not supported.

## OpenRouter — Optional

**Unlocks**
- The AI metadata writer, *Make better*, *Write all locales*, *What's New* for every language.
- Local-language keyword ideas when trying keywords in other countries.
- Brand and relevance ("Fit") checks behind Golden keywords.
- The popularity model's estimates (they need the Jev answers).

**Why:** these need a language model. OpenRouter lets you choose the model and pay only for what you use.

**Cost:** a full listing costs about $0.003 with DeepSeek V4 Pro (default; Claude Sonnet ≈ $0.015), a keyword check ≈ $0.00003. $5 lasts a long time. Set a spending limit on the key if you like.

**What is sent:** keyword text, your app's public name and App Store description, and your drafts. Never your keys or your data file.

**How to get it:** create an account at [openrouter.ai](https://openrouter.ai), add a little credit, **Keys → Create key**, paste it (starts with `sk-or-v1-`) and press **Save**. Pick the writer model under the key field.

## RevenueCat — Optional

**Unlocks:** MRR, active subscriptions, 28-day revenue, new customers and trials on Overview, with daily history.

**How to get it:** RevenueCat → your project → **Project settings → API keys → + New secret API key**, API version **2**, **read-only** permissions. Paste one key per line (one per project). Apps are matched to projects by bundle ID.

## Apple Ads website session — Advanced, optional

**Unlocks:** Apple's exact popularity index for any term, including terms missing from the monthly lists (these show `Apple · index`).

**How it works:** you log in to Apple Ads in a browser window inside the app; ASO Workbench then reads the same index the Apple Ads website shows. This is **not a documented API**: it may stop working at any time, and you use it at your own risk. Session cookies are stored with your other keys; **Sign out** deletes them.

**How to use it:** Connections → *Apple Ads website session* → **Sign in…** → log in → enter the App ID of any app in your Apple Ads account → **Check session**.
