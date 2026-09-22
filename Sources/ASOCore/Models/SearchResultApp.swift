import Foundation

/// An app as it appears in a public search result list.
public struct SearchResultApp: Sendable, Hashable, Codable, Identifiable {
    public let trackID: Int
    public let bundleID: String?
    public let name: String
    public let sellerName: String
    public let iconURL: URL?
    public let averageRating: Double?
    public let ratingCount: Int?
    public let primaryGenre: String?
    public let releaseDate: Date?
    public let currentVersionReleaseDate: Date?
    public let price: Double?
    public let version: String?
    /// Store description (only filled by lookups, not by ranking searches, to keep observations small).
    public let storeDescription: String?

    public var id: Int { trackID }

    public init(trackID: Int, bundleID: String?, name: String, sellerName: String, iconURL: URL?,
                averageRating: Double?, ratingCount: Int?, primaryGenre: String?, releaseDate: Date?,
                currentVersionReleaseDate: Date?, price: Double?, version: String?, storeDescription: String? = nil) {
        self.trackID = trackID
        self.bundleID = bundleID
        self.name = name
        self.sellerName = sellerName
        self.iconURL = iconURL
        self.averageRating = averageRating
        self.ratingCount = ratingCount
        self.primaryGenre = primaryGenre
        self.releaseDate = releaseDate
        self.currentVersionReleaseDate = currentVersionReleaseDate
        self.price = price
        self.version = version
        self.storeDescription = storeDescription
    }
}
