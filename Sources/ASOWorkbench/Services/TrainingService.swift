import Foundation
import Observation
import SwiftData
import ASOCore
import ASOProviders

/// Builds the popularity training set: term universe → dashboard labels → public features → Jev features → export.
/// Every stage is resumable (rows persist) and cancellable.
@Observable
final class TrainingService {
    struct Stage: Equatable {
        var name = ""
        var completed = 0
        var total = 0
        var isRunning = false
        var note = ""
    }

    /// Running stages by name; several can run at once (autocomplete, results and Jev use different endpoints).
    private(set) var stages: [String: Stage] = [:]
    private(set) var log: [String] = []
    private var tasks: [String: Task<Void, Never>] = [:]

    private let container: ModelContainer
    private let popularity: AppleAdsPopularityProvider
    /// Own hints providers with tighter pacers than the UI one; two independent streams double throughput.
    private let hints = AppStoreHintsProvider(pacer: RequestPacer(minimumInterval: 0.7))
    private let hints2 = AppStoreHintsProvider(pacer: RequestPacer(minimumInterval: 0.7))
    private let search: ITunesSearchProvider
    private let session: AppleAdsSessionService
    private let jev: JevClient
    private var hintCache: [String: [String]] = [:]
    private var hintCacheDirty = 0
    /// Per storefront and source: when the universe stage last completed (so re-runs skip finished work).
    private var universeDone: [String: Date] = [:]

    init(container: ModelContainer, popularity: AppleAdsPopularityProvider, hints _: AppStoreHintsProvider, search: ITunesSearchProvider, session: AppleAdsSessionService, jev: JevClient) {
        self.container = container
        self.popularity = popularity
        self.search = search
        self.session = session
        self.jev = jev
        if let data = try? Data(contentsOf: Self.hintCacheURL), let c = try? JSONDecoder().decode([String: [String]].self, from: data) { hintCache = c }
        if let data = UserDefaults.standard.data(forKey: "labUniverseDone"), let d = try? JSONDecoder().decode([String: Date].self, from: data) { universeDone = d }
    }

    nonisolated static var hintCacheURL: URL { exportDirectory.appendingPathComponent("hint-cache.json") }

    private func saveHintCache(force: Bool = false) {
        hintCacheDirty += 1
        guard force || hintCacheDirty >= 40 else { return }
        hintCacheDirty = 0
        if let data = try? JSONEncoder().encode(hintCache) { try? data.write(to: Self.hintCacheURL, options: .atomic) }
    }

    private func markUniverse(_ sf: String, _ source: String) {
        universeDone["\(sf)|\(source)"] = .now
        if let data = try? JSONEncoder().encode(universeDone) { UserDefaults.standard.set(data, forKey: "labUniverseDone") }
    }

    private func universeIsDone(_ sf: String, _ source: String, within days: Double = 30) -> Bool {
        guard let d = universeDone["\(sf)|\(source)"] else { return false }
        return Date().timeIntervalSince(d) < days * 86_400
    }

    /// Aggregate view for the UI.
    var stage: Stage {
        let running = stages.values.filter(\.isRunning)
        guard !running.isEmpty else { return Stage() }
        var s = Stage(name: running.map(\.name).joined(separator: " + "), completed: running.map(\.completed).reduce(0, +), total: running.map(\.total).reduce(0, +), isRunning: true, note: running.first?.note ?? "")
        if running.count > 1 { s.note = running.map { "\($0.name) \($0.completed)/\($0.total)" }.joined(separator: " · ") }
        return s
    }

    var isRunning: Bool { stages.values.contains(where: \.isRunning) || pipelineRunning }
    private(set) var pipelineRunning = false
    private(set) var pipelineStep = ""
    private var pipelineTask: Task<Void, Never>?

    func cancel() {
        for t in tasks.values { t.cancel() }
        pipelineTask?.cancel()
    }

    private func waitUntilIdle(_ name: String? = nil) async {
        while (name.map { stages[$0]?.isRunning ?? false } ?? stages.values.contains(where: \.isRunning)) {
            try? await Task.sleep(for: .milliseconds(300))
        }
    }

