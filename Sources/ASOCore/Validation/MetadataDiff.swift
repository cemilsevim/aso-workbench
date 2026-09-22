import Foundation

/// One field that differs between the baseline (what Apple holds) and the draft.
public struct FieldChange: Sendable, Hashable, Identifiable, Codable {
    public let field: MetadataField
    public let before: String
    public let after: String
    public var id: String { field.rawValue }

    public init(field: MetadataField, before: String, after: String) {
        self.field = field
        self.before = before
        self.after = after
    }
}

public enum MetadataDiff {
    /// Field-level differences. Whitespace-only differences are still differences;
    /// the user sees exactly what will be sent.
    public static func changes(baseline: MetadataFields, draft: MetadataFields) -> [FieldChange] {
        MetadataField.allCases.compactMap { field in
            let a = baseline[field], b = draft[field]
            return a == b ? nil : FieldChange(field: field, before: a, after: b)
        }
    }

    /// Keyword-level view of a keywords change: kept, added, removed (exact, case-insensitive).
    public struct KeywordDelta: Sendable, Hashable {
        public let kept: [String]
        public let added: [String]
        public let removed: [String]
    }

    public static func keywordDelta(before: String, after: String) -> KeywordDelta {
        let a = MetadataFields(keywords: before).keywordList
        let b = MetadataFields(keywords: after).keywordList
        let aSet = Set(a.map { $0.lowercased() })
        let bSet = Set(b.map { $0.lowercased() })
        return KeywordDelta(
            kept: b.filter { aSet.contains($0.lowercased()) },
            added: b.filter { !aSet.contains($0.lowercased()) },
            removed: a.filter { !bSet.contains($0.lowercased()) }
        )
    }
}
