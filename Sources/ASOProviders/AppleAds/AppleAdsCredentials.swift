import Foundation

/// Apple Ads Platform API v1 credentials (Account Settings → API in ads.apple.com).
public struct AppleAdsCredentials: Sendable, Codable, Equatable {
    public var clientID: String
    public var keyID: String
    public var orgID: String
    /// PEM text of the EC private key whose public half was uploaded to Apple Ads.
    public var privateKeyPEM: String

    public init(clientID: String, keyID: String, orgID: String, privateKeyPEM: String) {
        self.clientID = clientID
        self.keyID = keyID
        self.orgID = orgID
        self.privateKeyPEM = privateKeyPEM
    }

    public var isComplete: Bool {
        !clientID.isEmpty && !keyID.isEmpty && !orgID.isEmpty && !privateKeyPEM.isEmpty
    }

    /// Identifiers with every whitespace, newline and invisible character removed.
    public var sanitized: AppleAdsCredentials {
        AppleAdsCredentials(clientID: clientID.strippedIdentifier, keyID: keyID.strippedIdentifier, orgID: orgID.strippedIdentifier,
                            privateKeyPEM: privateKeyPEM.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

extension String {
    /// Removes whitespace, control and zero-width characters, pasted identifiers often carry a trailing newline.
    public var strippedIdentifier: String {
        filter { !$0.isWhitespace && !$0.isNewline && !($0.unicodeScalars.first.map { CharacterSet.controlCharacters.contains($0) || (0x200B...0x200F).contains($0.value) || $0.value == 0xFEFF } ?? false) }
    }
}
