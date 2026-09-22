import Foundation

/// Title ↔ term matching that survives spacing and punctuation differences: "my chart" matches "MyChart",
/// "e-bike" matches "ebike". Used by the competition signals and the difficulty score.
public enum TitleMatch {
    /// Lowercased letters and digits only.
    public static func compact(_ s: String) -> String {
        String(s.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
    }

    public static func contains(title: String, term: String) -> Bool {
        let t = term.lowercased().trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return false }
        if title.lowercased().contains(t) { return true }
        let ct = compact(term)
        return ct.count >= 3 && compact(title).contains(ct)
    }

    /// True when the top result's name and the term are the same name (one starts with the other, spacing aside):
    /// the search is navigational — people want that app, not a category.
    public static func namesAlign(leader: String, term: String) -> Bool {
        let a = compact(leader), b = compact(term)
        guard a.count >= 4, b.count >= 4 else { return false }
        if a.hasPrefix(b) || b.hasPrefix(a) { return true }
        // The leader's first name token (its brand position) inside the term: "koupon app amazon" ↔ "Koupon: Real Deals".
        let first = leader.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).first.map(String.init) ?? ""
        return first.count >= 5 && b.contains(first)
    }
}