    /// One-click run with the agreed defaults: universe → labels → autocomplete → results → Jev → train.
    /// Waits (up to an hour) for the Apple Ads dashboard sign-in when labels need it.
    func runAll(storefronts: [String], hintSeeds: Int, hintsLimit: Int = 3000, resultsLimit: Int, jevLimit: Int = 8000, useJev: Bool, apps: [TrackedApp], context: ModelContext, train: @escaping @MainActor () async -> String) {
        guard !isRunning else { return }
        pipelineRunning = true
        pipelineTask = Task {
            defer { pipelineRunning = false; pipelineStep = "" }
            append("Pipeline started: \(storefronts.joined(separator: ",")) · seeds \(hintSeeds) · hints \(hintsLimit) · results \(resultsLimit) · jev \(useJev ? jevLimit : 0). Finished parts are skipped on re-runs.")
            pipelineStep = "1/4 universe"
            buildUniverse(storefronts: storefronts, useGenreLists: true, useSuggestions: true, hintSeedLimit: hintSeeds, apps: apps, context: context)
            await waitUntilIdle("Universe")
            if Task.isCancelled { return }

            pipelineStep = "2/4 labels (waiting for sign-in if needed)"
            var waited = 0
            while !session.state.isSignedIn, waited < 3600, !Task.isCancelled {
                if await session.checkSession() { break }
                if waited == 0 { append("Labels need the Apple Ads dashboard session — sign in (Connections → Sign in…); the pipeline continues automatically.") }
                try? await Task.sleep(for: .seconds(20))
                waited += 20
            }
            guard session.state.isSignedIn else { append("Pipeline stopped: no dashboard session."); return }
            labelRows(context: context)
            await waitUntilIdle("Labels")
            if Task.isCancelled { return }

            // Feature stages hit three different services, so they run side by side.
            pipelineStep = "3/4 features (autocomplete + results + Jev in parallel)"
            collectHints(limit: hintsLimit, context: context)
            if resultsLimit > 0 { collectResults(limit: resultsLimit, depth: 50, context: context) }
            if useJev, await jev.isConfigured { collectJev(limit: jevLimit, context: context) }
            await waitUntilIdle()
            if Task.isCancelled { return }

            pipelineStep = "4/4 training"
            let summary = await train()
            append("Pipeline finished. \(summary)")
        }
    }

    private func run(_ name: String, _ body: @escaping @MainActor (_ progress: @escaping @MainActor (Int, Int, String) -> Void) async throws -> Void) {
        guard stages[name]?.isRunning != true else { return }
        stages[name] = Stage(name: name, isRunning: true)
        tasks[name] = Task {
            do {
                try await body { completed, total, note in
                    self.stages[name]?.completed = completed
                    self.stages[name]?.total = total
                    self.stages[name]?.note = note
                }
                append("\(name): done.")
            } catch is CancellationError {
                append("\(name): cancelled.")
            } catch {
                append("\(name): \(error.localizedDescription)")
            }
            stages[name]?.isRunning = false
            tasks[name] = nil
            saveHintCache(force: true)
        }
    }

    private func append(_ line: String) {
        log.append("\(Date().formatted(date: .omitted, time: .standard))  \(line)")
        if log.count > 400 { log.removeFirst(log.count - 400) }
        AppLog.write("[training] \(line)")
    }

    /// Progress line for the file log (called by the URL command runner).
    func progressLine() -> String {
        let running = stages.values.filter(\.isRunning)
        return running.isEmpty ? "idle" : running.map { "\($0.name) \($0.completed)/\($0.total) \($0.note)" }.joined(separator: " | ")
    }

    // MARK: Stats

    struct Stats {
        var rows = 0, labeled = 0, missing = 0, withHints = 0, withResults = 0, withJev = 0
        var bands = Array(repeating: 0, count: 5)
        var storefronts: [String: Int] = [:]
    }

    /// Latest dataset counts; refreshed by `refreshStats` (cheap fetch of a few columns, no JSON decoding).
    private(set) var stats = Stats()
    private var statsRefreshedAt: Date = .distantPast

    func refreshStats(context: ModelContext, force: Bool = false) {
        guard force || Date().timeIntervalSince(statsRefreshedAt) > 4 else { return }
        statsRefreshedAt = .now
        var d = FetchDescriptor<TrainingRow>()
        d.propertiesToFetch = [\.label, \.labelMissing, \.hintsCollected, \.resultsCollected, \.jevCollected, \.storefront]
        guard let rows = try? context.fetch(d) else { return }
        var s = Stats()
        s.rows = rows.count
        for r in rows {
            if let l = r.label { s.labeled += 1; s.bands[PopularityBand(index: l).rawValue] += 1 }
            if r.labelMissing { s.missing += 1 }
            if r.hintsCollected { s.withHints += 1 }
            if r.resultsCollected { s.withResults += 1 }
            if r.jevCollected { s.withJev += 1 }
            s.storefronts[r.storefront, default: 0] += 1
        }
        stats = s
    }

