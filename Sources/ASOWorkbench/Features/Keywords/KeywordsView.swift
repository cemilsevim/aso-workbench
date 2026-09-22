import SwiftUI
import AppKit
import SwiftData
import UniformTypeIdentifiers
import ASOCore

/// Table row built from a tracked keyword's latest observations.
nonisolated struct KeywordRow: Identifiable, Sendable {
    nonisolated struct Popularity: Sendable {
        let value: Int?
        let noRecord: Bool
        let anyGenre: Bool
        let scope: String
        let upperBound: Int?
        let confidence: Double?
        let subFloor: Int?
        let subFloorProbability: Double?
        let countryCode: String
        let genreRaw: String
        let periodStart: Date
        let rankInGenre: Int?
        var isBound: Bool { scope == "bound" || (noRecord && value == nil) }
        /// True when Apple's own number is the floor (or absent) and the model's 6–29 rank stands in for it.
        var usesModelValue: Bool { subFloor != nil && (value ?? 0) < ModelTrainer.publishedThreshold }
        /// The number the table shows and filters use: Apple's value when it is published, else the model's 6–29 rank.
        var displayValue: Int? { usesModelValue ? subFloor : value }
    }

    let id: PersistentIdentifier
    let text: String
    let outcome: RankOutcome?
    let rankSort: Int
    let delta: Int?
    let deltaAgainst: String
    let popularity: Popularity?
    let popularitySort: Int
    let signals: CompetitionSignals?
    let ratingMassSort: Int
    let difficulty: DifficultyScore?
    let difficultySort: Double
    let brandProbability: Double?
    let intent: String?
    let fitProbability: Double?
    let fitSort: Double
    /// Another app's name by results or by Jev with results in view (see TrackedKeyword.isBrandLike).
    let navigational: Bool
    let leaderName: String?
    let ads: (impressions: Int, taps: Int, installs: Int, spend: Double, currency: String)?
    let adsSort: Int
    let opportunity: Double?
    let lastMeasured: Date?
    let lastMeasuredSort: Date
    // Export-only details of the latest successful measurement.
    let measuredPosition: Int?
    let measuredCount: Int
    let measuredAt: Date?
    let measuredProvider: String

    init(_ k: TrackedKeyword, deltaReference: DeltaReference = .previous, markers: [Marker] = []) {
        id = k.persistentModelID
        text = k.text
        let latest = k.latestMeasured
        outcome = k.latestObservation?.outcome
        rankSort = latest?.position ?? Int.max
        let d = k.rankDelta(reference: deltaReference, markers: markers)
        delta = d.delta
        deltaAgainst = d.against
        popularity = k.latestPopularity.map {
            Popularity(value: $0.popularity1to100, noRecord: $0.noRecord, anyGenre: $0.anyGenre, scope: $0.scope, upperBound: $0.upperBound, confidence: $0.estimateConfidence, subFloor: $0.subFloorEstimate, subFloorProbability: $0.subFloorProbability,
                       countryCode: $0.countryCode, genreRaw: $0.genreRaw, periodStart: $0.periodStart, rankInGenre: $0.rankInGenre)
        }
        // Real scores sort by value; "below range" rows sort under every real score; unknown last.
        if let p = k.latestPopularity {
            // Floor terms with a sub-floor rank (6–29) order among themselves, still under every published value.
            if let s = p.subFloorEstimate, (p.popularity1to100 ?? 0) < ModelTrainer.publishedThreshold { popularitySort = s }
            else { popularitySort = p.popularity1to100 ?? ((p.upperBound ?? 50) - 100) }
        } else {
            popularitySort = -200
        }
        signals = latest?.signals
        ratingMassSort = latest?.signals?.medianRatingCountTop10 ?? -1
        // Observations stored before the score existed are computed from their saved results.
        difficulty = latest?.signals?.difficulty ?? latest.flatMap { DifficultyScore(results: $0.results, term: k.text) }
        difficultySort = difficulty?.score ?? -1
        brandProbability = k.brandProbability
        intent = k.intent
        fitProbability = k.fitProbability
        fitSort = k.fitProbability ?? -1
        navigational = k.isBrandLike && (k.brandProbability ?? 0) < 0.5
        leaderName = k.latestMeasured?.results.first?.name
        ads = k.adsSummary
        adsSort = k.adsSummary?.impressions ?? -1
        opportunity = k.opportunity
        lastMeasured = k.latestObservation?.fetchedAt
        lastMeasuredSort = k.latestObservation?.fetchedAt ?? .distantPast
        measuredPosition = latest?.position
        measuredCount = latest?.observedCount ?? 0
        measuredAt = latest?.fetchedAt
        measuredProvider = latest?.providerRaw ?? ""
    }
}

