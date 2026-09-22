import Foundation

/// App Store Connect localization identifiers. The raw value is exactly what the
/// ASC API expects in `attributes.locale`.
public enum AppLocale: String, CaseIterable, Sendable, Codable, Identifiable, Hashable {
    case enUS = "en-US", enGB = "en-GB", enAU = "en-AU", enCA = "en-CA"
    case deDE = "de-DE", frFR = "fr-FR", frCA = "fr-CA"
    case esES = "es-ES", esMX = "es-MX"
    case it, nlNL = "nl-NL", ptBR = "pt-BR", ptPT = "pt-PT"
    case ja, ko, zhHans = "zh-Hans", zhHant = "zh-Hant"
    case tr, ru, pl, uk, cs, sk, hu, ro, el
    case sv, no, da, fi
    case arSA = "ar-SA", he, hi, id, ms, th, vi, ca, hr

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .enUS: "English (U.S.)"
        case .enGB: "English (U.K.)"
        case .enAU: "English (Australia)"
        case .enCA: "English (Canada)"
        case .deDE: "German"
        case .frFR: "French"
        case .frCA: "French (Canada)"
        case .esES: "Spanish (Spain)"
        case .esMX: "Spanish (Mexico)"
        case .it: "Italian"
        case .nlNL: "Dutch"
        case .ptBR: "Portuguese (Brazil)"
        case .ptPT: "Portuguese (Portugal)"
        case .ja: "Japanese"
        case .ko: "Korean"
        case .zhHans: "Chinese (Simplified)"
        case .zhHant: "Chinese (Traditional)"
        case .tr: "Turkish"
        case .ru: "Russian"
        case .pl: "Polish"
        case .uk: "Ukrainian"
        case .cs: "Czech"
        case .sk: "Slovak"
        case .hu: "Hungarian"
        case .ro: "Romanian"
        case .el: "Greek"
        case .sv: "Swedish"
        case .no: "Norwegian"
        case .da: "Danish"
        case .fi: "Finnish"
        case .arSA: "Arabic"
        case .he: "Hebrew"
        case .hi: "Hindi"
        case .id: "Indonesian"
        case .ms: "Malay"
        case .th: "Thai"
        case .vi: "Vietnamese"
        case .ca: "Catalan"
        case .hr: "Croatian"
        }
    }

    /// Parses an ASC locale string leniently (case-insensitive); nil when unknown.
    public static func parse(_ raw: String) -> AppLocale? {
        let lowered = raw.lowercased()
        return allCases.first { $0.rawValue.lowercased() == lowered }
    }
}
