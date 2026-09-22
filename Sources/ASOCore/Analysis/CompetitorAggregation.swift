import Foundation

/// A competitor as seen through *our tracked queries only*. This is explicitly not
/// "all keywords of this competitor" — the research plan warns against implying that.
public struct CompetitorSummary: Sendable, Hashable, Identifiable {
    public let app: SearchResultApp
    /// Tracked keywords in which the app appeared, with its position in each.
    public let appearances: [(keyword: String, position: Int)]
    public var id: Int { app.trackID }

    public var appearanceCount: Int { appearances.count }
    public var averagePosition: Double {
        guard !appearances.isEmpty else { return 0 }
        return Double(appearances.map(\.position).reduce(0, +)) / Double(appearances.count)
    }
    public var top10Count: Int { appearances.filter { $0.position <= 10 }.count }

    public static func == (a: Self, b: Self) -> Bool {
        a.app == b.app && a.appearances.map(\.keyword) == b.appearances.map(\.keyword) && a.appearances.map(\.position) == b.appearances.map(\.position)
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(app.trackID)
        for x in appearances { hasher.combine(x.keyword); hasher.combine(x.position) }
    }
}

public enum CompetitorAggregation {
    /// Aggregates the latest result list of each tracked keyword. `ownTrackID` is excluded.
    /// `depth` limits how deep in each result list we look (default top 20).
    public static func aggregate(samples: [RankSample], ownTrackID: Int, depth: Int = 20) -> [CompetitorSummary] {
        var byApp: [Int: (app: SearchResultApp, hits: [(String, Int)])] = [:]
        for sample in samples {
            for (index, app) in sample.results.prefix(depth).enumerated() where app.trackID != ownTrackID {
                var entry = byApp[app.trackID] ?? (app, [])
                entry.hits.append((sample.keyword, index + 1))
                byApp[app.trackID] = entry
            }
        }
        return byApp.values
            .map { CompetitorSummary(app: $0.app, appearances: $0.hits.map { (keyword: $0.0, position: $0.1) }) }
            .sorted {
                if $0.appearanceCount != $1.appearanceCount { return $0.appearanceCount > $1.appearanceCount }
                return $0.averagePosition < $1.averagePosition
            }
    }
}
