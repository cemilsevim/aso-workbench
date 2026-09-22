import SwiftUI
import SwiftData
import Charts
import ASOCore

/// Lab → Popularity model: collect labelled data, train in-process, read the evaluation.
struct TrainingView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.modelContext) private var context
    @Query(sort: \TrackedApp.name) private var apps: [TrackedApp]

    @State private var storefronts: Set<String> = ["US"]
    @State private var useGenreLists = true
    @State private var useSuggestions = true
    @State private var hintSeedLimit = 300
    @State private var hintsLimit = 2000
    @State private var resultsLimit = 600
    @State private var jevLimit = 3000
    @State private var exportMessage: String?
    @State private var confirmDelete = false
    @State private var probeTerms = "study guide, test prep, cheat sheet, spaced repetition, note taking, homework helper, notes, comic book, webcomics"
    @State private var probeStorefront = "US"
    @State private var probeResult: String?
    @State private var probeBusy = false

    private var stats: TrainingService.Stats { env.training.stats }
    private var rowCount: Int { stats.rows }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                intro
                readiness
                oneClick
                progress
                statsView
                training
                DisclosureGroup("Advanced: run stages one by one") {
                    VStack(alignment: .leading, spacing: 14) {
                        probe
                        stage1
                        stage2
                        stage3
                        stage4
                    }
                    .padding(.top, 8)
                }
                logView
            }
            .padding(20)
        }
        .navigationTitle("Popularity model")
        .task {
            // Cheap column-only count every few seconds while the page is open; the 55k-row set is never loaded into the view.
            env.training.refreshStats(context: context, force: true)
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                env.training.refreshStats(context: context)
            }
        }
        .confirmationDialog("Delete all \(rowCount) training rows?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { try? env.training.deleteAll(context: context) }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Learn a general popularity score from Apple's own numbers").font(.title3.weight(.semibold))
            Text("Developer tool, hidden by default (Settings → Measurement → Show Lab). Train once here; the resulting model files are bundled into the app so every user gets the “est.” layer without Apple Ads access. Labels: Apple Ads dashboard index (5–100, exact term, per storefront). Features: public signals plus Jev's semantic judgements. Apple's own numbers always win when they exist.")
                .font(.callout).foregroundStyle(.secondary)
        }
    }

    private var readiness: some View {
        GroupBox("Prerequisites") {
            VStack(alignment: .leading, spacing: 6) {
                LabeledContent("Apple Ads API (genre lists, suggestions)") { ConnectionStateLabel(state: env.adsState) }
                LabeledContent("Apple Ads dashboard session (labels)") { Text(env.adsSession.state.isSignedIn ? "Signed in" : "Not signed in: labels need it").foregroundStyle(env.adsSession.state.isSignedIn ? .green : .orange) }
                LabeledContent("OpenRouter (Jev features)") { ConnectionStateLabel(state: env.openRouterState) }
            }
            .font(.callout)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var oneClick: some View {
        GroupBox("Recommended run (one click)") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Markets US, GB, DE, FR, TR · Apple genre lists + suggestions + 300 autocomplete seeds per market · dashboard labels for every term · then, in parallel: autocomplete features (3,000 terms), search-result features (800), Jev (8,000) · train and evaluate. About an hour. Everything is saved as it goes: press again after an interruption and finished parts are skipped; raise the limits in Advanced to extend the data later, then Train again.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("Run everything") {
                        env.training.runAll(storefronts: ["US", "GB", "DE", "FR", "TR"], hintSeeds: 300, resultsLimit: 800, useJev: true, apps: apps, context: context) {
                            await env.trainModel(context: context)
                            return env.trainer.report.map { "spearman \(String(format: "%.2f", $0.random.spearman))" } ?? (env.trainer.lastError ?? "")
                        }
                    }
                    .disabled(env.training.isRunning)
                    if env.training.pipelineRunning { Text(env.training.pipelineStep).font(.callout).foregroundStyle(.secondary) }
                    Spacer()
                    if env.training.isRunning { Button("Stop") { env.training.cancel() } }
                }
                if !env.adsSession.state.isSignedIn {
                    Text("Labels need the Apple Ads dashboard session: Connections → Sign in…. The run waits for it and continues on its own.").font(.caption).foregroundStyle(.orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Spot check of the label source: read the dashboard index for a few terms you know.
    private var probe: some View {
        GroupBox("Label source check (dashboard index)") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Reads the Apple Ads dashboard index for the terms below, so the label source can be spot-checked against values you know.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    TextField("Terms", text: $probeTerms).textFieldStyle(.roundedBorder)
                    TextField("SF", text: $probeStorefront).textFieldStyle(.roundedBorder).frame(width: 50)
                    Button("Probe") { Task { await runProbe() } }.disabled(probeBusy || !env.adsSession.state.isSignedIn)
                    if probeBusy { ProgressView().controlSize(.small) }
                }
                if let probeResult { Text(probeResult).font(.callout.monospaced()).textSelection(.enabled) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func runProbe() async {
        probeBusy = true
        defer { probeBusy = false }
        let terms = probeTerms.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if env.adsSession.referenceAdamID.isEmpty, let first = apps.first { env.adsSession.referenceAdamID = String(first.trackID) }
        do {
            let index = try await env.adsSession.popularity(terms: terms, storefront: probeStorefront)
            probeResult = terms.map { "\($0) = \(index[AppleAdsSessionService.normalize($0)].map(String.init) ?? "—")" }.joined(separator: " · ")
        } catch {
            probeResult = error.localizedDescription
        }
    }

    private var stage1: some View {
        GroupBox("1 · Term universe") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Where terms come from: Apple's monthly genre lists (head of the distribution), Apple Ads suggestions seeded with common first words, autocomplete expansion (long tail), and your tracked keywords.")
                    .font(.caption).foregroundStyle(.secondary)
                ScrollView {
                    StorefrontMultiPicker(selected: $storefronts).padding(.trailing, 8)
                }
                .frame(height: 150)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
                Text("Selected: \(storefronts.sorted().joined(separator: ", "))").font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 16) {
                    Toggle("Genre lists", isOn: $useGenreLists)
                    Toggle("Suggestions", isOn: $useSuggestions)
                    Stepper("Autocomplete seeds: \(hintSeedLimit)", value: $hintSeedLimit, in: 0...2000, step: 50)
                }
                .font(.callout)
                HStack {
                    Button("Build universe") {
                        env.training.buildUniverse(storefronts: storefronts.sorted(), useGenreLists: useGenreLists, useSuggestions: useSuggestions, hintSeedLimit: hintSeedLimit, apps: apps, context: context)
                    }
                    .disabled(env.training.isRunning || storefronts.isEmpty)
                    Text("≈ \(hintSeedLimit * storefronts.count * 12 / 10 / 60) min for autocomplete at 1.2 s per request").font(.caption).foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var stage2: some View {
        GroupBox("2 · Labels (dashboard index)") {
            HStack {
                Text("\(stats.rows - stats.labeled - stats.missing) rows waiting · 100 terms per request").font(.callout).foregroundStyle(.secondary)
                Spacer()
                Button("Label rows") { env.training.labelRows(context: context) }
                    .disabled(env.training.isRunning || !env.adsSession.state.isSignedIn)
            }
        }
    }

    private var stage3: some View {
        GroupBox("3 · Public features") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Stepper("Autocomplete features for up to \(hintsLimit) rows", value: $hintsLimit, in: 100...20000, step: 100)
                    Spacer()
                    Button("Collect autocomplete") { env.training.collectHints(limit: hintsLimit, context: context) }
                        .disabled(env.training.isRunning)
                }
                HStack {
                    Stepper("Search-result features for up to \(resultsLimit) rows (3 s each)", value: $resultsLimit, in: 50...5000, step: 50)
                    Spacer()
                    Button("Collect results") { env.training.collectResults(limit: resultsLimit, depth: 50, context: context) }
                        .disabled(env.training.isRunning)
                }
                Text("Both are stratified across popularity bands. Search results are the slow part; start with a few hundred and add more while the model trains.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .font(.callout)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var stage4: some View {
        GroupBox("4 · Jev features") {
            HStack {
                Stepper("Classify up to \(jevLimit) rows", value: $jevLimit, in: 100...50000, step: 100)
                Spacer()
                Button("Run Jev") { env.training.collectJev(limit: jevLimit, context: context) }
                    .disabled(env.training.isRunning || !env.openRouterState.isUsable)
            }
            .font(.callout)
        }
    }

    @ViewBuilder
    private var progress: some View {
        let s = env.training.stage
        if s.isRunning {
            HStack(spacing: 12) {
                ProgressView(value: Double(s.completed), total: Double(max(1, s.total))).frame(maxWidth: 260)
                Text("\(s.name) · \(s.completed)/\(s.total) · \(s.note)").font(.callout).lineLimit(1)
                Spacer()
                Button("Stop") { env.training.cancel() }
            }
            .padding(10)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var statsView: some View {
        GroupBox("Dataset") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 18) {
                    stat("Rows", stats.rows)
                    stat("Labelled", stats.labeled)
                    stat("No label", stats.missing)
                    stat("Autocomplete", stats.withHints)
                    stat("Results", stats.withResults)
                    stat("Jev", stats.withJev)
                    Spacer()
                    Button("Export JSONL") { do { let u = try env.training.export(context: context); exportMessage = u.path } catch { exportMessage = error.localizedDescription } }
                        .disabled(rowCount == 0)
                    Button("Delete all…", role: .destructive) { confirmDelete = true }.disabled(rowCount == 0 || env.training.isRunning)
                }
                if stats.labeled > 0 {
                    Chart {
                        ForEach(PopularityBand.allCases, id: \.rawValue) { b in
                            BarMark(x: .value("Band", b.label), y: .value("Rows", stats.bands[b.rawValue]))
                                .foregroundStyle(Color.accentColor)
                                .annotation(position: .top) { Text("\(stats.bands[b.rawValue])").font(.caption2) }
                        }
                    }
                    .chartYAxis(.hidden)
                    .frame(height: 120)
                    Text("Storefronts: " + stats.storefronts.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                }
                if let exportMessage { Text(exportMessage).font(.caption).foregroundStyle(.secondary).textSelection(.enabled) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func stat(_ title: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text("\(value)").font(.callout.weight(.medium)).monospacedDigit()
        }
    }

    private var training: some View {
        GroupBox("5 · Train and evaluate") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Boosted trees (CreateML), two stages: is the term in Apple's published range (≥35)? and if so, what value. 80/20 random holdout, a held-out storefront and held-out genres.")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Train") { Task { await env.trainModel(context: context) } }
                        .disabled(env.trainer.isTraining || stats.labeled < 60)
                    if env.trainer.isTraining { ProgressView().controlSize(.small) }
                }
                if let e = env.trainer.lastError { InlineMessage(kind: .error, text: e) }
                if let r = env.trainer.report {
                    reportView(r)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func reportView(_ r: ModelTrainer.Report) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Trained \(r.trainedAt.relativeLabel) on \(r.rowsTrain) rows (\(r.storefronts.joined(separator: ", "))) · features: \(r.featureGroups.joined(separator: ", "))")
                .font(.callout)
            Text("Stage 1: in Apple's published range (≥35)? accuracy \(String(format: "%.0f%%", r.publishedAccuracy * 100)) · precision \(String(format: "%.0f%%", r.publishedPrecision * 100)) · recall \(String(format: "%.0f%%", r.publishedRecall * 100)). Stage 2: value when it is. Apple's data has nothing between 6 and 34, so the estimate is either “< floor” or a value ≥35.")
                .font(.caption).foregroundStyle(.secondary)
            evaluation(r.random)
            if let c = r.inferenceLike { evaluation(c) }
            if let c = r.crossStorefront { evaluation(c) }
            ForEach(r.crossGenre, id: \.name) { evaluation($0) }
            if !r.crossGenre.isEmpty {
                Text("Held-out topic rows: the model never saw that topic's terms (its list terms plus everything Jev files under it). Close to the random holdout means the rule transfers across niches.").font(.caption).foregroundStyle(.secondary)
            }
            let top = r.featureImportance.sorted { $0.value > $1.value }.prefix(8)
            if !top.isEmpty {
                Text("Most useful features (holdout MAE increase when shuffled): " + top.map { "\($0.key) +\(String(format: "%.1f", $0.value))" }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text(verdict(r.random)).font(.callout.weight(.medium))
        }
    }

    private func evaluation(_ e: EvaluationReport) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(e.name) · \(e.count) rows").font(.subheadline.weight(.semibold))
            HStack(spacing: 18) {
                stat("Spearman", String(format: "%.2f", e.spearman))
                stat("MAE", String(format: "%.1f", e.mae))
                stat("Band exact", String(format: "%.0f%%", e.bandAccuracy * 100))
                stat("Band ±1", String(format: "%.0f%%", e.bandWithinOne * 100))
            }
            confusion(e)
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.callout.weight(.medium)).monospacedDigit()
        }
    }

    private func confusion(_ e: EvaluationReport) -> some View {
        Grid(horizontalSpacing: 6, verticalSpacing: 2) {
            GridRow {
                Text("actual \\ predicted").font(.caption2).foregroundStyle(.tertiary)
                ForEach(PopularityBand.allCases, id: \.rawValue) { Text($0.label).font(.caption2).foregroundStyle(.secondary) }
                Text("MAE").font(.caption2).foregroundStyle(.secondary)
            }
            ForEach(PopularityBand.allCases, id: \.rawValue) { a in
                GridRow {
                    Text(a.label).font(.caption2).foregroundStyle(.secondary)
                    ForEach(PopularityBand.allCases, id: \.rawValue) { p in
                        Text("\(e.confusion[a.rawValue][p.rawValue])").font(.caption.monospacedDigit())
                            .fontWeight(a == p ? .semibold : .regular)
                            .foregroundStyle(a == p ? Color.green : .primary)
                    }
                    Text(String(format: "%.0f", e.maePerBand[a.rawValue])).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func verdict(_ e: EvaluationReport) -> String {
        if e.spearman >= 0.6 && e.bandWithinOne >= 0.8 { return "Verdict: usable as the 4th popularity layer (labelled “est.”). Keep collecting; retrain monthly." }
        if e.spearman >= 0.4 { return "Verdict: directionally useful for ordering, not for values. Add search-result and Jev features and more storefronts, then retrain." }
        return "Verdict: not good enough to show numbers. Collect more labelled rows with full features before relying on it."
    }

    private var logView: some View {
        GroupBox("Log") {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(env.training.log.suffix(60).enumerated()), id: \.offset) { Text($0.element).font(.caption.monospaced()) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 140)
        }
    }
}
