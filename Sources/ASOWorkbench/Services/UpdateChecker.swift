import Foundation
import AppKit
import ASOCore
import ASOProviders

/// Tells people when a newer release is on GitHub. One unauthenticated request to api.github.com for the latest release
/// of `AppInfo.repository`; nothing about the user or their data is sent. The download itself happens in the browser.
@Observable
final class UpdateChecker {
    struct Release: Sendable, Equatable {
        let version: String
        let title: String
        let notes: String
        let pageURL: URL
        let downloadURL: URL?
        let publishedAt: Date?
    }

    enum Result: Equatable { case upToDate(String), available(Release), failed(String) }

    private(set) var available: Release?
    private(set) var lastResult: Result?
    private(set) var isChecking = false
    private let http = HTTPClient(serviceName: "GitHub releases", allowedHosts: ["api.github.com"])
    private let defaults = UserDefaults.standard

    var automatic: Bool {
        didSet { defaults.set(automatic, forKey: "updates.automatic") }
    }
    var lastChecked: Date? { defaults.object(forKey: "updates.lastChecked") as? Date }
    var skippedVersion: String? {
        get { defaults.string(forKey: "updates.skipped") }
        set { defaults.set(newValue, forKey: "updates.skipped") }
    }

    init() {
        automatic = defaults.object(forKey: "updates.automatic") as? Bool ?? true
    }

    /// At most once a day, and only when automatic checks are on.
    func checkIfDue() async {
        guard automatic else { return }
        if let last = lastChecked, Date.now.timeIntervalSince(last) < 20 * 3600 { return }
        await check(userInitiated: false)
    }

    @discardableResult
    func check(userInitiated: Bool) async -> Result {
        guard !isChecking else { return lastResult ?? .failed("Already checking") }
        isChecking = true
        defer { isChecking = false }
        let result: Result
        do {
            let url = URL(string: "https://api.github.com/repos/\(AppInfo.repository)/releases/latest")!
            let response = try await http.send(HTTPClient.request(url, headers: ["Accept": "application/vnd.github+json", "User-Agent": "ASO-Workbench/\(AppInfo.version)"], timeout: 20))
            if response.status == 404 {
                result = .upToDate(AppInfo.version)   // no release published yet
            } else {
                try http.check(response)
                guard let json = try JSONSerialization.jsonObject(with: response.data) as? [String: Any], let tag = json["tag_name"] as? String,
                      let latest = SemanticVersion(tag), let current = SemanticVersion(AppInfo.version) else {
                    throw ASOError.decoding(service: "GitHub", detail: "Unexpected release format.")
                }
                if latest > current {
                    let assets = json["assets"] as? [[String: Any]] ?? []
                    // The disk image is the normal download; the zip is the fallback.
                    let asset = assets.first { ($0["name"] as? String ?? "").hasSuffix(".dmg") } ?? assets.first { ($0["name"] as? String ?? "").hasSuffix(".zip") }
                    let zip = asset?["browser_download_url"] as? String
                    let iso = ISO8601DateFormatter()
                    let release = Release(version: latest.description, title: json["name"] as? String ?? tag, notes: json["body"] as? String ?? "",
                                          pageURL: URL(string: json["html_url"] as? String ?? "") ?? AppInfo.repositoryURL.appendingPathComponent("releases"),
                                          downloadURL: zip.flatMap(URL.init(string:)), publishedAt: (json["published_at"] as? String).flatMap(iso.date(from:)))
                    result = .available(release)
                } else {
                    result = .upToDate(AppInfo.version)
                }
            }
            defaults.set(Date.now, forKey: "updates.lastChecked")
        } catch {
            result = .failed(error.localizedDescription)
        }
        lastResult = result
        if case .available(let r) = result, userInitiated || r.version != skippedVersion { available = r } else if case .upToDate = result { available = nil }
        AppLog.write("[updates] \(result)")
        return result
    }

    func skip(_ release: Release) {
        skippedVersion = release.version
        available = nil
    }

    /// Opens GitHub in the browser; only github.com URLs are ever opened.
    func open(_ url: URL) {
        guard url.scheme == "https", let host = url.host, host == "github.com" || host.hasSuffix(".github.com") || host.hasSuffix("githubusercontent.com") else { return }
        NSWorkspace.shared.open(url)
    }
}
