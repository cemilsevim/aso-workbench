import SwiftUI
import UniformTypeIdentifiers
import ASOProviders
import ASOCore

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
            ConnectionsSettings()
                .tabItem { Label("Connections", systemImage: "key") }
            MeasurementSettings()
                .tabItem { Label("Measurement", systemImage: "gauge.with.dots.needle.33percent") }
        }
        .frame(width: 660, height: 600)
    }
}

struct ConnectionsSettings: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.modelContext) private var context
    var showIntro = false

    @State private var ascKeyID = ""
    @State private var ascIssuerID = ""
    @State private var ascPEM = ""
    @State private var adsClientID = ""
    @State private var adsKeyID = ""
    @State private var adsOrgID = ""
    @State private var adsPEM = ""
    @State private var showImporter = false
    @State private var importTarget: ImportTarget = .asc
    @State private var importError: String?
    @State private var ascKeyName = ""
    @State private var adsKeyName = ""
    @State private var busy = false
    @State private var showSignIn = false
    @State private var openRouterKey = ""
    @State private var revenueCatKeys = ""

    enum ImportTarget { case asc, ads }

    var body: some View {
        Form {
            Section {
                ConnectionsOverview()
            }

            Section {
                ConnectionIntro(
                    unlocks: ["Apple's own search popularity (1–100) per country, from the monthly Search Term Rank lists",
                              "Your campaigns' results per keyword and country: impressions, taps, installs, spend",
                              "Popularity when trying your keywords in other countries"],
                    dataFlow: "Read-only. Signs a token on this Mac and talks only to appleid.apple.com, api.ads.apple.com and api.searchads.apple.com. Needs no campaign and spends no money.",
                    steps: ["In Terminal, create a key pair (the private key never leaves your Mac):\n`openssl ecparam -genkey -name prime256v1 -noout -out aso-ads-private.pem`\n`openssl ec -in aso-ads-private.pem -pubout -out aso-ads-public.pem`",
                            "ads.apple.com → **Account Settings → User Management**: invite an API user with the **API Account Read Only** role (or use an account that already has API access).",
                            "Signed in as that user: **Account Settings → API** → paste the contents of *aso-ads-public.pem* → Save. Apple shows the **Client ID** and **Key ID**.",
                            "The **Org ID** is in the account menu at the top right of ads.apple.com.",
                            "Here: fill Client ID, Key ID, Org ID, choose *aso-ads-private.pem*, press Save."],
                    link: ("Open Apple Ads", "https://app-ads.apple.com/cm/app"))
                TextField("Client ID", text: $adsClientID, prompt: Text("SEARCHADS.xxxxxxxx-…"))
                TextField("Key ID", text: $adsKeyID)
                TextField("Org ID", text: $adsOrgID)
                keyRow(pem: adsPEM, name: adsKeyName, target: .ads, clear: { adsPEM = ""; adsKeyName = "" })
                if let importError, importTarget == .ads { InlineMessage(kind: .error, text: importError) }
                LabeledContent("Status") { ConnectionStateLabel(state: env.adsState) }
                diagnostics(ids: [("Client ID", adsClientID), ("Key ID", adsKeyID), ("Org ID", adsOrgID)], pem: adsPEM)
                Text("The fingerprint must equal `openssl pkey -in key.pem -pubout -outform DER | shasum -a 256` (first 16 characters) of the key whose public half you uploaded to Apple.")
                    .font(.caption2).foregroundStyle(.tertiary)
                HStack {
                    Button("Save") { Task { await saveAds() } }
                        .disabled(adsClientID.isEmpty || adsKeyID.isEmpty || adsOrgID.isEmpty || adsPEM.isEmpty)
                    Button("Test connection") { Task { busy = true; await env.verifyAppleAds(); busy = false } }
                        .disabled(env.credentials.loadAppleAds() == nil || busy)
                    Button("Remove", role: .destructive) { Task { adsClientID = ""; adsKeyID = ""; adsOrgID = ""; adsPEM = ""; adsKeyName = ""; await env.saveAppleAds(nil) } }
                        .disabled(env.credentials.loadAppleAds() == nil)
                }
            } header: {
                ConnectionHeader(title: "Apple Ads API", systemImage: "chart.bar", need: .recommended) { ConnectionStateLabel(state: env.adsState) }
            }

            Section {
                ConnectionIntro(
                    unlocks: ["Pull your current listing (name, subtitle, keywords, description, What's New) for every language",
                              "Publish drafts back: missing languages are created, screenshots copied, the result re-read",
                              "Detect new releases and read the privacy policy URL for the legal footer"],
                    dataFlow: "Signs a short-lived token on this Mac and talks only to api.appstoreconnect.apple.com. Nothing is written until you press Apply and confirm; nothing is ever submitted for review.",
                    steps: ["Open App Store Connect → **Users and Access → Integrations → App Store Connect API → Team Keys**.",
                            "Generate a key with the **App Manager** role (needed to write metadata; Developer is enough for read-only).",
                            "Download the **.p8** file: Apple lets you download it only once, and copy the **Key ID** and the **Issuer ID** shown above the table.",
                            "Here: fill Key ID and Issuer ID, choose the .p8 file, press Save. Individual keys are not supported."],
                    link: ("Open App Store Connect", "https://appstoreconnect.apple.com/access/integrations/api"))
                TextField("Key ID", text: $ascKeyID, prompt: Text("e.g. 2X9R4HXF34"))
                TextField("Issuer ID", text: $ascIssuerID, prompt: Text("UUID shown above the keys table"))
                keyRow(pem: ascPEM, name: ascKeyName, target: .asc, clear: { ascPEM = ""; ascKeyName = "" })
                if let importError, importTarget == .asc { InlineMessage(kind: .error, text: importError) }
                LabeledContent("Status") { ConnectionStateLabel(state: env.ascState) }
                diagnostics(ids: [("Key ID", ascKeyID), ("Issuer ID", ascIssuerID)], pem: ascPEM)
                HStack {
                    Button("Save") { Task { await saveASC() } }
                        .disabled(ascKeyID.isEmpty || ascIssuerID.isEmpty || ascPEM.isEmpty)
                    Button("Test connection") { Task { busy = true; await env.verifyASC(); busy = false } }
                        .disabled(env.credentials.loadASC() == nil || busy)
                    Button("Remove", role: .destructive) { Task { ascKeyID = ""; ascIssuerID = ""; ascPEM = ""; ascKeyName = ""; await env.saveASC(nil) } }
                        .disabled(env.credentials.loadASC() == nil)
                }
            } header: {
                ConnectionHeader(title: "App Store Connect API", systemImage: "doc.text", need: .optional) { ConnectionStateLabel(state: env.ascState) }
            }

            Section {
                ConnectionIntro(
                    unlocks: ["AI metadata writer, Make better, Write all locales and What's New translations",
                              "Local-language keyword ideas when trying keywords in other countries",
                              "Brand, relevance and \"is this an app?\" checks behind Golden keywords and Fit"],
                    dataFlow: "Pay-as-you-go on your own OpenRouter account (typical: a listing ≈ $0.003 with DeepSeek, a keyword check ≈ $0.00003). Sends keyword text, your app's public name and description and your drafts to openrouter.ai, never your keys or data file.",
                    steps: ["Create an account at openrouter.ai and add a little credit ($5 lasts a long time).",
                            "**Keys → Create key**; optionally set a spending limit on the key.",
                            "Paste the key (starts with `sk-or-v1-`) here and press Save."],
                    link: ("Open OpenRouter keys", "https://openrouter.ai/settings/keys"))
                Picker("Writer model", selection: Binding(get: { env.assistant.model }, set: { env.assistant.model = $0 })) {
                    ForEach(LLMClient.modelChoices, id: \.id) { Text($0.label).tag($0.id) }
                    if !LLMClient.modelChoices.contains(where: { $0.id == env.assistant.model }) { Text(env.assistant.model).tag(env.assistant.model) }
                }
                Text("Writes listings and translations. Keyword checks always use TypeSafe Jev, a small classification model that answers with probabilities.").font(.caption).foregroundStyle(.secondary)
                SecureField("OpenRouter API key", text: $openRouterKey, prompt: Text("sk-or-v1-…"))
                HStack {
                    Button("Save") { Task { await env.saveOpenRouterKey(openRouterKey); await env.verifyOpenRouter() } }.disabled(openRouterKey.isEmpty)
                    Button("Test connection") { Task { busy = true; await env.verifyOpenRouter(); busy = false } }.disabled(!env.openRouterState.isUsable || busy)
                    Button("Remove", role: .destructive) { Task { openRouterKey = ""; await env.saveOpenRouterKey(nil) } }.disabled(!env.openRouterState.isUsable)
                }
            } header: {
                ConnectionHeader(title: "OpenRouter (AI)", systemImage: "sparkles", need: .optional) { ConnectionStateLabel(state: env.openRouterState) }
            }

            Section {
                ConnectionIntro(
                    unlocks: ["MRR, active subscriptions, 28-day revenue, new customers and trials on Overview, with daily history"],
                    dataFlow: "Read-only. Talks only to api.revenuecat.com. Apps are matched to projects by bundle ID.",
                    steps: ["RevenueCat → your project → **Project settings → API keys → + New secret API key**.",
                            "Choose API version **2** and give it **read-only** permissions.",
                            "Paste it here, one key per line (one per project), and press Save."],
                    link: ("Open RevenueCat", "https://app.revenuecat.com"))
                TextEditor(text: $revenueCatKeys).font(.system(.body, design: .monospaced)).frame(minHeight: 60)
                HStack {
                    Button("Save") { env.saveRevenueCatKeys(revenueCatKeys.split(whereSeparator: { $0 == "\n" || $0 == "," }).map(String.init)) }
                    Button("Read now") { Task { await env.revenue.refresh(context: context) } }.disabled(!env.revenue.isConfigured || env.revenue.isRefreshing)
                    if env.revenue.isRefreshing { ProgressView().controlSize(.small) }
                    if let m = env.revenue.lastMessage { Text(m).font(.caption).foregroundStyle(.secondary) }
                }
            } header: {
                ConnectionHeader(title: "RevenueCat", systemImage: "dollarsign.circle", need: .optional) {
                    if env.revenue.isConfigured { Label("\(env.revenue.keys.count) key(s)", systemImage: "checkmark.circle.fill").foregroundStyle(.green) } else { Text("Not set").foregroundStyle(.secondary) }
                }
            }

            Section {
                ConnectionIntro(
                    unlocks: ["Apple's exact popularity index for any term, including the ones missing from the monthly lists"],
                    dataFlow: "Uses your own Apple Ads login inside an in-app browser and reads the index the Apple Ads website shows. This is not a documented API: it can stop working at any time and you use it at your own risk. Session cookies are stored locally with your other keys.",
                    steps: ["Press **Sign in…** and log in to Apple Ads as you would in a browser.",
                            "Enter the App ID of any app in your Apple Ads account as the reference app.",
                            "Press **Check session**. Sign out removes the cookies."])
                TextField("Reference app ID (adamId)", text: Binding(get: { env.adsSession.referenceAdamID }, set: { env.adsSession.referenceAdamID = $0 }), prompt: Text("App ID of any app in your Apple Ads account"))
                HStack {
                    Button("Sign in…") { showSignIn = true }
                    Button("Check session") { Task { await env.adsSession.checkSession() } }.disabled(env.adsSession.isBusy)
                    Button("Sign out", role: .destructive) { Task { await env.adsSession.signOut() } }.disabled(!env.adsSession.state.isSignedIn)
                }
            } header: {
                ConnectionHeader(title: "Apple Ads website session", systemImage: "safari", need: .advanced) { sessionLabel }
            }

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Where your keys live", systemImage: "lock").font(.headline)
                    Text("In one file on this Mac, readable only by your macOS user (permissions 600): \(CredentialStore.fileURL.path). Not in the data file, not in logs, not in CSV exports. Each key is sent only to its own service; the app refuses requests to any other host. Remove deletes a key from the file.")
                        .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                    Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([CredentialStore.fileURL]) }.controlSize(.small)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: load)
        .sheet(isPresented: $showSignIn) {
            AppleAdsSignInSheet { Task { await env.adsSession.checkSession() } }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.item]) { result in
            switch result {
            case .failure(let error):
                importError = error.localizedDescription
            case .success(let url):
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                do {
                    let text = try String(contentsOf: url, encoding: .utf8)
                    load(keyText: text, filename: url.lastPathComponent, into: importTarget)
                } catch {
                    importError = "Could not read \(url.lastPathComponent): \(error.localizedDescription)"
                }
            }
        }
    }

    /// Validates the PEM (must be a P-256 key), stores it for the target and fills the Key ID from `AuthKey_XXXX.p8` when empty.
    private func load(keyText: String, filename: String?, into target: ImportTarget) {
        do {
            _ = try ES256Signer(pem: keyText)
        } catch {
            importError = error.localizedDescription
            return
        }
        importError = nil
        switch target {
        case .asc:
            ascPEM = keyText
            ascKeyName = filename ?? "clipboard"
            if ascKeyID.isEmpty, let id = filename.flatMap(Self.keyID(fromFilename:)) { ascKeyID = id }
        case .ads:
            adsPEM = keyText
            adsKeyName = filename ?? "clipboard"
        }
    }

    /// `AuthKey_2X9R4HXF34.p8` → `2X9R4HXF34`.
    static func keyID(fromFilename name: String) -> String? {
        guard let match = name.firstMatch(of: /AuthKey_([A-Za-z0-9]+)\.p8$/) else { return nil }
        return String(match.1)
    }

    @ViewBuilder
    private var sessionLabel: some View {
        switch env.adsSession.state {
        case .unknown: Label("Not checked", systemImage: "circle.dashed").foregroundStyle(.secondary)
        case .signedOut: Label("Not signed in", systemImage: "circle").foregroundStyle(.secondary)
        case .signedIn(let at): Label("Signed in · checked \(at.relativeLabel)", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed(let m): Label(m, systemImage: "xmark.octagon.fill").foregroundStyle(.red)
        }
    }

    private func keyRow(pem: String, name: String, target: ImportTarget, clear: @escaping () -> Void) -> some View {
        LabeledContent("Private key") {
            HStack {
                if pem.isEmpty {
                    Text("No key loaded").foregroundStyle(.secondary)
                } else {
                    Label(name.isEmpty ? "Key loaded (saved earlier)" : "Key loaded · \(name)", systemImage: "checkmark")
                        .foregroundStyle(.green)
                        .help("\(pem.utf8.count) bytes, \(pem.hasPrefix("-----BEGIN EC PRIVATE KEY") ? "SEC1" : "PKCS#8") PEM")
                    Button("Clear", action: clear).controlSize(.small)
                }
                Button("Choose \(target == .asc ? ".p8" : ".pem") file…") {
                    importTarget = target
                    showImporter = true
                }
                Button("Paste") {
                    importTarget = target
                    if let text = NSPasteboard.general.string(forType: .string) {
                        load(keyText: text, filename: nil, into: target)
                    } else {
                        importError = "The clipboard has no text. Copy the contents of the key file first."
                    }
                }
                .help("Use the key text from the clipboard instead of a file")
            }
        }
    }

    private func load() {
        if let c = env.credentials.loadASC()?.sanitized { ascKeyID = c.keyID; ascIssuerID = c.issuerID; ascPEM = c.privateKeyPEM }
        if let c = env.credentials.loadAppleAds()?.sanitized { adsClientID = c.clientID; adsKeyID = c.keyID; adsOrgID = c.orgID; adsPEM = c.privateKeyPEM }
        openRouterKey = env.credentials.loadOpenRouterKey() ?? ""
        revenueCatKeys = env.credentials.loadRevenueCatKeys().joined(separator: "\n")
    }

    private func saveASC() async {
        let creds = ASCCredentials(keyID: ascKeyID, issuerID: ascIssuerID, privateKeyPEM: ascPEM).sanitized
        ascKeyID = creds.keyID; ascIssuerID = creds.issuerID; ascPEM = creds.privateKeyPEM
        await env.saveASC(creds)
        await env.verifyASC()
    }

    private func saveAds() async {
        let creds = AppleAdsCredentials(clientID: adsClientID, keyID: adsKeyID, orgID: adsOrgID, privateKeyPEM: adsPEM).sanitized
        adsClientID = creds.clientID; adsKeyID = creds.keyID; adsOrgID = creds.orgID; adsPEM = creds.privateKeyPEM
        await env.saveAppleAds(creds)
        await env.verifyAppleAds()
    }

    /// One line of facts that make "invalid_client" debuggable without exposing secrets.
    private func diagnostics(ids: [(String, String)], pem: String) -> some View {
        var parts: [String] = []
        for (name, value) in ids {
            let clean = value.strippedIdentifier
            parts.append(clean == value ? "\(name) \(value.count) chars" : "\(name) has \(value.count - clean.count) invisible/whitespace character(s): Save strips them")
        }
        if !pem.isEmpty {
            if let signer = try? ES256Signer(pem: pem) {
                parts.append("key fingerprint \(signer.publicKeyFingerprint)")
            } else {
                parts.append("key: not a valid P-256 PEM")
            }
        }
        return Text(parts.joined(separator: " · "))
            .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
    }
}

struct MeasurementSettings: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        @Bindable var settings = env.settings
        Form {
            Section("Public search") {
                Picker("Results inspected per keyword", selection: $settings.resultDepth) {
                    Text("50").tag(50); Text("100").tag(100); Text("200 (Apple's maximum)").tag(200)
                }
                Slider(value: $settings.pacingSeconds, in: 1...6, step: 0.5) {
                    Text("Seconds between requests")
                } minimumValueLabel: { Text("1s") } maximumValueLabel: { Text("6s") }
                Text("Currently \(settings.pacingSeconds, format: .number.precision(.fractionLength(1)))s. The public search API is limited to roughly 20 requests per minute; faster pacing produces errors. Takes effect after relaunch.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Golden keywords") {
                Stepper("Popularity at least \(settings.goldenMinPopularity)", value: $settings.goldenMinPopularity, in: 5...100, step: 5)
                Stepper("Difficulty at most \(settings.goldenMaxDifficulty)", value: $settings.goldenMaxDifficulty, in: 5...100, step: 5)
                Text("Used by the Golden filter in Keywords, the Overview card and the finder in Research.").font(.caption).foregroundStyle(.secondary)
                Divider()
                Stepper("Writer tier A (winnable now): difficulty ≤ \(settings.writerEasyDifficulty)", value: $settings.writerEasyDifficulty, in: 5...100, step: 5)
                Stepper("Writer tier B (reachable): difficulty ≤ \(settings.writerMaxDifficulty)", value: $settings.writerMaxDifficulty, in: 5...100, step: 5)
                Text("The metadata writer covers tier A phrases first (sorted by popularity), then tier B; harder phrases only when popularity ≥ 50 and only if room remains. A keyword already ranking in the top 10 is tier A whatever its difficulty.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Automatic refresh") {
                Toggle("Measure stale markets when the app opens", isOn: $settings.autoMeasureOnLaunch)
                Stepper("Consider a market stale after \(settings.staleHours) hours", value: $settings.staleHours, in: 6...72, step: 2)
                Text("There is no background daemon in this version: while the Mac is asleep or the app is closed, days are simply left unmeasured. Gaps are shown as gaps, never back-filled.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

struct GeneralSettings: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        @Bindable var updates = env.updates
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ASO Workbench").font(.title3.weight(.semibold))
                        Text("App Store Optimization on your Mac, with honest numbers.").font(.caption).foregroundStyle(.secondary)
                    }
                }
                LabeledContent("Version") { Text("\(AppInfo.version) (\(AppInfo.build))").monospacedDigit().textSelection(.enabled) }
                LabeledContent("Source") {
                    Button(AppInfo.repository) { NSWorkspace.shared.open(AppInfo.repositoryURL) }.buttonStyle(.link)
                }
            }
            Section("Updates") {
                Toggle("Check for updates automatically", isOn: $updates.automatic)
                Text("Once a day the app asks GitHub for the newest release of \(AppInfo.repository). Nothing about you or your data is sent. When there is one, a note appears at the bottom of the sidebar.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("Check now") { NotificationCenter.default.post(name: .checkForUpdatesRequested, object: nil) }
                        .disabled(env.updates.isChecking)
                    if let d = env.updates.lastChecked { Text("Last checked \(d.relativeLabel)").font(.caption).foregroundStyle(.secondary) }
                    if let skipped = env.updates.skippedVersion {
                        Spacer()
                        Button("Stop skipping \(skipped)") { env.updates.skippedVersion = nil }.controlSize(.small)
                    }
                }
            }
            Section("Data") {
                LabeledContent("Data file") {
                    Text(PersistenceController.storeURL.path).textSelection(.enabled).font(.caption).multilineTextAlignment(.trailing)
                }
                HStack {
                    Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([PersistenceController.storeURL]) }
                    Button("Show backups") {
                        let dir = PersistenceController.storeURL.deletingLastPathComponent().appendingPathComponent("Backups", isDirectory: true)
                        NSWorkspace.shared.open(FileManager.default.fileExists(atPath: dir.path) ? dir : PersistenceController.storeURL.deletingLastPathComponent())
                    }
                }
                Text("A plain SQLite file. Each new version backs it up to Backups/ before first opening it (five kept). Copy it to back up; delete it to start over.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
