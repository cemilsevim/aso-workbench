import Foundation
import Testing
@testable import ASOCore

@Suite("Rank outcomes")
struct RankOutcomeTests {
    @Test("Absence is not rank 201")
    func outsideRange() {
        let o = RankOutcome.outsideObservedRange(observedCount: 200)
        #expect(o.position == nil)
        #expect(o.shortLabel == "> 200")
        #expect(!o.isFailure)
    }

    @Test func found() {
        #expect(RankOutcome.found(position: 7, observedCount: 200).position == 7)
    }
}

@Suite("Storefront registry")
struct StorefrontTests {
    @Test("Unknown codes are not mapped to US")
    func unknown() {
        #expect(StorefrontRegistry.lookup("XX") == nil)
        #expect(StorefrontRegistry.lookup("tr")?.countryCode == "TR")
        #expect(StorefrontRegistry.lookup("JP")?.defaultLocale == .ja)
    }

    @Test func headerFormat() {
        #expect(StorefrontRegistry.lookup("US")?.storeFrontHeader == "143441-1,29")
    }

    @Test func localeParsing() {
        #expect(AppLocale.parse("zh-hans") == .zhHans)
        #expect(AppLocale.parse("en-us") == .enUS)
        #expect(AppLocale.parse("xx") == nil)
    }
}

@Suite("Competitor aggregation")
struct CompetitorTests {
    func app(_ id: Int, _ name: String, seller: String = "S", ratings: Int? = 100) -> SearchResultApp {
        SearchResultApp(trackID: id, bundleID: nil, name: name, sellerName: seller, iconURL: nil, averageRating: 4.5, ratingCount: ratings,
                        primaryGenre: nil, releaseDate: nil, currentVersionReleaseDate: nil, price: 0, version: nil)
    }

    @Test("Own app is excluded and appearances are counted per tracked keyword")
    func aggregate() {
        let s1 = RankSample(keyword: "budget", storefront: "US", device: .iPhone, provider: .itunesSearch,
                            outcome: .found(position: 2, observedCount: 3), fetchedAt: .now, results: [app(1, "Rival"), app(9, "Mine"), app(2, "Other")])
        let s2 = RankSample(keyword: "expense", storefront: "US", device: .iPhone, provider: .itunesSearch,
                            outcome: .outsideObservedRange(observedCount: 2), fetchedAt: .now, results: [app(1, "Rival"), app(3, "Third")])
        let summary = CompetitorAggregation.aggregate(samples: [s1, s2], ownTrackID: 9)
        #expect(summary.first?.app.trackID == 1)
        #expect(summary.first?.appearanceCount == 2)
        #expect(!summary.contains { $0.app.trackID == 9 })
    }

    @Test func signals() {
        let results = (1...12).map { app($0, $0 % 2 == 0 ? "Budget App \($0)" : "Other \($0)", seller: "S\($0 % 3)", ratings: $0 * 100) }
        let s = CompetitionSignals(results: results, term: "budget")
        #expect(s.titleMatchesTop10 == 5)
        #expect(s.distinctSellersTop10 == 3)
        #expect(s.medianRatingCountTop10 == 600)
        #expect(s.observedCount == 12)
    }
}
