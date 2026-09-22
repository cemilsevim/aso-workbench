import Foundation
import SwiftData
import ASOCore
import ASOProviders

/// Tries an app's own keywords in other storefronts in one pass, rank, Apple popularity (list → index → estimate),
/// difficulty and Jev language fit per country, so promising markets can be tracked with one click instead of
/// adding keywords one by one.
@Observable
final class MarketExpansion {
    nonisolated struct Row: Identifiable, Sendable {
        var id: String { "\(country)|\(term)" }
        let country: String
        let term: String
        var rank: Int?
        var observed: Int = 0
        var popularity: Int?
        /// "list" · "index" · "estimate" · "model" (6–29 rank among floor terms, Apple index 5) · "below"
        var popularityScope: String?
        /// Apple's own index when it sits at the floor and the model value stands in for it.
        var appleIndex: Int?
        /// Classifier probability behind a model value (kept so the observation can be stored like the Keywords page does).
        var modelProbability: Double?
        /// Set when the cell was written into the app's tracked keywords.
        var tracked = false
        /// For a local-language form: the tracked keyword it was derived from, and what it means.
        var sourceTerm: String?
        var meaning: String?
        var difficulty: Double?
        var leader: String?
        var leaderRatings: Int?
        var titleMatches: Int?
        var languageFit: Double?
        var failed = false

        var opportunity: Double? { guard let p = popularity, let d = difficulty else { return nil }; return Double(p) * (1 - pow(d / 100, 2)) }
        var opportunitySort: Double { opportunity ?? -1 }
        /// Worth a market: Apple-level demand and either an existing foothold or beatable results.
        var isCandidate: Bool { (popularity ?? 0) >= 30 && ((rank ?? 999) <= 30 || (difficulty ?? 100) <= 45) && (languageFit ?? 1) >= 0.4 }
    }

    struct Progress: Equatable { var step = ""; var completed = 0; var total = 0; var isRunning = false }
    private(set) var progress = Progress()
    private(set) var rows: [Row] = []
    private(set) var lastMessage: String?
    private var task: Task<Void, Never>?

    private let search: ITunesSearchProvider
    private let popularity: AppleAdsPopularityProvider
    private let session: AppleAdsSessionService
    private let research: ResearchService
    private let jev: JevClient
    private let llm: LLMClient
    private let settings: AppSettings
    private(set) var lastLocalizationCost: String?

    init(search: ITunesSearchProvider, popularity: AppleAdsPopularityProvider, session: AppleAdsSessionService, research: ResearchService, jev: JevClient, llm: LLMClient, settings: AppSettings) {
        self.search = search
        self.popularity = popularity
        self.session = session
        self.research = research
        self.jev = jev
        self.llm = llm
        self.settings = settings
    }

    nonisolated struct LocalForm: Sendable { let term: String; let source: String; let meaning: String }

    /// Asks the model how people in `storefront` actually search for what each term means, local search phrasing, not
    /// dictionary translation: with the app's description as context so the meaning survives. One call per storefront.
    func localForms(of terms: [String], app: TrackedApp, storefront sf: Storefront) async -> [LocalForm] {
        guard await llm.isConfigured else { return [] }
        let language = sf.defaultLocale.displayName
        let system = """
        You are an App Store search localization specialist. For each source keyword, give how people in the target country actually type that need into App Store search, in the store language: 1 to 3 short phrases, lower-case, no punctuation, at most 4 words, real search phrasing (what a person types, not marketing copy). Preserve the meaning of the source keyword, same need, same intent. If locals commonly search this need with the English words, say so by returning the English phrase as one candidate. Never invent brand names.
        Output strict JSON only: {"terms":[{"source":"…","candidates":[{"term":"…","meaning":"short gloss in English"}]}]}
        """
        let user = """
        App: \(app.name). What it does: \(String((app.storeDescription ?? "").prefix(900)))
        Target: \(sf.name) (\(sf.countryCode)) App Store, store language \(language).
        Source keywords (English or the app's home market): \(terms.joined(separator: ", "))
        """
        do {
            let (text, usage) = try await llm.complete(system: system, user: user, temperature: 0.3, maxTokens: 2500)
            if let u = usage { lastLocalizationCost = u.cost.map { String(format: "$%.4f", $0) } ?? "\(u.inputTokens)+\(u.outputTokens) tokens" }
            guard let json = LLMClient.extractJSONObject(text), let items = json["terms"] as? [[String: Any]] else { return [] }
            var out: [LocalForm] = []
            var seen = Set(terms.map { TrackedKeyword.normalize($0) })
            for item in items {
                guard let source = item["source"] as? String, let cands = item["candidates"] as? [[String: Any]] else { continue }
                for c in cands.prefix(3) {
                    guard let t = c["term"] as? String else { continue }
                    let clean = t.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    guard clean.count >= 2, seen.insert(TrackedKeyword.normalize(clean)).inserted else { continue }
                    out.append(LocalForm(term: clean, source: source, meaning: c["meaning"] as? String ?? ""))
                }
            }
            AppLog.write("[expand] local forms for \(sf.countryCode): \(out.count) from \(terms.count) terms (\(lastLocalizationCost ?? "?"))")
            return out
        } catch {
            AppLog.write("[expand] local forms for \(sf.countryCode) failed: \(error.localizedDescription)")
            return []
        }
    }

