import SwiftUI
import SwiftData
import ASOCore

/// MRR and subscription counts for the app's RevenueCat project, with the stored daily history.
struct RevenueCard: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.modelContext) private var context
    let app: TrackedApp

    var body: some View {
        let snaps = RevenueService.snapshots(for: app, context: context)
        let latest = snaps.first
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    if !env.revenue.isConfigured {
                        Text("Add RevenueCat secret API keys in Settings → RevenueCat to see MRR, active subscriptions and 28-day revenue here.").foregroundStyle(.secondary)
                    } else if let s = latest {
                        Text("\(s.projectName) · read \(s.fetchedAt.relativeLabel)\(s.appNames.split(separator: "|").count > 1 ? " · project holds \(s.appNames.split(separator: "|").count) apps (\(s.appNames.replacingOccurrences(of: "|", with: ", ")))" : "")")
                            .foregroundStyle(.secondary).lineLimit(2)
                    } else {
                        Text("No RevenueCat project matches this app (bundle \(app.bundleID ?? "?")). Press Refresh; projects are matched by bundle id, then by name.").foregroundStyle(.secondary)
                    }
                    Spacer()
                    if env.revenue.isRefreshing { ProgressView().controlSize(.small) }
                    else { Button("Refresh") { Task { await env.revenue.refresh(context: context) } }.controlSize(.small).disabled(!env.revenue.isConfigured) }
                }
                if let s = latest {
                    let previous = snaps.dropFirst().first { $0.fetchedAt < s.fetchedAt.addingTimeInterval(-20 * 3600) }
                    HStack(spacing: 12) {
                        StatCard(title: "MRR") {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(String(format: "$%.0f", s.mrr)).font(.title2.weight(.semibold)).monospacedDigit()
                                if let p = previous { DeltaLabel(delta: Int((s.mrr - p.mrr).rounded())) }
                            }
                        }
                        StatCard(title: "Active subscriptions") { Text("\(s.activeSubscriptions)").font(.title2.weight(.semibold)).monospacedDigit() }
                        StatCard(title: "Revenue · 28 days") { Text(String(format: "$%.0f", s.revenue28d)).font(.title2.weight(.semibold)).monospacedDigit() }
                        StatCard(title: "New customers · 28 days") { Text("\(s.newCustomers28d)").font(.title2.weight(.semibold)).monospacedDigit() }
                        StatCard(title: "Active trials") { Text("\(s.activeTrials)").font(.title2.weight(.semibold)).monospacedDigit() }
                    }
                    if snaps.count > 1 {
                        Table(Array(snaps.prefix(14))) {
                            TableColumn("Read") { r in Text(r.fetchedAt.formatted(date: .abbreviated, time: .shortened)).font(.caption) }
                            TableColumn("MRR") { r in Text(String(format: "$%.0f", r.mrr)).monospacedDigit() }.width(min: 60, ideal: 70)
                            TableColumn("Active subs") { r in Text("\(r.activeSubscriptions)").monospacedDigit() }.width(min: 80, ideal: 90)
                            TableColumn("Revenue 28d") { r in Text(String(format: "$%.0f", r.revenue28d)).monospacedDigit() }.width(min: 90, ideal: 100)
                            TableColumn("New customers") { r in Text("\(r.newCustomers28d)").monospacedDigit() }.width(min: 90, ideal: 110)
                            TableColumn("Trials") { r in Text("\(r.activeTrials)").monospacedDigit() }.width(min: 50, ideal: 60)
                        }
                        .frame(minHeight: 90, maxHeight: 200)
                    }
                    Text("RevenueCat overview metrics: MRR is normalized monthly recurring revenue of active subscriptions; revenue and new customers cover the last 28 days. Read on demand and once per launch; one snapshot per day is kept.")
                        .font(.caption).foregroundStyle(.tertiary)
                }
            }
            .font(.callout)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text("Revenue · RevenueCat")
        }
    }
}
