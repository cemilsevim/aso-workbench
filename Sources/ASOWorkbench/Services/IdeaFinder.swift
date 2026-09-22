import Foundation
import SwiftData
import ASOCore
import ASOProviders

/// App-independent gap finder: every term Apple publishes a popularity for in a country (its genre lists), minus
/// brands and non-app searches (Jev), measured for difficulty (public search): ranked by opportunity. A term with
/// real demand and weak results is a lead for an app that does not exist yet.
@Observable
final class IdeaFinder {
    struct Progress: Equatable { var step = ""; var completed = 0; var total = 0; var isRunning = false }
    private(set) var progress = Progress()
    private(set) var lastMessage: String?
    private var task: Task<Void, Never>?

    private let search: ITunesSearchProvider
    private let popularity: AppleAdsPopularityProvider
    private let jev: JevClient
    private let settings: AppSettings

    init(search: ITunesSearchProvider, popularity: AppleAdsPopularityProvider, jev: JevClient, settings: AppSettings) {
        self.search = search
        self.popularity = popularity
        self.jev = jev
        self.settings = settings
    }

    func cancel() { task?.cancel() }

    func scan(country: String, genres: [AppleAdsGenre], budget: Int, minPopularity: Int, maxDifficulty: Int, context: ModelContext) {
        guard !progress.isRunning else { return }
        task = Task { await run(country: country, genres: genres, budget: budget, minPopularity: minPopularity, maxDifficulty: maxDifficulty, context: context) }
    }

    /// Where gaps live: specific multi-word needs in the 40–60 band, not one-word head terms every big app already owns.
    nonisolated static func priority(popularity: Int, normalized: String, intent: String?) -> Double {
        var p = Double(popularity)
        let words = normalized.split(separator: " ").count
        if words >= 2 { p += 15 }
        if words >= 3 { p += 10 }
        // "x app" / "x free app" phrasing is nearly always someone looking for a specific app.
        if normalized.split(separator: " ").contains(where: { $0 == "app" || $0 == "apps" }) { p -= 25 }
        if popularity >= 70 { p -= 30 } else if popularity >= 60 { p -= 12 }
        switch intent {
        case "feature", "longtail": p += 10
        case "category": p -= 10
        default: break
        }
        return p
    }