    func cancel() { task?.cancel() }
    func clear() { rows = []; lastMessage = nil }

    /// `autoTrack`: every measured cell becomes a tracked keyword in that storefront (market created when missing) and
    /// its rank, results, difficulty and popularity are stored as observations, nothing has to be measured twice.
    func run(app: TrackedApp, terms: [String], countries: [String], device: DeviceContext, autoTrack: Bool = false, sourceMarket: TrackedMarket? = nil,
             catalog: CatalogService? = nil, context: ModelContext? = nil, localize: Bool = false) {
        guard !progress.isRunning else { return }
        task = Task { await evaluate(app: app, terms: terms, countries: countries, device: device, autoTrack: autoTrack, sourceMarket: sourceMarket, catalog: catalog, context: context, localize: localize) }
    }

    private func evaluate(app: TrackedApp, terms rawTerms: [String], countries: [String], device: DeviceContext, autoTrack: Bool, sourceMarket: TrackedMarket?,
                          catalog: CatalogService?, context: ModelContext?, localize: Bool) async {
        let terms = Array(NSOrderedSet(array: rawTerms.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })) as? [String] ?? rawTerms
        progress = Progress(step: "Starting", completed: 0, total: terms.count * countries.count, isRunning: true)
        lastMessage = nil
        defer { progress.isRunning = false }
        let trackID = app.trackID
        let adsOK = await popularity.isConfigured
        let jevOK = await jev.isConfigured
        if session.referenceAdamID.isEmpty { session.referenceAdamID = String(trackID) }
        var candidates = 0
        var trackedCount = 0
        let (periodStart, periodEnd) = AppleAdsPopularityProvider.lastFullMonth(monthsBack: 1)

