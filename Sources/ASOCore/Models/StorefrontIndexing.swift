import Foundation

/// Which App Store Connect localizations each storefront indexes for search (primary first). Only locales that share a
/// storefront compete for the same searches, so only those should avoid repeating each other's words.
/// Source: Apple's storefront localization table as compiled by AppTweak / AppFollow (2026); unknown storefronts fall
/// back to their default locale plus English (U.K.).
public enum StorefrontIndexing {
    static let table: [String: [String]] = [
        "US": ["en-US", "es-MX", "ru", "zh-Hans", "ar-SA", "fr-FR", "pt-BR", "zh-Hant", "vi", "ko"],
        "CA": ["en-CA", "fr-CA"],
        "GB": ["en-GB", "en-AU"], "AU": ["en-AU", "en-GB"], "NZ": ["en-AU", "en-GB"], "IE": ["en-GB"], "ZA": ["en-GB"], "PH": ["en-GB"], "SG": ["zh-Hans", "en-GB"], "IN": ["hi", "en-GB"],
        "DE": ["de-DE", "en-GB"], "AT": ["de-DE", "en-GB"], "CH": ["de-DE", "fr-FR", "it", "en-GB"],
        "FR": ["fr-FR", "en-GB"], "BE": ["nl-NL", "fr-FR", "en-GB"], "NL": ["nl-NL", "en-GB"], "LU": ["fr-FR", "de-DE", "en-GB"],
        "ES": ["es-ES", "ca", "en-GB"], "IT": ["it", "en-GB"], "PT": ["pt-PT", "en-GB"],
        "MX": ["es-MX", "en-GB"], "AR": ["es-MX", "en-GB"], "CL": ["es-MX", "en-GB"], "CO": ["es-MX", "en-GB"], "PE": ["es-MX", "en-GB"], "BR": ["pt-BR", "en-GB"],
        "JP": ["ja", "en-US"], "KR": ["ko", "en-GB"], "CN": ["zh-Hans", "en-GB"], "HK": ["zh-Hant", "en-GB"], "TW": ["zh-Hant", "en-GB"],
        "RU": ["ru", "uk", "en-GB"], "UA": ["uk", "ru", "en-GB"], "TR": ["tr", "en-GB"], "PL": ["pl", "en-GB"], "CZ": ["cs", "en-GB"], "SK": ["sk", "en-GB"],
        "HU": ["hu", "en-GB"], "RO": ["ro", "en-GB"], "GR": ["el", "en-GB"], "HR": ["hr", "en-GB"],
        "SE": ["sv", "en-GB"], "NO": ["no", "en-GB"], "DK": ["da", "en-GB"], "FI": ["fi", "en-GB"],
        "SA": ["ar-SA", "en-GB"], "AE": ["ar-SA", "en-GB"], "EG": ["ar-SA", "fr-FR", "en-GB"], "IL": ["he", "en-GB"],
        "ID": ["id", "en-GB"], "TH": ["th", "en-GB"], "VN": ["vi", "en-GB"], "MY": ["ms", "en-GB"],
    ]

    /// Locales indexed in a storefront, primary first.
    public static func indexedLocales(countryCode: String, fallbackPrimary: AppLocale? = nil) -> [AppLocale] {
        if let raw = table[countryCode.uppercased()] { return raw.compactMap(AppLocale.parse) }
        return [fallbackPrimary, .enGB].compactMap { $0 }
    }

    public static func primaryLocale(countryCode: String) -> AppLocale? { indexedLocales(countryCode: countryCode).first }

    public static func isIndexed(_ locale: AppLocale, in countryCode: String) -> Bool { indexedLocales(countryCode: countryCode).contains(locale) }
}
