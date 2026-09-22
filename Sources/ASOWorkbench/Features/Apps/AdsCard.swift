import SwiftUI
import SwiftData
import ASOCore

/// The advertiser's own Apple Ads results for this app, per storefront, from the last sync.
struct AdsCard: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.modelContext) private var context
    @Query private var apps: [TrackedApp]
    let app: TrackedApp

    nonisolated struct Row: Identifiable, Sendable {
        let id: String
        let country: String
        let impressions: Int
        let taps: Int
        let installs: Int
        let spend: Double
        let currency: String
        var cpi: Double? { installs > 0 ? spend / Double(installs) : nil }
        var cr: Double? { taps > 0 ? Double(installs) / Double(taps) : nil }
    }

    private var rows: [Row] {
        Dictionary(grouping: app.adsStats, by: \.country).map { cc, list in
            Row(id: cc, country: cc, impressions: list.reduce(0) { $0 + $1.impressions }, taps: list.reduce(0) { $0 + $1.taps },
                installs: list.reduce(0) { $0 + $1.installs }, spend: list.reduce(0) { $0 + $1.spend }, currency: list.first?.currency ?? "")
        }
        .sorted { $0.spend > $1.spend }
    }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    if let m = env.adsImport.lastMessage { Text(m).font(.callout).foregroundStyle(.secondary).lineLimit(2) }
                    else { Text("Your own campaign results: the ground truth for demand and cost per storefront. Sync reads the last 30 days for every tracked app.").font(.callout).foregroundStyle(.secondary) }
                    Spacer()
                    if env.adsImport.isSyncing { ProgressView().controlSize(.small) }
                    else {
                        Button("Sync last 30 days") { Task { await env.adsImport.sync(apps: apps, days: 30, context: context) } }.controlSize(.small)
                            .disabled(!env.adsState.isUsable)
                            .help(env.adsState.isUsable ? "Apple Ads Campaign Management API, same key as popularity" : "Connect Apple Ads (sidebar → Connections)")
                    }
                }
                if !rows.isEmpty {
                    Table(rows) {
                        TableColumn("Storefront") { r in Text("\(StorefrontRegistry.lookup(r.country)?.name ?? r.country) (\(r.country))") }
                        TableColumn("Impressions") { r in Text("\(r.impressions)").monospacedDigit() }.width(min: 80, ideal: 90)
                        TableColumn("Taps") { r in Text("\(r.taps)").monospacedDigit() }.width(min: 50, ideal: 60)
                        TableColumn("Installs") { r in Text("\(r.installs)").monospacedDigit() }.width(min: 60, ideal: 70)
                        TableColumn("Spend") { r in Text(String(format: "%.2f %@", r.spend, r.currency)).monospacedDigit() }.width(min: 80, ideal: 100)
                        TableColumn("Cost / install") { r in Text(r.cpi.map { String(format: "%.2f", $0) } ?? "—").monospacedDigit() }.width(min: 90, ideal: 100)
                        TableColumn("Tap → install") { r in Text(r.cr.map { String(format: "%.0f%%", $0 * 100) } ?? "—").monospacedDigit() }.width(min: 90, ideal: 100)
                    }
                    .frame(minHeight: 100, maxHeight: 220)
                    Text("Per keyword and storefront the same numbers sit in the Keywords table (“Ads” column).").font(.caption).foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text("Apple Ads · your campaigns")
        }
    }
}