        let sourceLanguage = sourceMarket?.storefront?.defaultLocale.rawValue.split(separator: "-").first.map(String.init) ?? "en"
        for country in countries {
            if Task.isCancelled { lastMessage = "Cancelled."; return }
            guard let sf = StorefrontRegistry.lookup(country) else { continue }
            var byTerm: [String: Row] = Dictionary(uniqueKeysWithValues: terms.map { ($0, Row(country: country, term: $0)) })
            var listRecords: [String: PopularityRecord] = [:]
            var countryTerms = terms
            // Local-language forms when the store speaks another language: the model proposes, the measurements decide.
            let targetLanguage = sf.defaultLocale.rawValue.split(separator: "-").first.map(String.init) ?? ""
            if localize, targetLanguage != sourceLanguage {
                progress.step = "\(country) · local search forms (AI)"
                if app.storeDescription == nil { await research.ensureDescription(app: app, storefront: sf) }
                for f in await localForms(of: terms, app: app, storefront: sf) {
                    var row = Row(country: country, term: f.term)
                    row.sourceTerm = f.source
                    row.meaning = f.meaning
                    byTerm[f.term] = row
                    countryTerms.append(f.term)
                }
                progress.total += (countryTerms.count - terms.count)
            }

            // Popularity: list → dashboard index → model estimate.
            if adsOK {
                progress.step = "\(country) · Apple Ads lists"
                var records: [PopularityRecord] = []
                if let g = app.adsGenre { records = (try? await popularity.popularity(terms: countryTerms, country: country, genre: g, monthsBack: 1)) ?? [] }
                else { records = (try? await popularity.popularityAcrossGenres(terms: countryTerms, country: country, monthsBack: 1)) ?? [] }
                let listed = Dictionary(grouping: records, by: { TrackedKeyword.normalize($0.searchTerm) })
                for t in countryTerms {
                    if let best = listed[TrackedKeyword.normalize(t)]?.max(by: { ($0.popularity1to100 ?? 0) < ($1.popularity1to100 ?? 0) }), let v = best.popularity1to100 {
                        byTerm[t]?.popularity = v; byTerm[t]?.popularityScope = "list"; listRecords[t] = best
                    }
                }
                var missing = countryTerms.filter { byTerm[$0]?.popularity == nil }
                if !missing.isEmpty, session.state.isSignedIn || session.state == .unknown {
                    progress.step = "\(country) · dashboard index"
                    if let index = try? await session.popularity(terms: missing, storefront: country) {
                        for t in missing { if let v = index[TrackedKeyword.normalize(t)] { byTerm[t]?.popularity = v; byTerm[t]?.popularityScope = "index" } }
                    }
                }
                missing = countryTerms.filter { byTerm[$0]?.popularity == nil }
                // Same rule as the Keywords table: Apple's floor (index < 30) shows the model's 6–29 rank instead.
                let floored = countryTerms.filter { byTerm[$0]?.popularityScope == "index" && (byTerm[$0]?.popularity ?? 30) < ModelTrainer.publishedThreshold }
                let toEstimate = missing + floored
                if !toEstimate.isEmpty {
                    progress.step = "\(country) · model estimate (\(toEstimate.count))"
                    let estimator = research.models.estimator
                    for r in await research.estimate(terms: toEstimate, storefront: sf) {
                        guard var row = byTerm[r.term] else { continue }
                        let isFloor = floored.contains(r.term)
                        switch r.estimate {
                        case .published(let v, let p):
                            row.modelProbability = p
                            if isFloor { row.appleIndex = row.popularity; row.popularity = estimator?.subFloorEstimate(publishedProbability: p); row.popularityScope = "model" }
                            else { row.popularity = v; row.popularityScope = "estimate" }
                        case .below(let p):
                            row.modelProbability = 1 - p
                            if isFloor { row.appleIndex = row.popularity }
                            row.popularity = estimator?.subFloorEstimate(publishedProbability: 1 - p)
                            row.popularityScope = row.popularity == nil ? "below" : "model"
                        case nil: break
                        }
                        byTerm[r.term] = row
                    }
                }
            }

            // Rank + difficulty from the public results; Jev language fit.
            let lang = sf.defaultLocale.displayName
            for t in countryTerms {
                if Task.isCancelled { lastMessage = "Cancelled."; return }
                progress.step = "\(country) · “\(t)”"
                var results: [SearchResultApp]?
                if let r = try? await search.search(term: t, storefront: sf, device: device, limit: settings.resultDepth) {
                    results = r
                    byTerm[t]?.observed = r.count
                    byTerm[t]?.rank = r.firstIndex { $0.trackID == trackID }.map { $0 + 1 }
                    let signals = CompetitionSignals(results: Array(r.prefix(50)), term: t)
                    byTerm[t]?.difficulty = signals.difficulty?.score
                    byTerm[t]?.titleMatches = signals.titleMatchesTop10
                    byTerm[t]?.leader = r.first?.name
                    byTerm[t]?.leaderRatings = r.first?.ratingCount
                } else {
                    byTerm[t]?.failed = true
                }
                if jevOK, let f = try? await jev.classify(term: t, storefront: country, storeLanguage: lang) { byTerm[t]?.languageFit = f.languageFit }
                progress.completed += 1
                if var row = byTerm[t] {
                    if autoTrack, let catalog, let context, let results {
                        persist(row: row, results: results, listRecord: listRecords[t], app: app, storefront: sf, device: device, sourceMarket: sourceMarket,
                                periodStart: periodStart, periodEnd: periodEnd, catalog: catalog, context: context)
                        row.tracked = true
                        byTerm[t] = row
                        trackedCount += 1
                    }
                    rows.removeAll { $0.id == row.id }
                    rows.append(row)
                    if row.isCandidate { candidates += 1 }
                }
            }
        }
        if let context { try? context.save() }
        lastMessage = "\(terms.count) keyword(s) × \(countries.count) storefront(s): \(candidates) candidate cell(s): Apple-level demand (≥ 30) with a top-30 rank or difficulty ≤ 45, in a language people search there." + (autoTrack ? " \(trackedCount) cell(s) tracked with their measurements; see Keywords in each storefront." : "")
        AppLog.write("[expand] \(lastMessage ?? "")")
        for r in rows.sorted(by: { ($0.opportunity ?? -1) > ($1.opportunity ?? -1) }).prefix(40) {
            AppLog.write("[expand] \(r.isCandidate ? "★" : " ") \(r.country)\(r.sourceTerm.map { " [from \($0)]" } ?? "") \(r.term) rank=\(r.rank.map { "#\($0)" } ?? ">\(r.observed)") pop=\(r.popularity ?? 0) \(r.popularityScope ?? "") diff=\(Int((r.difficulty ?? 0).rounded())) lang=\(String(format: "%.2f", r.languageFit ?? -1)) leader=\(r.leader ?? "-")")
        }
    }

