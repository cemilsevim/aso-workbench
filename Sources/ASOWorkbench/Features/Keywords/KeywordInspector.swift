import SwiftUI
import SwiftData
import Charts
import ASOCore

struct KeywordInspector: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.modelContext) private var context
    @Bindable var keyword: TrackedKeyword
    let market: TrackedMarket
    let ownTrackID: Int
    @State private var chartRange: ChartRange = .all

    enum ChartRange: String, CaseIterable, Identifiable {
        case week = "7D", month = "30D", quarter = "90D", all = "All"
        var id: String { rawValue }
        var days: Int? {
            switch self { case .week: 7; case .month: 30; case .quarter: 90; case .all: nil }
        }
    }

    private var observations: [RankObservation] { keyword.sortedObservations }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if let latest = keyword.latestObservation {
                    Text(latest.outcome.explanation).font(.callout).foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 4) {
                        SourceBadge(origin: .publicSearchObserved, detail: "\(latest.providerRaw) · \(market.title)")
                        Text("Measured \(latest.fetchedAt.shortLabel)").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                chart
                signals
                popularity
                topResults
                log
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(keyword.text).font(.title3.weight(.semibold)).textSelection(.enabled).lineLimit(2)
            HStack(spacing: 10) {
                RankLabel(outcome: keyword.latestObservation?.outcome).font(.title2)
                DeltaLabel(delta: keyword.rankDelta)
                Spacer(minLength: 8)
                Button {
                    env.tracking.measure([keyword], in: market, context: context)
                } label: { Label("Rank", systemImage: "arrow.clockwise") }
                .controlSize(.small)
                .disabled(env.tracking.progress.isRunning)
                .help("Measure this keyword's rank now (its popularity is refreshed afterwards)")
                Button {
                    Task { await env.research.refreshPopularity(for: market, only: [keyword.persistentModelID], context: context) }
                } label: { Label("Popularity", systemImage: "chart.bar") }
                .controlSize(.small)
                .disabled(!env.adsState.isUsable || env.research.isLoadingPopularity)
                .help(env.adsState.isUsable ? "Refresh only this keyword's popularity (Apple lists, dashboard index, model estimate)" : "Connect Apple Ads in Connections to fetch popularity")
            }
            TextField("Note", text: $keyword.note, prompt: Text("Add a note (intent, why tracked…)"))
                .textFieldStyle(.roundedBorder)
        }
    }

    private struct Point: Identifiable {
        let id: Date
        let date: Date
        let position: Int?
        let observedCount: Int
    }

    @ViewBuilder
    private var chart: some View {
        let all = observations.filter { !$0.outcome.isFailure && $0.outcomeKind != "notChecked" }
            .map { Point(id: $0.fetchedAt, date: $0.fetchedAt, position: $0.position, observedCount: $0.observedCount) }
        let cutoff = chartRange.days.map { Date().addingTimeInterval(-Double($0) * 86_400) }
        let points = cutoff.map { c in all.filter { $0.date >= c } } ?? all
        let found = points.filter { $0.position != nil }
        let outside = points.filter { $0.position == nil }
        let depth = max(points.map(\.observedCount).max() ?? env.settings.resultDepth, 10)
        let best = found.compactMap(\.position).min()
        let spanDays = (points.last?.date.timeIntervalSince(points.first?.date ?? .now) ?? 0) / 86_400
        let markers = (keyword.market?.app?.markers ?? []).filter { m in m.date >= (points.first?.date ?? .distantPast) && m.date <= .now }
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Rank history").font(.headline)
                    Spacer()
                    Picker("Range", selection: $chartRange) {
                        ForEach(ChartRange.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .controlSize(.small)
                    .frame(width: 160)
                }
                if points.isEmpty {
                    Text(all.isEmpty ? "No measurements yet." : "No measurements in this range.")
                        .font(.callout).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 80)
                } else {
                    Chart {
                        ForEach(found) { p in
                            AreaMark(x: .value("Date", p.date), yStart: .value("Bottom", depth), yEnd: .value("Rank", p.position ?? depth))
                                .interpolationMethod(.monotone)
                                .foregroundStyle(LinearGradient(colors: [Color.accentColor.opacity(0.35), Color.accentColor.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                            LineMark(x: .value("Date", p.date), y: .value("Rank", p.position ?? depth))
                                .interpolationMethod(.monotone)
                                .lineStyle(StrokeStyle(lineWidth: 2))
                                .foregroundStyle(Color.accentColor)
                            PointMark(x: .value("Date", p.date), y: .value("Rank", p.position ?? depth))
                                .symbolSize(found.count > 40 ? 12 : 30)
                                .foregroundStyle(Color.accentColor)
                        }
                        if !outside.isEmpty {
                            RuleMark(y: .value("Not found", depth))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                .foregroundStyle(.secondary)
                                .annotation(position: .top, alignment: .leading) {
                                    Text("not in top \(depth)").font(.caption2).foregroundStyle(.secondary)
                                }
                            ForEach(outside) { p in
                                PointMark(x: .value("Date", p.date), y: .value("Not found", depth))
                                    .symbol(.cross)
                                    .symbolSize(28)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        ForEach(markers, id: \.date) { m in
                            RuleMark(x: .value("Date", m.date))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                                .foregroundStyle(m.kind == "release" ? Color.orange : Color.purple)
                                .annotation(position: .top, alignment: .leading) {
                                    Text(m.title).font(.caption2).foregroundStyle(m.kind == "release" ? Color.orange : Color.purple).lineLimit(1)
                                }
                        }
                        if let best, let bestPoint = found.first(where: { $0.position == best }) {
                            PointMark(x: .value("Date", bestPoint.date), y: .value("Rank", best))
                                .symbolSize(60)
                                .foregroundStyle(.green)
                                .annotation(position: .top) { Text("#\(best)").font(.caption2.weight(.semibold)).foregroundStyle(.green) }
                        }
                    }
                    .chartYScale(domain: .automatic(includesZero: false, reversed: true), type: .log)
                    .chartYAxis {
                        AxisMarks(position: .leading, values: [1, 3, 10, 30, 100, depth].filter { $0 <= depth }) { value in
                            AxisGridLine().foregroundStyle(.quaternary)
                            AxisValueLabel {
                                if let v = value.as(Int.self) { Text(v == depth ? "\(depth)+" : "#\(v)").font(.caption2) }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                            AxisGridLine().foregroundStyle(.quaternary)
                            AxisValueLabel(format: spanDays < 1 ? .dateTime.hour().minute() : .dateTime.day().month(.abbreviated), collisionResolution: .greedy)
                                .font(.caption2)
                        }
                    }
                    .chartYAxisLabel("rank · log scale, 1 at top", position: .top, alignment: .leading)
                    .chartLegend(.hidden)
                    .frame(maxWidth: .infinity)
                    .frame(height: 210)
                    HStack(spacing: 14) {
                        stat("Latest", found.last.map { "#\($0.position ?? 0)" } ?? (outside.isEmpty ? "—" : "not found"))
                        stat("Best", best.map { "#\($0)" } ?? "—")
                        stat("Measurements", "\(points.count)")
                        if !outside.isEmpty { stat("Outside top \(depth)", "\(outside.count)") }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.callout.weight(.medium)).monospacedDigit()
        }
    }

    @ViewBuilder
    private var signals: some View {
        if let latest = keyword.latestMeasured, let d = latest.signals?.difficulty ?? DifficultyScore(results: latest.results, term: keyword.text) {
            GroupBox("Difficulty") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("\(d.rounded)").font(.title2.weight(.semibold)).monospacedDigit().foregroundStyle(ScoreBand.difficulty(d.score))
                        Text(d.tier).font(.headline)
                        Spacer()
                        SourceBadge(origin: .derived, detail: "top \(d.sampleSize) results")
                    }
                    Text("How hard it is to reach page one, from the top ten public results. Not a probability of ranking.")
                        .font(.caption).foregroundStyle(.secondary)
                    ForEach(d.components) { c in
                        componentRow(c.name, c.value, weight: c.weight).help(c.explanation)
                    }
                }
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        if let s = keyword.latestMeasured?.signals {
            GroupBox("Competition signals (top 10)") {
                VStack(alignment: .leading, spacing: 6) {
                    LabeledContent("Median rating count") { Text(s.medianRatingCountTop10.map { $0.formatted() } ?? "—").monospacedDigit() }
                    LabeledContent("Rating mass band") { Text(s.ratingMassBand) }
                    LabeledContent("Title matches") { Text("\(s.titleMatchesTop10) of 10").monospacedDigit() }
                    LabeledContent("Distinct sellers") { Text("\(s.distinctSellersTop10)").monospacedDigit() }
                    LabeledContent("Weighted rating") { Text(s.weightedRatingTop10.map { String(format: "%.2f ★", $0) } ?? "—") }
                    SourceBadge(origin: .derived, detail: "from \(s.observedCount) public results")
                }
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func componentRow(_ title: String, _ value: Double, weight: String) -> some View {
        HStack(spacing: 8) {
            Text(title).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
            ProgressView(value: min(100, max(0, value)), total: 100).frame(width: 72)
            Text("\(Int(value.rounded()))").monospacedDigit().frame(width: 30, alignment: .trailing)
            Text(weight).font(.caption2).foregroundStyle(.tertiary).frame(width: 26, alignment: .trailing)
        }
    }

    @ViewBuilder
    private var popularity: some View {
        GroupBox("Official popularity") {
            VStack(alignment: .leading, spacing: 6) {
                if env.research.loadingKeywordIDs.contains(keyword.persistentModelID) {
                    HStack(spacing: 8) { ProgressView().controlSize(.small); Text(env.research.popularityProgress ?? "Asking Apple Ads…") }
                } else if let p = keyword.latestPopularity {
                    if p.scope == "bound" || (p.noRecord && p.popularity1to100 == nil) {
                        HStack(spacing: 8) {
                            Text(p.upperBound.map { "< \($0)" } ?? "< 50").font(.title2.weight(.semibold)).monospacedDigit().foregroundStyle(.secondary)
                            Text("below Apple's published range").font(.headline)
                        }
                        Text("Apple's \(p.countryCode) lists cover roughly the top 500 terms per genre and stop at \(p.upperBound.map(String.init) ?? "about 50")/100 for \(p.periodStart.formatted(.dateTime.month(.wide).year())). This term is on none of them (\(p.anyGenre ? "all 15 genres checked" : p.genreRaw)). For the exact 5–100 value, sign in to the Apple Ads dashboard in Connections and refresh.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else if p.scope == "index", let v = p.popularity1to100 {
                        if v < ModelTrainer.publishedThreshold, let s = p.subFloorEstimate {
                            HStack(spacing: 8) {
                                Text("\(s)").font(.title2.weight(.semibold)).monospacedDigit().foregroundStyle(ScoreBand.popularity(s))
                                Text("model value · Apple index 5").font(.headline)
                            }
                            Text("Apple's dashboard reports 5 for this term in \(p.countryCode): since 29 September 2025 every term below Apple's published range shows 5, and nothing is published between 6 and 31. The model fills that band from public signals (autocomplete, search results, Jev): its probability that the term has published-range demand (\(Int((p.subFloorProbability ?? 0) * 100))%) places it in slot \(s - 5) of 24 among floor terms, so \(Int(Double(s - 6) / 23 * 100))% of floor terms rank below it. Treat it as an ordering aid; values of 30 and above are Apple's own.")
                                .font(.caption).foregroundStyle(.secondary)
                            SourceBadge(origin: .derived, detail: "model · \(p.countryCode) · \(p.fetchedAt.formatted(.dateTime.day().month(.abbreviated)))")
                        } else {
                            HStack(spacing: 8) {
                                Text("\(v)").font(.title2.weight(.semibold)).monospacedDigit().foregroundStyle(ScoreBand.popularity(v))
                                Text("Apple Ads dashboard index").font(.headline)
                            }
                            Text("The popularity index the Apple Ads console shows for this exact term in \(p.countryCode) (5 = below the published range). Read through your signed-in browser session; not part of the documented API.")
                                .font(.caption).foregroundStyle(.secondary)
                            SourceBadge(origin: .officialObserved, detail: "\(p.countryCode) · dashboard · \(p.fetchedAt.formatted(.dateTime.day().month(.abbreviated)))")
                        }
                    } else if p.scope == "estimate" {
                        HStack(spacing: 8) {
                            if let v = p.popularity1to100 {
                                Text("~\(v)").font(.title2.weight(.semibold)).monospacedDigit().foregroundStyle(ScoreBand.popularity(v))
                            } else {
                                Text("< \(p.upperBound ?? 40)").font(.title2.weight(.semibold)).monospacedDigit().foregroundStyle(.secondary)
                            }
                            Text("model estimate").font(.headline)
                            if let c = p.estimateConfidence { Text(String(format: "%.0f%% confidence", c * 100)).font(.caption).foregroundStyle(.secondary) }
                        }
                        Text("Learned from Apple's dashboard index using public signals only (Lab → Popularity model). Apple has no published number for this term; the estimate is capped below the published floor\(p.upperBound.map { " (< \($0))" } ?? "").")
                            .font(.caption).foregroundStyle(.secondary)
                        SourceBadge(origin: .derived, detail: "estimate")
                    } else if p.scope == "global", let v = p.popularity1to100 {
                        Text("Older suggestion-based reading (\(v)); those scores vary with the seed term and are no longer collected. Refresh popularity.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        LabeledContent("Popularity 1–100") {
                            Text(p.popularity1to100.map(String.init) ?? "—").monospacedDigit().fontWeight(.semibold)
                                .foregroundStyle(p.popularity1to100.map(ScoreBand.popularity) ?? .primary)
                        }
                        LabeledContent("Popularity 1–5") { Text(p.popularity1to5.map(String.init) ?? "—").monospacedDigit() }
                        LabeledContent("Rank in genre") { Text(p.rankInGenre.map(String.init) ?? "—").monospacedDigit() }
                        SourceBadge(origin: .officialObserved, detail: "\(p.countryCode) · \(p.genreRaw) · \(p.periodStart.formatted(.dateTime.month(.abbreviated).year()))")
                    }
                    Text("Fetched \(p.fetchedAt.relativeLabel)").font(.caption2).foregroundStyle(.secondary)
                } else {
                    Text(env.adsState.isUsable ? "Not fetched yet. Press Popularity above, or Update ▸ Refresh popularity in the toolbar." : "Connect Apple Ads (sidebar → Connections) to fetch Apple's own popularity score.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            .font(.callout)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var topResults: some View {
        if let latest = keyword.latestMeasured {
            let results = Array(latest.results.prefix(10))
            GroupBox("Top results (\(latest.fetchedAt.relativeLabel))") {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(results.enumerated()), id: \.element.trackID) { index, app in
                        HStack(spacing: 8) {
                            Text("\(index + 1)").monospacedDigit().foregroundStyle(.secondary).frame(width: 22, alignment: .trailing)
                            AppIconView(url: app.iconURL, size: 20)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(app.name).lineLimit(1).truncationMode(.tail).fontWeight(app.trackID == ownTrackID ? .semibold : .regular)
                                Text("\(app.sellerName) · \((app.ratingCount ?? 0).formatted(.number.notation(.compactName))) ratings").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            if app.trackID == ownTrackID { Image(systemName: "star.fill").foregroundStyle(.tint) }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var log: some View {
        GroupBox("Observation log") {
            VStack(alignment: .leading, spacing: 4) {
                if observations.isEmpty {
                    Text("No observations yet.").foregroundStyle(.secondary)
                }
                ForEach(observations.reversed().prefix(30), id: \.persistentModelID) { o in
                    HStack(spacing: 8) {
                        Text(o.fetchedAt.shortLabel).foregroundStyle(.secondary).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                        RankLabel(outcome: o.outcome)
                    }
                    .help("\(o.outcome.explanation) Provider: \(o.providerRaw).")
                }
            }
            .font(.callout)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
