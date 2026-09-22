import Foundation
import Testing
@testable import ASOProviders
import ASOCore

@Suite("App Store reviews feed parsing")
struct AppReviewsProviderTests {
    static let feed = """
    {"feed":{"entry":[
      {"im:name":{"label":"Some App"},"id":{"label":"123"},"title":{"label":"Some App"}},
      {"author":{"name":{"label":"Good girl"}},"updated":{"label":"2026-09-18T01:19:34-07:00"},"im:rating":{"label":"4"},"im:version":{"label":"26.17"},
       "id":{"label":"14563412880"},"title":{"label":"Signing in"},"content":{"label":"It’s fine.","attributes":{"type":"text"}}},
      {"author":{"name":{"label":"x"}},"updated":{"label":"2026-09-17T10:00:00-07:00"},"im:rating":{"label":"1"},"im:version":{"label":"26.16"},
       "id":{"label":"14563412881"},"title":{"label":"Crashes"},"content":{"label":"Crashes on launch"}}
    ]}}
    """

    @Test func parsesReviewsAndSkipsTheAppEntry() {
        let out = AppReviewsProvider.parse(Data(Self.feed.utf8), countryCode: "US")
        #expect(out.count == 2)
        #expect(out[0].rating == 4 && out[0].author == "Good girl" && out[0].version == "26.17" && out[0].title == "Signing in")
        #expect(out[0].date != nil)
        #expect(out[1].rating == 1 && out[1].body == "Crashes on launch")
    }

    @Test func singleEntryObjectAndEmptyBody() {
        let single = """
        {"feed":{"entry":{"author":{"name":{"label":"a"}},"updated":{"label":"2026-09-18T01:19:34-07:00"},"im:rating":{"label":"5"},"id":{"label":"1"},"title":{"label":"Great"},"content":{"label":"Love it"}}}}
        """
        #expect(AppReviewsProvider.parse(Data(single.utf8), countryCode: "DE").count == 1)
        #expect(AppReviewsProvider.parse(Data(), countryCode: "DE").isEmpty)
    }
}
