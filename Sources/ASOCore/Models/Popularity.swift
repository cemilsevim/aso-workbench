import Foundation

/// Apple Ads genres accepted by the search-term-popularity insight (fixed set,
/// upper-case with underscores; verified live 2026-08-16).
public enum AppleAdsGenre: String, CaseIterable, Sendable, Codable, Identifiable {
    case business = "BUSINESS"
    case education = "EDUCATION"
    case entertainment = "ENTERTAINMENT"
    case finance = "FINANCE"
    case foodDrink = "FOOD_DRINK"
    case games = "GAMES"
    case healthFitness = "HEALTH_FITNESS"
    case lifestyle = "LIFESTYLE"
    case newsPublication = "NEW_PUBLICATION"
    case photoVideo = "PHOTO_VIDEO"
    case productivityUtilities = "PRODUCTIVITY_UTILITIES"
    case shopping = "SHOPPING"
    case socialNetworking = "SOCIAL_NETWORKING"
    case sports = "SPORTS"
    case travel = "TRAVEL"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .newsPublication: "News & Publications"
        case .photoVideo: "Photo & Video"
        case .foodDrink: "Food & Drink"
        case .healthFitness: "Health & Fitness"
        case .productivityUtilities: "Productivity & Utilities"
        case .socialNetworking: "Social Networking"
        default: rawValue.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    /// Maps an App Store category name (as the iTunes Search API reports it) to Apple Ads' fixed genre list.
    /// Returns nil for categories without a counterpart (Graphics & Design, Medical, Music, Reference, Weather…).
    public init?(appStoreGenre: String?) {
        guard let g = appStoreGenre?.lowercased() else { return nil }
        switch g {
        case "business": self = .business
        case "education": self = .education
        case "entertainment": self = .entertainment
        case "finance": self = .finance
        case "food & drink": self = .foodDrink
        case "games": self = .games
        case "health & fitness": self = .healthFitness
        case "lifestyle": self = .lifestyle
        case "news", "magazines & newspapers", "books": self = .newsPublication
        case "photo & video": self = .photoVideo
        case "productivity", "utilities", "developer tools": self = .productivityUtilities
        case "shopping": self = .shopping
        case "social networking": self = .socialNetworking
        case "sports": self = .sports
        case "travel", "navigation": self = .travel
        default: return nil
        }
    }
}

/// Parses App Store links such as `https://apps.apple.com/tr/app/some-name/id123456789?l=en`.
public enum AppStoreURL {
    public struct Parsed: Sendable, Equatable {
        public let trackID: Int
        public let countryCode: String?
    }

    public static func parse(_ text: String) -> Parsed? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let id = Int(trimmed), id > 1000 { return Parsed(trackID: id, countryCode: nil) }
        guard trimmed.lowercased().contains("apple.com"), let match = trimmed.firstMatch(of: /\/id(\d{6,})/) else { return nil }
        guard let id = Int(match.1) else { return nil }
        let country = trimmed.firstMatch(of: /apple\.com\/([a-z]{2})\//.ignoresCase()).map { String($0.1).uppercased() }
        return Parsed(trackID: id, countryCode: country)
    }
}

/// A search-term popularity record from Apple Ads Platform API v1.
/// `popularity1to100` is relative *within the country*; it must not be compared across countries.
public struct PopularityRecord: Sendable, Hashable, Codable, Identifiable {
    public let searchTerm: String
    public let countryCode: String
    public let genre: AppleAdsGenre
    public let popularity1to100: Int?
    public let popularity1to5: Int?
    public let popularityInGenre: Int?
    public let rankInGenre: Int?
    /// First day of the period the record covers (monthly granularity).
    public let periodStart: Date
    public let periodEnd: Date
    public let fetchedAt: Date

    public var id: String { "\(countryCode)|\(genre.rawValue)|\(searchTerm)|\(periodStart.timeIntervalSince1970)" }

    public init(searchTerm: String, countryCode: String, genre: AppleAdsGenre, popularity1to100: Int?,
                popularity1to5: Int?, popularityInGenre: Int?, rankInGenre: Int?,
                periodStart: Date, periodEnd: Date, fetchedAt: Date) {
        self.searchTerm = searchTerm
        self.countryCode = countryCode
        self.genre = genre
        self.popularity1to100 = popularity1to100
        self.popularity1to5 = popularity1to5
        self.popularityInGenre = popularityInGenre
        self.rankInGenre = rankInGenre
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.fetchedAt = fetchedAt
    }
}

/// A keyword suggestion. `popularity` from Apple Ads is relative across all App
/// Store countries (no storefront in the response), so it is labelled as such.
public struct KeywordSuggestion: Sendable, Hashable, Codable, Identifiable {
    public let text: String
    public let provider: ProviderID
    public let origin: DataOrigin
    /// 0–100 when the provider supplies one; nil otherwise. Never zero-filled.
    public let popularity: Int?
    /// Position in the suggestion list (1-based): the only signal public hints give.
    public let position: Int
    public let fetchedAt: Date

    public var id: String { "\(provider.rawValue)|\(text)" }

    public init(text: String, provider: ProviderID, origin: DataOrigin, popularity: Int?, position: Int, fetchedAt: Date) {
        self.text = text
        self.provider = provider
        self.origin = origin
        self.popularity = popularity
        self.position = position
        self.fetchedAt = fetchedAt
    }
}
