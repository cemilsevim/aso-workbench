import Foundation
import Observation
import WebKit
import ASOCore

/// Optional provider: Apple Ads dashboard popularity index (5–100 for any exact term, per storefront).
///
/// This is the number the Apple Ads web console shows; it is not part of the documented Platform
/// API. It is read through the user's own signed-in browser session inside a WebKit view, so the
/// app never sees or stores the password. The endpoint is undocumented and may change — when it
/// does, the documented layers (country lists, published-range bound) keep working.
@Observable
final class AppleAdsSessionService: NSObject {
    enum State: Equatable {
        case unknown, signedOut, signedIn(checkedAt: Date), failed(String)
        var isSignedIn: Bool { if case .signedIn = self { return true }; return false }
    }

    private(set) var state: State = .unknown
    private(set) var isBusy = false

    /// An app id (adamId) inside the Apple Ads account; the query needs one for context.
    var referenceAdamID: String {
        didSet { UserDefaults.standard.set(referenceAdamID, forKey: "adsSessionReferenceAdamID") }
    }

    private var webView: WKWebView?
    private var loadContinuation: CheckedContinuation<Void, Error>?
    private let credentials = CredentialStore()
    private var restoredCookies = false

    static let consoleURL = URL(string: "https://app-ads.apple.com/cm/app")!
    private static let graphQL = "https://app-ads.apple.com/reporting/graphql"

    override init() {
        referenceAdamID = UserDefaults.standard.string(forKey: "adsSessionReferenceAdamID") ?? ""
        super.init()
    }

    // MARK: Session

    /// Loads the console in a hidden web view and reads where it landed: the console itself means signed in,
    /// Apple's sign-in page means signed out.
    @discardableResult
    func checkSession() async -> Bool {
        isBusy = true
        defer { isBusy = false }
        await restoreCookiesIfNeeded()
        do {
            try await load(Self.consoleURL)
        } catch {
            state = .failed(error.localizedDescription)
            return false
        }
        let host = webView?.url?.host ?? ""
        let signedIn = host == "app-ads.apple.com"
        state = signedIn ? .signedIn(checkedAt: .now) : .signedOut
        if signedIn { await persistCookies() }
        return signedIn
    }

    // Apple's sign-in cookies are session cookies, which WebKit drops when the app quits.
    // They are copied to the Keychain after a successful check and put back on the next launch.
    private func persistCookies() async {
        let cookies = await WKWebsiteDataStore.default().httpCookieStore.allCookies()
        let apple = cookies.filter { $0.domain.contains("apple.com") }
        let encoded: [[String: String]] = apple.compactMap { c in
            guard let props = c.properties else { return nil }
            var out: [String: String] = [:]
            for (k, v) in props {
                if let d = v as? Date { out[k.rawValue] = "date:\(d.timeIntervalSince1970)" }
                else if let b = v as? Bool { out[k.rawValue] = b ? "TRUE" : "FALSE" }
                else { out[k.rawValue] = "\(v)" }
            }
            return out
        }
        try? credentials.saveAdsCookies(encoded)
    }

    private func restoreCookiesIfNeeded() async {
        guard !restoredCookies else { return }
        restoredCookies = true
        let store = WKWebsiteDataStore.default().httpCookieStore
        let existing = await store.allCookies()
        guard !existing.contains(where: { $0.domain.contains("apple.com") && $0.name.lowercased().contains("myacinfo") }),
              let saved = credentials.loadAdsCookies() else { return }
        var restored = 0
        for dict in saved {
            var props: [HTTPCookiePropertyKey: Any] = [:]
            for (k, v) in dict {
                if v.hasPrefix("date:"), let t = Double(v.dropFirst(5)) { props[HTTPCookiePropertyKey(k)] = Date(timeIntervalSince1970: t) }
                else if v == "TRUE" || v == "FALSE" { props[HTTPCookiePropertyKey(k)] = v == "TRUE" }
                else { props[HTTPCookiePropertyKey(k)] = v }
            }
            if let c = HTTPCookie(properties: props) {
                await store.setCookie(c)
                restored += 1
            }
        }
        AppLog.write("[session] restored \(restored) Apple session cookies")
    }

    func signOut() async {
        let store = WKWebsiteDataStore.default()
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        let records = await store.dataRecords(ofTypes: types)
        await store.removeData(ofTypes: types, for: records.filter { $0.displayName.contains("apple.com") })
        webView = nil
        try? credentials.saveAdsCookies(nil)
        state = .signedOut
    }

