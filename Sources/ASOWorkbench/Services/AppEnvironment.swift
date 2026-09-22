import Foundation
import Observation
import SwiftData
import ASOCore
import ASOProviders

/// Composition root. Everything the UI needs is reachable from here, so views
/// stay free of construction logic and providers stay swappable.
@Observable
final class AppEnvironment {
    let container: ModelContainer
    let settings: AppSettings
    let credentials = CredentialStore()

    let search: ITunesSearchProvider
    let hints: AppStoreHintsProvider
    let popularity: AppleAdsPopularityProvider
    let metadata: ASCMetadataProvider

    let adsSession = AppleAdsSessionService()
    let jev: JevClient
    let llm: LLMClient
    let assistant: ASOAssistant
    let discovery: KeywordDiscovery
    let ideas: IdeaFinder
    let expansion: MarketExpansion
    let adsCampaigns: AppleAdsCampaignProvider
    let adsImport: AdsImportService
    let revenue: RevenueService
    let updates = UpdateChecker()
    let tracking: TrackingService
    let research: ResearchService
    let training: TrainingService
    let trainer = ModelTrainer()
    let models = EstimatorHolder()
    var estimator: PopularityEstimator? { models.estimator }
    let metadataService: MetadataService
    let catalog: CatalogService

    var ascState: ConnectionState = .notConfigured
    var adsState: ConnectionState = .notConfigured
    var openRouterState: ConnectionState = .notConfigured

    init(inMemory: Bool = false) {
        if !inMemory { PersistenceController.migrateLegacyDefaults() }
        let settings = AppSettings()
        self.settings = settings
        if !inMemory { PersistenceController.backupIfVersionChanged() }
        container = PersistenceController.makeContainer(inMemory: inMemory)

        search = ITunesSearchProvider(pacer: RequestPacer(minimumInterval: settings.pacingSeconds))
        hints = AppStoreHintsProvider()
        // Sanitised on load as well, so credentials saved by an older build (which kept a
        // trailing newline in pasted identifiers) work without re-entering them.
        let asc = credentials.loadASC()?.sanitized
        let ads = credentials.loadAppleAds()?.sanitized
        popularity = AppleAdsPopularityProvider(credentials: ads)
        adsCampaigns = AppleAdsCampaignProvider(credentials: ads)
        adsImport = AdsImportService(provider: adsCampaigns)
        revenue = RevenueService(keys: credentials.loadRevenueCatKeys())
        metadata = ASCMetadataProvider(credentials: asc)
        ascState = asc?.isComplete == true ? .configured : .notConfigured
        adsState = ads?.isComplete == true ? .configured : .notConfigured
        let orKey = credentials.loadOpenRouterKey()
        jev = JevClient(apiKey: orKey)
        llm = LLMClient(apiKey: orKey)
        assistant = ASOAssistant(llm: llm, search: search)
        discovery = KeywordDiscovery(search: search, hints: hints, popularity: popularity, session: adsSession, jev: jev, settings: settings)
        ideas = IdeaFinder(search: search, popularity: popularity, jev: jev, settings: settings)
        assistant.settings = settings
        openRouterState = (orKey ?? "").isEmpty ? .notConfigured : .configured

        tracking = TrackingService(provider: search, settings: settings)
        research = ResearchService(search: search, hints: hints, popularity: popularity, session: adsSession, jev: jev, models: models)
        expansion = MarketExpansion(search: search, popularity: popularity, session: adsSession, research: research, jev: jev, llm: llm, settings: settings)
        training = TrainingService(container: container, popularity: popularity, hints: hints, search: search, session: adsSession, jev: jev)
        metadataService = MetadataService(provider: metadata)
        metadataService.whatsNewLocalizer = { [assistant] source, srcLocale, locale, app in
            guard await assistant.isConfigured else { throw ASOError.notConfigured(service: "OpenRouter") }
            return try await assistant.localizeWhatsNew(source: source, sourceLocale: srcLocale, locale: locale, app: app)
        }
        catalog = CatalogService(search: search)
    }

    var mainContext: ModelContext { container.mainContext }