struct KeywordsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.modelContext) private var context
    let app: TrackedApp
    let market: TrackedMarket?

    @State private var selection = Set<PersistentIdentifier>()
    @State private var sortOrder = [KeyPathComparator(\KeywordRow.rankSort)]
    @State private var filter = ""
    @State private var filters = KeywordFilters()
    @State private var showFilters = false
    @State private var showAdd = false
    @State private var showInspector = true
    @State private var confirmDelete = false
    @State private var exportDocument: CSVDocument?

    private var rows: [KeywordRow] {
        guard let market else { return [] }
        let f = filter.trimmingCharacters(in: .whitespaces).lowercased()
        let reference = env.settings.deltaReference
        let markers = market.app?.markers ?? []
        return market.keywords
            .filter { f.isEmpty || $0.normalized.contains(f) }
            .map { KeywordRow($0, deltaReference: reference, markers: markers) }
            .filter { filters.allows($0) }
            .sorted(using: sortOrder)
    }

    private var selectedKeyword: TrackedKeyword? {
        guard let id = selection.first else { return nil }
        return market?.keywords.first { $0.persistentModelID == id }
    }

    var body: some View {
        Group {
            if let market {
                if market.keywords.isEmpty {
                    ContentUnavailableView {
                        Label("No keywords in \(market.title)", systemImage: "list.number")
                    } description: {
                        Text("Add the search terms you want to rank for. Each one is measured against the public App Store search for this storefront.")
                    } actions: {
                        HStack(spacing: 6) {
                            Button("Add Keywords…") { showAdd = true }
                            Keycap(keys: "⌘K")
                        }
                    }
                } else {
                    table(market)
                }
            } else {
                ContentUnavailableView("No market selected", systemImage: "globe", description: Text("Add a market from the toolbar."))
            }
        }
        .inspector(isPresented: $showInspector) {
            if let keyword = selectedKeyword, let market {
                KeywordInspector(keyword: keyword, market: market, ownTrackID: app.trackID)
                    .id(keyword.persistentModelID)
            } else {
                ContentUnavailableView {
                    Label("Select a keyword", systemImage: "sidebar.right")
                } description: {
                    Text("Rank history and competitors appear here.")
                } actions: {
                    ShortcutHints(items: [("↑↓", "move"), ("⌥⌘I", "hide")])
                }
            }
        }
        .inspectorColumnWidth(min: 300, ideal: 360, max: 520)
        .toolbar { toolbarContent }
        .sheet(isPresented: $showAdd) {
            if let market { AddKeywordsSheet(market: market) }
        }
        .confirmationDialog(deleteTitle, isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(selection.count == 1 ? "Remove Keyword" : "Remove \(selection.count) Keywords", role: .destructive) { deleteSelected() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(deleteMessage)
        }
        .onReceive(NotificationCenter.default.publisher(for: .addKeywordsRequested)) { _ in if market != nil { showAdd = true } }
        .onReceive(NotificationCenter.default.publisher(for: .deleteSelectionRequested)) { _ in if !selection.isEmpty { confirmDelete = true } }
        .onReceive(NotificationCenter.default.publisher(for: .measureRequested)) { _ in
            if let market, !env.tracking.progress.isRunning { measure(ids: Set(market.keywords.map(\.persistentModelID)), market) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .measureSelectionRequested)) { _ in
            if let market, !selection.isEmpty, !env.tracking.progress.isRunning { measure(ids: selection, market) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .popularityRequested)) { _ in
            if let market, env.adsState.isUsable { Task { await env.research.refreshPopularity(for: market, context: context) } }
        }
        .onReceive(NotificationCenter.default.publisher(for: .exportRequested)) { _ in if !rows.isEmpty { export() } }
        .onReceive(NotificationCenter.default.publisher(for: .toggleInspectorRequested)) { _ in showInspector.toggle() }
        .fileExporter(isPresented: Binding(get: { exportDocument != nil }, set: { if !$0 { exportDocument = nil } }),
                      document: exportDocument, contentType: .commaSeparatedText,
                      defaultFilename: "\(app.name) \(market?.title ?? "") keywords") { _ in exportDocument = nil }
        .safeAreaInset(edge: .bottom) { progressBar }
        .onChange(of: env.tracking.progress.isRunning) { was, now in
            // A finished measurement run pulls official popularity automatically when Apple Ads is connected.
            if was, !now, env.adsState.isUsable, let market, market.app != nil {
                let justMeasured = env.tracking.lastRunKeywordIDs
                Task { await env.research.refreshPopularity(for: market, only: justMeasured, context: context) }
            }
        }
    }

    private func table(_ market: TrackedMarket) -> some View {
        VStack(spacing: 0) {
            filterBar(market)
            Divider()
            keywordTable(market)
            Divider()
            shortcutFooter
        }
    }

    /// Always-visible reminder of the table's shortcuts.
    private var shortcutFooter: some View {
        HStack {
            ShortcutHints(items: [
                ("⌘K", "add"), ("⌘R", "measure"), ("⇧⌘R", "measure selected"), ("⇧⌘P", "popularity"), ("⌘⌫", "remove"), ("⌥⌘I", "inspector"),
            ])
            Spacer()
            Button { NotificationCenter.default.post(name: .showShortcutsRequested, object: nil) } label: {
                HStack(spacing: 5) { Text("All shortcuts").font(.caption); Keycap(keys: "⌘/") }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }

    /// Sits directly above the table so it stays aligned with it even when the inspector is open.
    private func filterBar(_ market: TrackedMarket) -> some View {
        HStack(spacing: 12) {
            Text(filter.isEmpty ? "\(market.keywords.count) keywords" : "\(rows.count) of \(market.keywords.count) keywords")
                .font(.callout).foregroundStyle(.secondary).monospacedDigit()
            if let last = market.lastMeasuredAt {
                Text("· measured \(last.relativeLabel)").font(.callout).foregroundStyle(.tertiary)
            }
            Spacer()
            Picker("Δ", selection: Binding(get: { env.settings.deltaReference }, set: { env.settings.deltaReference = $0 })) {
                ForEach(DeltaReference.allCases) { Text($0.title).tag($0) }
            }
            .frame(maxWidth: 260)
            .help("What the Δ column compares the latest rank against. Releases are detected from the App Store when you measure; applied metadata changes count too.")
            Button {
                showFilters.toggle()
            } label: {
                Label(filters.activeCount == 0 ? "Filters" : "Filters · \(filters.activeCount)", systemImage: "line.3.horizontal.decrease.circle")
            }
            .popover(isPresented: $showFilters, arrowEdge: .bottom) {
                KeywordFiltersPopover(filters: $filters, depth: env.settings.resultDepth, goldenMinPopularity: env.settings.goldenMinPopularity, goldenMaxDifficulty: env.settings.goldenMaxDifficulty)
            }
            TextField("Filter", text: $filter, prompt: Text("Filter keywords"))
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func keywordTable(_ market: TrackedMarket) -> some View {
        Table(rows, selection: $selection, sortOrder: $sortOrder) {
            columnsA(market)
            columnsB(market)
            columnsC(market)
        }
        .contextMenu(forSelectionType: PersistentIdentifier.self) { ids in
            Button(ids.count == 1 ? "Copy keyword" : "Copy \(ids.count) keywords") { copyKeywords(ids) }
            Button(ids.count == 1 ? "Measure rank now" : "Measure \(ids.count) ranks now") { measure(ids: ids, market) }
                .disabled(env.tracking.progress.isRunning)
            Button(ids.count == 1 ? "Refresh popularity" : "Refresh popularity for \(ids.count)") { refreshPopularity(ids) }
                .disabled(!env.adsState.isUsable || env.research.isLoadingPopularity)
            Button(ids.count == 1 ? "Remove…" : "Remove \(ids.count) keywords…", role: .destructive) { selection = ids; confirmDelete = true }
        }
        .onDeleteCommand { if !selection.isEmpty { confirmDelete = true } }
        .copyable(selection.compactMap { id in rows.first { $0.id == id }?.text })
    }

    @TableColumnBuilder<KeywordRow, KeyPathComparator<KeywordRow>>
    private func columnsA(_ market: TrackedMarket) -> some TableColumnContent<KeywordRow, KeyPathComparator<KeywordRow>> {
            TableColumn("Keyword", value: \.text) { row in
                Text(row.text).lineLimit(1).truncationMode(.tail).textSelection(.enabled).help(row.text)
            }
            .width(min: 160, ideal: 260)

            TableColumn("Rank", value: \.rankSort) { row in
                if env.tracking.progress.isRunning, env.tracking.progress.currentKeyword == row.text {
                    ProgressView().controlSize(.small)
                } else {
                    RankLabel(outcome: row.outcome)
                        .help(row.outcome?.explanation ?? "Not measured yet.")
                }
            }
            .width(min: 56, ideal: 64)

            TableColumn("Δ") { row in
                DeltaLabel(delta: row.delta).help("Rank movement \(row.deltaAgainst). Change the reference with the Δ menu above the table.")
                    .help("Change versus the previous measurement from the same provider. Blank when not comparable.")
            }
            .width(min: 44, ideal: 52)

    }

    @TableColumnBuilder<KeywordRow, KeyPathComparator<KeywordRow>>
    private func columnsB(_ market: TrackedMarket) -> some TableColumnContent<KeywordRow, KeyPathComparator<KeywordRow>> {
            TableColumn("Popularity", value: \.popularitySort) { row in
                if env.research.loadingKeywordIDs.contains(row.id) {
                    ProgressView().controlSize(.small)
                } else {
                    PopularityCell(observation: row.popularity, adsConnected: env.adsState.isUsable)
                }
            }
            .width(min: 100, ideal: 170)

            TableColumn("Difficulty", value: \.difficultySort) { row in
                if let d = row.difficulty {
                    HStack(spacing: 6) {
                        Text("\(d.rounded)").monospacedDigit().fontWeight(.medium).foregroundStyle(ScoreBand.difficulty(d.score))
                        Text(d.tier).font(.caption).foregroundStyle(.secondary)
                    }
                    .help(Self.difficultyHelp(d))
                } else {
                    Text("—").foregroundStyle(.tertiary)
                }
            }
            .width(min: 90, ideal: 120)

            TableColumn("Opportunity") { row in
                if let o = row.opportunity {
                    HStack(spacing: 4) {
                        if (row.popularity?.value ?? 0) >= env.settings.goldenMinPopularity, (row.difficulty?.score ?? 100) <= Double(env.settings.goldenMaxDifficulty), (row.brandProbability ?? 0) < 0.5, !row.navigational {
                            if (row.fitProbability ?? 1) >= 0.5 {
                                Image(systemName: "star.fill").foregroundStyle(.yellow)
                            } else {
                                Image(systemName: "star.slash").foregroundStyle(.secondary)
                            }
                        }
                        Text("\(Int(o.rounded()))").monospacedDigit()
                        if let b = row.brandProbability, b >= 0.5 { Text("brand").font(.caption2).foregroundStyle(.orange) }
                        else if row.navigational { Text("brand · results").font(.caption2).foregroundStyle(.orange) }
                        else if let f = row.fitProbability, f < 0.5 { Text("unrelated").font(.caption2).foregroundStyle(.orange) }
                    }
                    .help("popularity × (1 − (difficulty/100)²). Filled star = golden for this app: popularity ≥ \(env.settings.goldenMinPopularity), difficulty ≤ \(env.settings.goldenMaxDifficulty), not a brand, and related to what the app does. Slashed star = the numbers pass but the term is unrelated to this app (Jev fit < 50%): a lead for a different app, not a keyword for this one.")
                } else {
                    Text("—").foregroundStyle(.tertiary)
                }
            }
            .width(min: 80, ideal: 100)

            TableColumn("Fit", value: \.fitSort) { row in
                if row.navigational {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle").foregroundStyle(Color.orange)
                        Text("brand · results").font(.caption)
                    }
                    .help("The search results say this is a name, not a need: the top result\(row.leaderName.map { " (\($0))" } ?? "") owns the term, or Jev, shown the top results, judged it navigational. Never golden and never used by the writer, whatever the word means.")
                } else if let f = row.fitProbability {
                    HStack(spacing: 4) {
                        Image(systemName: f >= 0.5 ? "checkmark.circle.fill" : "xmark.circle").foregroundStyle(f >= 0.5 ? Color.green : Color.orange)
                        Text(f >= 0.5 ? "related" : "unrelated").font(.caption)
                        Text("\(Int(f * 100))%").font(.caption).monospacedDigit().foregroundStyle(.secondary)
                    }
                    .help("Jev's probability that someone searching this term wants an app like this one, judged against the app's own App Store description. Below 50% the term cannot be golden for this app.")
                } else {
                    Text("—").foregroundStyle(.tertiary).help("Not checked yet. Needs an OpenRouter key (Connections); the check runs with the next popularity refresh.")
                }
            }
            .width(min: 90, ideal: 130)

    }

    @TableColumnBuilder<KeywordRow, KeyPathComparator<KeywordRow>>
    private func columnsC(_ market: TrackedMarket) -> some TableColumnContent<KeywordRow, KeyPathComparator<KeywordRow>> {
            TableColumn("Ads", value: \.adsSort) { row in
                if let a = row.ads {
                    HStack(spacing: 4) {
                        Text("\(a.impressions)").monospacedDigit()
                        Text("· \(a.taps) taps · \(a.installs) inst.").font(.caption).foregroundStyle(.secondary)
                    }
                    .help("Your own Apple Ads results for this exact keyword in this storefront over the synced window: \(a.impressions) impressions, \(a.taps) taps, \(a.installs) installs, spend \(String(format: "%.2f", a.spend)) \(a.currency). Impressions are the most reliable demand signal for terms Apple's index leaves at 5.")
                } else {
                    Text("—").foregroundStyle(.tertiary).help("No Apple Ads keyword for this term in this storefront in the synced window (Overview → Apple Ads → Sync).")
                }
            }
            .width(min: 110, ideal: 150)

            TableColumn("Rating mass", value: \.ratingMassSort) { row in
                if let s = row.signals, let m = s.medianRatingCountTop10 {
                    Text("\(s.ratingMassBand) · \(m.formatted(.number.notation(.compactName)))").monospacedDigit()
                        .help("Median rating count of the top 10 results (\(m.formatted())). A competition signal, not search volume.")
                } else {
                    Text("—").foregroundStyle(.tertiary)
                }
            }
            .width(min: 110, ideal: 150)

            TableColumn("Title match") { row in
                if let s = row.signals {
                    Text("\(s.titleMatchesTop10)/10").monospacedDigit()
                        .help("How many of the top 10 have the keyword in their name.")
                } else { Text("—").foregroundStyle(.tertiary) }
            }
            .width(min: 70, ideal: 90)

            TableColumn("Measured", value: \.lastMeasuredSort) { row in
                Text(row.lastMeasured?.relativeLabel ?? "never").foregroundStyle(.secondary)
            }
            .width(min: 90, ideal: 120)
    }

    /// ⌘C and the context menu put the selected keywords on the pasteboard, one per line.
    private func copyKeywords(_ ids: Set<PersistentIdentifier>) {
        let text = rows.filter { ids.contains($0.id) }.map(\.text).joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button { showAdd = true } label: { Label("Add", systemImage: "plus").labelStyle(.titleAndIcon) }
                .disabled(market == nil)
                .help("Add keywords to this market (⌘K)")
            Menu {
                let all = market.map { Set($0.keywords.map(\.persistentModelID)) } ?? []
                let busy = env.tracking.progress.isRunning || env.research.isLoadingPopularity
                Section("Ranks — public App Store search, ~3 s per keyword") {
                    Button("Measure all \(all.count) keywords   ⌘R") { if let market { measure(ids: all, market) } }
                        .disabled(all.isEmpty || busy)
                    Button((selection.isEmpty ? "Measure selected keywords" : "Measure \(selection.count) selected") + "   ⇧⌘R") { if let market { measure(ids: selection, market) } }
                        .disabled(selection.isEmpty || busy)
                }
                Section(env.adsState.isUsable ? "Popularity — Apple Ads, a few seconds" : "Popularity — connect Apple Ads first (Connections)") {
                    Button("Refresh popularity for all \(all.count)   ⇧⌘P") { refreshPopularity(all) }
                        .disabled(!env.adsState.isUsable || all.isEmpty || busy)
                    Button(selection.isEmpty ? "Refresh popularity for selected" : "Refresh popularity for \(selection.count) selected") { refreshPopularity(selection) }
                        .disabled(!env.adsState.isUsable || selection.isEmpty || busy)
                }
                Divider()
                Text("Measuring ranks also refreshes the popularity of the keywords it measured.")
            } label: {
                Label(env.tracking.progress.isRunning ? "Measuring…" : env.research.isLoadingPopularity ? "Refreshing…" : "Update", systemImage: "arrow.triangle.2.circlepath")
                    .labelStyle(.titleAndIcon)
            }
            .disabled(market == nil || market?.keywords.isEmpty == true)
            .help("Measure ranks or refresh popularity — for every keyword or only the selected ones")
            Button { export() } label: { Label("Export CSV", systemImage: "square.and.arrow.up") }
                .disabled(rows.isEmpty)
                .help("Save this market's keywords with ranks, popularity and difficulty as a CSV file (⇧⌘E)")
            Button { showInspector.toggle() } label: { Label("Inspector", systemImage: "sidebar.right") }
                .help("Show or hide the inspector (⌥⌘I)")
        }
    }

    @ViewBuilder
    private var progressBar: some View {
        let p = env.tracking.progress
        if p.isRunning {
            HStack(spacing: 12) {
                ProgressView(value: Double(p.completed), total: Double(max(p.total, 1)))
                    .frame(maxWidth: 240)
                Text("Measuring \(p.completed)/\(p.total) · \(p.currentKeyword)").font(.callout).lineLimit(1)
                if p.failures > 0 { Text("\(p.failures) failed").foregroundStyle(.orange).font(.callout) }
                Spacer()
                Button("Stop") { env.tracking.cancel() }
            }
            .padding(10)
            .background(.bar)
        } else if env.research.isLoadingPopularity {
            HStack(spacing: 12) {
                ProgressView().controlSize(.small)
                Text(env.research.popularityProgress ?? "Asking Apple Ads…").font(.callout)
                Spacer()
            }
            .padding(10)
            .background(.bar)
        } else if let message = env.research.lastPopularityMessage {
            HStack {
                InlineMessage(kind: .info, text: message)
                Button { env.research.clearPopularityMessage() } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.borderless).foregroundStyle(.secondary)
            }
            .padding(8)
            .background(.bar)
        }
    }

    static func difficultyHelp(_ d: DifficultyScore) -> String {
        """
        Difficulty \(d.rounded)/100 (\(d.tier)) — estimated from the top \(d.sampleSize) public results, not a probability of ranking.
        \(d.components.map { "\($0.name) \(Int($0.value.rounded()))" }.joined(separator: " · "))
        """
    }

    private var selectedTexts: [String] {
        (market?.keywords ?? []).filter { selection.contains($0.persistentModelID) }.map(\.text).sorted()
    }

    private var deleteTitle: String {
        let names = selectedTexts
        if names.count == 1 { return "Remove “\(names[0])”?" }
        return "Remove \(names.count) keywords?"
    }

    private var deleteMessage: String {
        let names = selectedTexts
        let list = names.count <= 8 ? names.joined(separator: ", ") : names.prefix(8).joined(separator: ", ") + " and \(names.count - 8) more"
        return "\(list)\n\nTheir rank history and popularity observations in \(market?.title ?? "this market") will be deleted too. This cannot be undone."
    }

    /// Popularity for the given keywords only (all layers: Apple lists, dashboard index, model estimate).
    private func refreshPopularity(_ ids: Set<PersistentIdentifier>) {
        guard let market, !ids.isEmpty else { return }
        Task { await env.research.refreshPopularity(for: market, only: ids, context: context) }
    }

    private func measure(ids: Set<PersistentIdentifier>, _ market: TrackedMarket) {
        let keywords = market.sortedKeywords.filter { ids.contains($0.persistentModelID) }
        // A release since the last look becomes a marker first, so this measurement lands on the right side of it.
        Task {
            if let app = market.app, let sf = market.storefront {
                await env.catalog.recordReleaseIfNew(app: app, storefront: sf, context: context)
                await env.catalog.recordReviews(app: app, storefronts: [sf], context: context)
            }
            env.tracking.measure(keywords, in: market, context: context)
        }
    }

    private func deleteSelected() {
        guard let market else { return }
        for k in market.keywords where selection.contains(k.persistentModelID) { context.delete(k) }
        selection.removeAll()
        try? context.save()
    }

    private func export() {
        var lines = ["keyword,storefront,device,rank,observed_count,delta,popularity_1_100,popularity_source,popularity_genre,fit_probability,difficulty,difficulty_tier,rating_mass_median_top10,title_matches_top10,measured_at,provider"]
        let country = market?.countryCode ?? ""
        let device = market?.device.rawValue ?? ""
        for r in rows {
            var fields: [String] = []
            fields.append(r.text)
            fields.append(country)
            fields.append(device)
            fields.append(r.measuredPosition.map(String.init) ?? "")
            fields.append(String(r.measuredCount))
            fields.append(r.delta.map(String.init) ?? "")
            fields.append(r.popularity?.displayValue.map(String.init) ?? "")
            fields.append(r.popularity.map { p in p.usesModelValue ? "model_6_29_rank" + (p.scope == "index" ? "_apple_index_5" : "") : p.isBound ? "below_published_range" + (p.upperBound.map { "_lt_\($0)" } ?? "") : (p.scope == "index" ? "apple_ads_dashboard_index" : p.scope == "estimate" ? "model_estimate" : p.scope == "global" ? "apple_ads_suggestion_relative" : "apple_ads_country_list") } ?? "unavailable")
            fields.append(r.popularity.map { $0.isBound ? "" : $0.genreRaw } ?? "")
            fields.append(r.fitProbability.map { String(format: "%.2f", $0) } ?? "")
            fields.append(r.difficulty.map { String($0.rounded) } ?? "")
            fields.append(r.difficulty?.tier ?? "")
            fields.append(r.signals?.medianRatingCountTop10.map(String.init) ?? "")
            fields.append(r.signals.map { String($0.titleMatchesTop10) } ?? "")
            fields.append(r.measuredAt?.ISO8601Format() ?? "")
            fields.append(r.measuredProvider)
            lines.append(fields.map(CSVDocument.escape).joined(separator: ","))
        }
        exportDocument = CSVDocument(text: lines.joined(separator: "\n"))
    }
}

struct PopularityCell: View {
    let observation: KeywordRow.Popularity?
    let adsConnected: Bool

    var body: some View {
        if let o = observation {
            if o.usesModelValue, let s = o.subFloor {
                HStack(spacing: 6) {
                    Text("\(s)").monospacedDigit().foregroundStyle(ScoreBand.popularity(s))
                    SourceBadge(origin: .derived, compact: true)
                    Text(o.scope == "index" ? "model · Apple 5" : "model").font(.caption).foregroundStyle(.tertiary)
                }
                .help("Model value \(s) on the 6–29 band Apple stopped publishing (since 29 Sep 2025 Apple reports 5 for every term below its published range\(o.scope == "index" ? "; the dashboard index for this term is 5" : "")). It is the term's demand rank among floor terms from public signals (autocomplete, search results, Jev): \(Int(Double(s - 6) / 23 * 100))% of floor terms rank below it. Values of 30 and above are Apple's own numbers.")
            } else if o.scope == "index", let v = o.value {
                HStack(spacing: 6) {
                    Text("\(v)").monospacedDigit().fontWeight(.medium).foregroundStyle(ScoreBand.popularity(v))
                    SourceBadge(origin: .officialObserved, compact: true)
                    Text("index").font(.caption).foregroundStyle(.secondary)
                }
                .help("Apple Ads dashboard popularity index for this exact term in \(o.countryCode): \(v)/100 (5 = below Apple's published range; Apple publishes nothing between 6 and 31). Read through your signed-in Apple Ads browser session; the endpoint is not part of the documented API.")
            } else if o.scope == "estimate" {
                HStack(spacing: 6) {
                    if let v = o.value {
                        Text("~\(v)").monospacedDigit().foregroundStyle(ScoreBand.popularity(v).opacity(0.85))
                    } else {
                        Text("< \(o.upperBound ?? 40)").monospacedDigit().foregroundStyle(.secondary)
                    }
                    Text("est.\(o.confidence.map { String(format: " %.0f%%", $0 * 100) } ?? "")").font(.caption).foregroundStyle(.tertiary)
                }
                .help(o.value == nil
                      ? "Model estimate: probably below Apple's published range (no number exists there — Apple's data has nothing between 6 and 34). The percentage is the model's confidence."
                      : "Model estimate from public signals (autocomplete, search results, Jev). Apple has no number for this term. The percentage is the probability that the term has published-range demand; the value is capped below Apple's list floor\(o.upperBound.map { " (< \($0))" } ?? "").")
            } else if o.scope == "global", let v = o.value {
                HStack(spacing: 6) {
                    Text("\(v)").monospacedDigit().foregroundStyle(.secondary)
                    Text("suggestion · relative").font(.caption).foregroundStyle(.tertiary)
                }
                .help("Older reading from Apple's keyword-suggestion endpoint. Those scores change with the seed term, so they are no longer collected. Refresh popularity to replace it.")
            } else if o.isBound {
                HStack(spacing: 6) {
                    Text(o.upperBound.map { "< \($0)" } ?? "< 50").monospacedDigit().foregroundStyle(.secondary)
                    Text("unlisted").font(.caption).foregroundStyle(.tertiary)
                }
                .help("Below Apple's published range. Apple's \(o.countryCode) lists cover roughly the top 500 terms per genre and this month stop at \(o.upperBound.map(String.init) ?? "about 50")/100; this term is on none of them (\(o.anyGenre ? "all 15 genres checked" : o.genreRaw)). Sign in to the Apple Ads dashboard in Connections to get the exact 5–100 index for such terms.")
            } else if let v = o.value {
                HStack(spacing: 6) {
                    Text("\(v)").monospacedDigit().fontWeight(.medium).foregroundStyle(ScoreBand.popularity(v))
                    SourceBadge(origin: .officialObserved, compact: true)
                    Text(AppleAdsGenre(rawValue: o.genreRaw)?.displayName ?? o.genreRaw)
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.tail)
                }
                .help("Apple Ads search popularity \(v)/100, relative within \(o.countryCode), from the \(AppleAdsGenre(rawValue: o.genreRaw)?.displayName ?? o.genreRaw) list for \(o.periodStart.formatted(.dateTime.month(.wide).year())). Rank in that list: \(o.rankInGenre.map(String.init) ?? "—").")
            } else {
                Text("—").foregroundStyle(.tertiary)
            }
        } else {
            Text(adsConnected ? "not fetched" : "not connected")
                .foregroundStyle(.tertiary)
                .help(adsConnected ? "Press Popularity in the toolbar (it also runs automatically after each measurement)." : "Connect Apple Ads (sidebar → Connections) to fetch official popularity.")
        }
    }
}

