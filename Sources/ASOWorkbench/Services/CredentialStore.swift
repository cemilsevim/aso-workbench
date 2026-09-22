import Foundation
import ASOProviders

/// Stores API credentials in a 0600 JSON file inside the app's Application Support folder.
///
/// Why not the Keychain: this app is ad-hoc signed and rebuilt often; every rebuild changes the
/// code signature, so macOS re-prompts for every Keychain item and blocks unattended runs. The
/// file is readable only by the user account. Existing Keychain items are migrated on first read.
struct CredentialStore {
    enum Account: String { case appStoreConnect = "asc", appleAds = "apple-ads", openRouter = "openrouter", adsCookies = "ads-session-cookies", revenueCat = "revenuecat" }
    struct RevenueCatKeys: Codable { var keys: [String] }

    struct OpenRouterKey: Codable { var apiKey: String }

    nonisolated static var fileURL: URL {
        PersistenceController.storeURL.deletingLastPathComponent().appendingPathComponent("credentials.json")
    }

    func loadASC() -> ASCCredentials? { load(.appStoreConnect) }
    func loadAppleAds() -> AppleAdsCredentials? { load(.appleAds) }
    func loadOpenRouterKey() -> String? { (load(.openRouter) as OpenRouterKey?)?.apiKey }
    func loadAdsCookies() -> [[String: String]]? { load(.adsCookies) }
    func loadRevenueCatKeys() -> [String] { ((load(.revenueCat) as RevenueCatKeys?)?.keys ?? []).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty } }
    func saveRevenueCatKeys(_ keys: [String]) throws { try save(keys.isEmpty ? nil : RevenueCatKeys(keys: keys), account: .revenueCat) }

    func save(_ creds: ASCCredentials?) throws { try save(creds, account: .appStoreConnect) }
    func save(_ creds: AppleAdsCredentials?) throws { try save(creds, account: .appleAds) }
    func saveOpenRouterKey(_ key: String?) throws { try save(key.map(OpenRouterKey.init), account: .openRouter) }
    func saveAdsCookies(_ cookies: [[String: String]]?) throws { try save(cookies, account: .adsCookies) }

    // MARK: File

    private func readAll() -> [String: Any] {
        guard let data = try? Data(contentsOf: Self.fileURL), let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return json
    }

    private func writeAll(_ dict: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: dict)
        // Owner-only: the folder 700, the file 600, written atomically so a crash never leaves half a key.
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: Self.fileURL.deletingLastPathComponent().path)
        try data.write(to: Self.fileURL, options: [.atomic, .completeFileProtection])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: Self.fileURL.path)
    }

    private func load<T: Decodable>(_ account: Account) -> T? {
        let all = readAll()
        if let raw = all[account.rawValue], let data = try? JSONSerialization.data(withJSONObject: raw), let v = try? JSONDecoder().decode(T.self, from: data) {
            return v
        }
        return nil
    }

    private func save<T: Encodable>(_ value: T?, account: Account) throws {
        var all = readAll()
        if let value {
            let data = try JSONEncoder().encode(value)
            all[account.rawValue] = try JSONSerialization.jsonObject(with: data)
        } else {
            all.removeValue(forKey: account.rawValue)
        }
        try writeAll(all)
    }
}
