import Testing
@testable import ASOCore

@Suite("Metadata validation")
struct MetadataValidatorTests {
    @Test("Code points and UTF-8 bytes are counted separately")
    func textMeasure() {
        let m = TextMeasure(String(repeating: "界", count: 34))
        #expect(m.codePoints == 34)
        #expect(m.utf8Bytes == 102)
        #expect(m.isAmbiguous(100))
        #expect(!m.fits(100))
        let ascii = TextMeasure("expense tracker")
        #expect(ascii.fits(100))
        #expect(!ascii.isMultiByte)
    }

    @Test("Ambiguous keyword length is a warning, not an error")
    func ambiguousLimit() {
        let fields = MetadataFields(name: "Flow", keywords: String(repeating: "界", count: 34))
        let issues = MetadataValidator.validate(fields)
        #expect(issues.contains { $0.field == .keywords && $0.severity == .warning })
        #expect(!MetadataValidator.hasErrors(issues))
    }

    @Test("Hard overflow is an error")
    func overflow() {
        let issues = MetadataValidator.validate(MetadataFields(name: String(repeating: "a", count: 31)))
        #expect(MetadataValidator.hasErrors(issues))
    }

    @Test("Only exact duplicates are reported — no stemming (Flow vs flower)")
    func noStemming() {
        let fields = MetadataFields(name: "Flow", subtitle: "Focus timer", keywords: "flower,timer,focus,timer")
        let issues = MetadataValidator.validate(fields)
        let messages = issues.map(\.message)
        #expect(!messages.contains { $0.contains("\"flower\"") })
        #expect(messages.contains { $0.contains("\"timer\" appears more than once") })
        #expect(messages.contains { $0.contains("\"focus\" already appears") })
    }

    @Test("Comma spacing and empty slots are flagged")
    func commaRules() {
        let issues = MetadataValidator.validate(MetadataFields(name: "X", keywords: "a, b,,c,"))
        #expect(issues.contains { $0.message.contains("Spaces next to commas") })
        #expect(issues.contains { $0.message.contains("Empty keyword slots") })
    }
}

@Suite("Metadata diff")
struct MetadataDiffTests {
    @Test func fieldChanges() {
        let a = MetadataFields(name: "A", keywords: "one,two")
        let b = MetadataFields(name: "A", keywords: "two,three")
        let changes = MetadataDiff.changes(baseline: a, draft: b)
        #expect(changes.map(\.field) == [.keywords])
        let delta = MetadataDiff.keywordDelta(before: a.keywords, after: b.keywords)
        #expect(delta.kept == ["two"])
        #expect(delta.added == ["three"])
        #expect(delta.removed == ["one"])
    }

    @Test func contentHashIsStable() {
        let f = MetadataFields(name: "A", subtitle: "B")
        #expect(MetadataHasher.hash(f) == MetadataHasher.hash(f))
        #expect(MetadataHasher.hash(f) != MetadataHasher.hash(MetadataFields(name: "A", subtitle: "C")))
    }
}


@Suite("ASO rules")
struct ASORulesTests {
    @Test("Repetition, filler and phrases are caught; a clean listing scores high")
    func review() {
        let bad = MetadataFields(name: "Inkwave: AI Manga&Comic Maker", subtitle: "AI Comic & Manga from Selfies", keywords: "comic, manga maker,free,ai")
        let r = ASORules.review(bad)
        #expect(r.errors >= 3)
        #expect(r.findings.contains { $0.rule == "Zero repetition" && $0.message.contains("“ai”") })
        #expect(r.findings.contains { $0.rule == "No filler" && $0.message.contains("“free”") })
        #expect(r.findings.contains { $0.rule == "Keywords" && $0.message.contains("phrase") })
        #expect(r.score < 60)

        let good = MetadataFields(name: "Toonsmith: Manga Webtoon Maker", subtitle: "Cartoon Yourself, Anime Story",
                                  keywords: "comic,manhwa,book,photo,selfie,generator,creator,art,strip,graphic,novel,hero,shonen,isekai,romance")
        let g = ASORules.review(good)
        #expect(g.errors == 0)
        #expect(g.score >= 85)
        #expect(g.charactersUsed == 30 + 29 + 99)
    }

    @Test("Secondary locale overlap is flagged")
    func overlap() {
        let primary = MetadataFields(name: "Toonsmith: Manga Webtoon Maker", subtitle: "Cartoon Yourself, Anime Story", keywords: "comic,manhwa,book")
        let secondary = MetadataFields(name: "Toonsmith: Superhero Toon", subtitle: "Character Art, Couple, Fantasy", keywords: "manga,avatar,pfp")
        let r = ASORules.review(secondary, locale: .esMX, siblings: [(.enUS, primary)])
        #expect(r.findings.contains { $0.rule == "Locale overlap" && $0.message.contains("manga") })
    }
}

@Suite("ASO repair")
struct ASORepairTests {
    @Test("Keywords are packed to 100, cleaned of title words, filler and plurals, and topped up")
    func repair() {
        let f = MetadataFields(name: "Meshcraft: AI 3D Model Maker", subtitle: "Scan Photo & Export to Blender",
                               keywords: "3d,modeling,scanner,viewer,pose,mesh,asset,render,ar,unity,sculpt,generator,create,prototype,convert,art,scanners")
        let r = ASORules.repair(f, topUpWith: ["blender", "printing", "cad", "figure"])
        #expect(r.fields.keywords.count <= 100)
        #expect(!r.fields.keywords.split(separator: ",").contains("3d"))
        #expect(!r.fields.keywords.contains("scanners"))
        #expect(!r.fields.subtitle.contains("&"))
        #expect(r.fields.keywords.count >= 90)
        #expect(ASORules.review(r.fields).errors == 0)
    }
}