/// Numeric filters for the keyword table.
nonisolated struct KeywordFilters: Equatable, Sendable {
    var minPopularity: Double = 0
    var maxDifficulty: Double = 100
    var onlyFound = false
    var onlyListed = false
    var excludeBrands = false
    var hideUnrelated = false

    var activeCount: Int {
        (minPopularity > 0 ? 1 : 0) + (maxDifficulty < 100 ? 1 : 0) + (onlyFound ? 1 : 0) + (onlyListed ? 1 : 0) + (excludeBrands ? 1 : 0) + (hideUnrelated ? 1 : 0)
    }

    func allows(_ row: KeywordRow) -> Bool {
        if excludeBrands, (row.brandProbability ?? 0) >= 0.5 || row.navigational { return false }
        if hideUnrelated, let f = row.fitProbability, f < 0.5 { return false }
        if onlyFound, row.measuredPosition == nil { return false }
        if onlyListed, !(row.popularity.map { ($0.scope == "country" || $0.scope == "index") && $0.value != nil } ?? false) { return false }
        if minPopularity > 0 {
            guard let v = row.popularity?.displayValue, Double(v) >= minPopularity else { return false }
        }
        if maxDifficulty < 100 {
            guard let d = row.difficulty, d.score <= maxDifficulty else { return false }
        }
        return true
    }
}

