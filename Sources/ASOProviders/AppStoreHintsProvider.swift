import Foundation
import ASOCore

/// App Store search autocomplete ("hints"). Public endpoint, storefront selected
/// through the `X-Apple-Store-Front` header. Apple removed the `priority` field in
/// 2026, so the only signal left is the position in the list.
public struct AppStoreHintsProvider: SuggestionProvider {
    public let id: ProviderID = .appStoreHints
    private let http = HTTPClient(serviceName: "App Store hints", allowedHosts: ["search.itunes.apple.com"])
    private let pacer: RequestPacer

    public init(pacer: RequestPacer = RequestPacer(minimumInterval: 1.5)) {
        self.pacer = pacer
    }

    public func suggestions(seed: String, storefront: Storefront) async throws -> [KeywordSuggestion] {
        await pacer.wait()
        var comps = URLComponents(string: "https://search.itunes.apple.com/WebObjects/MZSearchHints.woa/wa/hints")!
        comps.queryItems = [
            .init(name: "clientApplication", value: "Software"),
            .init(name: "term", value: seed),
            .init(name: "e", value: "true"),
            .init(name: "media", value: "software"),
        ]
        let request = HTTPClient.request(comps.url!, headers: [
            "X-Apple-Store-Front": storefront.storeFrontHeader,
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
        ])
        let response = try await http.send(request)
        try http.check(response)
        let now = Date()
        return try Self.parse(response.data).enumerated().map { index, term in
            KeywordSuggestion(text: term, provider: .appStoreHints, origin: .publicSearchObserved, popularity: nil, position: index + 1, fetchedAt: now)
        }
    }

    /// The endpoint answers with an XML property list: `{ hints: [ { term, url } ] }`.
    public static func parse(_ data: Data) throws -> [String] {
        if let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
           let hints = plist["hints"] as? [[String: Any]] {
            return hints.compactMap { $0["term"] as? String }.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        }
        // Fallback: tolerate slightly malformed plists by scanning for <key>term</key><string>…</string>.
        let text = String(decoding: data, as: UTF8.self)
        var out: [String] = []
        var search = text.startIndex
        while let keyRange = text.range(of: "<key>term</key>", range: search..<text.endIndex),
              let open = text.range(of: "<string>", range: keyRange.upperBound..<text.endIndex),
              let close = text.range(of: "</string>", range: open.upperBound..<text.endIndex) {
            out.append(String(text[open.upperBound..<close.lowerBound]).decodingXMLEntities)
            search = close.upperBound
        }
        if out.isEmpty && !text.contains("<plist") {
            throw ASOError.decoding(service: "App Store hints", detail: "Response was not a property list.")
        }
        return out
    }
}

extension String {
    var decodingXMLEntities: String {
        replacingOccurrences(of: "&amp;", with: "&").replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">").replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'").replacingOccurrences(of: "&#39;", with: "'")
    }
}