    // MARK: Popularity index

    /// Raw rows of the last query (name, popularity, matchType) for diagnostics.
    private(set) var lastRawRows: [[String: Any]] = []

    /// Exact-term popularity (5–100) for one storefront. Missing terms are absent from the result.
    func popularity(terms: [String], storefront: String, adamIDOverride: String? = nil) async throws -> [String: Int] {
        guard !terms.isEmpty else { return [:] }
        if webView?.url?.host != "app-ads.apple.com" {
            guard await checkSession() else { throw ASOError.notConfigured(service: "Apple Ads dashboard session") }
        }
        guard let webView else { throw ASOError.notConfigured(service: "Apple Ads dashboard session") }
        let adamID = (adamIDOverride ?? referenceAdamID).trimmingCharacters(in: .whitespaces)
        guard !adamID.isEmpty else { throw ASOError.invalidInput("Set a reference app id for the Apple Ads dashboard session (Connections).") }

        var out: [String: Int] = [:]
        for chunk in stride(from: 0, to: terms.count, by: 100).map({ Array(terms[$0..<min($0 + 100, terms.count)]) }) {
            let termsJSON = String(decoding: try JSONSerialization.data(withJSONObject: chunk), as: UTF8.self)
            let body = """
            const query = "query getKeywordPopularitiesGql($adamId: String!, $storefronts: [String!]!, $keywordTerms: [String!]!) { recommendationV2 { getKeywordPopularities(adamId: $adamId, storefronts: $storefronts, keywordTerms: $keywordTerms) { id name popularity matchType __typename } __typename } }";
            const r = await fetch("\(Self.graphQL)", { method: "POST", headers: { "Content-Type": "application/json" }, credentials: "include",
              body: JSON.stringify({ operationName: "getKeywordPopularitiesGql", variables: { adamId: "\(adamID)", storefronts: ["\(storefront.uppercased())"], keywordTerms: \(termsJSON) }, query }) });
            const text = await r.text();
            return JSON.stringify({ status: r.status, body: text.slice(0, 400000) });
            """
            let raw = try await webView.callAsyncJavaScript(body, arguments: [:], in: nil, contentWorld: .page)
            guard let s = raw as? String, let data = s.data(using: .utf8), let envelope = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let status = envelope["status"] as? Int, let bodyText = envelope["body"] as? String else {
                throw ASOError.decoding(service: "Apple Ads dashboard", detail: "No response from the console page.")
            }
            if status == 401 || status == 403 || bodyText.contains("<html") {
                state = .signedOut
                throw ASOError.unauthorized(service: "Apple Ads dashboard session")
            }
            guard status == 200, let json = try? JSONSerialization.jsonObject(with: Data(bodyText.utf8)) as? [String: Any] else {
                throw ASOError.http(service: "Apple Ads dashboard", status: status, message: String(bodyText.prefix(300)))
            }
            let rows = ((json["data"] as? [String: Any])?["recommendationV2"] as? [String: Any])?["getKeywordPopularities"] as? [[String: Any]] ?? []
            lastRawRows = rows
            for row in rows {
                guard let name = row["name"] as? String else { continue }
                let pop = (row["popularity"] as? Int) ?? (row["popularity"] as? Double).map(Int.init)
                if let pop { out[Self.normalize(name)] = pop }
            }
            state = .signedIn(checkedAt: .now)
        }
        return out
    }

    static func normalize(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    // MARK: WebKit plumbing

    private func makeWebView() -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let wv = WKWebView(frame: CGRect(x: 0, y: 0, width: 1200, height: 800), configuration: config)
        wv.navigationDelegate = self
        wv.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.4 Safari/605.1.15"
        return wv
    }

    private func load(_ url: URL) async throws {
        let wv = webView ?? makeWebView()
        webView = wv
        loadContinuation?.resume(throwing: CancellationError())
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            loadContinuation = cont
            wv.load(URLRequest(url: url, timeoutInterval: 30))
        }
        // Give the single-page app a moment to settle its own redirects.
        try? await Task.sleep(for: .milliseconds(800))
    }
}

extension AppleAdsSessionService: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loadContinuation?.resume()
        loadContinuation = nil
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        loadContinuation?.resume(throwing: error)
        loadContinuation = nil
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        loadContinuation?.resume(throwing: error)
        loadContinuation = nil
    }
}
