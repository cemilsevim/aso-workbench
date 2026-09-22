import Foundation

/// Where a number came from. Never collapse these into a single "score" — the
/// research plan requires the origin to be visible next to every metric.
public enum DataOrigin: String, Sendable, Codable, CaseIterable {
    /// Apple's own API (Apple Ads Platform API v1, App Store Connect).
    case officialObserved = "official_observed"
    /// Public, unauthenticated App Store endpoints (iTunes Search, search hints).
    case publicSearchObserved = "public_search_observed"
    /// Computed by us from other observations (competition signals).
    case derived = "derived"
    /// Provider was not configured or returned no record. This is not zero.
    case unavailable = "unavailable"

    public var label: String {
        switch self {
        case .officialObserved: "Apple (official)"
        case .publicSearchObserved: "Public search"
        case .derived: "Derived"
        case .unavailable: "Unavailable"
        }
    }
}

/// Identifies a concrete provider implementation so history from different
/// providers is never silently merged.
public struct ProviderID: RawRepresentable, Hashable, Sendable, Codable, ExpressibleByStringLiteral {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }

    public static let itunesSearch: ProviderID = "itunes-search"
    public static let appStoreHints: ProviderID = "appstore-hints"
    public static let appleAdsPopularity: ProviderID = "apple-ads-v1-popularity"
    public static let appleAdsSuggestions: ProviderID = "apple-ads-v1-suggestions"
    public static let appStoreConnect: ProviderID = "asc-v1"
}

/// Device context of a search observation. iPhone, iPad and Mac results differ.
public enum DeviceContext: String, Sendable, Codable, CaseIterable {
    case iPhone = "iphone"
    case iPad = "ipad"
    case mac = "mac"

    /// `entity` parameter of the iTunes Search API.
    public var itunesEntity: String {
        switch self {
        case .iPhone: "software"
        case .iPad: "iPadSoftware"
        case .mac: "macSoftware"
        }
    }

    public var label: String {
        switch self {
        case .iPhone: "iPhone"
        case .iPad: "iPad"
        case .mac: "Mac"
        }
    }
}
