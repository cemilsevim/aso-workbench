import Foundation
import SwiftData
import ASOCore
import ASOProviders

/// Subscription revenue per app from RevenueCat, kept as daily snapshots so MRR can be read over time.
@Observable
final class RevenueService {
    private(set) var isRefreshing = false
    private(set) var lastMessage: String?
    private let provider = RevenueCatProvider()
    var keys: [String]

    init(keys: [String]) { self.keys = keys }
    var isConfigured: Bool { !keys.isEmpty }

    /// Reads every project reachable with the stored keys and stores one snapshot per project (replacing today's).
    func refresh(context: ModelContext) async {
        guard !isRefreshing, isConfigured else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        var projects = 0, failures: [String] = []
        for key in keys {
            do {
                for p in try await provider.projects(key: key) {
                    let apps = (try? await provider.apps(key: key, project: p.id)) ?? []
                    let o = try await provider.overview(key: key, project: p.id)
                    let dayStart = Calendar.current.startOfDay(for: .now)
                    for old in (try? context.fetch(FetchDescriptor<RevenueSnapshot>())) ?? [] where old.projectID == p.id && old.fetchedAt >= dayStart { context.delete(old) }
                    let snap = RevenueSnapshot(projectID: p.id, projectName: p.name, bundleIDs: apps.compactMap(\.bundleID), appNames: apps.filter { $0.type == "app_store" }.map(\.name),
                                               mrr: o.mrr, activeSubscriptions: o.activeSubscriptions, revenue28d: o.revenue28d, newCustomers28d: o.newCustomers28d,
                                               activeTrials: o.activeTrials, activeUsers28d: o.activeUsers28d)
                    context.insert(snap)
                    projects += 1
                }
            } catch {
                failures.append(error.localizedDescription)
            }
        }
        try? context.save()
        lastMessage = "\(projects) RevenueCat project(s) read" + (failures.isEmpty ? "." : "; \(failures.count) key(s) failed: \(failures.first ?? "").")
        AppLog.write("[revenue] \(lastMessage ?? "")")
    }

    /// Snapshots for the project that holds this app (matched by bundle id, then by name), newest first.
    static func snapshots(for app: TrackedApp, context: ModelContext) -> [RevenueSnapshot] {
        let all = (try? context.fetch(FetchDescriptor<RevenueSnapshot>(sortBy: [SortDescriptor(\.fetchedAt, order: .reverse)]))) ?? []
        let bundle = app.bundleID ?? ""
        let byBundle = all.filter { !bundle.isEmpty && $0.bundleIDs.split(separator: "|").contains { $0 == bundle[...] } }
        if !byBundle.isEmpty { return byBundle }
        let first = app.name.split(separator: ":").first.map { String($0).lowercased().replacingOccurrences(of: " ", with: "") } ?? ""
        return all.filter { s in !first.isEmpty && (s.projectName.lowercased().replacingOccurrences(of: " ", with: "").contains(first) || s.appNames.lowercased().replacingOccurrences(of: " ", with: "").contains(first)) }
    }
}
