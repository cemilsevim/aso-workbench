import Foundation

/// App Store Connect API team key. Individual keys (`sub=user`) are not supported
/// in this version; the Settings screen says so.
public struct ASCCredentials: Sendable, Codable, Equatable {
    public var keyID: String
    public var issuerID: String
    /// Contents of the `AuthKey_XXXX.p8` file.
    public var privateKeyPEM: String

    public init(keyID: String, issuerID: String, privateKeyPEM: String) {
        self.keyID = keyID
        self.issuerID = issuerID
        self.privateKeyPEM = privateKeyPEM
    }

    public var isComplete: Bool { !keyID.isEmpty && !issuerID.isEmpty && !privateKeyPEM.isEmpty }

    public var sanitized: ASCCredentials {
        ASCCredentials(keyID: keyID.strippedIdentifier, issuerID: issuerID.strippedIdentifier, privateKeyPEM: privateKeyPEM.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