    // MARK: Stage 1 — term universe

    func buildUniverse(storefronts: [String], useGenreLists: Bool, useSuggestions: Bool, hintSeedLimit: Int, apps: [TrackedApp], context: ModelContext) {
        run("Universe") { [self] progress in
            var existing = Set(try context.fetch(FetchDescriptor<TrainingRow>()).map { "\($0.storefront)|\($0.normalized)" })
            var added = 0
            var pending: [TrainingRow] = []
            func add(_ term: String, _ sf: String, _ source: String, list: Int? = nil) {
                let n = TrackedKeyword.normalize(term)
                guard n.count >= 2, n.count <= 60 else { return }
                let key = "\(sf.uppercased())|\(n)"
                guard existing.insert(key).inserted else { return }
                pending.append(TrainingRow(term: n, storefront: sf, source: source, listScore: list))
                added += 1
            }
            func flush(into ctx: ModelContext) {
                for r in pending { ctx.insert(r) }
                pending.removeAll()
                try? ctx.save()
            }
            // Tracked keywords
            for app in apps { for m in app.markets where storefronts.contains(m.countryCode) { for k in m.keywords { add(k.text, m.countryCode, "tracked") } } }
            flush(into: context)

            for sf in storefronts {
                try Task.checkCancellation()
                // Seeds for suggestions and autocomplete come from the genre lists' first words; when the lists were
                // already fetched on an earlier run, rebuild the seeds from the stored rows instead of refetching.
                var seeds: [String] = []
                if useGenreLists, await popularity.isConfigured {
                    if universeIsDone(sf, "genre") {
                        seeds = (try? context.fetch(FetchDescriptor<TrainingRow>())).map { $0.filter { $0.storefront == sf && $0.source.hasPrefix("genre_list:") }.map { $0.normalized.split(separator: " ").first.map(String.init) ?? $0.normalized } } ?? []
                        append("\(sf): genre lists already fetched — skipped")
                    } else {
                        var done = 0
                        for genre in AppleAdsGenre.allCases {
                            try Task.checkCancellation()
                            progress(done, AppleAdsGenre.allCases.count, "\(sf) · \(genre.displayName) list")
                            let rows = (try? await popularity.genreDataset(country: sf, genre: genre, monthsBack: 1)) ?? []
                            for r in rows { add(r.searchTerm, sf, "genre_list:\(genre.rawValue)", list: r.popularity1to100) }
                            seeds += rows.map { $0.searchTerm.split(separator: " ").first.map(String.init) ?? $0.searchTerm }
                            done += 1
                        }
                        flush(into: context)
                        markUniverse(sf, "genre")
                        append("\(sf): genre lists → \(added) new rows so far")
                    }
                }
                if useSuggestions, await popularity.isConfigured, !universeIsDone(sf, "suggest") {
                    let firstWords = Array(Set(seeds)).prefix(60)
                    var done = 0
                    for app in apps.prefix(2) {
                        for seed in firstWords {
                            try Task.checkCancellation()
                            progress(done, firstWords.count * min(2, apps.count), "\(sf) · suggestions for “\(seed)”")
                            let rows = (try? await popularity.keywordSuggestions(appID: app.trackID, seeds: [seed], country: sf, pageSize: 200)) ?? []
                            for r in rows { add(r.text, sf, "suggestions:\(app.trackID)") }
                            done += 1
                        }
                    }
                    flush(into: context)
                    markUniverse(sf, "suggest")
                    append("\(sf): suggestions → \(added) new rows so far")
                }
                // Autocomplete expansion: hints for the most common first words (cached on disk, 0.7 s each when not cached).
                if hintSeedLimit > 0, let storefront = StorefrontRegistry.lookup(sf), !universeIsDone(sf, "hints\(hintSeedLimit)") {
                    var counts: [String: Int] = [:]
                    for s in seeds { counts[s, default: 0] += 1 }
                    let ordered = counts.sorted { $0.value > $1.value }.map(\.key).prefix(hintSeedLimit)
                    var done = 0
                    for seed in ordered {
                        try Task.checkCancellation()
                        progress(done, ordered.count, "\(sf) · autocomplete “\(seed)”")
                        let terms = await cachedHints(seed: seed, storefront: storefront) ?? []
                        for t in terms { add(t, sf, "hints:\(seed)") }
                        done += 1
                        if done % 50 == 0 { flush(into: context) }
                    }
                    flush(into: context)
                    markUniverse(sf, "hints\(hintSeedLimit)")
                    append("\(sf): autocomplete expansion → \(added) new rows so far")
                }
            }
            flush(into: context)
            append("Universe: +\(added) new rows.")
        }
    }

