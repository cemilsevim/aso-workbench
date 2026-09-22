import Foundation

/// The house ASO rules (docs/Comics_AI_ASO.pdf, generalised). They describe how Apple indexes a
/// listing and how the three indexed fields should be written. Pure functions, no network.
public enum ASORules {
    /// Apple indexes title + subtitle + keywords as one pool: 30 + 30 + 100 characters.
    public static let indexedBudget = 160

    /// Words with no search value that only burn characters.
    public static let fillerWords: Set<String> = [
        "app", "apps", "free", "best", "top", "new", "the", "a", "an", "and", "or", "of", "for", "with", "your", "my", "in", "on", "to", "by", "from",
        "&", "+", "pro", "plus", "hd", "lite", "official", "ultimate", "amazing", "easy", "simple", "fast", "great", "good",
        // tr / de / fr / es / pt
        "ve", "ile", "için", "en", "iyi", "ücretsiz", "uygulama", "uygulaması", "und", "mit", "für", "kostenlos", "beste", "et", "pour", "avec", "gratuit", "meilleur",
        "y", "con", "para", "gratis", "mejor", "e", "com", "grátis", "melhor",
    ]

    /// Words in a field, lower-cased, letters/digits only. `Inkwave: Manga Webtoon Maker` → [inkwave, manga, webtoon, maker].
    public static func words(_ text: String) -> [String] {
        text.lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    public struct Finding: Sendable, Hashable, Identifiable, Codable {
        public enum Kind: String, Sendable, Codable { case error, warning, info, good }
        public let kind: Kind
        public let rule: String
        public let message: String
        public var id: String { rule + "|" + message }
    }

    public struct Report: Sendable, Hashable {
        public let findings: [Finding]
        /// Distinct indexed words across the three fields.
        public let indexedWords: [String]
        public let charactersUsed: Int
        public var errors: Int { findings.filter { $0.kind == .error }.count }
        public var warnings: Int { findings.filter { $0.kind == .warning }.count }
        /// 0–100: share of rules satisfied (errors weigh double).
        public let score: Int
    }

    /// Checks one locale's fields against the rules. `siblingFields` are other locales indexed on the same
    /// storefront (e.g. es-MX beside en-US in the US store): their words should not overlap with this one.
    public static func review(_ f: MetadataFields, locale: AppLocale? = nil, siblings: [(AppLocale, MetadataFields)] = [], storefront: String? = nil) -> Report {
        var out: [Finding] = []
        let title = words(f.name), subtitle = words(f.subtitle)
        let keywordItems = f.keywordList
        let keywordWords = keywordItems.flatMap(words)

        // 1. Budget: 30 / 30 / 100, and how much of the 160-character pool is used.
        let used = f.name.count + f.subtitle.count + f.keywords.count
        if f.name.count > 30 { out.append(.init(kind: .error, rule: "Budget", message: "Title is \(f.name.count)/30 characters.")) }
        if f.subtitle.count > 30 { out.append(.init(kind: .error, rule: "Budget", message: "Subtitle is \(f.subtitle.count)/30 characters.")) }
        if f.keywords.count > 100 { out.append(.init(kind: .error, rule: "Budget", message: "Keywords are \(f.keywords.count)/100 characters.")) }
        if used < 140 { out.append(.init(kind: .warning, rule: "Budget", message: "Only \(used) of the 160 indexed characters are used; every unused character is a lost ranking chance.")) }
        else { out.append(.init(kind: .good, rule: "Budget", message: "\(used)/160 indexed characters used.")) }
        if f.keywords.count >= 95 && f.keywords.count <= 100 { out.append(.init(kind: .good, rule: "Keywords", message: "Keyword field is full (\(f.keywords.count)/100).")) }
        else if !f.keywords.isEmpty && f.keywords.count < 90 { out.append(.init(kind: .warning, rule: "Keywords", message: "Keyword field has \(100 - f.keywords.count) unused characters.")) }

        // 2. Zero repetition across fields: a word lives in exactly one field.
        let inTitle = Set(title), inSubtitle = Set(subtitle), inKeywords = Set(keywordWords)
        for w in inTitle.intersection(inSubtitle).sorted() { out.append(.init(kind: .error, rule: "Zero repetition", message: "“\(w)” is in both Title and Subtitle; each word should live in one field.")) }
        for w in inTitle.intersection(inKeywords).sorted() { out.append(.init(kind: .error, rule: "Zero repetition", message: "“\(w)” is in Title and again in Keywords.")) }
        for w in inSubtitle.intersection(inKeywords).sorted() { out.append(.init(kind: .error, rule: "Zero repetition", message: "“\(w)” is in Subtitle and again in Keywords.")) }
        var seen = Set<String>()
        for w in keywordWords where !seen.insert(w).inserted { out.append(.init(kind: .error, rule: "Zero repetition", message: "“\(w)” appears twice in Keywords.")) }

        // 3. Singular, no filler.
        for w in (title + subtitle + keywordWords) where fillerWords.contains(w) {
            out.append(.init(kind: .warning, rule: "No filler", message: "“\(w)” has no search value; use the characters for a real search word."))
        }
        if f.name.contains("&") || f.subtitle.contains("&") { out.append(.init(kind: .warning, rule: "No filler", message: "“&” is filler; Apple does not index it.")) }
        let allWords = Set(title + subtitle + keywordWords)
        for w in allWords where w.count > 3 && w.hasSuffix("s") && allWords.contains(String(w.dropLast())) {
            out.append(.init(kind: .warning, rule: "Singular", message: "Both “\(String(w.dropLast()))” and “\(w)” are present; Apple matches plurals from the singular."))
        }

        // 4. Keywords field shape: comma only, single words, no spaces.
        if f.keywords.contains(", ") || f.keywords.contains(" ,") { out.append(.init(kind: .error, rule: "Keywords", message: "Spaces next to commas waste characters: write “a,b” not “a, b”.")) }
        for item in keywordItems where item.contains(" ") {
            out.append(.init(kind: .warning, rule: "Keywords", message: "“\(item)” is a phrase; Apple cross-matches single words across fields, so split it and spend the saved characters on a new word."))
        }
        if f.keywords.hasSuffix(",") || f.keywords.contains(",,") { out.append(.init(kind: .warning, rule: "Keywords", message: "Empty keyword slot (trailing or double comma).")) }

        // 5. Title / subtitle structure.
        if title.isEmpty { out.append(.init(kind: .error, rule: "Title", message: "Title is empty.")) }
        if subtitle.isEmpty { out.append(.init(kind: .warning, rule: "Subtitle", message: "Subtitle is empty; it is both an indexed field and the first line users read in results.")) }
        if !f.name.contains(":") && !f.name.contains(" - ") && title.count >= 3 {
            out.append(.init(kind: .info, rule: "Title", message: "Title has no brand separator (“Brand: Feature words”); make sure the search words are still visible."))
        }

        // 6. Description is not indexed on the App Store.
        if !f.description.isEmpty {
            let descWords = Set(words(f.description))
            let onlyInDescription = descWords.subtracting(allWords).filter { $0.count > 4 && !fillerWords.contains($0) }
            if onlyInDescription.count > 40 && used < 140 {
                out.append(.init(kind: .info, rule: "Description", message: "The description is not indexed by the App Store; write it for conversion, and move any search words you rely on into the three indexed fields."))
            }
        }

        // 7. Locales indexed on the same storefront must not overlap. Only siblings that share the storefront count;
        //    when this locale is the storefront's primary, the secondary is the one that should change (info, not a penalty).
        let indexed = storefront.map { StorefrontIndexing.indexedLocales(countryCode: $0, fallbackPrimary: locale) }
        let primary = indexed?.first
        for (loc, sib) in siblings where indexed?.contains(loc) ?? true {
            let sibWords = Set(words(sib.name) + words(sib.subtitle) + sib.keywordList.flatMap(words))
            let overlap = allWords.intersection(sibWords).subtracting(fillerWords)
            guard !overlap.isEmpty else { continue }
            let list = overlap.sorted().prefix(6).joined(separator: ", ")
            if let primary, locale == primary {
                out.append(.init(kind: .info, rule: "Locale overlap", message: "\(loc.rawValue) repeats \(overlap.count) of these words (\(list)); rewrite \(loc.rawValue) to add new words — the primary listing keeps the best ones."))
            } else {
                out.append(.init(kind: .warning, rule: "Locale overlap", message: "\(overlap.count) word(s) also appear in \(loc.rawValue) (\(list)); a secondary locale should add new words, not repeat them."))
            }
        }

        let ordered = out.sorted { rank($0.kind) < rank($1.kind) }
        let penalty = ordered.reduce(0) { $0 + ($1.kind == .error ? 12 : $1.kind == .warning ? 5 : 0) }
        return Report(findings: ordered, indexedWords: Array(allWords).sorted(), charactersUsed: used, score: max(0, 100 - penalty))
    }

    private static func rank(_ k: Finding.Kind) -> Int {
        switch k { case .error: 0; case .warning: 1; case .info: 2; case .good: 3 }
    }

    /// The rules as text, for the AI assistant's instructions and for the Help sheet.
    public static let summary: String = """
    1. Apple indexes only Title (30), Subtitle (30) and Keywords (100): one pool of 160 characters. The description is not indexed on the App Store (it is on Google Play).
    2. Zero repetition: a word appears in exactly one of the three fields. A repeated word is a wasted character.
    3. Words are singular and without filler (app, free, best, &, from, with…). Apple matches plurals from the singular.
    4. Title is the heaviest field. Brand + feature when demand comes from the brand (social, ads); feature + brand (or no brand) when demand comes from search. A brand spelled as real words (e.g. "Pixel Notes") indexes those words.
    5. Subtitle never repeats a title word; it opens a new search intent and states the differentiator. It is visible under the title in results.
    6. Keywords: comma-separated single words, no spaces, no phrases; Apple cross-matches words across fields ("maker" in title + "comic","book" in keywords matches "comic book maker"). Use genres/terms the app really delivers. Fill to 95–100 characters.
    7. Each additional locale adds another 160 indexed characters. Secondary locales indexed on the same storefront (es-MX beside en-US in the US) get a non-overlapping English set. Native locales are written in the local language from local search behaviour, not translated.
    8. ASO is a process: change one field per 3-week cycle (keywords → subtitle → first screenshot → title), archive the listing and rank table before each change, and judge by rank movement and conversion (impression→page view ≥4%, page view→download ≥40%).
    """
}

// MARK: - Deterministic repair

public extension ASORules {
    struct RepairResult: Sendable, Hashable {
        public let fields: MetadataFields
        public let notes: [String]
    }

