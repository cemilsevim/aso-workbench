import SwiftUI
import SwiftData
import AppKit
import ASOCore

nonisolated struct IdeaRow: Identifiable, Sendable {
    let id: PersistentIdentifier
    let term: String
    let genre: String
    let popularity: Int
    let difficulty: Double?
    let difficultySort: Double
    let tier: String
    let opportunity: Double?
    let opportunitySort: Double
    let leader: String
    let leaderRatings: Int?
    let titleMatches: Int?
    let brand: Double?
    let appable: Double?
    let measuredAt: Date?
    let isGap: Bool
    let excluded: String?

    init(_ c: IdeaCandidate, maxDifficulty: Int) {
        id = c.persistentModelID
        term = c.term
        genre = AppleAdsGenre(rawValue: c.genreRaw)?.displayName ?? c.genreRaw
        popularity = c.popularity
        difficulty = c.difficulty
        difficultySort = c.difficulty ?? 101
        tier = c.difficulty.map { DifficultyScore.tier(for: $0) } ?? ""
        opportunity = c.opportunity
        opportunitySort = c.opportunity ?? -1
        leader = c.leaderName ?? ""
        leaderRatings = c.leaderRatings
        titleMatches = c.titleMatches
        brand = c.brand
        appable = c.appable
        measuredAt = c.measuredAt
        isGap = c.isGap(maxDifficulty: maxDifficulty)
        if c.wantsFree { excluded = "wants free" }
        else if let b = c.brand, b >= 0.5 { excluded = "brand" }
        else if c.leaderOwnsTerm == true { excluded = "brand · top result owns the name" }
        else if let n = c.navigational, n >= 0.6 { excluded = "looking for one app" }
        else if c.nameCrowd == true { excluded = "a name, not a need" }
        else if let n = c.natural, n < 0.5 { excluded = "not a search" }
        else if let a = c.appable, a < 0.5 { excluded = "not an app" }
        else { excluded = nil }
    }
}