    /// Writes one measured cell into the app's tracked keywords: market (created if missing), keyword (reused if present),
    /// a rank observation with the results (so difficulty and competitors come along) and a popularity observation.
    private func persist(row: Row, results: [SearchResultApp], listRecord: PopularityRecord?, app: TrackedApp, storefront sf: Storefront, device: DeviceContext,
                         sourceMarket: TrackedMarket?, periodStart: Date, periodEnd: Date, catalog: CatalogService, context: ModelContext) {
        if app.markets.first(where: { $0.countryCode == sf.countryCode }) == nil {
            catalog.addMarket(to: app, storefront: sf, device: device, context: context)
        }
        guard let market = app.markets.first(where: { $0.countryCode == sf.countryCode }) else { return }
        let normalized = TrackedKeyword.normalize(row.term)
        let keyword: TrackedKeyword
        if let existing = market.keywords.first(where: { $0.normalized == normalized }) { keyword = existing } else {
            keyword = TrackedKeyword(text: row.term)
            keyword.market = market
            context.insert(keyword)
        }
        // Brand, intent and fit are properties of the term and the app, not of the storefront: reuse the source market's answers.
        if let source = row.sourceTerm, keyword.note.isEmpty {
            keyword.note = "local form of “\(source)”" + (row.meaning.map { $0.isEmpty ? "" : " · \($0)" } ?? "")
        }
        if let src = sourceMarket?.keywords.first(where: { $0.normalized == TrackedKeyword.normalize(row.sourceTerm ?? row.term) }) {
            if keyword.brandProbability == nil { keyword.brandProbability = src.brandProbability; keyword.intent = src.intent }
            if keyword.fitProbability == nil { keyword.fitProbability = src.fitProbability }
        }
        let outcome: RankOutcome = row.rank.map { .found(position: $0, observedCount: results.count) } ?? .outsideObservedRange(observedCount: results.count)
        let sample = RankSample(keyword: row.term, storefront: sf.countryCode, device: device, provider: .itunesSearch, outcome: outcome, fetchedAt: .now, results: results)
        let rank = RankObservation(sample: sample)
        rank.keyword = keyword
        context.insert(rank)

        var pop: PopularityObservation?
        switch row.popularityScope {
        case "list":
            if let r = listRecord { pop = PopularityObservation(record: r) }
        case "index":
            if let v = row.popularity { pop = PopularityObservation(dashboardIndex: v, countryCode: sf.countryCode, periodStart: periodStart, periodEnd: periodEnd) }
        case "model":
            if let apple = row.appleIndex {
                let o = PopularityObservation(dashboardIndex: apple, countryCode: sf.countryCode, periodStart: periodStart, periodEnd: periodEnd)
                o.subFloorEstimate = row.popularity
                o.subFloorProbability = row.modelProbability
                pop = o
            } else {
                let o = PopularityObservation(estimate: nil, confidence: 1 - (row.modelProbability ?? 0.5), upperBound: nil, countryCode: sf.countryCode, periodStart: periodStart, periodEnd: periodEnd)
                o.subFloorEstimate = row.popularity
                o.subFloorProbability = row.modelProbability
                pop = o
            }
        case "estimate":
            if let v = row.popularity { pop = PopularityObservation(estimate: v, confidence: row.modelProbability ?? 0.5, upperBound: nil, countryCode: sf.countryCode, periodStart: periodStart, periodEnd: periodEnd) }
        case "below":
            pop = PopularityObservation(estimate: nil, confidence: 1 - (row.modelProbability ?? 0.5), upperBound: nil, countryCode: sf.countryCode, periodStart: periodStart, periodEnd: periodEnd)
        default:
            break
        }
        if let pop { pop.keyword = keyword; context.insert(pop) }
        try? context.save()
    }

}
