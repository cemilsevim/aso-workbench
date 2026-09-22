import Foundation
import Testing
@testable import ASOProviders
import ASOCore

@Suite("Provider response parsing")
struct ParsingTests {
    @Test func itunesSearch() throws {
        let json = """
        {"resultCount":1,"results":[{"trackId":123,"bundleId":"com.x.y","trackName":"Budget Buddy","artistName":"X Inc","sellerName":"X Inc",
          "artworkUrl100":"https://is1-ssl.mzstatic.com/a.png","averageUserRating":4.6,"userRatingCount":1200,"primaryGenreName":"Finance",
          "releaseDate":"2021-03-04T07:00:00Z","currentVersionReleaseDate":"2026-08-01T10:00:00Z","price":0,"version":"3.1"}]}
        """
        let apps = try ITunesSearchProvider.parse(Data(json.utf8))
        #expect(apps.count == 1)
        #expect(apps[0].trackID == 123)
        #expect(apps[0].ratingCount == 1200)
        #expect(apps[0].releaseDate != nil)
    }

    @Test func hintsPlist() throws {
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict><key>hints</key><array>
        <dict><key>term</key><string>budget planner</string><key>url</key><string>https://x</string></dict>
        <dict><key>term</key><string>budget &amp; expense</string><key>url</key><string>https://y</string></dict>
        </array></dict></plist>
        """
        let terms = try AppStoreHintsProvider.parse(Data(plist.utf8))
        #expect(terms == ["budget planner", "budget & expense"])
    }

    @Test func appleAdsRows() throws {
        let json = """
        {"result":{"rows":[{"searchTerm":"expense tracker","rankInGenre":3,"searchPopularityInGenre":88,"searchPopularity1to100":61,"searchPopularity1to5":4}]}}
        """
        let rows = try AppleAdsPopularityProvider.parseRows(Data(json.utf8))
        #expect(rows.count == 1)
        #expect(rows[0].searchPopularity1to100 == 61)
    }

    @Test func appleAdsBodyHasNoSorting() {
        let body = AppleAdsPopularityProvider.popularityBody(country: "tr", genre: .finance, monthsBack: 1, terms: ["a"], pageSize: 50)
        #expect(body["sorting"] == nil)
        let filters = body["filters"] as? [[String: Any]]
        #expect(filters?.count == 3)
        #expect((filters?.first?["value"] as? String) == "TR")
    }

    @Test func es256SignerProducesThreeSegments() throws {
        // Throwaway key generated for the test only.
        let pem = """
        -----BEGIN PRIVATE KEY-----
        MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgevZzL1gdAFr88hb2
        OF/2NxApJCzGCEDdfSp6VQO30hyhRANCAAQRWz+jn65BtOMvdyHKcvjBeBSDZH2r
        1RTwjmYSi9R/zpBnuQ4EiMnCqfMPWiZqB4QdbAd0E7oH50VpuZ1P087G
        -----END PRIVATE KEY-----
        """
        let signer = try ES256Signer(pem: pem)
        let jwt = try signer.sign(header: ["alg": "ES256", "kid": "K"], payload: ["iss": "I", "exp": 1])
        #expect(jwt.split(separator: ".").count == 3)
    }

    @Test func ascMerge() {
        let v = ASCMetadataProvider.Resource(["id": "v1", "attributes": ["locale": "en-US", "keywords": "a,b", "description": "D"]])!
        let i = ASCMetadataProvider.Resource(["id": "i1", "attributes": ["locale": "en-US", "name": "N", "subtitle": "S"]])!
        let ver = ASCMetadataProvider.Resource(["id": "ver", "attributes": ["versionString": "1.2", "appStoreState": "PREPARE_FOR_SUBMISSION"]])!
        let snaps = ASCMetadataProvider.merge(versionLocs: [v], infoLocs: [i], version: ver)
        #expect(snaps.count == 1)
        #expect(snaps[0].fields.name == "N")
        #expect(snaps[0].fields.keywords == "a,b")
        #expect(snaps[0].versionLocalizationID == "v1")
        #expect(snaps[0].appInfoLocalizationID == "i1")
        #expect(snaps[0].versionString == "1.2")
    }
}

@Suite("Credential sanitising")
struct CredentialSanitisingTests {
    @Test("Trailing newline and zero-width characters are stripped from identifiers")
    func strips() {
        let creds = AppleAdsCredentials(clientID: " SEARCHADS.abc\n", keyID: "2e72\u{200B}ad71\n", orgID: "1905\t", privateKeyPEM: "\n-----BEGIN X-----\n").sanitized
        #expect(creds.clientID == "SEARCHADS.abc")
        #expect(creds.keyID == "2e72ad71")
        #expect(creds.orgID == "1905")
        #expect(creds.privateKeyPEM == "-----BEGIN X-----")
    }
}
