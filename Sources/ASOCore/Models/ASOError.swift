import Foundation

/// Errors surfaced to the UI. Each case carries enough context to be shown as-is.
public enum ASOError: Error, LocalizedError, Sendable, Equatable {
    case notConfigured(service: String)
    case unauthorized(service: String)
    case rateLimited(service: String, retryAfterSeconds: Int?)
    case http(service: String, status: Int, message: String)
    case decoding(service: String, detail: String)
    case network(String)
    case invalidInput(String)
    case conflict(String)
    case unsupported(String)

    public var errorDescription: String? {
        switch self {
        case .notConfigured(let s): return "\(s) is not connected. Add credentials in Settings."
        case .unauthorized(let s):
            if s == "Apple Ads" {
                return "Apple rejected the signed client secret (invalid_client). The private key is not the pair of the public key uploaded at ads.apple.com → API, or the Client ID / Key ID belong to another key. Load the .pem that matches the uploaded public key."
            }
            if s == "App Store Connect" {
                return "App Store Connect rejected the token (401). Check that the .p8 file, Key ID and Issuer ID belong to the same team key and that the key is not revoked."
            }
            return "\(s) rejected the credentials (401/403)."
        case .rateLimited(let s, let retry):
            if let retry { return "\(s) rate limit reached. Retry after \(retry)s." }
            return "\(s) rate limit reached."
        case .http(let s, let status, let message): return "\(s) returned HTTP \(status): \(message)"
        case .decoding(let s, let detail): return "\(s) returned an unexpected response: \(detail)"
        case .network(let detail): return "Network error: \(detail)"
        case .invalidInput(let detail): return detail
        case .conflict(let detail): return detail
        case .unsupported(let detail): return detail
        }
    }
}
