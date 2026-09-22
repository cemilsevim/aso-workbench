import Foundation

/// Runtime-validated capability flags for a provider:
/// documentation and community code disagree about what Apple accepts, so the
/// adapter records what actually worked and when.
public struct ProviderCapabilities: Sendable, Codable, Hashable {
    public var supportsTermFilter: Bool?
    public var supportsSort: Bool?
    public var maxPageSize: Int
    public var lastValidatedAt: Date?
    public var lastError: String?

    public init(supportsTermFilter: Bool? = nil, supportsSort: Bool? = nil, maxPageSize: Int = 200,
                lastValidatedAt: Date? = nil, lastError: String? = nil) {
        self.supportsTermFilter = supportsTermFilter
        self.supportsSort = supportsSort
        self.maxPageSize = maxPageSize
        self.lastValidatedAt = lastValidatedAt
        self.lastError = lastError
    }
}

/// Connection state shown in Settings. "Configured" does not imply "verified".
public enum ConnectionState: Sendable, Hashable {
    case notConfigured
    case configured
    case verified(at: Date, detail: String)
    case failed(String)

    public var isUsable: Bool {
        switch self {
        case .configured, .verified: true
        default: false
        }
    }
}
