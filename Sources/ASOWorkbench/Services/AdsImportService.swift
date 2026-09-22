import Foundation
import SwiftData
import ASOCore
import ASOProviders

/// Pulls the advertiser's own Apple Ads keyword results (last N days, per storefront) into the app: the most reliable
/// demand signal that exists for terms Apple's popularity index leaves at 5, and the ground truth for any ads plan.
@Observable
final class AdsImportService {
    private(set) var isSyncing = false
    private(set) var lastMessage: String?
    private(set) var lastSyncAt: Date?
    private let provider: AppleAdsCampaignProvider

    init(provider: AppleAdsCampaignProvider) { self.provider = provider }

    var isConfigured: Bool { get async { await provider.isConfigured } }

    /// Replaces the stored stats for every campaign that belongs to a tracked app.
    func sync(apps: [TrackedApp], days: Int = 30, context: ModelContext) async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        let end = Date.now, start = end.addingTimeInterval(-Double(days) * 86_400)
        do {
            let campaigns = try await provider.campaigns()
            var rows = 0, matched = 0
            for c in campaigns {
                guard let adam = c.adamID, let app = apps.first(where: { $0.trackID == adam }) else { continue }
                matched += 1
                let stats = try await provider.keywordReport(campaignID: c.id, start: start, end: end)
                for old in app.adsStats where old.campaignID == c.id { context.delete(old) }
                for s in stats {
                    let rec = AdsKeywordStat(s, campaignName: c.name, periodStart: start, periodEnd: end)
                    rec.app = app
                    context.insert(rec)
                    rows += 1
                }
            }
            try? context.save()
            lastSyncAt = .now
            lastMessage = "\(campaigns.count) campaign(s) in the account, \(matched) for tracked apps; \(rows) keyword × storefront row(s) for the last \(days) days."
        } catch {
            lastMessage = error.localizedDescription
        }
        AppLog.write("[ads] sync: \(lastMessage ?? "")")
    }
}