struct KeywordFiltersPopover: View {
    @Binding var filters: KeywordFilters
    let depth: Int
    var goldenMinPopularity = 40
    var goldenMaxDifficulty = 45

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Filters").font(.headline)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Popularity at least")
                    Spacer()
                    Text(filters.minPopularity == 0 ? "any" : "\(Int(filters.minPopularity))").monospacedDigit().foregroundStyle(.secondary)
                }
                Slider(value: $filters.minPopularity, in: 0...100, step: 5)
                Text("Rows with only an upper bound (\"< 50\") are hidden once a minimum is set.").font(.caption2).foregroundStyle(.tertiary)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Difficulty at most")
                    Spacer()
                    Text(filters.maxDifficulty == 100 ? "any" : "\(Int(filters.maxDifficulty))").monospacedDigit().foregroundStyle(.secondary)
                }
                Slider(value: $filters.maxDifficulty, in: 0...100, step: 5)
            }
            Toggle("Only keywords found in the top \(depth)", isOn: $filters.onlyFound)
            Toggle("Only keywords with an exact Apple score", isOn: $filters.onlyListed)
            Toggle("Hide other brands' names (Jev brand ≥ 50%)", isOn: $filters.excludeBrands)
            Toggle("Hide terms unrelated to this app (Jev fit < 50%)", isOn: $filters.hideUnrelated)
            HStack {
                Button {
                    filters = KeywordFilters(minPopularity: Double(goldenMinPopularity), maxDifficulty: Double(goldenMaxDifficulty), onlyFound: false, onlyListed: false, excludeBrands: true, hideUnrelated: true)
                } label: { Label("Golden (pop ≥\(goldenMinPopularity) · diff ≤\(goldenMaxDifficulty) · no brands · related)", systemImage: "star.fill") }
                Spacer()
                Button("Reset") { filters = KeywordFilters() }.disabled(filters.activeCount == 0)
            }
        }
        .padding(16)
        .frame(width: 340)
    }
}

struct CSVDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.commaSeparatedText]
    var text: String

    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws {
        text = String(decoding: configuration.file.regularFileContents ?? Data(), as: UTF8.self)
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }

    static func escape(_ s: String) -> String {
        if s.contains(",") || s.contains("\"") || s.contains("\n") {
            return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return s
    }
}
