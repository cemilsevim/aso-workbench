import SwiftUI
import SwiftData
import ASOCore

struct AddAppSheet: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    var onAdded: (TrackedApp) -> Void

    @State private var query = ""
    @State private var searchCountry = "US"
    @State private var results: [SearchResultApp] = []
    @State private var selectedResult: SearchResultApp?
    @State private var selectedMarkets: Set<String> = ["US"]
    @State private var device: DeviceContext = .iPhone
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Find the app") {
                    HStack {
                        TextField("App name, App Store link or ID", text: $query)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { Task { await search() } }
                        Picker("", selection: $searchCountry) {
                            ForEach(StorefrontRegistry.sortedByName) { Text("\($0.countryCode) · \($0.name)").tag($0.countryCode) }
                        }
                        .labelsHidden()
                        .frame(width: 180)
                        Button("Search") { Task { await search() } }
                            .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty || env.catalog.isSearching)
                    }
                    if env.catalog.isSearching { ProgressView().controlSize(.small) }
                    if let error { InlineMessage(kind: .error, text: error) }
                    if !results.isEmpty {
                        List(results, selection: $selectedResult) { app in
                            HStack(spacing: 10) {
                                AppIconView(url: app.iconURL, size: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(app.name).lineLimit(1)
                                    Text("\(app.sellerName) · \(app.primaryGenre ?? "—") · \(app.ratingCount ?? 0) ratings · ID \(app.trackID)")
                                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                            }
                            .tag(app)
                        }
                        .frame(minHeight: 180, maxHeight: 260)
                    }
                }
                Section("Markets to track") {
                    Picker("Device", selection: $device) {
                        ForEach(DeviceContext.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    StorefrontMultiPicker(selected: $selectedMarkets)
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Text(selectedResult.map { "Adding \($0.name)" } ?? "Select an app above").foregroundStyle(.secondary).font(.callout)
                Spacer()
                Keycap(keys: "esc")
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Keycap(keys: "↩")
                Button("Add App") { add() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(selectedResult == nil || selectedMarkets.isEmpty)
            }
            .padding()
        }
        .frame(width: 640, height: 620)
    }

    private func search() async {
        error = nil
        if let parsed = AppStoreURL.parse(query), let c = parsed.countryCode, StorefrontRegistry.lookup(c) != nil {
            searchCountry = c
            selectedMarkets.insert(c)
        }
        guard let sf = StorefrontRegistry.lookup(searchCountry) else { return }
        do {
            results = try await env.catalog.findApps(query: query, storefront: sf)
            if results.isEmpty { error = "No apps found for \"\(query)\" in \(sf.name)." }
            if results.count == 1 { selectedResult = results[0] }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func add() {
        guard let result = selectedResult else { return }
        let markets = selectedMarkets.compactMap(StorefrontRegistry.lookup).sorted { $0.countryCode < $1.countryCode }
        let app = env.catalog.addApp(result, markets: markets, device: device, context: context)
        onAdded(app)
        dismiss()
    }
}

/// Checkbox grid of storefronts.
struct StorefrontMultiPicker: View {
    @Binding var selected: Set<String>
    private let columns = [GridItem(.adaptive(minimum: 150), alignment: .leading)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 4) {
            ForEach(StorefrontRegistry.sortedByName) { sf in
                Toggle(isOn: Binding(get: { selected.contains(sf.countryCode) }, set: { on in
                    if on { selected.insert(sf.countryCode) } else { selected.remove(sf.countryCode) }
                })) {
                    Text("\(sf.countryCode) · \(sf.name)").lineLimit(1)
                }
                .toggleStyle(.checkbox)
            }
        }
    }
}

struct AddMarketSheet: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let app: TrackedApp
    var onAdded: (TrackedMarket) -> Void

    @State private var country = "US"
    @State private var device: DeviceContext = .iPhone

    var body: some View {
        VStack(spacing: 16) {
            Text("Add a market for \(app.name)").font(.headline)
            Form {
                Picker("Storefront", selection: $country) {
                    ForEach(StorefrontRegistry.sortedByName) { Text("\($0.countryCode) · \($0.name)").tag($0.countryCode) }
                }
                Picker("Device", selection: $device) {
                    ForEach(DeviceContext.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Add Market") {
                    guard let sf = StorefrontRegistry.lookup(country) else { return }
                    env.catalog.addMarket(to: app, storefront: sf, device: device, context: context)
                    if let m = app.markets.first(where: { $0.countryCode == sf.countryCode && $0.device == device }) { onAdded(m) }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 420)
    }
}