    /// Fixes what code can fix without judgement: the keyword field is rebuilt from single words,
    /// stripped of title/subtitle words, filler, duplicates and plural twins, packed to ≤100
    /// characters, and topped up from `fillers` (evidence-ranked words) when there is room.
    /// Title and subtitle are left to the model; only "&" and double spaces are cleaned.
    static func repair(_ input: MetadataFields, topUpWith fillers: [String] = []) -> RepairResult {
        var f = input
        var notes: [String] = []
        f.name = f.name.replacingOccurrences(of: " & ", with: " ").replacingOccurrences(of: "&", with: "").replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespaces)
        f.subtitle = f.subtitle.replacingOccurrences(of: " & ", with: ", ").replacingOccurrences(of: "&", with: "").replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespaces)
        if f.name != input.name || f.subtitle != input.subtitle { notes.append("Removed “&” (not indexed).") }

        let reserved = Set(words(f.name) + words(f.subtitle))
        var seen = Set<String>()
        var kept: [String] = []
        var dropped: [String] = []
        let rawItems = f.keywords.split(separator: ",").flatMap { $0.split(separator: " ") }.map { String($0).lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
        for w in rawItems + fillers.map({ $0.lowercased() }) {
            let clean = w.filter { $0.isLetter || $0.isNumber || $0 == "-" }
            guard clean.count >= 2 else { continue }
            // Model shorthand ("calend", "generat") is worthless in the index: drop obvious stubs of longer evidence words.
            if clean.count >= 5, fillers.contains(where: { $0.lowercased().hasPrefix(clean) && $0.count >= clean.count + 2 }), !fillers.contains(where: { $0.lowercased() == clean }) { dropped.append(clean); continue }
            if reserved.contains(clean) { dropped.append(clean); continue }
            // Plural twins of title/subtitle words: Apple matches "comics" from "comic" and vice versa.
            if clean.hasSuffix("s"), reserved.contains(String(clean.dropLast())) { dropped.append(clean); continue }
            if reserved.contains(clean + "s") { dropped.append(clean); continue }
            if fillerWords.contains(clean) { dropped.append(clean); continue }
            if !seen.insert(clean).inserted { continue }
            if clean.hasSuffix("s"), seen.contains(String(clean.dropLast())) { continue }
            if seen.contains(clean + "s") { kept.removeAll { $0 == clean + "s" }; seen.remove(clean + "s") }
            kept.append(clean)
        }
        // Pack to the 100-character budget in the given order (model's words first, evidence words after).
        var packed: [String] = []
        var length = 0
        for w in kept {
            let add = packed.isEmpty ? w.count : w.count + 1
            if length + add <= 100 { packed.append(w); length += add }
        }
        f.keywords = packed.joined(separator: ",")
        let unique = Array(Set(dropped)).sorted()
        if !unique.isEmpty { notes.append("Dropped from keywords (already in title/subtitle or filler): \(unique.joined(separator: ", ")).") }
        if kept.count > packed.count { notes.append("Trimmed \(kept.count - packed.count) word(s) to fit 100 characters.") }
        if input.keywords.count > 100 { notes.append("Keywords were \(input.keywords.count) characters; packed to \(f.keywords.count).") }
        if !fillers.isEmpty, packed.count > rawItems.count { notes.append("Topped up with evidence-ranked words.") }
        return RepairResult(fields: f, notes: notes)
    }
}