    /// Consecutive throttled responses; drives the back-off below.
    private var hintThrottleHits = 0

    /// Nil means the request failed (throttled or network): nothing is cached and the row stays uncollected.
    private func cachedHints(seed: String, storefront: Storefront, stream: Int = 0) async -> [String]? {
        let key = "\(storefront.countryCode)|\(seed.lowercased())"
        if let c = hintCache[key] { return c }
        let provider = stream == 0 ? hints : hints2
        do {
            let terms = try await provider.suggestions(seed: seed, storefront: storefront).map(\.text)
            hintThrottleHits = 0
            hintCache[key] = terms
            saveHintCache()
            return terms
        } catch {
            if case ASOError.rateLimited = error { hintThrottleHits += 1 } else if case ASOError.http(_, let status, _) = error, status == 403 { hintThrottleHits += 1 }
            if hintThrottleHits > 0 {
                // Apple answers 429 for a while after a burst; wait it out instead of poisoning the cache with empties.
                let pause = min(300, 20 * hintThrottleHits)
                if hintThrottleHits == 1 || hintThrottleHits % 5 == 0 { append("Autocomplete throttled by Apple (\(hintThrottleHits)×); pausing \(pause)s.") }
                try? await Task.sleep(for: .seconds(pause))
            }
            return nil
        }
    }

    /// Rows that already have Jev features first (so feature groups overlap on the same rows), then the rest, stratified.
    static func prioritized(_ rows: [TrainingRow], limit: Int) -> [TrainingRow] {
        let withJev = rows.filter(\.jevCollected), without = rows.filter { !$0.jevCollected }
        var out = stratified(withJev, limit: limit)
        if out.count < limit { out += stratified(without, limit: limit - out.count) }
        return out
    }

    /// Nil when any of the three lookups failed; the row is retried on the next run.
    private func hintFeatures(for row: TrainingRow, storefront sf: Storefront, stream: Int) async -> PublicFeatures? {
        var f = row.features
        guard let own = await cachedHints(seed: row.term, storefront: sf, stream: stream) else { return nil }
        f.ownHintCount = own.count
        f.ownSelfPosition = (own.firstIndex { TrackedKeyword.normalize($0) == row.normalized }).map { $0 + 1 } ?? 0
        let first = row.normalized.split(separator: " ").first.map(String.init) ?? row.normalized
        guard let fw = await cachedHints(seed: first, storefront: sf, stream: stream) else { return nil }
        f.firstWordHintCount = fw.count
        f.firstWordPosition = (fw.firstIndex { TrackedKeyword.normalize($0) == row.normalized }).map { $0 + 1 } ?? 0
        let prefix = String(row.normalized.prefix(4))
        guard let pf = prefix == first ? fw : await cachedHints(seed: prefix, storefront: sf, stream: stream) else { return nil }
        f.prefixHintCount = pf.count
        f.prefixPosition = (pf.firstIndex { TrackedKeyword.normalize($0) == row.normalized }).map { $0 + 1 } ?? 0
        return f
    }

    // MARK: Stage 2 — labels

