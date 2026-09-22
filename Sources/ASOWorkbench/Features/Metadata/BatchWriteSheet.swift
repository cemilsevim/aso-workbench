import SwiftUI
import SwiftData
import ASOCore

/// Writes every locale of the app in one pass (each locale sees the ones written before it, so words are not repeated
/// on the same storefront) and saves the best proposal of each as that locale's draft.
struct BatchWriteSheet: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let app: TrackedApp
    let locales: [AppLocale]
    let marketFor: (AppLocale) -> TrackedMarket?
    var onFinished: () -> Void

    @State private var strategy: ASOAssistant.BrandStrategy = .featureFirst
    @State private var brand = ""
    @State private var notes = ""
    @State private var selected: Set<AppLocale> = []
    @State private var results: [ASOAssistant.BatchResult] = []
    @State private var ran = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Write all locales with AI").font(.title3.weight(.semibold))
                    Text("Locales are written in order; each one avoids the words already used by the others on its storefront. The best proposal of each becomes that locale's draft (baselines stay untouched; Apply is still a separate step).")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(ran ? "Done" : "Cancel") { if ran { onFinished() }; dismiss() }
            }
            HStack(spacing: 12) {
                Picker("Demand", selection: $strategy) {
                    ForEach(ASOAssistant.BrandStrategy.allCases) { Text($0.title).tag($0) }
                }
                .frame(maxWidth: 260)
                TextField("Brand as it should appear", text: $brand).textFieldStyle(.roundedBorder).frame(width: 200)
                TextField("Notes for every locale (optional)", text: $notes).textFieldStyle(.roundedBorder)
            }
            GroupBox("Locales (\(selected.count))") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), alignment: .leading)], alignment: .leading, spacing: 4) {
                    ForEach(locales) { l in
                        let m = marketFor(l)
                        let tracked = m?.keywords.count ?? 0
                        let evidenced = m?.keywords.filter { $0.latestPopularity != nil && $0.difficultyScore != nil }.count ?? 0
                        let thin = evidenced < 5
                        Toggle(isOn: Binding(get: { selected.contains(l) }, set: { if $0 { selected.insert(l) } else { selected.remove(l) } })) {
                            HStack(spacing: 6) {
                                Text("\(l.rawValue) · \(l.displayName)")
                                Text("→ \(m?.countryCode ?? "no market") · \(evidenced)/\(tracked) keywords with evidence").font(.caption).foregroundStyle(thin ? Color.orange : Color.secondary)
                                if thin { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange).help("Fewer than 5 keywords with popularity and difficulty in this market: the writer would mostly translate. Track keywords there first (Research → Try keywords in other countries with local forms, or Find golden keywords).") }
                            }
                        }
                        .toggleStyle(.checkbox).font(.callout)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 12) {
                if env.assistant.isBusy {
                    ProgressView().controlSize(.small)
                    Text(env.assistant.batchProgress ?? "Writing…").font(.callout).foregroundStyle(.secondary)
                } else {
                    Button {
                        Task {
                            ran = true
                            results = await env.assistant.writeAll(app: app, locales: locales.filter { selected.contains($0) }, marketFor: marketFor, strategy: strategy,
                                                                   brandName: brand, notes: notes, metadata: env.metadataService, context: context)
                        }
                    } label: { Label("Write \(selected.count) locale(s) (~$\(String(format: "%.2f", Double(selected.count) * 0.016)))", systemImage: "sparkles") }
                    .buttonStyle(.borderedProminent)
                    .disabled(selected.isEmpty || brand.isEmpty)
                }
                Spacer()
                if let c = env.assistant.lastCost, ran { Text("last call \(c)").font(.caption).foregroundStyle(.tertiary) }
            }
            if !results.isEmpty {
                Table(results) {
                    TableColumn("Locale") { r in Text("\(r.locale.rawValue) → \(r.market)") }
                        .width(min: 110, ideal: 130)
                    TableColumn("Score") { r in
                        if let e = r.error { Text(e).foregroundStyle(.red).lineLimit(1) }
                        else { Text("\(r.score)/100 · covers \(r.covered)/\(r.total)").monospacedDigit().foregroundStyle(r.score >= 85 ? .green : .orange) }
                    }
                    .width(min: 150, ideal: 170)
                    TableColumn("Title") { r in Text(r.title).lineLimit(1).textSelection(.enabled) }
                    TableColumn("Subtitle") { r in Text(r.subtitle).lineLimit(1).textSelection(.enabled) }
                    TableColumn("Keywords") { r in Text(r.keywords).lineLimit(1).textSelection(.enabled).font(.caption) }
                }
                .frame(minHeight: 160)
                Text("Drafts are saved. Pick a locale in the Metadata bar to review or edit it, then Apply per locale.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(minWidth: 900, minHeight: 480)
        .onAppear {
            if brand.isEmpty { brand = app.name.split(separator: ":").first.map { String($0).trimmingCharacters(in: .whitespaces) } ?? app.name }
            if selected.isEmpty { selected = Set(locales) }
        }
    }
}
