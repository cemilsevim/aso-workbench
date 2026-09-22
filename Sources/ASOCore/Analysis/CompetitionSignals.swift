import Foundation

/// Separate, explainable competition signals for one query's result list.
/// These are shown side by side, never averaged into a single "difficulty".
public struct CompetitionSignals: Sendable, Hashable, Codable {
    /// Median rating count of the top 10 results.
    public let medianRatingCountTop10: Int?
    /// How many of the top 10 have the query (case-insensitive) in their name.
    public let titleMatchesTop10: Int
    /// Distinct sellers among the top 10, low diversity means a few players dominate.
    public let distinctSellersTop10: Int
    /// Average star rating (rating-count weighted) of the top 10.
    public let weightedRatingTop10: Double?
    public let observedCount: Int
    /// Difficulty estimate over the top ten results (nil for records stored in an older format; callers recompute).
    public let difficulty: DifficultyScore?

    public init(results: [SearchResultApp], term: String) {
        let top = Array(results.prefix(10))
        observedCount = results.count
        let counts = top.compactMap(\.ratingCount).sorted()
        medianRatingCountTop10 = counts.isEmpty ? nil : counts[counts.count / 2]
        let t = term.lowercased()
        titleMatchesTop10 = top.filter { TitleMatch.contains(title: $0.name, term: t) }.count
        distinctSellersTop10 = Set(top.map { $0.sellerName.lowercased() }).count
        var wsum = 0.0, qsum = 0.0
        for app in top {
            guard let r = app.averageRating, let c = app.ratingCount else { continue }
            let w = log1p(Double(c))
            wsum += w
            qsum += r * w
        }
        weightedRatingTop10 = wsum > 0 ? qsum / wsum : nil
        difficulty = DifficultyScore(results: results, term: term)
    }

    private enum CodingKeys: String, CodingKey { case medianRatingCountTop10, titleMatchesTop10, distinctSellersTop10, weightedRatingTop10, observedCount, difficulty }

    /// Stored signals from older versions carry a difficulty in a different shape; it is dropped (nil) and
    /// recomputed from the stored results by the callers, instead of failing the whole record.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        medianRatingCountTop10 = try c.decodeIfPresent(Int.self, forKey: .medianRatingCountTop10)
        titleMatchesTop10 = try c.decodeIfPresent(Int.self, forKey: .titleMatchesTop10) ?? 0
        distinctSellersTop10 = try c.decodeIfPresent(Int.self, forKey: .distinctSellersTop10) ?? 0
        weightedRatingTop10 = try c.decodeIfPresent(Double.self, forKey: .weightedRatingTop10)
        observedCount = try c.decodeIfPresent(Int.self, forKey: .observedCount) ?? 0
        difficulty = (try? c.decodeIfPresent(DifficultyScore.self, forKey: .difficulty)) ?? nil
    }

    /// Coarse, human-readable band derived only from the median rating count, labelled as derived.
    public var ratingMassBand: String {
        guard let m = medianRatingCountTop10 else { return "—" }
        switch m {
        case ..<200: return "Low"
        case ..<2_000: return "Medium"
        case ..<20_000: return "High"
        default: return "Very high"
        }
    }
}
