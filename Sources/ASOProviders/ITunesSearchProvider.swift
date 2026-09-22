import Foundation
import ASOCore

/// Public iTunes Search API. No authentication. Results are a *proxy* for App Store
/// search ranking and are labelled as such; they are not equal to on-device results.
public struct ITunesSearchProvider: SearchRankProvider {
    public let id: ProviderID = .itunesSearch
    private let http = HTTPClient(serviceName: "iTunes Search", allowedHosts: ["itunes.apple.com"])
    private let pacer: RequestPacer

    public init(pacer: RequestPacer = RequestPacer(minimumInterval: 3.1)) {
        self.pacer = pacer
    }

    public func search(term: String, storefront: Storefront, device: DeviceContext, limit: Int) async throws -> [SearchResultApp] {
        try await query([
            "term": term, "country": storefront.searchCountry, "entity": device.itunesEntity, "limit": String(limit),
        ])
    }

    public func lookup(term: String, storefront: Storefront, limit: Int) async throws -> [SearchResultApp] {
        try await query(["term": term, "country": storefront.searchCountry, "entity": "software", "limit": String(limit)])
    }

    public func lookup(trackID: Int, storefront: Storefront) async throws -> SearchResultApp? {
        await pacer.wait()
        var comps = URLComponents(string: "https://itunes.apple.com/lookup")!
        comps.queryItems = [.init(name: "id", value: String(trackID)), .init(name: "country", value: storefront.searchCountry), .init(name: "entity", value: "software")]
        let response = try await http.send(HTTPClient.request(comps.url!))
        try http.check(response)
        return try Self.parse(response.data, keepDescription: true).first
    }

    private func query(_ params: [String: String]) async throws -> [SearchResultApp] {
        await pacer.wait()
        var comps = URLComponents(string: "https://itunes.apple.com/search")!
        comps.queryItems = params.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        let response = try await http.send(HTTPClient.request(comps.url!))
        try http.check(response)
        return try Self.parse(response.data)
    }

    // MARK: Parsing

    struct Envelope: Decodable { let results: [Row] }
    struct Row: Decodable {
        let trackId: Int
        let bundleId: String?
        let trackName: String
        let artistName: String?
        let sellerName: String?
        let artworkUrl100: String?
        let averageUserRating: Double?
        let userRatingCount: Int?
        let primaryGenreName: String?
        let releaseDate: Date?
        let currentVersionReleaseDate: Date?
        let price: Double?
        let version: String?
        let description: String?
    }

    public static func parse(_ data: Data, keepDescription: Bool = false) throws -> [SearchResultApp] {
        do {
            return try JSON.decoder.decode(Envelope.self, from: data).results.map {
                SearchResultApp(
                    trackID: $0.trackId, bundleID: $0.bundleId, name: $0.trackName,
                    sellerName: $0.sellerName ?? $0.artistName ?? "", iconURL: $0.artworkUrl100.flatMap(URL.init(string:)),
                    averageRating: $0.averageUserRating, ratingCount: $0.userRatingCount, primaryGenre: $0.primaryGenreName,
                    releaseDate: $0.releaseDate, currentVersionReleaseDate: $0.currentVersionReleaseDate, price: $0.price, version: $0.version,
                    storeDescription: keepDescription ? $0.description : nil)
            }
        } catch {
            throw ASOError.decoding(service: "iTunes Search", detail: String(describing: error))
        }
    }
}
