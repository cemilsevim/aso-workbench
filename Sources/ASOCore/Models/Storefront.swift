import Foundation

/// A country-level App Store storefront. Storefront and locale are deliberately
/// separate concepts (see: `JP` storefront with `ja` locale,
/// `CH` storefront with `de-DE` locale, etc.
public struct Storefront: Hashable, Sendable, Identifiable, Codable {
    /// ISO 3166-1 alpha-2 country code in upper case, e.g. "US", "TR".
    public let countryCode: String
    /// Human readable country name (English).
    public let name: String
    /// Apple's numeric storefront identifier used by the `X-Apple-Store-Front` header.
    public let appleStorefrontID: Int
    /// The App Store Connect locale most commonly used for this storefront.
    public let defaultLocale: AppLocale

    public var id: String { countryCode }

    /// Value for the `X-Apple-Store-Front` header. `-1,29` selects the JSON/plist
    /// flavour of the search-hints endpoint used by public autocomplete.
    public var storeFrontHeader: String { "\(appleStorefrontID)-1,29" }

    /// Lower-case country code as expected by the iTunes Search API.
    public var searchCountry: String { countryCode.lowercased() }

    public init(countryCode: String, name: String, appleStorefrontID: Int, defaultLocale: AppLocale) {
        self.countryCode = countryCode.uppercased()
        self.name = name
        self.appleStorefrontID = appleStorefrontID
        self.defaultLocale = defaultLocale
    }
}

