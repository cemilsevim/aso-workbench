import Foundation

/// One written App Store review as the public reviews feed reports it (per storefront, newest first, 50 per page).
public struct CustomerReview: Sendable, Hashable, Codable, Identifiable {
    public let id: String
    public let countryCode: String
    public let title: String
    public let body: String
    public let rating: Int
    public let author: String
    public let version: String?
    public let date: Date?

    public init(id: String, countryCode: String, title: String, body: String, rating: Int, author: String, version: String?, date: Date?) {
        self.id = id
        self.countryCode = countryCode
        self.title = title
        self.body = body
        self.rating = rating
        self.author = author
        self.version = version
        self.date = date
    }
}