    func labelRows(context: ModelContext) {
        run("Labels") { [self] progress in
            let all = try context.fetch(FetchDescriptor<TrainingRow>())
            // Country-list terms carry Apple's official score already; that beats the dashboard index (which returns
            // 5 for brands and some generic terms it does not index). Also migrates rows labelled by an older build.
            var fromList = 0
            for r in all where r.listScore != nil && r.labelSource != "list" {
                r.label = r.listScore
                r.labelSource = "list"
                r.labelMissing = false
                fromList += 1
                if fromList % 2000 == 0 { try? context.save(); progress(fromList, all.count, "applying Apple list scores"); await Task.yield() }
            }
            if fromList > 0 { try? context.save(); append("Labels: \(fromList) rows take Apple's list score.") }

            let rows = all.filter { $0.label == nil && !$0.labelMissing }
            let byStorefront = Dictionary(grouping: rows, by: \.storefront)
            var done = 0
            for (sf, group) in byStorefront {
                let chunks = stride(from: 0, to: group.count, by: 100).map { Array(group[$0..<min($0 + 100, group.count)]) }
                // Three dashboard queries in flight; each is one GraphQL call in the signed-in web view.
                for wave in stride(from: 0, to: chunks.count, by: 3).map({ Array(chunks[$0..<min($0 + 3, chunks.count)]) }) {
                    try Task.checkCancellation()
                    progress(done, rows.count, "\(sf) · dashboard index ×\(wave.count)")
                    let termLists: [[String]] = wave.map { $0.map(\.term) }
                    async let r0 = queryIndex(termLists.count > 0 ? termLists[0] : nil, sf)
                    async let r1 = queryIndex(termLists.count > 1 ? termLists[1] : nil, sf)
                    async let r2 = queryIndex(termLists.count > 2 ? termLists[2] : nil, sf)
                    let results = Array((await [r0, r1, r2]).prefix(wave.count))
                    for (chunk, index) in zip(wave, results) {
                        guard let index else { continue }   // failed query: rows stay pending for the next run
                        for row in chunk {
                            if let v = index[row.normalized] { row.label = v; row.labelSource = "index"; row.labeledAt = .now } else { row.labelMissing = true }
                        }
                        done += chunk.count
                    }
                    try? context.save()
                    if results.allSatisfy({ $0 == nil }) { throw ASOError.notConfigured(service: "Apple Ads dashboard session (queries failing)") }
                }
            }
            append("Labels: \(done) rows from the dashboard index.")
        }
    }

    private func queryIndex(_ terms: [String]?, _ storefront: String) async -> [String: Int]? {
        guard let terms else { return nil }
        return try? await session.popularity(terms: terms, storefront: storefront)
    }

    // MARK: Stage 3 — public features

    private var hintsDone = 0

