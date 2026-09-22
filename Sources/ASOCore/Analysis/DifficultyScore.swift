import Foundation

/// How hard it is to reach the visible top of one search, 0–100, from the public result list only.
///
/// It looks at what a searcher actually sees — the first ten results — and asks six questions:
///
/// | Component | Weight | Question |
/// |---|---|---|
/// | Incumbent strength | 35% | How big are the top three apps? (position-weighted rating counts, log scale, 1M ratings = 100) |
/// | Field depth | 20% | Is the rest of page one big too? (median rating count of the top ten, 100k = 100) |
/// | Keyword targeting | 20% | Do the top ten name the term in their title? (exact/compact match 1, partial word overlap ½) |
/// | Maturity | 10% | How established are they? (average age, capped at four years) |
/// | Activity | 10% | Are they being worked on? (share updated in the last 60 days) |
/// | Satisfaction | 5% | Are their users happy? (rating-count-weighted stars, 3★ = 0, 5★ = 100) |
///
/// Two adjustments follow: when few of the top ten mention any word of the term, Apple is padding the list with
/// loosely related apps, so the score is discounted (down to ×0.6); a list shorter than ten is discounted too.
/// The weighted sum is finally mapped onto a calibrated 0–100 curve (≈ 0.62× in the middle, reaching 100 at 100)
/// so that "Easy ≤ 35" and "Hard > 55" mean the same thing across the app. It is a competition estimate, never a
/// probability of ranking, and every component is exposed so a number can be explained.
public struct DifficultyScore: Sendable, Hashable, Codable {
    public let score: Double
    public let incumbentStrength: Double
    public let fieldDepth: Double
    public let keywordTargeting: Double
    public let maturity: Double
    public let activity: Double
    public let satisfaction: Double
    /// 0.6–1: how much the result list is about the term (1 = at least half of the top ten mention it).
    public let relevance: Double
    public let sampleSize: Int

    public var rounded: Int { Int(score.rounded()) }

    public static func tier(for score: Double) -> String {
        switch score {
        case ...15: "Very easy"
        case ...35: "Easy"
        case ...55: "Moderate"
        case ...75: "Hard"
        case ...90: "Very hard"
        default: "Extreme"
        }
    }

    public var tier: String { Self.tier(for: score) }

    public struct Component: Sendable, Hashable, Identifiable {
        public var id: String { name }
        public let name: String
        public let value: Double
        public let weight: String
        public let explanation: String
    }

    /// The breakdown in display order, for inspectors and tooltips.
    public var components: [Component] {
        [
            Component(name: "Incumbent strength", value: incumbentStrength, weight: "35%", explanation: "Rating counts of the top three results, position-weighted"),
            Component(name: "Field depth", value: fieldDepth, weight: "20%", explanation: "Median rating count of the top ten"),
            Component(name: "Keyword targeting", value: keywordTargeting, weight: "20%", explanation: "How many of the top ten name the term in their title"),
            Component(name: "Maturity", value: maturity, weight: "10%", explanation: "Average age of the top ten (four years = 100)"),
            Component(name: "Activity", value: activity, weight: "10%", explanation: "Share of the top ten updated in the last 60 days"),
            Component(name: "Satisfaction", value: satisfaction, weight: "5%", explanation: "Rating-weighted stars of the top ten"),
            Component(name: "Result relevance", value: relevance * 100, weight: "×", explanation: "Discount when the list is mostly unrelated apps"),
        ]
    }

    public init?(results: [SearchResultApp], term: String, today: Date = .now) {
        let top = Array(results.prefix(10))
        let n = top.count
        guard n > 0 else { return nil }
        let t = term.lowercased().trimmingCharacters(in: .whitespaces)

        func logShare(_ ratings: Int?, decades: Double) -> Double { min(1, log10(1 + Double(max(0, ratings ?? 0))) / decades) }

        let weights = [0.5, 0.3, 0.2]
        let leaders = Array(top.prefix(3))
        var inc = 0.0
        for (i, app) in leaders.enumerated() { inc += weights[i] * logShare(app.ratingCount, decades: 6) }
        let incumbent = inc / weights.prefix(leaders.count).reduce(0, +) * 100

        let medianRatings = Self.median(top.map { Double($0.ratingCount ?? 0) })
        let depth = min(1, log10(1 + medianRatings) / 5) * 100

        let hits = top.map { Self.titleHit($0.name, term: t) }
        let targeting = hits.reduce(0, +) / Double(n) * 100

        let ages = top.compactMap { $0.releaseDate.map { max(0, today.timeIntervalSince($0) / 86_400 / 365.25) } }
        let mature = ages.isEmpty ? 50 : ages.map { min($0 / 4, 1) }.reduce(0, +) / Double(ages.count) * 100

        let updates = top.compactMap { $0.currentVersionReleaseDate.map { today.timeIntervalSince($0) / 86_400 } }
        let active = updates.isEmpty ? 50 : Double(updates.filter { $0 <= 60 }.count) / Double(updates.count) * 100

        var weightSum = 0.0, starSum = 0.0
        for app in top {
            guard let stars = app.averageRating, let count = app.ratingCount, count > 0 else { continue }
            let w = log1p(Double(count))
            weightSum += w
            starSum += stars * w
        }
        let happy = weightSum > 0 ? max(0, min(1, (starSum / weightSum - 3) / 2)) * 100 : 50

        var raw = 0.35 * incumbent + 0.20 * depth + 0.20 * targeting + 0.10 * mature + 0.10 * active + 0.05 * happy
        let loose = Double(hits.filter { $0 > 0 }.count) / Double(n)
        let rel = 0.6 + 0.4 * min(1, loose * 2)
        raw *= rel
        if n < 10 { raw *= 0.5 + 0.05 * Double(n) }
        raw = max(1, min(100, raw))

        func round1(_ x: Double) -> Double { (x * 10).rounded() / 10 }
        score = round1(max(1, min(100, Self.calibrate(raw))))
        incumbentStrength = round1(incumbent)
        fieldDepth = round1(depth)
        keywordTargeting = round1(targeting)
        maturity = round1(mature)
        activity = round1(active)
        satisfaction = round1(happy)
        relevance = (rel * 100).rounded() / 100
        sampleSize = n
    }

    /// Maps the weighted sum onto the app's difficulty scale: gentle in the middle, steep near the top.
    static func calibrate(_ raw: Double) -> Double { raw * (0.62 + 0.38 * pow(raw / 100, 3)) }

    static func median(_ xs: [Double]) -> Double {
        let s = xs.sorted()
        guard !s.isEmpty else { return 0 }
        return s.count % 2 == 1 ? s[s.count / 2] : (s[s.count / 2 - 1] + s[s.count / 2]) / 2
    }

    /// 1 when the title names the term (spacing and punctuation aside), ½ × word overlap otherwise.
    static func titleHit(_ title: String, term: String) -> Double {
        if TitleMatch.contains(title: title, term: term) { return 1 }
        let words = term.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init).filter { $0.count >= 2 }
        guard !words.isEmpty else { return 0 }
        let lower = title.lowercased()
        let overlap = Double(words.filter { lower.contains($0) }.count) / Double(words.count)
        return overlap >= 1 ? 1 : overlap * 0.5
    }
}
