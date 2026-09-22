import SwiftUI
import SwiftData
import ASOCore

/// Competitors as observed in *our tracked queries*. Deliberately not "all keywords of app X".
struct CompetitorsView: View {
    @Environment(AppEnvironment.self) private var env
    let app: TrackedApp
    let market: TrackedMarket?

    @State private var depth = 10
    @State private var selection: Int?
    @State private var importTarget: SearchResultApp?

    private var samples: [RankSample] {
        guard let market, let sf = market.storefront else { return [] }
        return market.keywords.compactMap { k in k.latestMeasured?.asSample(keyword: k.text, storefront: sf.countryCode) }
    }

    private var summaries: [CompetitorSummary] {
        CompetitorAggregation.aggregate(samples: samples, ownTrackID: app.trackID, depth: depth)
    }

    var body: some View {
        Group {
            if samples.isEmpty {
                ContentUnavailableView("No measurements yet", systemImage: "person.2",
                                       description: Text("Measure keywords first. Competitors are the apps that appear in those search results."))
            } else {
                HSplitView {
                    table.frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
                    detail.frame(minWidth: 260, idealWidth: 320, maxWidth: 520, maxHeight: .infinity)
                }
            }
        }
        .sheet(item: $importTarget) { target in
            if let market { KeywordDiscoverySheet(app: app, market: market, competitor: target, seeds: KeywordDiscovery.phrases(from: target.name, maxUnigrams: 4, maxBigrams: 2)) }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Picker("Depth", selection: $depth) {
                    Text("Top 5").tag(5); Text("Top 10").tag(10); Text("Top 20").tag(20); Text("Top 50").tag(50)
                }
                .pickerStyle(.menu)
                .help("How deep in each result list to look")
            }
        }
    }

    private var table: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Apps seen in the top \(depth) of your \(samples.count) tracked keyword(s) in \(market?.title ?? "")")
                    .font(.callout).foregroundStyle(.secondary)
                Spacer()
                SourceBadge(origin: .publicSearchObserved)
            }
            .padding(12)
            Table(summaries, selection: $selection) {
                TableColumn("App") { c in
                    HStack(spacing: 8) {
                        AppIconView(url: c.app.iconURL, size: 22)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(c.app.name).lineLimit(1)
                            Text(c.app.sellerName).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
                .width(min: 180, ideal: 260)
                TableColumn("Keywords") { c in Text("\(c.appearanceCount)").monospacedDigit() }.width(70)
                TableColumn("Top 10") { c in Text("\(c.top10Count)").monospacedDigit() }.width(60)
                TableColumn("Avg. position") { c in Text(String(format: "%.1f", c.averagePosition)).monospacedDigit() }.width(90)
                TableColumn("Ratings") { c in Text((c.app.ratingCount ?? 0).formatted()).monospacedDigit() }.width(80)
                TableColumn("Rating") { c in Text(c.app.averageRating.map { String(format: "%.1f", $0) } ?? "—").monospacedDigit() }.width(56)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var detail: some View {
        if let id = selection, let c = summaries.first(where: { $0.id == id }) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        AppIconView(url: c.app.iconURL, size: 44)
                        VStack(alignment: .leading) {
                            Text(c.app.name).font(.headline)
                            Text("\(c.app.sellerName) · \(c.app.primaryGenre ?? "—")").font(.caption).foregroundStyle(.secondary)
                            Text("App ID \(c.app.trackID)\(c.app.bundleID.map { " · \($0)" } ?? "")").font(.caption2).foregroundStyle(.tertiary).textSelection(.enabled)
                        }
                    }
                    if let d = c.app.currentVersionReleaseDate {
                        LabeledContent("Last update") { Text(d.formatted(date: .abbreviated, time: .omitted)) }.font(.callout)
                    }
                    Button { importTarget = c.app } label: { Label("Import keywords from this app…", systemImage: "square.and.arrow.down.on.square") }
                        .help("Mine its title and description, expand with autocomplete and Apple Ads suggestions, score, and pick what to track")
                    Divider()
                    Text("Appears in these tracked keywords").font(.subheadline.weight(.semibold))
                    ForEach(c.appearances.sorted { $0.position < $1.position }, id: \.keyword) { a in
                        HStack {
                            Text(a.keyword)
                            Spacer()
                            Text("#\(a.position)").monospacedDigit().foregroundStyle(.secondary)
                        }
                        .font(.callout)
                    }
                    Text("Only queries you track are shown. This is not the competitor's full keyword set.")
                        .font(.caption).foregroundStyle(.secondary).padding(.top, 8)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView("Select a competitor", systemImage: "person.crop.square", description: Text("Its positions in your tracked keywords appear here."))
        }
    }
}
