import SwiftUI
import SwiftData
import ASOCore

/// Shared sheet for "Import keywords from a competitor" and "Find golden keywords".
struct KeywordDiscoverySheet: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let app: TrackedApp
    let market: TrackedMarket
    /// When set, the competitor's listing text is mined; otherwise only the seeds are expanded.
    let competitor: SearchResultApp?
    let seeds: [String]

    @State private var candidates: [KeywordDiscovery.Candidate] = []
    @State private var selected = Set<String>()
    @State private var ran = false
    @State private var onlyGolden = false
    @State private var difficultyLimit = 25

    private var title: String { competitor.map { "Import keywords from \($0.name)" } ?? "Find golden keywords" }
    private var shown: [KeywordDiscovery.Candidate] {
        onlyGolden ? candidates.filter { $0.golden(minPopularity: env.settings.goldenMinPopularity, maxDifficulty: env.settings.goldenMaxDifficulty) } : candidates
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            Text(competitor == nil
                 ? "Seeds: \(seeds.prefix(8).joined(separator: ", "))\(seeds.count > 8 ? " …" : ""). Each seed is expanded with App Store autocomplete and Apple Ads suggestions; candidates get Apple popularity (country lists, then the dashboard index), Jev filters out other brands and unnatural phrases, and the most promising ones are measured for difficulty."
                 : "Words and two-word phrases from the competitor's title and description, plus autocomplete and Apple Ads suggestions around its title words. Then popularity, Jev filtering and difficulty as in Research.")
                .font(.callout).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Stepper("Measure difficulty for top \(difficultyLimit) (3 s each)", value: $difficultyLimit, in: 5...60, step: 5).font(.callout)
                Button(ran ? "Run again" : "Discover") { Task { await run() } }
                    .disabled(env.discovery.progress.isRunning)
                    .keyboardShortcut(.defaultAction)
                if env.discovery.progress.isRunning {
                    ProgressView().controlSize(.small)
                    Text("\(env.discovery.progress.step) \(env.discovery.progress.total > 0 ? "\(env.discovery.progress.completed)/\(env.discovery.progress.total)" : "")").font(.callout).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Toggle("Golden only", isOn: $onlyGolden).toggleStyle(.checkbox)
                Text("golden = popularity ≥ \(env.settings.goldenMinPopularity) · difficulty ≤ \(env.settings.goldenMaxDifficulty) · not another brand · related to this app").font(.caption).foregroundStyle(.tertiary)
            }
            if let m = env.discovery.lastMessage, ran { Text(m).font(.caption).foregroundStyle(.secondary) }
            Table(shown, selection: $selected) {
                TableColumn("Keyword") { c in
                    HStack(spacing: 6) {
                        if c.golden(minPopularity: env.settings.goldenMinPopularity, maxDifficulty: env.settings.goldenMaxDifficulty) { Image(systemName: "star.fill").foregroundStyle(.yellow) }
                        else if c.goldenLead(minPopularity: env.settings.goldenMinPopularity, maxDifficulty: env.settings.goldenMaxDifficulty) {
                            Image(systemName: "star.slash").foregroundStyle(.secondary).help("The numbers pass but the term is unrelated to this app (Jev fit \(Int((c.jevFit ?? 0) * 100))%): a lead for another app.")
                        }
                        Text(c.term)
                        if let f = c.jevFit, f < 0.5 { Text("unrelated").font(.caption2).foregroundStyle(.orange) }
                        if c.alreadyTracked { Text("tracked").font(.caption2).foregroundStyle(.tertiary) }
                    }
                }
                .width(min: 180, ideal: 240)
                TableColumn("Popularity") { c in
                    if let p = c.popularity {
                        HStack(spacing: 6) {
                            Text("\(p)").monospacedDigit().fontWeight(.medium).foregroundStyle(ScoreBand.popularity(p))
                            Text(c.popularityScope == "index" ? "index" : (c.genre ?? "list")).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    } else {
                        Text("< \(c.upperBound ?? 40)").foregroundStyle(.secondary).monospacedDigit()
                    }
                }
                .width(min: 100, ideal: 150)
                TableColumn("Opportunity") { c in
                    if let o = c.opportunity { Text("\(Int(o.rounded()))").monospacedDigit() } else { Text("—").foregroundStyle(.tertiary) }
                }
                .width(min: 80, ideal: 90)
                TableColumn("Difficulty") { c in
                    if let d = c.difficulty {
                        HStack(spacing: 6) { Text("\(d.rounded)").monospacedDigit().foregroundStyle(ScoreBand.difficulty(d.score)); Text(d.tier).font(.caption).foregroundStyle(.secondary) }
                    } else { Text("—").foregroundStyle(.tertiary) }
                }
                .width(min: 90, ideal: 110)
                TableColumn("Jev") { c in
                    if let b = c.jevBrand, let n = c.jevNatural {
                        Text("\(c.jevIntent ?? "") · brand \(Int(b * 100))% · natural \(Int(n * 100))%").font(.caption).foregroundStyle(b >= 0.7 || n < 0.4 ? .orange : .secondary).lineLimit(1)
                    } else { Text("—").foregroundStyle(.tertiary) }
                }
                .width(min: 150, ideal: 220)
                TableColumn("Source") { c in Text(c.sources.sorted().joined(separator: ", ")).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
            }
            .frame(minHeight: 320)
            HStack {
                Text(selected.isEmpty ? "Select keywords to track" : "\(selected.count) selected").font(.callout).foregroundStyle(.secondary)
                Spacer()
                Button("Select golden") { selected = Set(candidates.filter { $0.golden(minPopularity: env.settings.goldenMinPopularity, maxDifficulty: env.settings.goldenMaxDifficulty) && !$0.alreadyTracked }.map(\.id)) }
                    .disabled(candidates.isEmpty)
                Button("Track selected in \(market.title)") {
                    let terms = candidates.filter { selected.contains($0.id) && !$0.alreadyTracked }.map(\.term)
                    env.catalog.addKeywords(terms.joined(separator: "\n"), to: market, context: context)
                    if let added = Optional(market.sortedKeywords.filter { terms.contains($0.normalized) }), !added.isEmpty {
                        env.tracking.measure(added, in: market, context: context)
                    }
                    dismiss()
                }
                .disabled(selected.isEmpty)
            }
        }
        .padding(16)
        .frame(width: 900, height: 640)
    }

    private func run() async {
        candidates = await env.discovery.discover(competitor: competitor, seeds: seeds, app: app, market: market, hintSeedLimit: 8, difficultyLimit: difficultyLimit)
        ran = true
    }
}
