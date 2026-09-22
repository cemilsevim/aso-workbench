import Foundation

/// Popularity bands used for the classifier and for reporting. Apple's index runs 5–100 (5 = floor).
public enum PopularityBand: Int, CaseIterable, Sendable, Codable {
    case none = 0, low, medium, high, veryHigh

    public init(index: Int) {
        switch index {
        case ...5: self = .none
        case ...24: self = .low
        case ...44: self = .medium
        case ...64: self = .high
        default: self = .veryHigh
        }
    }

    public var label: String {
        switch self {
        case .none: "none"
        case .low: "low"
        case .medium: "medium"
        case .high: "high"
        case .veryHigh: "very high"
        }
    }

    /// Representative index value for a band (used when only a band is predicted).
    public var midpoint: Int {
        switch self {
        case .none: 5
        case .low: 15
        case .medium: 35
        case .high: 55
        case .veryHigh: 78
        }
    }
}

/// Signals available without any Apple account. Missing groups are encoded with sentinels and flags.
public struct PublicFeatures: Sendable, Codable, Hashable {
    // Lexical
    public var wordCount: Int
    public var charCount: Int
    public var avgWordLength: Double
    public var hasDigit: Bool
    public var hasNonASCII: Bool
    public var hasPunctuation: Bool

    // Autocomplete (App Store hints). Positions are 1-based; 0 = absent; -1 = not collected.
    public var ownHintCount: Int = -1
    public var ownSelfPosition: Int = -1
    public var firstWordHintCount: Int = -1
    public var firstWordPosition: Int = -1
    public var prefixHintCount: Int = -1
    public var prefixPosition: Int = -1

    // Public search results (optional).
    public var resultCount: Int = -1
    public var top10MedianRatings: Int = -1
    public var leaderRatings: Int = -1
    public var titleMatchesTop10: Int = -1
    public var distinctSellersTop10: Int = -1
    public var difficulty: Double = -1
    public var resultRelevance: Double = -1

    public init(term: String) {
        let words = term.split(separator: " ").map(String.init)
        wordCount = max(1, words.count)
        charCount = term.count
        avgWordLength = words.isEmpty ? Double(term.count) : Double(words.map(\.count).reduce(0, +)) / Double(words.count)
        hasDigit = term.contains { $0.isNumber }
        hasNonASCII = term.unicodeScalars.contains { $0.value > 127 }
        hasPunctuation = term.contains { $0.isPunctuation || $0.isSymbol }
    }

    public var hasHints: Bool { ownHintCount >= 0 || firstWordHintCount >= 0 || prefixHintCount >= 0 }
    public var hasResults: Bool { resultCount >= 0 }

    /// Fills the result-based group from a public result list.
    public mutating func apply(results: [SearchResultApp], term: String) {
        let s = CompetitionSignals(results: results, term: term)
        resultCount = results.count
        top10MedianRatings = s.medianRatingCountTop10 ?? 0
        leaderRatings = results.prefix(10).compactMap(\.ratingCount).max() ?? 0
        titleMatchesTop10 = s.titleMatchesTop10
        distinctSellersTop10 = s.distinctSellersTop10
        difficulty = s.difficulty?.score ?? -1
        resultRelevance = s.difficulty?.relevance ?? -1
    }
}

/// Semantic judgements from Jev (probabilities). -1 = not collected.
public struct JevFeatures: Sendable, Codable, Hashable {
    public var brand: Double = -1
    public var naturalQuery: Double = -1
    public var languageFit: Double = -1
    public var headTerm: Double = -1          // expected score 0–4
    public var demand: Double = -1            // expected score 0–4
    public var demandProbabilities: [Double] = []   // 5 levels
    public var intent: String = ""            // brand | category | feature | longtail | other
    public var intentProbabilities: [String: Double] = [:]
    public var genre: String = ""             // Apple Ads genre guess
    public var genreConfidence: Double = -1

    public init() {}
    public var isCollected: Bool { demand >= 0 }
}

/// One labelled example, as exported to JSONL.
public struct TrainingExample: Sendable, Codable {
    public var term: String
    public var storefront: String
    public var source: String
    public var label: Int?
    public var listScore: Int?
    public var features: PublicFeatures
    public var jev: JevFeatures?
    public var labeledAt: Date?

    public init(term: String, storefront: String, source: String, label: Int?, listScore: Int?, features: PublicFeatures, jev: JevFeatures?, labeledAt: Date?) {
        self.term = term
        self.storefront = storefront
        self.source = source
        self.label = label
        self.listScore = listScore
        self.features = features
        self.jev = jev
        self.labeledAt = labeledAt
    }
}

/// Flattens an example into the columns the tree models consume. Column order is fixed.
public enum FeatureColumns {
    public static let intents = ["brand", "category", "feature", "longtail", "other"]

    public static let numericNames: [String] = [
        "word_count", "char_count", "avg_word_length", "has_digit", "has_non_ascii", "has_punct",
        "has_hints", "own_hint_count", "own_self_position", "first_word_hint_count", "first_word_position", "prefix_hint_count", "prefix_position",
        "has_results", "result_count", "log_top10_median_ratings", "log_leader_ratings", "title_matches_top10", "distinct_sellers_top10", "difficulty", "result_relevance",
        "has_jev", "jev_brand", "jev_natural", "jev_language_fit", "jev_head_term", "jev_demand",
        "jev_demand_p0", "jev_demand_p1", "jev_demand_p2", "jev_demand_p3", "jev_demand_p4",
        "jev_intent_brand", "jev_intent_category", "jev_intent_feature", "jev_intent_longtail", "jev_intent_other",
    ]
    public static let categoricalNames: [String] = ["storefront", "jev_genre"]

    /// Position of the `hasHints` indicator in `numeric(_:jev:)`.
    public static var hasHintsIndex: Int { numericNames.firstIndex(of: "has_hints") ?? 6 }

    public static func numeric(_ f: PublicFeatures, jev: JevFeatures?) -> [Double] {
        func log1(_ v: Int) -> Double { v < 0 ? -1 : log10(Double(v) + 1) }
        let j = jev ?? JevFeatures()
        let dp = j.demandProbabilities.count == 5 ? j.demandProbabilities : [-1, -1, -1, -1, -1]
        let ip = intents.map { j.intentProbabilities[$0] ?? (j.isCollected ? 0 : -1) }
        return [
            Double(f.wordCount), Double(f.charCount), f.avgWordLength, f.hasDigit ? 1 : 0, f.hasNonASCII ? 1 : 0, f.hasPunctuation ? 1 : 0,
            f.hasHints ? 1 : 0, Double(f.ownHintCount), Double(f.ownSelfPosition), Double(f.firstWordHintCount), Double(f.firstWordPosition), Double(f.prefixHintCount), Double(f.prefixPosition),
            f.hasResults ? 1 : 0, Double(f.resultCount), log1(f.top10MedianRatings), log1(f.leaderRatings), Double(f.titleMatchesTop10), Double(f.distinctSellersTop10), f.difficulty, f.resultRelevance,
            j.isCollected ? 1 : 0, j.brand, j.naturalQuery, j.languageFit, j.headTerm, j.demand,
            dp[0], dp[1], dp[2], dp[3], dp[4],
            ip[0], ip[1], ip[2], ip[3], ip[4],
        ]
    }

    public static func categorical(_ storefront: String, jev: JevFeatures?) -> [String] {
        [storefront.uppercased(), (jev?.genre.isEmpty == false ? jev!.genre : "unknown")]
    }
}
