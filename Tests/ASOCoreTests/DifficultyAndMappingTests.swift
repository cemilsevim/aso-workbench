import Foundation
import Testing
@testable import ASOCore

@Suite("Difficulty score")
struct DifficultyScoreTests {
    func app(_ id: Int, _ name: String, seller: String, ratings: Int, stars: Double = 4.5, ageYears: Double = 3) -> SearchResultApp {
        SearchResultApp(trackID: id, bundleID: nil, name: name, sellerName: seller, iconURL: nil, averageRating: stars, ratingCount: ratings,
                        primaryGenre: nil, releaseDate: Date().addingTimeInterval(-ageYears * 365 * 86_400), currentVersionReleaseDate: nil, price: 0, version: nil)
    }

    func appUpdated(_ id: Int, _ name: String, ratings: Int, stars: Double, ageYears: Double, updatedDaysAgo: Double) -> SearchResultApp {
        SearchResultApp(trackID: id, bundleID: nil, name: name, sellerName: "S\(id)", iconURL: nil, averageRating: stars, ratingCount: ratings, primaryGenre: nil,
                        releaseDate: Date().addingTimeInterval(-ageYears * 365.25 * 86_400), currentVersionReleaseDate: Date().addingTimeInterval(-updatedDaysAgo * 86_400), price: 0, version: nil)
    }

    @Test("Entrenched, relevant results score much harder than a thin, irrelevant list")
    func bands() {
        let hard = (1...50).map { appUpdated($0, "Budget Planner \($0)", ratings: 400_000, stars: 4.8, ageYears: 8, updatedDaysAgo: 10) }
        let easy = (1...8).map { appUpdated($0, "Random Tool \($0)", ratings: 30, stars: 3.8, ageYears: 0.5, updatedDaysAgo: 300) }
        let h = DifficultyScore(results: hard, term: "budget planner")!
        let e = DifficultyScore(results: easy, term: "budget planner")!
        #expect(h.score > 75)
        #expect(e.score < 15)
        #expect(e.relevance == 0.6)
        #expect(h.components.count == 7)
        #expect(DifficultyScore(results: [], term: "x") == nil)
    }

    @Test func helpers() {
        #expect(DifficultyScore.median([3, 1, 2]) == 2)
        #expect(DifficultyScore.median([1, 2, 3, 4]) == 2.5)
        #expect(DifficultyScore.titleHit("Comic Book Reader", term: "comic book") == 1)
        #expect(DifficultyScore.titleHit("Book of Comic Art", term: "comic book") == 1)
        #expect(DifficultyScore.titleHit("Book Club", term: "comic book") == 0.25)
        #expect(DifficultyScore.calibrate(100) == 100)
    }
}

@Suite("Genre mapping and App Store links")
struct MappingTests {
    @Test func genreMapping() {
        #expect(AppleAdsGenre(appStoreGenre: "Photo & Video") == .photoVideo)
        #expect(AppleAdsGenre(appStoreGenre: "Books") == .newsPublication)
        #expect(AppleAdsGenre(appStoreGenre: "Utilities") == .productivityUtilities)
        #expect(AppleAdsGenre(appStoreGenre: "Graphics & Design") == nil)
        #expect(AppleAdsGenre(appStoreGenre: nil) == nil)
    }

    @Test func appStoreLinks() {
        #expect(AppStoreURL.parse("https://apps.apple.com/tr/app/keynote/id361285480?l=en") == .init(trackID: 361285480, countryCode: "TR"))
        #expect(AppStoreURL.parse("https://apps.apple.com/app/id361285480") == .init(trackID: 361285480, countryCode: nil))
        #expect(AppStoreURL.parse("361285480") == .init(trackID: 361285480, countryCode: nil))
        #expect(AppStoreURL.parse("comic reader") == nil)
    }
}