    // MARK: Connections

    func saveASC(_ creds: ASCCredentials?) async {
        do {
            try credentials.save(creds)
            await metadata.update(credentials: creds)
            ascState = creds?.isComplete == true ? .configured : .notConfigured
        } catch {
            ascState = .failed(error.localizedDescription)
        }
    }

    func saveAppleAds(_ creds: AppleAdsCredentials?) async {
        do {
            try credentials.save(creds)
            await popularity.update(credentials: creds)
            await adsCampaigns.update(credentials: creds)
            adsState = creds?.isComplete == true ? .configured : .notConfigured
        } catch {
            adsState = .failed(error.localizedDescription)
        }
    }

    /// Silent launch-time check so the sidebar dots reflect reality without a click.
    func verifyConfiguredConnections() async {
        async let a: Void = ascState.isUsable ? verifyASC() : ()
        async let b: Void = adsState.isUsable ? verifyAppleAds() : ()
        _ = await (a, b)
        await adsSession.checkSession()
        if openRouterState.isUsable { await verifyOpenRouter() }
        if revenue.isConfigured { await revenue.refresh(context: mainContext) }
        await updates.checkIfDue()
        AppLog.write("[launch] asc=\(ascState) ads=\(adsState) session=\(adsSession.state) openrouter=\(openRouterState)")
    }

    func saveRevenueCatKeys(_ keys: [String]) {
        let clean = keys.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        try? credentials.saveRevenueCatKeys(clean)
        revenue.keys = clean
    }

    func saveOpenRouterKey(_ key: String?) async {
        do {
            let clean = key?.trimmingCharacters(in: .whitespacesAndNewlines)
            try credentials.saveOpenRouterKey(clean)
            await jev.update(apiKey: clean)
            await llm.update(apiKey: clean)
            openRouterState = (clean ?? "").isEmpty ? .notConfigured : .configured
        } catch {
            openRouterState = .failed(error.localizedDescription)
        }
    }

    func verifyOpenRouter() async {
        do {
            let detail = try await jev.verify()
            openRouterState = .verified(at: .now, detail: detail)
        } catch {
            openRouterState = .failed(error.localizedDescription)
        }
    }

    func trainModel(context: ModelContext) async {
        let labeled = (try? context.fetch(FetchDescriptor<TrainingRow>(predicate: #Predicate { $0.label != nil }))) ?? []
        // All labelled rows train the model; excluding brands (tried 2026-09-19) lowered every metric.
        // Rows collected before the 429 back-off existed stored a burst-blocked autocomplete as three zero counts
        // ("paypal" with no suggestions). Those are unmeasured, not empty: reset them so the next hints stage retries.
        var reset = 0
        for r in labeled where r.hintsCollected {
            var f = r.features
            if f.ownHintCount == 0, f.firstWordHintCount == 0, f.prefixHintCount == 0 {
                f.ownHintCount = -1; f.firstWordHintCount = -1; f.prefixHintCount = -1
                f.ownSelfPosition = 0; f.firstWordPosition = 0; f.prefixPosition = 0
                r.features = f
                r.hintsCollected = false
                reset += 1
            }
        }
        if reset > 0 { try? context.save(); AppLog.write("[lab] reset \(reset) rows whose autocomplete counts were all zero (blocked fetch, not empty)") }
        let featured = labeled.filter { $0.jevCollected || $0.hintsCollected }
        let rows = featured.count >= 500 ? featured : labeled
        AppLog.write("[lab] training on \(rows.count) rows (\(featured.count) with Jev/autocomplete features of \(labeled.count) labelled)")
        await trainer.train(rows: rows)
        models.reload()
    }

    func verifyASC() async {
        do {
            let detail = try await metadata.verify()
            ascState = .verified(at: .now, detail: detail)
        } catch {
            ascState = .failed(error.localizedDescription)
        }
    }

    func verifyAppleAds() async {
        do {
            let detail = try await popularity.verify()
            adsState = .verified(at: .now, detail: detail)
        } catch {
            adsState = .failed(error.localizedDescription)
        }
    }
}
