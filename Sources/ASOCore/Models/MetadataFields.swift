import Foundation

/// The editable text fields of an App Store listing for one locale.
/// Name and subtitle live on `appInfoLocalizations`; the rest on
/// `appStoreVersionLocalizations`.
public struct MetadataFields: Sendable, Hashable, Codable {
    public var name: String
    public var subtitle: String
    public var keywords: String
    public var promotionalText: String
    public var description: String
    /// Release notes of the editable version ("What's New"); per locale, not indexed.
    public var whatsNew: String

    public init(name: String = "", subtitle: String = "", keywords: String = "",
                promotionalText: String = "", description: String = "", whatsNew: String = "") {
        self.name = name
        self.subtitle = subtitle
        self.keywords = keywords
        self.promotionalText = promotionalText
        self.description = description
        self.whatsNew = whatsNew
    }

    private enum CodingKeys: String, CodingKey { case name, subtitle, keywords, promotionalText, description, whatsNew }

    /// Drafts saved before `whatsNew` existed decode with an empty value.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        subtitle = try c.decodeIfPresent(String.self, forKey: .subtitle) ?? ""
        keywords = try c.decodeIfPresent(String.self, forKey: .keywords) ?? ""
        promotionalText = try c.decodeIfPresent(String.self, forKey: .promotionalText) ?? ""
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        whatsNew = try c.decodeIfPresent(String.self, forKey: .whatsNew) ?? ""
    }

    public static let empty = MetadataFields()

    public subscript(field: MetadataField) -> String {
        get {
            switch field {
            case .name: name
            case .subtitle: subtitle
            case .keywords: keywords
            case .promotionalText: promotionalText
            case .description: description
            case .whatsNew: whatsNew
            }
        }
        set {
            switch field {
            case .name: name = newValue
            case .subtitle: subtitle = newValue
            case .keywords: keywords = newValue
            case .promotionalText: promotionalText = newValue
            case .description: description = newValue
            case .whatsNew: whatsNew = newValue
            }
        }
    }

    /// Individual keywords from the comma-separated keyword field, trimmed, empties removed.
    public var keywordList: [String] {
        keywords.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
}

public enum MetadataField: String, CaseIterable, Sendable, Codable, Identifiable {
    case name, subtitle, keywords, promotionalText, description, whatsNew

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .name: "Name"
        case .subtitle: "Subtitle"
        case .keywords: "Keywords"
        case .promotionalText: "Promotional Text"
        case .description: "Description"
        case .whatsNew: "What's New"
        }
    }

    /// Apple's documented limit. Apple documents the keyword field as both "100
    /// characters" and "100 bytes"; both counters are shown to the user.
    public var limit: Int {
        switch self {
        case .name, .subtitle: 30
        case .keywords: 100
        case .promotionalText: 170
        case .description, .whatsNew: 4000
        }
    }

    /// Which ASC resource carries the field.
    public var resource: MetadataResource {
        switch self {
        case .name, .subtitle: .appInfoLocalization
        case .keywords, .promotionalText, .description, .whatsNew: .appStoreVersionLocalization
        }
    }

    public var isMultiline: Bool { self == .description || self == .promotionalText || self == .whatsNew }
}

public enum MetadataResource: String, Sendable, Codable {
    case appInfoLocalization = "appInfoLocalizations"
    case appStoreVersionLocalization = "appStoreVersionLocalizations"
}

/// A read-only snapshot of what Apple currently holds for one locale, with the
/// resource identifiers needed to write back safely.
public struct MetadataSnapshot: Sendable, Hashable, Codable {
    public let locale: AppLocale
    public let fields: MetadataFields
    public let appInfoLocalizationID: String?
    public let versionLocalizationID: String?
    public let versionString: String?
    public let versionState: String?
    public let fetchedAt: Date

    public init(locale: AppLocale, fields: MetadataFields, appInfoLocalizationID: String?,
                versionLocalizationID: String?, versionString: String?, versionState: String?, fetchedAt: Date) {
        self.locale = locale
        self.fields = fields
        self.appInfoLocalizationID = appInfoLocalizationID
        self.versionLocalizationID = versionLocalizationID
        self.versionString = versionString
        self.versionState = versionState
        self.fetchedAt = fetchedAt
    }

    /// Stable content hash used to detect that the baseline changed under us before applying.
    public var contentHash: String { MetadataHasher.hash(fields) }
}

public enum MetadataHasher {
    /// Deterministic, dependency-free hash of the field content (FNV-1a 64).
    public static func hash(_ fields: MetadataFields) -> String {
        let joined = MetadataField.allCases.map { "\($0.rawValue)=\(fields[$0])" }.joined(separator: "\u{1F}")
        var h: UInt64 = 0xcbf29ce484222325
        for byte in joined.utf8 {
            h ^= UInt64(byte)
            h = h &* 0x100000001b3
        }
        return String(h, radix: 16)
    }
}
