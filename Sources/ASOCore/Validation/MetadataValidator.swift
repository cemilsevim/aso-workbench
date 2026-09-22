import Foundation

public enum ValidationSeverity: Int, Sendable, Comparable, Codable {
    case info = 0, warning = 1, error = 2
    public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
}

public struct ValidationIssue: Sendable, Hashable, Identifiable, Codable {
    public let field: MetadataField
    public let severity: ValidationSeverity
    public let message: String
    public var id: String { "\(field.rawValue)|\(severity.rawValue)|\(message)" }

    public init(field: MetadataField, severity: ValidationSeverity, message: String) {
        self.field = field
        self.severity = severity
        self.message = message
    }
}

/// Deterministic, explainable metadata checks. Heuristics (like stem overlap)
/// are deliberately absent: exact duplicates are reported, linguistic guesses are not.
public enum MetadataValidator {
    public static func validate(_ fields: MetadataFields) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        for field in MetadataField.allCases {
            let value = fields[field]
            let measure = TextMeasure(value)
            let limit = field.limit

            if measure.codePoints > limit && measure.utf8Bytes > limit {
                issues.append(.init(field: field, severity: .error,
                                    message: "\(field.title) is \(measure.codePoints) characters / \(measure.utf8Bytes) bytes; the limit is \(limit)."))
            } else if measure.isAmbiguous(limit) {
                issues.append(.init(field: field, severity: .warning,
                                    message: "\(field.title) is \(measure.codePoints) characters but \(measure.utf8Bytes) UTF-8 bytes. Apple documents the limit as both; verify against App Store Connect before relying on it."))
            }
            if value != value.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
                issues.append(.init(field: field, severity: .info, message: "\(field.title) has leading or trailing whitespace."))
            }
        }

        if fields.name.trimmingCharacters(in: .whitespaces).isEmpty {
            issues.append(.init(field: .name, severity: .error, message: "Name is required."))
        }

        issues.append(contentsOf: keywordIssues(fields))
        return issues.sorted { ($0.severity, $0.field.rawValue) > ($1.severity, $1.field.rawValue) }
    }

    private static func keywordIssues(_ fields: MetadataFields) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        let raw = fields.keywords
        guard !raw.isEmpty else { return issues }

        // Spaces around commas waste budget: "a, b" costs one more byte than "a,b".
        if raw.contains(", ") || raw.contains(" ,") {
            issues.append(.init(field: .keywords, severity: .info, message: "Spaces next to commas count against the 100-character budget. Use \"a,b\" instead of \"a, b\"."))
        }
        if raw.hasSuffix(",") || raw.hasPrefix(",") || raw.contains(",,") {
            issues.append(.init(field: .keywords, severity: .warning, message: "Empty keyword slots (leading, trailing or double commas)."))
        }

        let list = fields.keywordList
        let lowered = list.map { $0.lowercased() }

        // Exact duplicates inside the keyword field.
        var seen = Set<String>()
        var dups = Set<String>()
        for k in lowered where !seen.insert(k).inserted { dups.insert(k) }
        for d in dups.sorted() {
            issues.append(.init(field: .keywords, severity: .warning, message: "\"\(d)\" appears more than once in Keywords."))
        }

        // Exact word overlap with name / subtitle. Apple indexes those fields already,
        // so a repeated exact word adds no new coverage. Only exact matches: no stemming.
        let titleWords = Set((fields.name + " " + fields.subtitle)
            .lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init))
        for k in Set(lowered).sorted() where titleWords.contains(k) {
            issues.append(.init(field: .keywords, severity: .info, message: "\"\(k)\" already appears in Name or Subtitle; Apple indexes those fields, so this slot is likely redundant."))
        }

        // Multi-word keywords are legal but usually each word is indexed separately.
        for k in list where k.contains(" ") {
            issues.append(.init(field: .keywords, severity: .info, message: "\"\(k)\" contains a space. Apple indexes words individually; splitting it may free budget."))
        }
        return issues
    }

    public static func hasErrors(_ issues: [ValidationIssue]) -> Bool {
        issues.contains { $0.severity == .error }
    }
}
