import Foundation

/// Three different ways to count text length. Apple's documentation disagrees
/// with itself (100 characters vs 100 bytes for keywords), so we show all of them
/// instead of picking one silently.
public struct TextMeasure: Sendable, Hashable {
    public let codePoints: Int
    public let utf8Bytes: Int
    public let graphemes: Int

    public init(_ text: String) {
        codePoints = text.unicodeScalars.count
        utf8Bytes = text.utf8.count
        graphemes = text.count
    }

    /// True when the text is unambiguously within `limit` under every counting rule.
    public func fits(_ limit: Int) -> Bool { codePoints <= limit && utf8Bytes <= limit }

    /// True when at least one counting rule exceeds the limit but not all, the user must decide.
    public func isAmbiguous(_ limit: Int) -> Bool {
        (codePoints <= limit) != (utf8Bytes <= limit)
    }

    /// Multi-byte text (accents, CJK, emoji) makes the byte count diverge from code points.
    public var isMultiByte: Bool { utf8Bytes != codePoints }
}
