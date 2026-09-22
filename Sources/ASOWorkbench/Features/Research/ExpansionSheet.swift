import SwiftUI
import SwiftData
import AppKit
import ASOCore

/// "Try my keywords in other countries": pick storefronts and keywords, measure everything, track the winners.
struct ExpansionSheet: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let app: TrackedApp
    let market: TrackedMarket

    @State private var countries: Set<String> = []
    @State private var terms: Set<String> = []
    @State private var selection = Set<String>()
    @State private var sortOrder = [KeyPathComparator(\MarketExpansion.Row.opportunitySort, order: .reverse)]
    @State private var candidatesOnly = false
    @State private var tracked = 0
    @AppStorage("expansion.autoTrack") private var autoTrack = true
    @AppStorage("expansion.localize") private var localize = true

    private var shownRows: [MarketExpansion.Row] {
        let base = candidatesOnly ? env.expansion.rows.filter(\.isCandidate) : env.expansion.rows
        return base.sorted(using: sortOrder)
    }
    private var trackedTerms: [String] { market.sortedKeywords.map(\.text) }
    private var estimateMinutes: Int { max(1, Int((Double(countries.count * terms.count) * (env.settings.pacingSeconds + 0.6)) / 60)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Try \(app.name)'s keywords in other countries").font(.title3.weight(.semibold))
                    Text("Same words, other storefronts: rank, Apple popularity, difficulty and whether people there search in that language. Track the cells that work with one click.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Close") { dismiss() }
            }
            HStack(alignment: .top, spacing: 16) {
                GroupBox("Storefronts (\(countries.count))") {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), alignment: .leading)], alignment: .leading, spacing: 4) {
                            ForEach(StorefrontRegistry.sortedByName.filter { $0.countryCode != market.countryCode }, id: \.countryCode) { sf in
                                Toggle("\(sf.name) (\(sf.countryCode))", isOn: Binding(get: { countries.contains(sf.countryCode) }, set: { if $0 { countries.insert(sf.countryCode) } else { countries.remove(sf.countryCode) } }))
                                    .toggleStyle(.checkbox).font(.callout)
                            }
                        }
                    }
                    .frame(height: 150)
                }
                GroupBox("Keywords (\(terms.count) of \(trackedTerms.count))") {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Button("All") { terms = Set(trackedTerms) }
                            Button("None") { terms = [] }
                            Button("Best 10") { terms = Set(market.sortedKeywords.sorted { ($0.opportunity ?? 0) > ($1.opportunity ?? 0) }.prefix(10).map(\.text)) }
                        }
                        .controlSize(.small)
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), alignment: .leading)], alignment: .leading, spacing: 4) {
                                ForEach(trackedTerms, id: \.self) { t in
                                    Toggle(t, isOn: Binding(get: { terms.contains(t) }, set: { if $0 { terms.insert(t) } else { terms.remove(t) } }))
                                        .toggleStyle(.checkbox).font(.callout)
                                }
                            }
                        }
                        .frame(height: 118)
                    }
                }
            }
            HStack(spacing: 12) {
                if env.expansion.progress.isRunning {
                    Button("Stop") { env.expansion.cancel() }
                    ProgressView(value: Double(env.expansion.progress.completed), total: Double(max(1, env.expansion.progress.total))).frame(width: 160)
                    Text("\(env.expansion.progress.step) · \(env.expansion.progress.completed)/\(env.expansion.progress.total)").font(.callout).foregroundStyle(.secondary).lineLimit(1)
                } else {
                    Button {
                        env.expansion.clear()
                        env.expansion.run(app: app, terms: trackedTerms.filter { terms.contains($0) }, countries: Array(countries).sorted(), device: market.device,
                                          autoTrack: autoTrack, sourceMarket: market, catalog: env.catalog, context: context, localize: localize)
                    } label: { Label("Measure \(countries.count * terms.count) cells (~\(estimateMinutes) min)", systemImage: "globe") }
                    .buttonStyle(.borderedProminent)
                    .disabled(countries.isEmpty || terms.isEmpty)
                }
                Toggle("Candidates only", isOn: $candidatesOnly).toggleStyle(.checkbox)
                Toggle("Track every measured keyword (saves rank, popularity, difficulty)", isOn: $autoTrack).toggleStyle(.checkbox)
                    .disabled(env.expansion.progress.isRunning)
                Toggle("Add local-language forms (AI proposes how locals search it, measurements decide)", isOn: $localize).toggleStyle(.checkbox)
                    .disabled(env.expansion.progress.isRunning || !env.openRouterState.isUsable)
                    .help("For storefronts in another language, Claude proposes 1–3 local search phrasings per keyword with the app's description as context, then every candidate is measured like the originals. About $0.01 per storefront.")
                Spacer()
                if let m = env.expansion.lastMessage { Text(m).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
            }
            table
            HStack {
                Button("Track selected in their storefronts") { trackSelected() }.disabled(selection.isEmpty || autoTrack)
                    .help(autoTrack ? "Every measured cell is already tracked" : "")
                if tracked > 0 { Text("\(tracked) keyword(s) tracked · measure them from Keywords").font(.caption).foregroundStyle(.secondary) }
                Spacer()
                Button("Export CSV") { exportCSV() }.disabled(env.expansion.rows.isEmpty)
            }
        }
        .padding(16)
        .frame(minWidth: 1100, minHeight: 700)
        .onAppear {
            if countries.isEmpty { countries = Set(["GB", "DE", "FR", "ES", "IT", "BR", "JP", "KR"].filter { $0 != market.countryCode }) }
            if terms.isEmpty { terms = Set(trackedTerms.prefix(20)) }
        }
    }

    private var table: some View {
        Table(shownRows, selection: $selection, sortOrder: $sortOrder) {
            columnsA
            columnsB
        }
        .contextMenu(forSelectionType: String.self) { ids in
            Button("Copy keyword\(ids.count > 1 ? "s" : "")") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(shownRows.filter { ids.contains($0.id) }.map(\.term).joined(separator: "\n"), forType: .string)
            }
        }
    }

    @TableColumnBuilder<MarketExpansion.Row, KeyPathComparator<MarketExpansion.Row>>
    private var columnsA: some TableColumnContent<MarketExpansion.Row, KeyPathComparator<MarketExpansion.Row>> {
            TableColumn("Storefront", value: \.country) { r in Text("\(StorefrontRegistry.lookup(r.country)?.name ?? r.country) (\(r.country))").lineLimit(1) }
                .width(min: 120, ideal: 150)
            TableColumn("Keyword", value: \.term) { r in
                HStack(spacing: 6) {
                    if r.isCandidate { Image(systemName: "star.fill").foregroundStyle(.yellow) }
                    Text(r.term).lineLimit(1).textSelection(.enabled).help(r.meaning.map { "\(r.term) — \($0)" } ?? r.term)
                    if let src = r.sourceTerm { Text("← \(src)").font(.caption2).foregroundStyle(.purple).lineLimit(1) }
                    if r.tracked { Text("tracked").font(.caption2).foregroundStyle(.tertiary) }
                }
            }
            .width(min: 160, ideal: 220)
            TableColumn("Rank") { r in
                if r.failed { Text("failed").foregroundStyle(.red) }
                else if let k = r.rank { Text("#\(k)").monospacedDigit().foregroundStyle(k <= 10 ? Color.green : Color.primary) }
                else if r.observed == 0 { Text("no results").font(.caption).foregroundStyle(.secondary).help("Apple returned no apps for this phrase: nobody has claimed it, but check that people actually search it") }
                else { Text("> \(r.observed)").foregroundStyle(.secondary).monospacedDigit() }
            }
            .width(min: 70, ideal: 80)
            TableColumn("Popularity") { r in
                if let p = r.popularity {
                    HStack(spacing: 6) {
                        Text("\(p)").monospacedDigit().fontWeight(.medium).foregroundStyle(ScoreBand.popularity(p))
                        SourceBadge(origin: (r.popularityScope == "estimate" || r.popularityScope == "model") ? .derived : .officialObserved, compact: true)
                        Text(r.popularityScope == "model" ? "model · Apple 5" : (r.popularityScope ?? "")).font(.caption).foregroundStyle(.secondary)
                    }
                    .help(r.popularityScope == "model" ? "Apple's dashboard index is 5 (below its published range). The model's 6–29 value is the term's demand rank among floor terms in this storefront; 30 and above are Apple's own numbers." : "")
                } else if r.popularityScope == "below" { Text("< 30").foregroundStyle(.secondary).monospacedDigit() }
                else { Text("—").foregroundStyle(.tertiary) }
            }
            .width(min: 110, ideal: 130)
    }

    @TableColumnBuilder<MarketExpansion.Row, KeyPathComparator<MarketExpansion.Row>>
    private var columnsB: some TableColumnContent<MarketExpansion.Row, KeyPathComparator<MarketExpansion.Row>> {
            TableColumn("Difficulty") { r in
                if let d = r.difficulty { HStack(spacing: 6) { Text("\(Int(d.rounded()))").monospacedDigit().foregroundStyle(ScoreBand.difficulty(d)); Text(DifficultyScore.tier(for: d)).font(.caption).foregroundStyle(.secondary) } }
                else { Text("—").foregroundStyle(.tertiary) }
            }
            .width(min: 100, ideal: 120)
            TableColumn("Opportunity", value: \.opportunitySort) { r in
                if let o = r.opportunity { Text("\(Int(o.rounded()))").monospacedDigit() } else { Text("—").foregroundStyle(.tertiary) }
            }
            .width(min: 80, ideal: 90)
            TableColumn("Language") { r in languageCell(r.languageFit) }
            .width(min: 130, ideal: 160)
            TableColumn("Top result") { r in leaderCell(r) }
            .width(min: 150, ideal: 200)
    }

    @ViewBuilder
    private func languageCell(_ l: Double?) -> some View {
        if let l {
            let pct = Int(l * 100)
            Text(l >= 0.4 ? "searched there · \(pct)%" : "rarely searched · \(pct)%").font(.caption).foregroundStyle(l >= 0.4 ? Color.secondary : Color.orange)
        } else {
            Text("—").foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private func leaderCell(_ r: MarketExpansion.Row) -> some View {
        HStack(spacing: 6) {
            Text(r.leader ?? "—").lineLimit(1)
            if let n = r.leaderRatings { Text(n.formatted(.number.notation(.compactName))).font(.caption).monospacedDigit().foregroundStyle(.secondary) }
        }
    }

    private func trackSelected() {
        let picked = shownRows.filter { selection.contains($0.id) }
        var count = 0
        for row in picked {
            guard let sf = StorefrontRegistry.lookup(row.country) else { continue }
            if app.markets.first(where: { $0.countryCode == row.country }) == nil {
                env.catalog.addMarket(to: app, storefront: sf, device: market.device, context: context)
            }
            guard let target = app.markets.first(where: { $0.countryCode == row.country }) else { continue }
            count += env.catalog.addKeywords(row.term, to: target, context: context)
        }
        try? context.save()
        tracked += count
    }

    private func exportCSV() {
        var lines = ["storefront,keyword,from_keyword,meaning,rank,observed_count,popularity_1_100,popularity_source,difficulty,opportunity,language_fit,top_result,top_result_ratings,candidate"]
        for r in env.expansion.rows {
            let cells: [String] = [r.country, r.term, r.sourceTerm ?? "", r.meaning ?? "", r.rank.map(String.init) ?? "", String(r.observed), r.popularity.map(String.init) ?? "", r.popularityScope ?? "",
                         r.difficulty.map { String(Int($0.rounded())) } ?? "", r.opportunity.map { String(Int($0.rounded())) } ?? "", r.languageFit.map { String(format: "%.2f", $0) } ?? "",
                         r.leader ?? "", r.leaderRatings.map(String.init) ?? "", r.isCandidate ? "1" : "0"]
            lines.append(cells.map { "\"" + $0.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }.joined(separator: ","))
        }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(app.name)-countries.csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        if panel.runModal() == .OK, let url = panel.url { try? lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8) }
    }
}