    func collectHints(limit: Int, context: ModelContext) {
        run("Autocomplete features") { [self] progress in
            let all = try context.fetch(FetchDescriptor<TrainingRow>(predicate: #Predicate { $0.label != nil && !$0.hintsCollected }))
            let rows = Self.prioritized(all, limit: limit)
            hintsDone = 0
            progress(0, rows.count, "")
            // Two streams with their own pacers; rows alternate between them.
            let total = rows.count
            let ids0 = stride(from: 0, to: total, by: 2).map { rows[$0].persistentModelID }
            let ids1 = stride(from: 1, to: total, by: 2).map { rows[$0].persistentModelID }
            async let a: Void = hintsWorker(ids: ids0, stream: 0, total: total)
            async let b: Void = hintsWorker(ids: ids1, stream: 1, total: total)
            _ = try await (a, b)
            try? context.save()
            append("Autocomplete features: \(total) rows.")
        }
    }

    private func hintsWorker(ids: [PersistentIdentifier], stream: Int, total: Int) async throws {
        let context = container.mainContext
        for id in ids {
            try Task.checkCancellation()
            guard let row = context.model(for: id) as? TrainingRow, let sf = StorefrontRegistry.lookup(row.storefront) else { continue }
            guard let f = await hintFeatures(for: row, storefront: sf, stream: stream) else { hintsDone += 1; continue }
            row.features = f
            row.hintsCollected = true
            hintsDone += 1
            stages["Autocomplete features"]?.completed = hintsDone
            stages["Autocomplete features"]?.total = total
            stages["Autocomplete features"]?.note = "\(row.storefront) · “\(row.term)”"
            if hintsDone % 25 == 0 { try? context.save() }
        }
    }

    func collectResults(limit: Int, depth: Int, context: ModelContext) {
        run("Search-result features") { [self] progress in
            let all = try context.fetch(FetchDescriptor<TrainingRow>(predicate: #Predicate { $0.label != nil && !$0.resultsCollected }))
            let rows = Self.prioritized(all, limit: limit)
            var done = 0
            for row in rows {
                try Task.checkCancellation()
                guard let sf = StorefrontRegistry.lookup(row.storefront) else { continue }
                progress(done, rows.count, "\(row.storefront) · “\(row.term)”")
                if let results = try? await search.search(term: row.term, storefront: sf, device: .iPhone, limit: depth) {
                    var f = row.features
                    f.apply(results: results, term: row.term)
                    row.features = f
                    row.resultsCollected = true
                }
                done += 1
                if done % 10 == 0 { try? context.save() }
            }
            try? context.save()
            append("Search-result features: \(rows.count) rows.")
        }
    }

    // MARK: Stage 4 — Jev

    func collectJev(limit: Int, context: ModelContext) {
        run("Jev features") { [self] progress in
            guard await jev.isConfigured else { throw ASOError.notConfigured(service: "OpenRouter") }
            let all = try context.fetch(FetchDescriptor<TrainingRow>(predicate: #Predicate { $0.label != nil && !$0.jevCollected }))
            let rows = Self.stratified(all, limit: limit)
            var done = 0
            var failures = 0
            // Eight requests in flight; Jev is fast and cheap, OpenRouter rate limits are the only ceiling.
            for batch in stride(from: 0, to: rows.count, by: 8).map({ Array(rows[$0..<min($0 + 8, rows.count)]) }) {
                try Task.checkCancellation()
                progress(done, rows.count, "“\(batch[0].term)” …")
                let inputs = batch.map { ($0.term, $0.storefront, StorefrontRegistry.lookup($0.storefront)?.defaultLocale.displayName ?? "English") }
                let results: [JevFeatures?] = await withTaskGroup(of: (Int, JevFeatures?).self) { group in
                    for (i, input) in inputs.enumerated() {
                        group.addTask { [jev] in (i, try? await jev.classify(term: input.0, storefront: input.1, storeLanguage: input.2)) }
                    }
                    var out = Array(repeating: JevFeatures?.none, count: inputs.count)
                    for await (i, f) in group { out[i] = f }
                    return out
                }
                for (row, f) in zip(batch, results) {
                    if let f { row.jev = f } else { failures += 1 }
                }
                done += batch.count
                if done % 40 == 0 { try? context.save() }
                if failures > 50, failures > done / 2 { throw ASOError.http(service: "OpenRouter", status: 429, message: "too many failures; stopping Jev stage") }
            }
            try? context.save()
            append("Jev features: \(rows.count - failures) ok, \(failures) failed.")
        }
    }

    /// Balanced sample across bands so the model sees the whole range, not just the popular head.
    static func stratified(_ rows: [TrainingRow], limit: Int) -> [TrainingRow] {
        guard limit > 0, rows.count > limit else { return rows }
        let groups = Dictionary(grouping: rows, by: { $0.band?.rawValue ?? -1 })
        let per = max(1, limit / max(1, groups.count))
        var out: [TrainingRow] = []
        for (_, g) in groups.sorted(by: { $0.key < $1.key }) { out += g.shuffled().prefix(per) }
        if out.count < limit {
            let taken = Set(out.map(\.persistentModelID))
            out += rows.filter { !taken.contains($0.persistentModelID) }.shuffled().prefix(limit - out.count)
        }
        return Array(out.prefix(limit))
    }

    // MARK: Export

    nonisolated static var exportDirectory: URL {
        let dir = PersistenceController.storeURL.deletingLastPathComponent().appendingPathComponent("training", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func export(context: ModelContext) throws -> URL {
        let rows = try context.fetch(FetchDescriptor<TrainingRow>())
        let url = Self.exportDirectory.appendingPathComponent("popularity-\(Date().formatted(.iso8601.year().month().day())).jsonl")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var out = Data()
        for r in rows {
            let ex = TrainingExample(term: r.term, storefront: r.storefront, source: r.source, label: r.label, listScore: r.listScore, features: r.features, jev: r.jev, labeledAt: r.labeledAt)
            out += try encoder.encode(ex)
            out += Data("\n".utf8)
        }
        try out.write(to: url, options: .atomic)
        append("Exported \(rows.count) rows → \(url.lastPathComponent)")
        return url
    }

    func deleteAll(context: ModelContext) throws {
        for r in try context.fetch(FetchDescriptor<TrainingRow>()) { context.delete(r) }
        try context.save()
        append("Training rows deleted.")
    }
}
