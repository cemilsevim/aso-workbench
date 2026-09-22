import SwiftUI
import SwiftData
import ASOCore

/// Written reviews across the app's storefronts, newest first, with what arrived since the last check.
struct ReviewsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.modelContext) private var context
    let app: TrackedApp

    @State private var country = ""
    @State private var minRating = 1
    @State private var onlyNew = false
    @State private var search = ""

    private var reviews: [ReviewRecord] {
        app.reviews
            .filter { country.isEmpty || $0.countryCode == country }
            .filter { $0.rating >= minRating }
            .filter { !onlyNew || $0.isNew }
            .filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || $0.body.localizedCaseInsensitiveContains(search) }
            .sorted { ($0.date ?? $0.fetchedAt) > ($1.date ?? $1.fetchedAt) }
    }
    private var countries: [String] { Array(Set(app.reviews.map(\.countryCode))).sorted() }

    var body: some View {
        VStack(spacing: 0) {
            controls
            Divider()
            if app.reviews.isEmpty {
                ContentUnavailableView("No written reviews stored yet", systemImage: "text.bubble",
                                       description: Text("Reviews are read from Apple's public feed for every tracked storefront when you measure. Press Check to read them now; ratings without text are counted on the Overview page instead."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                list
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Picker("Storefront", selection: $country) {
                Text("All storefronts").tag("")
                ForEach(countries, id: \.self) { Text("\(StorefrontRegistry.lookup($0)?.name ?? $0) (\($0))").tag($0) }
            }
            .frame(maxWidth: 240)
            Picker("Rating", selection: $minRating) {
                ForEach([1, 2, 3, 4, 5], id: \.self) { Text($0 == 1 ? "All ratings" : "≥ \($0) ★").tag($0) }
            }
            .frame(maxWidth: 150)
            Toggle("New only", isOn: $onlyNew).toggleStyle(.checkbox)
            TextField("Search reviews", text: $search).textFieldStyle(.roundedBorder).frame(maxWidth: 220)
            Spacer()
            Text("\(app.reviews.count) stored · \(app.reviews.filter(\.isNew).count) new").font(.callout).foregroundStyle(.secondary)
            summary
            if env.catalog.isCheckingReviews {
                ProgressView().controlSize(.small)
            } else {
                Button("Check tracked storefronts") { Task { await env.catalog.recordReviews(app: app, storefronts: app.sortedMarkets.compactMap(\.storefront), context: context) } }
                Button("Check all 50") { Task { await env.catalog.recordReviews(app: app, storefronts: StorefrontRegistry.sortedByName, context: context) } }
                    .help("One public request per storefront; about a minute")
            }
        }
        .padding(12)
    }

    private var summary: some View {
        let all = app.reviews
        let avg = all.isEmpty ? 0 : Double(all.map(\.rating).reduce(0, +)) / Double(all.count)
        return HStack(spacing: 8) {
            ForEach((1...5).reversed(), id: \.self) { r in
                let n = all.filter { $0.rating == r }.count
                Text("\(r)★ \(n)").font(.caption).monospacedDigit().foregroundStyle(n == 0 ? Color.secondary.opacity(0.5) : Color.secondary)
            }
            if !all.isEmpty { Text(String(format: "avg %.1f", avg)).font(.caption).foregroundStyle(.secondary) }
        }
    }

    private var list: some View {
        List(reviews, id: \.persistentModelID) { r in
            reviewRow(r)
        }
    }

    @ViewBuilder
    private func reviewRow(_ r: ReviewRecord) -> some View {
        let tint: Color = r.rating >= 4 ? .green : r.rating <= 2 ? .red : .orange
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(String(repeating: "★", count: r.rating) + String(repeating: "☆", count: 5 - r.rating)).foregroundStyle(tint)
                Text(r.title).font(.headline).lineLimit(2)
                if r.isNew { Text("new").font(.caption2).padding(.horizontal, 6).padding(.vertical, 2).background(Color.accentColor.opacity(0.15), in: Capsule()) }
                Spacer()
                Text("\(StorefrontRegistry.lookup(r.countryCode)?.name ?? r.countryCode) (\(r.countryCode))").font(.caption).foregroundStyle(.secondary)
            }
            Text(r.body).font(.callout).textSelection(.enabled)
            HStack(spacing: 8) {
                Text(r.author).font(.caption).foregroundStyle(.secondary)
                if let v = r.version { Text("v\(v)").font(.caption).foregroundStyle(.tertiary) }
                Text((r.date ?? r.fetchedAt).formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 6)
    }
}
