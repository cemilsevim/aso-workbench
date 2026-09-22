import Foundation

/// Facts about the running build that several layers need (update checks, request attribution, the About box).
/// The bundle script writes them into Info.plist from `VERSION` and `ASO_REPOSITORY`; the fallbacks keep
/// `swift run` and tests working.
public enum AppInfo {
    /// "owner/repo" on GitHub where releases are published.
    public static var repository: String {
        (Bundle.main.object(forInfoDictionaryKey: "ASORepository") as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "mustafakendiguzel/aso-workbench"
    }
    public static var repositoryURL: URL { URL(string: "https://github.com/\(repository)")! }
    /// Marketing version, e.g. "1.0.0".
    public static var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0" }
    public static var build: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0" }
}

/// Semantic-version comparison for release tags ("v1.2.0", "1.2", "1.3.0-beta.1").
public struct SemanticVersion: Comparable, Sendable, CustomStringConvertible {
    public let parts: [Int]
    public let prerelease: String?

    public init?(_ raw: String) {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("v") || s.hasPrefix("V") { s.removeFirst() }
        let split = s.split(separator: "-", maxSplits: 1).map(String.init)
        let nums = split.first?.split(separator: ".").map { Int($0) } ?? []
        guard !nums.isEmpty, nums.allSatisfy({ $0 != nil }) else { return nil }
        parts = nums.map { $0! }
        prerelease = split.count > 1 ? split[1] : nil
    }

    public var description: String { parts.map(String.init).joined(separator: ".") + (prerelease.map { "-\($0)" } ?? "") }

    public static func < (a: SemanticVersion, b: SemanticVersion) -> Bool {
        for i in 0..<max(a.parts.count, b.parts.count) {
            let x = i < a.parts.count ? a.parts[i] : 0, y = i < b.parts.count ? b.parts[i] : 0
            if x != y { return x < y }
        }
        // 1.2.0-beta < 1.2.0
        switch (a.prerelease, b.prerelease) {
        case (nil, nil): return false
        case (.some, nil): return true
        case (nil, .some): return false
        case let (.some(p), .some(q)): return p < q
        }
    }

    public static func == (a: SemanticVersion, b: SemanticVersion) -> Bool { !(a < b) && !(b < a) }
}
