import SwiftUI
import SwiftData
import ASOCore

/// Keyword discovery. Public autocomplete is always available; Apple Ads data
/// appears in its own sections when the account is connected.
struct ResearchView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.modelContext) private var context
    let app: TrackedApp
    let market: TrackedMarket?

    @State private var seed = ""
    @State private var results = ResearchService.SuggestionSet()
    @State private var hasSearched = false
    @State private var genreRows: [PopularityRecord] = []
    @State private var genreError: String?
    @State private var genreFilter = ""
    @State private var isLoadingGenre = false
    @State private var browseGenre: AppleAdsGenre = .entertainment
    @State private var showGolden = false
    @State private var showExpansion = false
    @State private var importLink = ""
    @State private var importTarget: SearchResultApp?
    @State private var importError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                goldenSection
                seedSection
                if hasSearched {
                    suggestionsSection(title: "App Store autocomplete", origin: .publicSearchObserved,
                                       note: "Suggestions Apple shows while typing in \(market?.title ?? "the store"). Position is the only signal; Apple removed the traffic score in 2026.",
                                       items: results.publicHints, error: results.publicError)
                    if env.adsState.isUsable {
                        suggestionsSection(title: "Apple Ads keyword suggestions", origin: .officialObserved,
                                           note: "Seeded with the term above and this app. The 0–100 popularity is relative across all App Store countries, Apple does not return a storefront, so use it for discovery, not for country-level decisions.",
                                           items: results.appleAds, error: results.appleAdsError)
                    }
                }
                genreSection
            }
            .padding(20)
        }
        .onAppear { if let g = app.adsGenre { browseGenre = g } }
        .sheet(isPresented: $showExpansion) {
            if let market { ExpansionSheet(app: app, market: market).environment(env) }
        }
        .sheet(isPresented: $showGolden) {
            if let market { KeywordDiscoverySheet(app: app, market: market, competitor: nil, seeds: goldenSeeds) }
        }
        .sheet(item: $importTarget) { target in
            if let market { KeywordDiscoverySheet(app: app, market: market, competitor: target, seeds: KeywordDiscovery.phrases(from: target.name, maxUnigrams: 4, maxBigrams: 2)) }
        }
    }

    /// Seeds for the golden finder: best tracked keywords first, then the app's own title words.
    private var goldenSeeds: [String] {
        let tracked = (market?.sortedKeywords ?? []).sorted { ($0.latestPopularity?.popularity1to100 ?? -1) > ($1.latestPopularity?.popularity1to100 ?? -1) }.map(\.text)
        return Array((tracked + KeywordDiscovery.phrases(from: app.name, maxUnigrams: 4, maxBigrams: 2)).prefix(8))
    }

    private var goldenSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text("Golden = Apple popularity ≥ \(env.settings.goldenMinPopularity), difficulty ≤ \(env.settings.goldenMaxDifficulty) and not another brand's name (Settings → Measurement). The finder expands your best keywords and title words with autocomplete and Apple Ads suggestions, scores every candidate and measures difficulty for the most promising ones. Or import a competitor's keywords from its App Store link.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    Button { showGolden = true } label: { Label("Find golden keywords", systemImage: "star.circle") }
                        .disabled(market == nil)
                    Button { showExpansion = true } label: { Label("Try keywords in other countries", systemImage: "globe") }
                        .disabled(market == nil || (market?.keywords.isEmpty ?? true))
                    Divider().frame(height: 18)
                    TextField("Competitor App Store link or ID", text: $importLink).textFieldStyle(.roundedBorder).frame(maxWidth: 340)
                        .onSubmit { Task { await lookupImport() } }
                    Button("Import keywords…") { Task { await lookupImport() } }
                        .disabled(market == nil || AppStoreURL.parse(importLink) == nil)
                }
                if let importError { InlineMessage(kind: .error, text: importError) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            HStack { Text("Golden keywords and competitor import"); Image(systemName: "star.fill").foregroundStyle(.yellow) }
        }
    }

    private func lookupImport() async {
        importError = nil
        guard let market, let sf = market.storefront, let parsed = AppStoreURL.parse(importLink) else { return }
        do {
            if let found = try await env.catalog.findApps(query: String(parsed.trackID), storefront: sf).first { importTarget = found }
            else { importError = "No app found for that link in \(sf.name)." }
        } catch { importError = error.localizedDescription }
    }

    // MARK: Seed

    private var seedSection: some View {
        GroupBox("Discover from a seed term") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    TextField("e.g. budget planner", text: $seed)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { Task { await search() } }
                    Button("Suggest") { Task { await search() } }
                        .disabled(seed.trimmingCharacters(in: .whitespaces).isEmpty || market == nil || env.research.isLoadingSuggestions)
                    if env.research.isLoadingSuggestions { ProgressView().controlSize(.small) }
                }
                if market == nil {
                    Text("Add a market first; suggestions are storefront-specific.").font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func search() async {
        guard let market, let sf = market.storefront else { return }
        results = await env.research.suggestions(seed: seed, storefront: sf, app: app)
        hasSearched = true
    }

    private func suggestionsSection(title: String, origin: DataOrigin, note: String, items: [KeywordSuggestion], error: String?) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text(note).font(.caption).foregroundStyle(.secondary)
                if let error { InlineMessage(kind: .error, text: error) }
                if items.isEmpty && error == nil {
                    Text("No suggestions returned.").foregroundStyle(.secondary).font(.callout)
                }
                ForEach(items) { s in
                    HStack(spacing: 10) {
                        Text("\(s.position)").monospacedDigit().foregroundStyle(.secondary).frame(width: 24, alignment: .trailing)
                        Text(s.text).textSelection(.enabled)
                        Spacer()
                        if let pop = s.popularity {
                            Text("\(pop)").monospacedDigit()
                            SourceBadge(origin: .officialObserved, detail: "cross-country")
                        }
                        trackButton(s.text)
                    }
                    .font(.callout)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            HStack { Text(title); SourceBadge(origin: origin) }
        }
    }

    @ViewBuilder
    private func trackButton(_ text: String) -> some View {
        if let market {
            let tracked = market.keywords.contains { $0.normalized == TrackedKeyword.normalize(text) }
            Button(tracked ? "Tracked" : "Track") {
                env.catalog.addKeywords(text, to: market, context: context)
            }
            .disabled(tracked)
            .controlSize(.small)
        }
    }

    // MARK: Genre dataset

    private var genreSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text("Apple's monthly list of popular search terms for a country and genre (last completed month). No campaign is needed. Popularity is relative within the country.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Text(market?.countryCode ?? "—").font(.callout)
                    Picker("Genre", selection: $browseGenre) {
                        ForEach(AppleAdsGenre.allCases) { Text($0.displayName).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 220)
                    Spacer()
                    TextField("Filter", text: $genreFilter).textFieldStyle(.roundedBorder).frame(width: 180)
                    Button("Load") { Task { await loadGenre() } }
                        .disabled(!env.adsState.isUsable || market == nil || isLoadingGenre)
                    if isLoadingGenre { ProgressView().controlSize(.small) }
                }
                if !env.adsState.isUsable {
                    Text("Connect Apple Ads (sidebar → Connections) to load this dataset.").font(.callout).foregroundStyle(.secondary)
                }
                if let genreError { InlineMessage(kind: .error, text: genreError) }
                if !genreRows.isEmpty {
                    let filtered = genreRows.filter { genreFilter.isEmpty || $0.searchTerm.localizedCaseInsensitiveContains(genreFilter) }
                    Text("\(filtered.count) of \(genreRows.count) terms").font(.caption).foregroundStyle(.secondary)
                    Table(filtered) {
                        TableColumn("#") { Text($0.rankInGenre.map(String.init) ?? "—").monospacedDigit() }.width(40)
                        TableColumn("Search term", value: \.searchTerm)
                        TableColumn("1–100") { Text($0.popularity1to100.map(String.init) ?? "—").monospacedDigit() }.width(60)
                        TableColumn("1–5") { Text($0.popularity1to5.map(String.init) ?? "—").monospacedDigit() }.width(40)
                        TableColumn("") { row in trackButton(row.searchTerm) }.width(80)
                    }
                    .frame(minHeight: 300, maxHeight: 520)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            HStack { Text("Popular search terms by genre"); SourceBadge(origin: .officialObserved) }
        }
    }

    private func loadGenre() async {
        guard let market else { return }
        let genre = browseGenre
        isLoadingGenre = true
        genreError = nil
        defer { isLoadingGenre = false }
        do {
            genreRows = try await env.research.genreDataset(country: market.countryCode, genre: genre)
            if genreRows.isEmpty { genreError = "Apple returned no rows for \(market.countryCode) / \(genre.displayName). Data is published with a delay of a few weeks." }
        } catch {
            genreError = error.localizedDescription
        }
    }
}