    private func run(country: String, genres: [AppleAdsGenre], budget: Int, minPopularity: Int, maxDifficulty: Int, context: ModelContext) async {
        progress = Progress(step: "Apple Ads lists", completed: 0, total: genres.count, isRunning: true)
        lastMessage = nil
        defer { progress.isRunning = false }
        guard let sf = StorefrontRegistry.lookup(country) else { lastMessage = "Unknown storefront \(country)."; return }
        guard await popularity.isConfigured else { lastMessage = "Apple Ads is not connected (sidebar → Connections)."; return }

        // 1. Every published term in the chosen genre lists, keeping the best popularity per term.
        var best: [String: PopularityRecord] = [:]
        var listErrors = 0
        for (i, g) in genres.enumerated() {
            if Task.isCancelled { lastMessage = "Cancelled."; return }
            progress.step = "Apple Ads · \(g.displayName) list"
            progress.completed = i
            do {
                for r in try await popularity.genreDataset(country: country, genre: g, monthsBack: 1) {
                    guard let p = r.popularity1to100, p >= minPopularity else { continue }
                    let n = TrackedKeyword.normalize(r.searchTerm)
                    if (best[n]?.popularity1to100 ?? 0) < p { best[n] = r }
                }
            } catch { listErrors += 1 }
        }

        // 2. Upsert candidates for this country.
        let cc = country
        let existing = ((try? context.fetch(FetchDescriptor<IdeaCandidate>(predicate: #Predicate { $0.countryCode == cc }))) ?? [])
        var byTerm = Dictionary(existing.map { ($0.normalized, $0) }, uniquingKeysWith: { a, _ in a })
        var added = 0
        for (n, r) in best {
            let c: IdeaCandidate
            if let e = byTerm[n] { c = e } else {
                c = IdeaCandidate(countryCode: country, term: r.searchTerm, normalized: n, genreRaw: r.genre.rawValue, popularity: r.popularity1to100 ?? 0)
                context.insert(c)
                byTerm[n] = c
                added += 1
            }
            c.popularity = r.popularity1to100 ?? c.popularity
            c.genreRaw = r.genre.rawValue
            c.rankInGenre = r.rankInGenre
            c.updatedAt = .now
        }
        try? context.save()
        let candidates = Array(byTerm.values).filter { best[$0.normalized] != nil }

        // 3. Jev cache from the Lab (free) for brand / natural / intent.
        let cached = ((try? context.fetch(FetchDescriptor<TrainingRow>(predicate: #Predicate { $0.storefront == cc && $0.jevCollected }))) ?? [])
        let cache = Dictionary(cached.compactMap { r in r.jev.map { (r.normalized, $0) } }, uniquingKeysWith: { a, _ in a })
        for c in candidates where c.brand == nil { if let j = cache[c.normalized] { c.brand = j.brand; c.natural = j.naturalQuery; c.intent = j.intent } }
        for c in candidates where c.measuredAt != nil && c.leaderOwnsTerm == nil { c.updateResultFlags() }

        // 4. Long-tail-first queue of unmeasured terms; Jev runs only on what this scan can reach.
        let stale = Date.now.addingTimeInterval(-7 * 86_400)
        let queue = candidates
            .filter { !$0.wantsFree && ($0.measuredAt ?? .distantPast) < stale && ($0.brand ?? 0) < 0.5 && ($0.natural ?? 1) >= 0.5 && ($0.appable ?? 1) >= 0.5 }
            .sorted { Self.priority(popularity: $0.popularity, normalized: $0.normalized, intent: $0.intent) > Self.priority(popularity: $1.popularity, normalized: $1.normalized, intent: $1.intent) }
        let reach = Array(queue.prefix(budget * 3))
        if await jev.isConfigured {
            let lang = sf.defaultLocale.displayName
            let needJev = reach.filter { $0.brand == nil }
            progress.step = "Jev · brand check (\(needJev.count))"
            progress.total = needJev.count
            progress.completed = 0
            for batch in stride(from: 0, to: needJev.count, by: 8).map({ Array(needJev[$0..<min($0 + 8, needJev.count)]) }) {
                if Task.isCancelled { try? context.save(); lastMessage = "Cancelled."; return }
                let inputs = batch.map(\.term)
                let results: [JevFeatures?] = await withTaskGroup(of: (Int, JevFeatures?).self) { g in
                    for (i, term) in inputs.enumerated() { g.addTask { [jev] in (i, try? await jev.classify(term: term, storefront: cc, storeLanguage: lang)) } }
                    var out = Array(repeating: JevFeatures?.none, count: inputs.count)
                    for await (i, f) in g { out[i] = f }
                    return out
                }
                for (c, f) in zip(batch, results) { if let f { c.brand = f.brand; c.natural = f.naturalQuery; c.intent = f.intent } }
                progress.completed += batch.count
            }
            let needApp = reach.filter { $0.appable == nil && ($0.brand ?? 1) < 0.5 && ($0.natural ?? 0) >= 0.5 }
            progress.step = "Jev · app-able check (\(needApp.count))"
            progress.total = needApp.count
            progress.completed = 0
            for batch in stride(from: 0, to: needApp.count, by: 8).map({ Array(needApp[$0..<min($0 + 8, needApp.count)]) }) {
                if Task.isCancelled { try? context.save(); lastMessage = "Cancelled."; return }
                let inputs = batch.map(\.term)
                let results: [Double?] = await withTaskGroup(of: (Int, Double?).self) { g in
                    for (i, term) in inputs.enumerated() { g.addTask { [jev] in (i, try? await jev.appable(term: term, storefront: cc, storeLanguage: lang)) } }
                    var out = Array(repeating: Double?.none, count: inputs.count)
                    for await (i, f) in g { out[i] = f }
                    return out
                }
                for (c, f) in zip(batch, results) { if let f { c.appable = f } }
                progress.completed += batch.count
            }
            try? context.save()
        }

        // 5. Difficulty for the best-placed unmeasured terms (public search, ~3 s each).
        let toMeasure = reach.filter { ($0.brand ?? 0) < 0.5 && ($0.natural ?? 1) >= 0.5 && ($0.appable ?? 1) >= 0.5 }.prefix(budget)
        progress.step = "Difficulty · public search"
        progress.total = toMeasure.count
        progress.completed = 0
        var measured = 0
        for c in toMeasure {
            if Task.isCancelled { break }
            progress.step = "Difficulty · “\(c.term)”"
            guard let results = try? await search.search(term: c.term, storefront: sf, device: .iPhone, limit: 50) else { progress.completed += 1; continue }
            let signals = CompetitionSignals(results: results, term: c.term)
            c.difficulty = signals.difficulty?.score
            c.leaderName = results.first?.name
            c.leaderRatings = results.first?.ratingCount
            c.medianRatings = signals.medianRatingCountTop10
            c.titleMatches = signals.titleMatchesTop10
            c.resultCount = results.count
            c.measuredAt = .now
            c.updateResultFlags()
            c.topNames = results.prefix(5).map(\.name).joined(separator: " | ")
            measured += 1
            progress.completed += 1
            if measured % 5 == 0 { try? context.save() }
        }
        try? context.save()

        // 6. Jev, shown the actual top results: is this a way of finding one specific app? Cheap, runs once per measured term.
        if await jev.isConfigured {
            let lang = sf.defaultLocale.displayName
            let needNav = candidates.filter { $0.measuredAt != nil && $0.navigational == nil && ($0.brand ?? 0) < 0.5 && $0.leaderOwnsTerm != true }.prefix(200)
            progress.step = "Jev · navigational check (\(needNav.count))"
            progress.total = needNav.count
            progress.completed = 0
            for batch in stride(from: 0, to: needNav.count, by: 8).map({ Array(needNav[$0..<min($0 + 8, needNav.count)]) }) {
                if Task.isCancelled { break }
                let inputs = batch.map { ($0.term, ($0.topNames ?? $0.leaderName ?? "").components(separatedBy: " | ")) }
                let results: [Double?] = await withTaskGroup(of: (Int, Double?).self) { g in
                    for (i, input) in inputs.enumerated() { g.addTask { [jev] in (i, try? await jev.navigational(term: input.0, topResults: input.1, storefront: cc, storeLanguage: lang)) } }
                    var out = Array(repeating: Double?.none, count: inputs.count)
                    for await (i, f) in g { out[i] = f }
                    return out
                }
                for (c, f) in zip(batch, results) { if let f { c.navigational = f } }
                progress.completed += batch.count
            }
            try? context.save()
        }

        let gaps = candidates.filter { $0.isGap(maxDifficulty: maxDifficulty) }.sorted { ($0.difficulty ?? 100) < ($1.difficulty ?? 100) }
        let unmeasured = queue.count - measured
        lastMessage = "\(best.count) published terms in \(country) (\(added) new)\(listErrors > 0 ? ", \(listErrors) list(s) failed" : ""). Measured \(measured) this run, long-tail first; \(max(0, unmeasured)) candidates still unmeasured, scan again to continue. \(gaps.count) gap(s) so far (difficulty ≤ \(maxDifficulty))."
        AppLog.write("[ideas] \(lastMessage ?? "")")
        for g in gaps.prefix(15) {
            AppLog.write("[ideas] gap \(g.term) pop=\(g.popularity) diff=\(Int((g.difficulty ?? 0).rounded())) opp=\(Int((g.opportunity ?? 0).rounded())) leader=\(g.leaderName ?? "-")/\(g.leaderRatings ?? 0) titles=\(g.titleMatches ?? -1)/10 appable=\(String(format: "%.2f", g.appable ?? -1))")
        }
    }
}
