import Foundation
import Testing
@testable import ASOProviders
import ASOCore

/// Opt-in live checks against your own Apple Ads account. They run only when the variables below are set, never print
/// key material, and never write anything:
///
///     ASO_LIVE_ADS_CLIENT_ID=… ASO_LIVE_ADS_KEY_ID=… ASO_LIVE_ADS_ORG_ID=… ASO_LIVE_ADS_KEY_PATH=/path/to/key.pem \
///       swift test --filter LiveAppleAds
@Suite("Live Apple Ads (opt-in)")
struct LiveAppleAdsTests {
    static var creds: AppleAdsCredentials? {
        let env = ProcessInfo.processInfo.environment
        guard let path = env["ASO_LIVE_ADS_KEY_PATH"], let pem = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
        return AppleAdsCredentials(clientID: env["ASO_LIVE_ADS_CLIENT_ID"] ?? "", keyID: env["ASO_LIVE_ADS_KEY_ID"] ?? "",
                                   orgID: env["ASO_LIVE_ADS_ORG_ID"] ?? "", privateKeyPEM: pem)
    }

    @Test(.enabled(if: creds != nil))
    func tokenFlow() async throws {
        let message = try await AppleAdsPopularityProvider(credentials: Self.creds).verify()
        #expect(message.contains("Token OK"))
    }

    @Test(.enabled(if: creds != nil))
    func genreListAndTermLookup() async throws {
        let provider = AppleAdsPopularityProvider(credentials: Self.creds)
        let list = try await provider.genreDataset(country: "US", genre: .photoVideo, monthsBack: 1)
        #expect(!list.isEmpty)
        let known = Array(list.prefix(3).map(\.searchTerm))
        let rows = try await provider.popularity(terms: known, country: "US", genre: .photoVideo, monthsBack: 1)
        #expect(!rows.isEmpty)
    }

    @Test(.enabled(if: creds != nil))
    func campaignReportShape() async throws {
        let provider = AppleAdsCampaignProvider(credentials: Self.creds)
        let campaigns = try await provider.campaigns()
        guard let first = campaigns.first else { return }   // an account without campaigns is fine
        let rows = try await provider.keywordReport(campaignID: first.id, start: .now.addingTimeInterval(-30 * 86_400), end: .now)
        #expect(rows.allSatisfy { !$0.country.isEmpty })
    }
}
