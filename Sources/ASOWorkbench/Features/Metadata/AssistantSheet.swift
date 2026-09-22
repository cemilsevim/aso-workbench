import SwiftUI
import SwiftData
import ASOCore

/// "Write with AI": three rule-checked proposals for the current locale; one click fills the draft.
struct AssistantSheet: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    let app: TrackedApp
    let market: TrackedMarket?
    let locale: AppLocale
    let current: MetadataFields
    let siblings: [(AppLocale, MetadataFields)]
    var onPick: (MetadataFields) -> Void

    @State private var strategy: ASOAssistant.BrandStrategy = .featureFirst
    @State private var rewriteCopy = false
    @State private var brand = ""
    @State private var notes = ""
    @State private var proposals: [ASOAssistant.Proposal] = []
    @State private var ran = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Write the \(locale.rawValue) listing with AI").font(.headline)
                Spacer()
                Text(env.assistant.model).font(.caption).foregroundStyle(.tertiary)
                Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            Text("The writer model gets the house rules, your tracked keywords with Apple popularity and difficulty, the competitors seen in your queries and the app's description, and returns three listings. Each one is scored by the rule engine before you see it. Nothing is sent to Apple.")
                .font(.callout).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Picker("Demand", selection: $strategy) {
                    ForEach(ASOAssistant.BrandStrategy.allCases) { Text($0.title).tag($0) }
                }
                .frame(maxWidth: 420)
                TextField("Brand as it should appear", text: $brand).textFieldStyle(.roundedBorder).frame(width: 220)
                Toggle("Rewrite promotional text and description too", isOn: $rewriteCopy).toggleStyle(.checkbox)
                    .help("Empty fields are always written. Turn this on to replace existing copy as well; both fields are conversion copy, not indexed.")
            }
            TextField("Notes for the model (positioning, words to avoid, differentiator)", text: $notes).textFieldStyle(.roundedBorder)
            HStack {
                Button(ran ? "Generate again" : "Generate 3 proposals") { Task { await run() } }
                    .disabled(env.assistant.isBusy || brand.isEmpty)
                    .keyboardShortcut(.defaultAction)
                if env.assistant.isBusy { ProgressView().controlSize(.small); Text("Asking the model…").font(.callout).foregroundStyle(.secondary) }
                if let c = env.assistant.lastCost { Text("cost \(c)").font(.caption).foregroundStyle(.tertiary) }
                Spacer()
            }
            if let e = env.assistant.lastError { InlineMessage(kind: .error, text: e) }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(proposals) { p in proposalCard(p) }
                }
            }
        }
        .padding(16)
        .frame(width: 760, height: 640)
        .onAppear { if brand.isEmpty { brand = app.name.split(separator: ":").first.map { String($0).trimmingCharacters(in: .whitespaces) } ?? app.name } }
    }

    private func run() async {
        proposals = await env.assistant.propose(app: app, market: market, locale: locale, strategy: strategy, brandName: brand, siblings: siblings, current: current, notes: notes, rewriteCopy: rewriteCopy)
        ran = true
    }

    private func proposalCard(_ p: ASOAssistant.Proposal) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Proposal \(p.label)").font(.subheadline.weight(.semibold))
                    Text("rule score \(p.review.score)/100 · \(p.review.charactersUsed)/160 chars").font(.caption).foregroundStyle(p.review.errors == 0 ? .green : .orange)
                    Spacer()
                    Button("Use this") { onPick(p.fields); dismiss() }
                }
                field("Title", p.fields.name, limit: 30)
                field("Subtitle", p.fields.subtitle, limit: 30)
                field("Keywords", p.fields.keywords, limit: 100)
                if !(p.coveredPhrases.isEmpty && p.missedPhrases.isEmpty) {
                    Text("covers \(p.coveredPhrases.count)/\(p.coveredPhrases.count + p.missedPhrases.count) priority phrases" + (p.missedPhrases.isEmpty ? "" : " · missing: \(p.missedPhrases.prefix(6).joined(separator: ", "))"))
                        .font(.caption).foregroundStyle(p.missedPhrases.isEmpty ? .green : .secondary)
                }
                if !p.rationale.isEmpty { Text(p.rationale).font(.callout).foregroundStyle(.secondary) }
                ForEach(p.repairs, id: \.self) { r in
                    Label(r, systemImage: "wrench.and.screwdriver").font(.caption).foregroundStyle(.blue)
                }
                ForEach(p.review.findings.filter { $0.kind != .good }.prefix(5)) { f in
                    Label(f.message, systemImage: f.kind == .error ? "xmark.octagon.fill" : f.kind == .warning ? "exclamationmark.triangle.fill" : "info.circle")
                        .font(.caption).foregroundStyle(f.kind == .error ? .red : f.kind == .warning ? .orange : .secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func field(_ label: String, _ value: String, limit: Int) -> some View {
        HStack(alignment: .top) {
            Text(label).font(.caption).foregroundStyle(.secondary).frame(width: 64, alignment: .leading)
            Text(value).textSelection(.enabled)
            Spacer()
            Text("\(value.count)/\(limit)").font(.caption.monospacedDigit()).foregroundStyle(value.count > limit ? .red : .secondary)
        }
        .font(.callout)
    }
}