/// Central registry of known storefronts. Unknown country codes are never
/// silently mapped to US; `lookup` returns nil instead.
public enum StorefrontRegistry {
    public static let all: [Storefront] = [
        .init(countryCode: "US", name: "United States", appleStorefrontID: 143441, defaultLocale: .enUS),
        .init(countryCode: "GB", name: "United Kingdom", appleStorefrontID: 143444, defaultLocale: .enGB),
        .init(countryCode: "CA", name: "Canada", appleStorefrontID: 143455, defaultLocale: .enCA),
        .init(countryCode: "AU", name: "Australia", appleStorefrontID: 143460, defaultLocale: .enAU),
        .init(countryCode: "NZ", name: "New Zealand", appleStorefrontID: 143461, defaultLocale: .enAU),
        .init(countryCode: "IE", name: "Ireland", appleStorefrontID: 143449, defaultLocale: .enGB),
        .init(countryCode: "DE", name: "Germany", appleStorefrontID: 143443, defaultLocale: .deDE),
        .init(countryCode: "AT", name: "Austria", appleStorefrontID: 143445, defaultLocale: .deDE),
        .init(countryCode: "CH", name: "Switzerland", appleStorefrontID: 143459, defaultLocale: .deDE),
        .init(countryCode: "FR", name: "France", appleStorefrontID: 143442, defaultLocale: .frFR),
        .init(countryCode: "BE", name: "Belgium", appleStorefrontID: 143446, defaultLocale: .nlNL),
        .init(countryCode: "NL", name: "Netherlands", appleStorefrontID: 143452, defaultLocale: .nlNL),
        .init(countryCode: "ES", name: "Spain", appleStorefrontID: 143454, defaultLocale: .esES),
        .init(countryCode: "PT", name: "Portugal", appleStorefrontID: 143453, defaultLocale: .ptPT),
        .init(countryCode: "IT", name: "Italy", appleStorefrontID: 143450, defaultLocale: .it),
        .init(countryCode: "GR", name: "Greece", appleStorefrontID: 143448, defaultLocale: .el),
        .init(countryCode: "TR", name: "Türkiye", appleStorefrontID: 143480, defaultLocale: .tr),
        .init(countryCode: "PL", name: "Poland", appleStorefrontID: 143478, defaultLocale: .pl),
        .init(countryCode: "CZ", name: "Czechia", appleStorefrontID: 143489, defaultLocale: .cs),
        .init(countryCode: "SK", name: "Slovakia", appleStorefrontID: 143496, defaultLocale: .sk),
        .init(countryCode: "HU", name: "Hungary", appleStorefrontID: 143482, defaultLocale: .hu),
        .init(countryCode: "RO", name: "Romania", appleStorefrontID: 143487, defaultLocale: .ro),
        .init(countryCode: "UA", name: "Ukraine", appleStorefrontID: 143492, defaultLocale: .uk),
        .init(countryCode: "RU", name: "Russia", appleStorefrontID: 143469, defaultLocale: .ru),
        .init(countryCode: "SE", name: "Sweden", appleStorefrontID: 143456, defaultLocale: .sv),
        .init(countryCode: "NO", name: "Norway", appleStorefrontID: 143457, defaultLocale: .no),
        .init(countryCode: "DK", name: "Denmark", appleStorefrontID: 143458, defaultLocale: .da),
        .init(countryCode: "FI", name: "Finland", appleStorefrontID: 143447, defaultLocale: .fi),
        .init(countryCode: "JP", name: "Japan", appleStorefrontID: 143462, defaultLocale: .ja),
        .init(countryCode: "KR", name: "South Korea", appleStorefrontID: 143466, defaultLocale: .ko),
        .init(countryCode: "CN", name: "China mainland", appleStorefrontID: 143465, defaultLocale: .zhHans),
        .init(countryCode: "TW", name: "Taiwan", appleStorefrontID: 143470, defaultLocale: .zhHant),
        .init(countryCode: "HK", name: "Hong Kong", appleStorefrontID: 143463, defaultLocale: .zhHant),
        .init(countryCode: "SG", name: "Singapore", appleStorefrontID: 143464, defaultLocale: .enGB),
        .init(countryCode: "MY", name: "Malaysia", appleStorefrontID: 143473, defaultLocale: .ms),
        .init(countryCode: "TH", name: "Thailand", appleStorefrontID: 143475, defaultLocale: .th),
        .init(countryCode: "ID", name: "Indonesia", appleStorefrontID: 143476, defaultLocale: .id),
        .init(countryCode: "PH", name: "Philippines", appleStorefrontID: 143474, defaultLocale: .enUS),
        .init(countryCode: "VN", name: "Vietnam", appleStorefrontID: 143471, defaultLocale: .vi),
        .init(countryCode: "IN", name: "India", appleStorefrontID: 143467, defaultLocale: .enGB),
        .init(countryCode: "MX", name: "Mexico", appleStorefrontID: 143468, defaultLocale: .esMX),
        .init(countryCode: "BR", name: "Brazil", appleStorefrontID: 143503, defaultLocale: .ptBR),
        .init(countryCode: "AR", name: "Argentina", appleStorefrontID: 143505, defaultLocale: .esMX),
        .init(countryCode: "CL", name: "Chile", appleStorefrontID: 143483, defaultLocale: .esMX),
        .init(countryCode: "CO", name: "Colombia", appleStorefrontID: 143501, defaultLocale: .esMX),
        .init(countryCode: "PE", name: "Peru", appleStorefrontID: 143507, defaultLocale: .esMX),
        .init(countryCode: "ZA", name: "South Africa", appleStorefrontID: 143472, defaultLocale: .enGB),
        .init(countryCode: "SA", name: "Saudi Arabia", appleStorefrontID: 143479, defaultLocale: .arSA),
        .init(countryCode: "AE", name: "United Arab Emirates", appleStorefrontID: 143481, defaultLocale: .arSA),
        .init(countryCode: "EG", name: "Egypt", appleStorefrontID: 143516, defaultLocale: .arSA),
        .init(countryCode: "IL", name: "Israel", appleStorefrontID: 143491, defaultLocale: .he),
    ]

    private static let byCode: [String: Storefront] = Dictionary(uniqueKeysWithValues: all.map { ($0.countryCode, $0) })

    /// Exact lookup by ISO country code. Returns nil for unknown codes — callers
    /// must surface that instead of defaulting to another market.
    public static func lookup(_ countryCode: String) -> Storefront? {
        byCode[countryCode.uppercased()]
    }

    public static var sortedByName: [Storefront] { all.sorted { $0.name < $1.name } }
}
