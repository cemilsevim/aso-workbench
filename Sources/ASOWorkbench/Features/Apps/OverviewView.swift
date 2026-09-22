import SwiftUI
import SwiftData
import ASOCore

struct OverviewView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.modelContext) private var context
    @Bindable var app: TrackedApp
    let market: TrackedMarket?

    private let columns = [GridItem(.adaptive(minimum: 200), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if let market {
                    LazyVGrid(columns: columns, spacing: 12) {
                        StatCard(title: "Tracked keywords") { Text("\(market.keywords.count)").font(.title2).monospacedDigit() }
                        StatCard(title: "In top 10") { Text("\(top10(market))").font(.title2).monospacedDigit() }
                        StatCard(title: "Found in top \(env.settings.resultDepth)") { Text("\(found(market))").font(.title2).monospacedDigit() }
                        StatCard(title: "Last measurement") {
                            Text(market.lastMeasuredAt?.relativeLabel ?? "Never").font(.title3)
                        }
                    }
                } else {
                    InlineMessage(kind: .info, text: "No market yet. Use the market menu in the toolbar to add one.")
                }

                if let market {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 6) {
                            let golden = market.keywords.filter { $0.isGolden(minPopularity: env.settings.goldenMinPopularity, maxDifficulty: env.settings.goldenMaxDifficulty) }
                                .sorted { ($0.opportunity ?? 0) > ($1.opportunity ?? 0) }
                            if golden.isEmpty {
                                Text("No tracked keyword is golden yet (popularity ≥ \(env.settings.goldenMinPopularity), difficulty ≤ \(env.settings.goldenMaxDifficulty), not another brand, related to this app). Research → Find golden keywords expands around your best terms.")
                                    .font(.callout).foregroundStyle(.secondary)
                            } else {
                                ForEach(golden.prefix(8), id: \.persistentModelID) { k in
                                    HStack {
                                        Image(systemName: "star.fill").foregroundStyle(.yellow)
                                        Text(k.text)
                                        Spacer()
                                        Text("opportunity \(Int((k.opportunity ?? 0).rounded())) · pop \(k.latestPopularity?.popularity1to100 ?? 0) · diff \(k.difficultyScore?.rounded ?? 0) · \(k.latestMeasured?.outcome.shortLabel ?? "—")").font(.caption).foregroundStyle(.secondary).monospacedDigit()
                                    }
                                    .font(.callout)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } label: {
                        HStack { Text("Golden keywords in \(market.title)"); Image(systemName: "star.fill").foregroundStyle(.yellow) }
                    }
                }

                RevenueCard(app: app)

                RatingsCard(app: app)

                AdsCard(app: app)

                GroupBox("Connections") {
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent("App Store Connect") {
                            HStack { ConnectionStateLabel(state: env.ascState); connectButton(env.ascState) }
                        }
                        LabeledContent("Apple Ads Platform API") {
                            HStack { ConnectionStateLabel(state: env.adsState); connectButton(env.adsState) }
                        }
                        LabeledContent("Public App Store search") { Label("Always available · proxy for on-device ranking", systemImage: "globe").foregroundStyle(.secondary) }
                        HStack {
                            Text("Rank tracking and autocomplete work without any account.").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Button("Manage connections…") { NotificationCenter.default.post(name: .openConnectionsRequested, object: nil) }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Apple Ads genre for popularity lookups") {
                    VStack(alignment: .leading, spacing: 6) {
                        Picker("Genre", selection: $app.adsGenre) {
                            Text("Any: search all 15 genres (default)").tag(Optional<AppleAdsGenre>.none)
                            Divider()
                            ForEach(AppleAdsGenre.allCases) { Text($0.displayName).tag(Optional($0)) }
                        }
                        .frame(maxWidth: 420)
                        if let mapped = AppleAdsGenre(appStoreGenre: app.primaryGenre) {
                            Text("App Store category \"\(app.primaryGenre ?? "")\" maps to \(mapped.displayName); it was set automatically when the app was added.")
                                .font(.caption).foregroundStyle(.secondary)
                        } else {
                            Text("App Store category \"\(app.primaryGenre ?? "—")\" has no Apple Ads counterpart, so every genre is searched.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Text("Apple publishes search-term popularity per country and genre (a fixed list of 15; some App Store categories such as \(app.primaryGenre ?? "Graphics & Design") have no counterpart). \"Any\" looks every genre up and keeps the best record per term. Scores are relative within a country and must not be compared across countries.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Shortcuts") {
                    VStack(alignment: .leading, spacing: 8) {
                        ShortcutHints(items: [("⌘N", "add app"), ("⌘K", "add keywords"), ("⌘R", "measure market"), ("⇧⌘P", "popularity")])
                        ShortcutHints(items: [("⌘⌫", "remove selected"), ("⇧⌘E", "export CSV"), ("⌥⌘I", "inspector"), ("⌘/", "all shortcuts")])
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("How to read the numbers") {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Rank comes from the public iTunes Search API for the selected storefront and device. It is a proxy, not the ranking every user sees.", systemImage: "1.circle")
                        Label("\"> 200\" means the app was not among the observed results. It is never stored as rank 201.", systemImage: "2.circle")
                        Label("Popularity is Apple's own score when Apple Ads is connected; \"no record\" is stored as such, never as zero.", systemImage: "3.circle")
                        Label("Competition signals (rating mass, title matches, seller diversity) are shown separately and never averaged into one score.", systemImage: "4.circle")
                    }
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(20)
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            AppIconView(url: app.iconURL, size: 56)
            VStack(alignment: .leading, spacing: 3) {
                Text(app.name).font(.title2.weight(.semibold))
                Text("\(app.sellerName) · \(app.primaryGenre ?? "—") · App ID \(app.trackID)\(app.bundleID.map { " · \($0)" } ?? "")")
                    .font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
                Text("Markets: " + (app.sortedMarkets.map(\.title).joined(separator: ", ").nilIfEmpty ?? "none"))
                    .font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func connectButton(_ state: ConnectionState) -> some View {
        if case .notConfigured = state {
            Button("Connect…") { NotificationCenter.default.post(name: .openConnectionsRequested, object: nil) }
                .controlSize(.small)
        }
    }

    private func top10(_ market: TrackedMarket) -> Int {
        market.keywords.filter { ($0.latestMeasured?.position ?? Int.max) <= 10 }.count
    }
    private func found(_ market: TrackedMarket) -> Int {
        market.keywords.filter { $0.latestMeasured?.position != nil }.count
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