/// Market gaps across the whole store: high Apple popularity, weak results, app-able, independent of any tracked app.
struct IdeasView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.modelContext) private var context
    @Query(sort: \IdeaCandidate.popularity, order: .reverse) private var candidates: [IdeaCandidate]

    @AppStorage("ideas.country") private var country = "US"
    @AppStorage("ideas.genre") private var genreRaw = ""
    @AppStorage("ideas.budget") private var budget = 50
    @AppStorage("ideas.minPopularity") private var minPopularity = 40
    @AppStorage("ideas.maxDifficulty") private var maxDifficulty = 35
    @AppStorage("ideas.gapsOnly") private var gapsOnly = false
    @AppStorage("ideas.measuredOnly") private var measuredOnly = true
    @State private var selection = Set<PersistentIdentifier>()
    @State private var sortOrder = [KeyPathComparator(\IdeaRow.difficultySort, order: .forward)]
    @State private var filterText = ""

    private var rows: [IdeaRow] {
        var out = candidates.filter { $0.countryCode == country }.map { IdeaRow($0, maxDifficulty: maxDifficulty) }
        if measuredOnly { out = out.filter { $0.measuredAt != nil } }
        if gapsOnly { out = out.filter(\.isGap) }
        if !filterText.isEmpty { out = out.filter { $0.term.localizedCaseInsensitiveContains(filterText) } }
        return out.sorted(using: sortOrder)
    }

    private var countryCount: Int { candidates.filter { $0.countryCode == country }.count }

    var body: some View {
        VStack(spacing: 0) {
            controls
            Divider()
            table
            Divider()
            footer
        }
        .navigationTitle("App ideas")
        .navigationSubtitle("Demand Apple publishes, results nobody owns")
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Picker("Storefront", selection: $country) {
                    ForEach(StorefrontRegistry.sortedByName, id: \.countryCode) { Text("\($0.name) (\($0.countryCode))").tag($0.countryCode) }
                }
                .frame(maxWidth: 220)
                Picker("Genre", selection: $genreRaw) {
                    Text("All 15 genres").tag("")
                    ForEach(AppleAdsGenre.allCases, id: \.rawValue) { Text($0.displayName).tag($0.rawValue) }
                }
                .frame(maxWidth: 260)
                Picker("Measure", selection: $budget) {
                    Text("20 terms (~1 min)").tag(20)
                    Text("50 terms (~3 min)").tag(50)
                    Text("100 terms (~5 min)").tag(100)
                    Text("200 terms (~10 min)").tag(200)
                }
                .frame(maxWidth: 220)
                Picker("Min popularity", selection: $minPopularity) {
                    ForEach([30, 40, 50, 60], id: \.self) { Text("≥ \($0)").tag($0) }
                }
                .frame(maxWidth: 170)
                Picker("Gap difficulty", selection: $maxDifficulty) {
                    ForEach([25, 35, 45], id: \.self) { Text("≤ \($0)").tag($0) }
                }
                .frame(maxWidth: 170)
                Spacer()
                if env.ideas.progress.isRunning {
                    Button("Stop") { env.ideas.cancel() }
                } else {
                    Button {
                        let genres = genreRaw.isEmpty ? AppleAdsGenre.allCases : [AppleAdsGenre(rawValue: genreRaw)].compactMap { $0 }
                        env.ideas.scan(country: country, genres: genres, budget: budget, minPopularity: minPopularity, maxDifficulty: maxDifficulty, context: context)
                    } label: { Label("Scan", systemImage: "lightbulb") }
                    .buttonStyle(.borderedProminent)
                }
            }
            HStack(spacing: 12) {
                Toggle("Gaps only (difficulty ≤ \(maxDifficulty))", isOn: $gapsOnly).toggleStyle(.checkbox)
                Toggle("Measured only", isOn: $measuredOnly).toggleStyle(.checkbox)
                TextField("Filter terms", text: $filterText).textFieldStyle(.roundedBorder).frame(maxWidth: 220)
                Spacer()
                if env.ideas.progress.isRunning {
                    ProgressView().controlSize(.small)
                    Text("\(env.ideas.progress.step)\(env.ideas.progress.total > 0 ? " · \(env.ideas.progress.completed)/\(env.ideas.progress.total)" : "")")
                        .font(.callout).foregroundStyle(.secondary).lineLimit(1)
                } else {
                    Text("\(rows.count) shown · \(countryCount) published terms stored for \(country)").font(.callout).foregroundStyle(.secondary)
                }
            }
            Text("Every term here has an Apple popularity value (genre lists, last month). Scans measure the long tail first, specific multi-word needs in the 40–60 band, because one-word head terms are always owned by big apps. Jev drops brands, non-searches and things no app can be; the results drop navigational names (top app owns the name) and crowded names. A gap = real demand, an app-shaped need, weak results. ~3 s per measured term; each scan continues where the last stopped.")
                .font(.caption).foregroundStyle(.tertiary)
        }
        .padding(12)
    }

    private var table: some View {
        Table(rows, selection: $selection, sortOrder: $sortOrder) {
            columnsA
            columnsB
        }
        .contextMenu(forSelectionType: PersistentIdentifier.self) { ids in
            Button("Copy term\(ids.count > 1 ? "s" : "")") { copy(ids) }
        }
        .copyable(selection.compactMap { id in rows.first { $0.id == id }?.term })
    }

    @TableColumnBuilder<IdeaRow, KeyPathComparator<IdeaRow>>
    private var columnsA: some TableColumnContent<IdeaRow, KeyPathComparator<IdeaRow>> {
            TableColumn("Term", value: \.term) { row in
                HStack(spacing: 6) {
                    if row.isGap { Image(systemName: "star.fill").foregroundStyle(.yellow) }
                    Text(row.term).lineLimit(1).truncationMode(.tail).textSelection(.enabled).help(row.term)
                    if let e = row.excluded { Text(e).font(.caption2).foregroundStyle(.orange) }
                }
            }
            .width(min: 180, ideal: 260)
            TableColumn("Genre", value: \.genre) { row in Text(row.genre).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
                .width(min: 110, ideal: 150)
            TableColumn("Popularity", value: \.popularity) { row in
                HStack(spacing: 6) {
                    Text("\(row.popularity)").monospacedDigit().fontWeight(.medium).foregroundStyle(ScoreBand.popularity(row.popularity))
                    SourceBadge(origin: .officialObserved, compact: true)
                }
            }
            .width(min: 90, ideal: 110)
            TableColumn("Difficulty", value: \.difficultySort) { row in
                if let d = row.difficulty {
                    HStack(spacing: 6) { Text("\(Int(d.rounded()))").monospacedDigit().foregroundStyle(ScoreBand.difficulty(d)); Text(row.tier).font(.caption).foregroundStyle(.secondary) }
                } else { Text("not measured").font(.caption).foregroundStyle(.tertiary) }
            }
            .width(min: 110, ideal: 130)
            TableColumn("Opportunity", value: \.opportunitySort) { row in
                if let o = row.opportunity { Text("\(Int(o.rounded()))").monospacedDigit() } else { Text("—").foregroundStyle(.tertiary) }
            }
            .width(min: 80, ideal: 95)
    }

    @TableColumnBuilder<IdeaRow, KeyPathComparator<IdeaRow>>
    private var columnsB: some TableColumnContent<IdeaRow, KeyPathComparator<IdeaRow>> {
            TableColumn("Top result") { row in
                if row.leader.isEmpty { Text("—").foregroundStyle(.tertiary) } else {
                    HStack(spacing: 6) {
                        Text(row.leader).lineLimit(1).truncationMode(.tail)
                        if let r = row.leaderRatings { Text(r.formatted(.number.notation(.compactName))).font(.caption).monospacedDigit().foregroundStyle(.secondary) }
                    }
                    .help("\(row.leader) · \(row.leaderRatings ?? 0) ratings")
                }
            }
            .width(min: 160, ideal: 220)
            TableColumn("Title match") { row in
                if let t = row.titleMatches { Text("\(t)/10").monospacedDigit().foregroundStyle(t <= 3 ? Color.green : Color.primary) } else { Text("—").foregroundStyle(.tertiary) }
            }
            .width(min: 80, ideal: 90)
            TableColumn("App-able") { row in
                if let a = row.appable { Text("\(Int(a * 100))%").monospacedDigit().foregroundStyle(a >= 0.5 ? Color.primary : Color.orange) } else { Text("—").foregroundStyle(.tertiary) }
            }
            .width(min: 70, ideal: 80)
            TableColumn("Measured") { row in
                Text(row.measuredAt.map { $0.formatted(.relative(presentation: .named)) } ?? "—").font(.caption).foregroundStyle(.secondary)
            }
            .width(min: 90, ideal: 120)
    }

    private var footer: some View {
        HStack {
            if let m = env.ideas.lastMessage { Text(m).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
            Spacer()
            Button("Export CSV") { exportCSV() }.disabled(rows.isEmpty)
        }
        .padding(10)
    }

    private func copy(_ ids: Set<PersistentIdentifier>) {
        let text = rows.filter { ids.contains($0.id) }.map(\.term).joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func exportCSV() {
        var lines = ["term,storefront,genre,popularity_1_100,difficulty,difficulty_tier,opportunity,top_result,top_result_ratings,title_matches_top10,brand_probability,appable_probability,gap,measured_at"]
        let f = ISO8601DateFormatter()
        for r in rows {
            let cells: [String] = [r.term, country, r.genre, String(r.popularity), r.difficulty.map { String(Int($0.rounded())) } ?? "", r.tier, r.opportunity.map { String(Int($0.rounded())) } ?? "",
                                   r.leader, r.leaderRatings.map(String.init) ?? "", r.titleMatches.map(String.init) ?? "", r.brand.map { String(format: "%.2f", $0) } ?? "",
                                   r.appable.map { String(format: "%.2f", $0) } ?? "", r.isGap ? "1" : "0", r.measuredAt.map { f.string(from: $0) } ?? ""]
            lines.append(cells.map { "\"" + $0.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }.joined(separator: ","))
        }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "app-ideas-\(country).csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        if panel.runModal() == .OK, let url = panel.url { try? lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8) }
    }
}
