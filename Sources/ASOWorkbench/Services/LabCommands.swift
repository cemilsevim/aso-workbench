import Foundation
import SwiftData
import ASOCore

/// `asoworkbench://lab/<action>?...`, lets the training pipeline be driven from a script while the app runs.
/// Actions: status · probe(terms,sf) · universe(sf,genre,suggest,seeds) · label · hints(limit) · results(limit) · jev(limit) · train · export · cancel
enum LabCommands {
    static func handle(_ url: URL, env: AppEnvironment, context: ModelContext, apps: [TrackedApp]) async {
        guard url.scheme == "asoworkbench", url.host == "lab" else { return }
        let action = url.pathComponents.dropFirst().first ?? ""
        let q = Dictionary(uniqueKeysWithValues: (URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        AppLog.write("[lab] command \(action) \(q)")
        switch action {
        case "status":
            env.training.refreshStats(context: context, force: true)
            let s = env.training.stats
            AppLog.write("[lab] status rows=\(s.rows) labeled=\(s.labeled) missing=\(s.missing) hints=\(s.withHints) results=\(s.withResults) jev=\(s.withJev) bands=\(s.bands) storefronts=\(s.storefronts) job=\(env.training.progressLine()) pipeline=\(env.training.pipelineStep) session=\(env.adsSession.state) openrouter=\(env.openRouterState)")
        case "probe":
            let terms = (q["terms"] ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            if env.adsSession.referenceAdamID.isEmpty, let first = apps.first { env.adsSession.referenceAdamID = String(first.trackID) }
            do {
                let index = try await env.adsSession.popularity(terms: terms, storefront: q["sf"] ?? "US", adamIDOverride: q["adam"])
                AppLog.write("[lab] probe adam=\(q["adam"] ?? env.adsSession.referenceAdamID) sf=\(q["sf"] ?? "US") " + terms.map { "\($0)=\(index[AppleAdsSessionService.normalize($0)].map(String.init) ?? "—")" }.joined(separator: " · "))
                let raw = env.adsSession.lastRawRows.prefix(6).map { r in "\(r["name"] ?? "?")|pop=\(r["popularity"] ?? "?")|match=\(r["matchType"] ?? "?")" }
                AppLog.write("[lab] probe raw rows=\(env.adsSession.lastRawRows.count) sample: " + raw.joined(separator: " ; "))
            } catch {
                AppLog.write("[lab] probe error: \(error.localizedDescription)")
            }
        case "universe":
            let sfs = (q["sf"] ?? "US").split(separator: ",").map { String($0).uppercased() }
            env.training.buildUniverse(storefronts: sfs, useGenreLists: q["genre"] != "0", useSuggestions: q["suggest"] != "0", hintSeedLimit: Int(q["seeds"] ?? "300") ?? 300, apps: apps, context: context)
        case "label":
            if env.adsSession.referenceAdamID.isEmpty, let first = apps.first { env.adsSession.referenceAdamID = String(first.trackID) }
            env.training.labelRows(context: context)
        case "hints":
            env.training.collectHints(limit: Int(q["limit"] ?? "2000") ?? 2000, context: context)
        case "results":
            env.training.collectResults(limit: Int(q["limit"] ?? "600") ?? 600, depth: 50, context: context)
        case "jev":
            env.training.collectJev(limit: Int(q["limit"] ?? "3000") ?? 3000, context: context)
        case "train":
            await env.trainModel(context: context)
            if let r = env.trainer.report {
                AppLog.write("[lab] train stage1 published: acc=\(String(format: "%.2f", r.publishedAccuracy)) prec=\(String(format: "%.2f", r.publishedPrecision)) rec=\(String(format: "%.2f", r.publishedRecall))")
                AppLog.write("[lab] train rows=\(r.rowsTrain)+\(r.rowsTest) random: spearman=\(String(format: "%.3f", r.random.spearman)) mae=\(String(format: "%.1f", r.random.mae)) band=\(String(format: "%.2f", r.random.bandAccuracy)) within1=\(String(format: "%.2f", r.random.bandWithinOne)) confusion=\(r.random.confusion)")
                if let c = r.inferenceLike { AppLog.write("[lab] train \(c.name): spearman=\(String(format: "%.3f", c.spearman)) mae=\(String(format: "%.1f", c.mae)) band=\(String(format: "%.2f", c.bandAccuracy)) within1=\(String(format: "%.2f", c.bandWithinOne))") }
                if let c = r.crossStorefront { AppLog.write("[lab] train cross \(c.name): spearman=\(String(format: "%.3f", c.spearman)) mae=\(String(format: "%.1f", c.mae)) band=\(String(format: "%.2f", c.bandAccuracy)) within1=\(String(format: "%.2f", c.bandWithinOne))") }
                for g in r.crossGenre { AppLog.write("[lab] train \(g.name): spearman=\(String(format: "%.3f", g.spearman)) mae=\(String(format: "%.1f", g.mae)) within1=\(String(format: "%.2f", g.bandWithinOne))") }
                AppLog.write("[lab] importance " + r.featureImportance.sorted { $0.value > $1.value }.prefix(12).map { "\($0.key)=\(String(format: "%.2f", $0.value))" }.joined(separator: " "))
            } else if let e = env.trainer.lastError {
                AppLog.write("[lab] train error: \(e)")
            }
        case "export":
            if let u = try? env.training.export(context: context) { AppLog.write("[lab] exported \(u.path)") }
        case "runall":
            let sfs = (q["sf"] ?? "US,GB,DE,FR,TR").split(separator: ",").map { String($0).uppercased() }
            env.training.runAll(storefronts: sfs, hintSeeds: Int(q["seeds"] ?? "300") ?? 300, hintsLimit: Int(q["hints"] ?? "3000") ?? 3000, resultsLimit: Int(q["results"] ?? "800") ?? 800, jevLimit: Int(q["jevlimit"] ?? "8000") ?? 8000, useJev: q["jev"] != "0", apps: apps, context: context) {
                await env.trainModel(context: context)
                if let r = env.trainer.report {
                    return "random: spearman=\(String(format: "%.3f", r.random.spearman)) mae=\(String(format: "%.1f", r.random.mae)) band=\(String(format: "%.2f", r.random.bandAccuracy)) within1=\(String(format: "%.2f", r.random.bandWithinOne))" + (r.crossStorefront.map { " · \($0.name): spearman=\(String(format: "%.3f", $0.spearman)) mae=\(String(format: "%.1f", $0.mae))" } ?? "")
                }
                return env.trainer.lastError ?? "no report"
            }
        case "assistant":
            // asoworkbench://lab/assistant?app=<trackID>&locale=en-US&brand=Comics%20AI: logs three rule-checked proposals.
            guard let app = apps.first(where: { String($0.trackID) == q["app"] }) ?? apps.first, let locale = AppLocale.parse(q["locale"] ?? "en-US") else { return }
            let market = app.sortedMarkets.first { $0.countryCode == (q["sf"] ?? "US") } ?? app.sortedMarkets.first
            let current = env.metadataService.draftFields(for: app, locale: locale)
            let siblings: [(AppLocale, MetadataFields)] = app.drafts.compactMap { d in d.locale.flatMap { $0 == locale ? nil : ($0, d.fields) } }
            let proposals = await env.assistant.propose(app: app, market: market, locale: locale, strategy: q["strategy"] == "brand" ? .brandFirst : .featureFirst,
                                                        brandName: q["brand"] ?? app.name, siblings: siblings, current: current, notes: q["notes"] ?? "")
            if let e = env.assistant.lastError { AppLog.write("[lab] assistant error: \(e)") }
            for p in proposals {
                AppLog.write("[lab] assistant \(p.label) promo=\(p.fields.promotionalText.count)ch desc=\(p.fields.description.count)ch score=\(p.review.score) covers=\(p.coveredPhrases.count)/\(p.coveredPhrases.count + p.missedPhrases.count) missing=\(p.missedPhrases.joined(separator: "|")) chars=\(p.review.charactersUsed) title=\"\(p.fields.name)\" (\(p.fields.name.count)) subtitle=\"\(p.fields.subtitle)\" (\(p.fields.subtitle.count)) keywords=\"\(p.fields.keywords)\" (\(p.fields.keywords.count)) findings=\(p.review.findings.filter { $0.kind != .good }.map(\.message)) repairs=\(p.repairs)")
            }
            AppLog.write("[lab] assistant cost=\(env.assistant.lastCost ?? "?")")
        case "discover":
            // asoworkbench://lab/discover?app=<trackID>&sf=US&seeds=comic,manga&competitor=<trackID>&difficulty=10
            guard let app = apps.first(where: { String($0.trackID) == q["app"] }) ?? apps.first,
                  let market = app.sortedMarkets.first(where: { $0.countryCode == (q["sf"] ?? "US") }) ?? app.sortedMarkets.first, let sf = market.storefront else { return }
            var competitor: SearchResultApp?
            if let id = q["competitor"].flatMap(Int.init) { competitor = try? await env.search.lookup(trackID: id, storefront: sf) }
            let seeds = (q["seeds"] ?? "").split(separator: ",").map { String($0) }
            let result = await env.discovery.discover(competitor: competitor, seeds: seeds, app: app, market: market, hintSeedLimit: 6, difficultyLimit: Int(q["difficulty"] ?? "10") ?? 10)
            AppLog.write("[lab] discover \(env.discovery.lastMessage ?? "")")
            for c in result.prefix(25) {
                AppLog.write("[lab] discover \(c.golden(minPopularity: env.settings.goldenMinPopularity, maxDifficulty: env.settings.goldenMaxDifficulty) ? "★" : " ") \(c.term) pop=\(c.popularity.map(String.init) ?? "<\(c.upperBound ?? 40)") \(c.popularityScope ?? "") diff=\(c.difficulty.map { String($0.rounded) } ?? "-") brand=\(c.jevBrand.map { String(format: "%.2f", $0) } ?? "-") natural=\(c.jevNatural.map { String(format: "%.2f", $0) } ?? "-") src=\(c.sources.sorted().joined(separator: "+"))")
            }
        case "estimate":
            // asoworkbench://lab/estimate?sf=US&terms=comic%20maker,manga%20reader: runs the model on ad-hoc terms and logs each estimate.
            guard let sf = StorefrontRegistry.lookup(q["sf"] ?? "US") else { AppLog.write("[lab] estimate: unknown storefront"); return }
            let terms = (q["terms"] ?? "").split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            AppLog.write("[lab] estimate model=\(env.models.estimator?.origin ?? "none") sf=\(sf.countryCode) terms=\(terms.count)")
            for r in await env.research.estimate(terms: terms, storefront: sf) {
                let e: String
                switch r.estimate {
                case .published(let v, let p): e = "\(v) (p=\(String(format: "%.2f", p)))"
                case .below(let p): e = "below floor (p=\(String(format: "%.2f", p)))"
                case nil: e = "no model"
                }
                AppLog.write("[lab] estimate \(r.term): \(e) hints=\(r.features.ownHintCount)/\(r.features.firstWordHintCount)/\(r.features.prefixHintCount) pos=\(r.features.ownSelfPosition)/\(r.features.firstWordPosition)/\(r.features.prefixPosition) jev=\(r.jev.map { String(format: "brand %.2f demand %.2f", $0.brand, $0.demand) } ?? "-")")
            }
        case "fit":
            // asoworkbench://lab/fit?app=<trackID>&sf=DE&force=1: Jev fit for every tracked keyword of that market, logged.
            guard let app = apps.first(where: { String($0.trackID) == q["app"] }) ?? apps.first,
                  let market = app.sortedMarkets.first(where: { $0.countryCode == (q["sf"] ?? "US") }) ?? app.sortedMarkets.first, let sf = market.storefront else { return }
            await env.research.classifyKeywords(market.keywords, app: app, storefront: sf, context: context, forceFit: q["force"] == "1")
            AppLog.write("[lab] fit \(app.name) \(sf.countryCode): description \(app.storeDescription?.count ?? -1) chars")
            for k in market.keywords.sorted(by: { ($0.fitProbability ?? -1) > ($1.fitProbability ?? -1) }) {
                AppLog.write("[lab] fit \(k.text): \(k.fitProbability.map { String(format: "%.2f", $0) } ?? "-") nav=\(k.navigational.map { String(format: "%.2f", $0) } ?? "-") leaderOwns=\(k.leaderOwnsTerm) golden=\(k.isGolden(minPopularity: env.settings.goldenMinPopularity, maxDifficulty: env.settings.goldenMaxDifficulty)) lead=\(k.isGoldenLead(minPopularity: env.settings.goldenMinPopularity, maxDifficulty: env.settings.goldenMaxDifficulty))")
            }
        case "ideas":
            // asoworkbench://lab/ideas?sf=US&genre=GAMES&budget=10&min=40: app-gap scan, results logged as [ideas].
            let genres = q["genre"].flatMap(AppleAdsGenre.init(rawValue:)).map { [$0] } ?? AppleAdsGenre.allCases
            env.ideas.scan(country: q["sf"] ?? "US", genres: genres, budget: Int(q["budget"] ?? "10") ?? 10, minPopularity: Int(q["min"] ?? "40") ?? 40, maxDifficulty: Int(q["diff"] ?? "35") ?? 35, context: context)
        case "expand":
            // asoworkbench://lab/expand?app=<trackID>&from=US&to=DE,FR&terms=a,b: keyword × storefront evaluation, logged as [expand].
            guard let app = apps.first(where: { String($0.trackID) == q["app"] }) ?? apps.first,
                  let market = app.sortedMarkets.first(where: { $0.countryCode == (q["from"] ?? "US") }) ?? app.sortedMarkets.first else { return }
            let terms = (q["terms"] ?? "").split(separator: ",").map { String($0) }.filter { !$0.isEmpty }
            let countries = (q["to"] ?? "DE").split(separator: ",").map { String($0).uppercased() }
            env.expansion.clear()
            env.expansion.run(app: app, terms: terms.isEmpty ? market.sortedKeywords.prefix(6).map(\.text) : terms, countries: countries, device: market.device,
                              autoTrack: q["track"] == "1", sourceMarket: market, catalog: env.catalog, context: context, localize: q["localize"] == "1")
        case "writeall":
            // asoworkbench://lab/writeall?app=<trackID>&brand=YourBrand: batch-writes every locale that has a snapshot or draft.
            guard let app = apps.first(where: { String($0.trackID) == q["app"] }) ?? apps.first else { return }
            let locales = Set(app.snapshots.compactMap(\.locale) + app.drafts.compactMap(\.locale)).sorted { $0.rawValue < $1.rawValue }
            let marketFor: (AppLocale) -> TrackedMarket? = { locale in
                let ms = app.sortedMarkets
                let region = locale.rawValue.split(separator: "-").last.map { String($0).uppercased() }
                return ms.first { $0.storefront?.defaultLocale == locale } ?? ms.first { $0.countryCode == region } ?? ms.first
            }
            let results = await env.assistant.writeAll(app: app, locales: locales, marketFor: marketFor, strategy: .featureFirst, brandName: q["brand"] ?? app.name,
                                                       notes: "", metadata: env.metadataService, context: context)
            for r in results { AppLog.write("[lab] writeall \(r.locale.rawValue)→\(r.market) score=\(r.score) covers=\(r.covered)/\(r.total) title=\"\(r.title)\" subtitle=\"\(r.subtitle)\" keywords=\"\(r.keywords)\"\(r.error.map { " error=\($0)" } ?? "")") }
        case "marker":
            // asoworkbench://lab/marker?app=<trackID>&title=test&hoursAgo=3: pins a note marker; logs Δ per keyword against it.
            guard let app = apps.first(where: { String($0.trackID) == q["app"] }) ?? apps.first else { return }
            let m = ReleaseMarker(date: Date.now.addingTimeInterval(-Double(q["hoursAgo"] ?? "3")! * 3600), kind: "note", title: q["title"] ?? "test marker")
            m.app = app
            context.insert(m)
            try? context.save()
            if let market = app.sortedMarkets.first, let sf = market.storefront { await env.catalog.recordReleaseIfNew(app: app, storefront: sf, context: context) }
            AppLog.write("[lab] marker markers now: " + app.markers.map { "\($0.kind) \($0.title) \($0.date.formatted(date: .abbreviated, time: .shortened))" }.joined(separator: " | "))
            for market in app.sortedMarkets {
                for k in market.sortedKeywords.prefix(8) {
                    let d = k.rankDelta(reference: .lastMarker, markers: app.markers)
                    AppLog.write("[lab] marker \(market.countryCode) \(k.text): Δ=\(d.delta.map(String.init) ?? "-") against \(d.against)")
                }
            }
        case "ratings":
            // asoworkbench://lab/ratings?app=<trackID>&all=1: reads rating counts per storefront and logs the table.
            guard let app = apps.first(where: { String($0.trackID) == q["app"] }) ?? apps.first else { return }
            let sfs = q["all"] == "1" ? StorefrontRegistry.sortedByName : app.sortedMarkets.compactMap(\.storefront)
            await env.catalog.recordRatings(app: app, storefronts: sfs, context: context)
            for (cc, obs) in Dictionary(grouping: app.ratings, by: \.countryCode).sorted(by: { $0.key < $1.key }) {
                let latest = obs.max { $0.fetchedAt < $1.fetchedAt }!
                AppLog.write("[lab] ratings \(cc): \(latest.count) ratings avg=\(latest.average.map { String(format: "%.2f", $0) } ?? "-") observations=\(obs.count)")
            }
        case "reviews":
            // asoworkbench://lab/reviews?app=<trackID>&all=1: reads written reviews per storefront and logs the newest.
            guard let app = apps.first(where: { String($0.trackID) == q["app"] }) ?? apps.first else { return }
            let sfs = q["all"] == "1" ? StorefrontRegistry.sortedByName : app.sortedMarkets.compactMap(\.storefront)
            await env.catalog.recordReviews(app: app, storefronts: sfs, context: context)
            for r in app.reviews.sorted(by: { ($0.date ?? $0.fetchedAt) > ($1.date ?? $1.fetchedAt) }).prefix(6) {
                AppLog.write("[lab] review \(r.countryCode) \(r.rating)★ “\(r.title)” by \(r.author) v\(r.version ?? "-") \(r.date?.formatted(date: .abbreviated, time: .omitted) ?? "-"): \(String(r.body.prefix(80)))")
            }
        case "adsync":
            // asoworkbench://lab/adsync?days=30: imports the advertiser's Apple Ads keyword rows for tracked apps and logs them.
            await env.adsImport.sync(apps: apps, days: Int(q["days"] ?? "30") ?? 30, context: context)
            for app in apps where !app.adsStats.isEmpty {
                for r in app.adsStats.sorted(by: { $0.impressions > $1.impressions }).prefix(10) {
                    AppLog.write("[lab] ads \(app.name) \(r.country) [\(r.keyword)] \(r.matchType) impr=\(r.impressions) taps=\(r.taps) inst=\(r.installs) spend=\(String(format: "%.2f", r.spend)) \(r.currency)")
                }
            }
        case "ascstatus":
            // asoworkbench://lab/ascstatus?app=<trackID>, read-only: versions, locales on App Store Connect, screenshot sets.
            guard let app = apps.first(where: { String($0.trackID) == q["app"] }) ?? apps.first else { return }
            do {
                let versions = try await env.metadataService.versions(app: app)
                AppLog.write("[lab] asc \(app.name) versions: " + versions.map { "v\($0.versionString) \($0.state)\($0.isEditable ? " (editable)" : "")" }.joined(separator: " · "))
                await env.metadataService.pullSnapshots(for: app, context: context)
                AppLog.write("[lab] asc locales: " + app.snapshots.filter { $0.source == "asc" }.map { "\($0.localeRaw) name=\"\($0.fields.name)\" kw=\($0.fields.keywords.count)ch wn=\($0.fields.whatsNew.count)ch" }.joined(separator: " | "))
            } catch { AppLog.write("[lab] asc error: \(error.localizedDescription)") }
        case "improve":
            // asoworkbench://lab/improve?app=<trackID>&locale=en-US&sf=US: one improved draft, logged (not saved).
            guard let app = apps.first(where: { String($0.trackID) == q["app"] }) ?? apps.first, let locale = AppLocale.parse(q["locale"] ?? "en-US") else { return }
            let market = app.sortedMarkets.first { $0.countryCode == (q["sf"] ?? "US") } ?? app.sortedMarkets.first
            let current = env.metadataService.draftFields(for: app, locale: locale)
            let siblings: [(AppLocale, MetadataFields)] = app.drafts.compactMap { d in d.locale.flatMap { $0 == locale ? nil : ($0, d.fields) } }
            let brand = app.name.split(separator: ":").first.map { String($0).trimmingCharacters(in: .whitespaces) } ?? app.name
            if let p = await env.assistant.improve(app: app, market: market, locale: locale, current: current, brandName: brand, siblings: siblings) {
                AppLog.write("[lab] improve title=\"\(p.fields.name)\" (\(p.fields.name.count)) subtitle=\"\(p.fields.subtitle)\" (\(p.fields.subtitle.count)) keywords=\"\(p.fields.keywords)\" (\(p.fields.keywords.count)) findings=\(p.review.findings.filter { $0.kind != .good }.map(\.message))")
            } else { AppLog.write("[lab] improve error: \(env.assistant.lastError ?? "?")") }
        case "revenue":
            await env.revenue.refresh(context: context)
            for app in apps {
                if let s = RevenueService.snapshots(for: app, context: context).first {
                    AppLog.write("[lab] revenue \(app.name): project \(s.projectName) mrr=$\(Int(s.mrr)) subs=\(s.activeSubscriptions) revenue28d=$\(Int(s.revenue28d)) new=\(s.newCustomers28d) trials=\(s.activeTrials)")
                } else { AppLog.write("[lab] revenue \(app.name): no matching project") }
            }
        case "cancel":
            env.training.cancel()
        default:
            AppLog.write("[lab] unknown action \(action)")
        }
    }
}
