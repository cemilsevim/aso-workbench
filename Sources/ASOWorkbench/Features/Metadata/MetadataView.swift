import SwiftUI
import ASOProviders
import SwiftData
import ASOCore

/// Draft editor with live validation, diff against the App Store Connect baseline,
/// and a gated apply flow (snapshot → validate → diff → confirm → apply → re-read).
struct MetadataView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.modelContext) private var context
    let app: TrackedApp
    var market: TrackedMarket? = nil
    @State private var showAssistant = false
    @State private var showBatchWrite = false
    @State private var showApplyAll = false
    @State private var beforeImprove: MetadataFields?
    @State private var showLegalDetails = false
    @State private var showWhatsNew = false
    @State private var applyCreateMissing = true
    @State private var applyCopyFrom: AppLocale = .enUS
    @State private var ascVersions: [ASCMetadataProvider.VersionInfo] = []
    @State private var newVersionString = ""

    @State private var locale: AppLocale = .enUS
    @State private var fields = MetadataFields.empty
    @State private var loadedLocale: AppLocale?
    @State private var showApply = false
    @State private var showManualBaseline = false
    @State private var resultMessage: (kind: InlineMessage.Kind, text: String)?

    /// Locales worth writing: every tracked market's store language, plus whatever App Store Connect or drafts already hold.
    private var availableLocales: [AppLocale] {
        var set = Set(app.snapshots.compactMap(\.locale) + app.drafts.compactMap(\.locale))
        for m in app.sortedMarkets { if let l = m.storefront?.defaultLocale { set.insert(l) } }
        if set.isEmpty { set.insert(.enUS) }
        // Primary locales of tracked markets first (in market order), then the rest alphabetically.
        let primary = app.sortedMarkets.compactMap { $0.storefront?.defaultLocale }
        var out: [AppLocale] = []
        for l in primary where set.contains(l) && !out.contains(l) { out.append(l) }
        for l in set.sorted(by: { $0.rawValue < $1.rawValue }) where !out.contains(l) { out.append(l) }
        return out
    }
    private var baselineRecord: MetadataSnapshotRecord? { app.snapshots.first { $0.localeRaw == locale.rawValue } }
    private var baseline: MetadataFields? { baselineRecord?.fields }
    private var issues: [ValidationIssue] { MetadataValidator.validate(fields) }
    /// Other locales of this app (for the same-storefront overlap rule).
    private var siblings: [(AppLocale, MetadataFields)] {
        app.drafts.compactMap { d in d.locale.flatMap { $0 == locale ? nil : ($0, d.fields) } }
    }
    private var rules: ASORules.Report { ASORules.review(fields, locale: locale, siblings: siblings, storefront: marketFor(locale)?.countryCode) }
    private var plan: ASOAssistant.KeywordPlan { ASOAssistant.plan(market: marketFor(locale), easyDifficulty: env.settings.writerEasyDifficulty, maxDifficulty: env.settings.writerMaxDifficulty) }

    /// The tracked market whose storefront speaks this locale (de-DE → DE); falls back to the given or first market.
    private func marketFor(_ locale: AppLocale) -> TrackedMarket? {
        let ms = app.sortedMarkets
        let region = locale.rawValue.split(separator: "-").last.map { String($0).uppercased() }
        return ms.first { $0.storefront?.defaultLocale == locale } ?? ms.first { $0.countryCode == region } ?? market ?? ms.first
    }
    private var changes: [FieldChange] { baseline.map { MetadataDiff.changes(baseline: $0, draft: fields) } ?? [] }

    var body: some View {
        HSplitView {
            editor.frame(minWidth: 480, maxWidth: .infinity, maxHeight: .infinity)
            side.frame(minWidth: 300, idealWidth: 360, maxWidth: 480, maxHeight: .infinity)
        }
        .toolbar { toolbar }
        .task(id: locale) { loadDraft() }
        .onChange(of: fields) { _, new in saveDraft(new) }
        .onChange(of: market?.countryCode) { _, _ in
            if let l = market?.storefront?.defaultLocale, l != locale { locale = l; loadDraft() }
        }
        .sheet(isPresented: $showApply) { applySheet }
        .sheet(isPresented: $showManualBaseline) { ManualBaselineSheet(app: app, locale: locale) }
        .sheet(isPresented: $showApplyAll) {
            ApplyAllSheet(app: app, locales: availableLocales).environment(env)
        }
        .sheet(isPresented: $showWhatsNew) {
            WhatsNewSheet(app: app, locales: availableLocales).environment(env)
        }
        .sheet(isPresented: $showBatchWrite) {
            BatchWriteSheet(app: app, locales: availableLocales, marketFor: marketFor) { loadDraft(force: true) }
                .environment(env)
        }
        .sheet(isPresented: $showAssistant) {
            AssistantSheet(app: app, market: marketFor(locale), locale: locale, current: fields, siblings: siblings) { picked in
                fields = picked
            }
        }
    }

    // MARK: Editor

    private var editor: some View {
        Form {
            if let message = resultMessage {
                InlineMessage(kind: message.kind, text: message.text)
            } else if let m = env.metadataService.lastMessage {
                InlineMessage(kind: .info, text: m)
            }
            HStack(spacing: 6) {
                Image(systemName: "arrow.right.circle").foregroundStyle(.secondary)
                Text("Flow: **Baseline ▸ Pull** what Apple holds → **Write ▸ Write with AI** or **Make better** → check the score and keyword coverage on the right → **Publish ▸ Apply**. Drafts save as you type; nothing reaches Apple until you apply.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(MetadataField.allCases) { field in
                Section {
                    if field.isMultiline {
                        TextEditor(text: binding(field))
                            .font(.body)
                            .frame(minHeight: field == .description ? 180 : 70)
                    } else {
                        TextField(field.title, text: binding(field), prompt: Text(field == .keywords ? "comma,separated,keywords" : ""))
                            .textFieldStyle(.roundedBorder)
                            .labelsHidden()
                    }
                    counter(for: field)
                } header: {
                    HStack {
                        Text(field.title)
                        Spacer()
                        Text(field.resource == .appInfoLocalization ? "App Info" : "Version").font(.caption2).foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func binding(_ field: MetadataField) -> Binding<String> {
        Binding(get: { fields[field] }, set: { fields[field] = $0 })
    }

    private func counter(for field: MetadataField) -> some View {
        let m = TextMeasure(fields[field])
        let limit = field.limit
        let over = m.codePoints > limit && m.utf8Bytes > limit
        let ambiguous = m.isAmbiguous(limit)
        return HStack(spacing: 8) {
            Text("\(m.codePoints) / \(limit) characters").monospacedDigit()
            if m.isMultiByte || field == .keywords {
                Text("· \(m.utf8Bytes) bytes").monospacedDigit().foregroundStyle(ambiguous ? .orange : .secondary)
            }
            if field == .keywords {
                Text("· \(fields.keywordList.count) keywords").foregroundStyle(.secondary)
            }
            if let baseline, baseline[field] != fields[field] {
                Text("· changed").foregroundStyle(.tint)
            }
            Spacer()
        }
        .font(.caption)
        .foregroundStyle(over ? .red : .secondary)
    }

    // MARK: Side panel

    private var side: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        let covered = plan.priority.filter { ASOAssistant.KeywordPlan.covers(fields, phrase: $0.term) }.count
                        if plan.priority.isEmpty {
                            Label("No keyword evidence for this locale yet: the writer would only translate. Track keywords in the \(marketFor(locale)?.countryCode ?? "matching") market (Research → Try keywords in other countries with local forms) and refresh popularity first.", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        } else {
                            Text("\(covered) of \(plan.priority.count) priority phrases covered (every word of the phrase somewhere in title, subtitle or keywords).")
                                .foregroundStyle(covered == plan.priority.count ? .green : .secondary)
                            ForEach(plan.priority) { it in
                                HStack(spacing: 6) {
                                    Image(systemName: ASOAssistant.KeywordPlan.covers(fields, phrase: it.term) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(ASOAssistant.KeywordPlan.covers(fields, phrase: it.term) ? Color.green : Color.secondary)
                                    Text(it.tier).font(.caption2.weight(.bold)).padding(.horizontal, 5).padding(.vertical, 1)
                                        .background((it.tier == "A" ? Color.green : it.tier == "B" ? Color.blue : Color.orange).opacity(0.18), in: Capsule())
                                        .help(it.tier == "A" ? "Winnable now: difficulty ≤ \(env.settings.writerEasyDifficulty) or already top 10" : it.tier == "B" ? "Reachable: difficulty ≤ \(env.settings.writerMaxDifficulty)" : "Popular but hard: only if room remains")
                                    Text(it.term).lineLimit(1)
                                    Spacer()
                                    Text("pop \(it.popularity.map(String.init) ?? "?") · diff \(it.difficulty.map(String.init) ?? "?")\(it.rank.map { " · \($0)" } ?? "")")
                                        .font(.caption).monospacedDigit().foregroundStyle(.tertiary)
                                }
                            }
                            if !plan.avoid.isEmpty {
                                Text("Not for this listing (brand, navigational, unrelated or too hard): " + plan.avoid.map(\.term).joined(separator: ", ")).font(.caption).foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Text("Keyword coverage · \(marketFor(locale)?.countryCode ?? "—")")
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        @Bindable var app = app
                        HStack {
                            if app.hasLegalFooter {
                                let present = LegalFooter.contains(fields.description, eulaURL: app.effectiveEULA, privacyURL: app.privacyURL)
                                Label(present ? "Terms and privacy links are in this description" : "Added automatically when you apply", systemImage: present ? "checkmark.circle.fill" : "clock")
                                    .foregroundStyle(present ? Color.green : Color.secondary)
                            } else {
                                Label("Off", systemImage: "circle").foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(showLegalDetails ? "Hide" : "Edit") { showLegalDetails.toggle() }.controlSize(.small)
                        }
                        if showLegalDetails {
                        Toggle("Append Terms of Use and Privacy Policy links to every description", isOn: $app.legalFooterEnabled).toggleStyle(.checkbox)
                        TextField("Custom Terms of Use URL (empty = Apple's standard EULA, used automatically)", text: $app.eulaURL).textFieldStyle(.roundedBorder)
                        TextField("Privacy Policy URL (filled from App Store Connect on Pull)", text: $app.privacyURL).textFieldStyle(.roundedBorder)
                        TextField("Optional note above the links (e.g. subscription terms), one language for all locales", text: $app.legalNote).textFieldStyle(.roundedBorder)
                        HStack {
                            Text("Apple requires these links for apps with auto-renewable subscriptions.").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Button("Insert here") {
                                var f = fields
                                if env.metadataService.ensureLegalFooter(&f, app: app, locale: locale) { fields = f }
                            }
                            .controlSize(.small).disabled(!app.hasLegalFooter)
                            Button("Insert into all locales") { insertLegalFooterEverywhere() }
                                .buttonStyle(.borderedProminent).controlSize(.small).disabled(!app.hasLegalFooter)
                                .help("Appends the block to every locale's draft description now (each in its own language)")
                        }
                        Text("Automatic: Apple's standard EULA (\(LegalFooter.appleStandardEULA)) unless you set your own, plus the privacy policy URL Apple holds. Labels follow the locale; the block is re-generated, never duplicated; the description is trimmed at a line if 4000 characters would be exceeded.")
                            .font(.caption).foregroundStyle(.tertiary)
                        }
                    }
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Text("Legal footer")
                }

                GroupBox("Baseline") {
                    VStack(alignment: .leading, spacing: 6) {
                        if let rec = baselineRecord {
                            Text(rec.source == "asc" ? "From App Store Connect" : "Entered manually")
                            if let v = rec.versionString { Text("Version \(v) · \(rec.versionState ?? "")").foregroundStyle(.secondary) }
                            Text("Pulled \(rec.fetchedAt.relativeLabel)").foregroundStyle(.secondary)
                        } else {
                            Text("No baseline for \(locale.rawValue). Pull from App Store Connect or enter the current listing manually to see a diff.")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("\(rules.score)").font(.title2.weight(.semibold)).monospacedDigit().foregroundStyle(rules.score >= 85 ? .green : rules.score >= 60 ? .orange : .red)
                            Text("/100 · \(rules.charactersUsed)/160 indexed characters").font(.callout).foregroundStyle(.secondary)
                        }
                        ForEach(rules.findings.filter { $0.kind != .good }) { f in
                            Label {
                                Text(f.message)
                            } icon: {
                                Image(systemName: f.kind == .error ? "xmark.octagon.fill" : f.kind == .warning ? "exclamationmark.triangle.fill" : "info.circle")
                                    .foregroundStyle(f.kind == .error ? Color.red : f.kind == .warning ? Color.orange : Color.secondary)
                            }
                        }
                        ForEach(issues) { issue in
                            Label {
                                Text(issue.message)
                            } icon: {
                                Image(systemName: icon(issue.severity)).foregroundStyle(color(issue.severity))
                            }
                        }
                        if rules.errors == 0 && rules.warnings == 0 && issues.isEmpty { Label("Follows every house rule.", systemImage: "checkmark.seal").foregroundStyle(.green) }
                        Text("Indexed words: " + rules.indexedWords.joined(separator: ", ")).font(.caption).foregroundStyle(.tertiary).textSelection(.enabled)
                    }
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    HStack { Text("ASO rules"); Spacer(); Button("Rules…") { NotificationCenter.default.post(name: .showRulesRequested, object: nil) }.controlSize(.small) }
                }

                GroupBox("Changes vs baseline") {
                    VStack(alignment: .leading, spacing: 8) {
                        if baseline == nil {
                            Text("—").foregroundStyle(.secondary)
                        } else if changes.isEmpty {
                            Text("Draft equals the baseline.").foregroundStyle(.secondary)
                        }
                        ForEach(changes) { c in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(c.field.title).font(.subheadline.weight(.semibold))
                                if c.field == .keywords {
                                    let d = MetadataDiff.keywordDelta(before: c.before, after: c.after)
                                    if !d.added.isEmpty { Text("+ " + d.added.joined(separator: ", ")).foregroundStyle(.green) }
                                    if !d.removed.isEmpty { Text("− " + d.removed.joined(separator: ", ")).foregroundStyle(.red) }
                                    Text("\(d.kept.count) kept").foregroundStyle(.secondary).font(.caption)
                                } else {
                                    Text(c.before.isEmpty ? "(empty)" : c.before).foregroundStyle(.red).strikethrough().lineLimit(3)
                                    Text(c.after.isEmpty ? "(empty)" : c.after).foregroundStyle(.green).lineLimit(3)
                                }
                            }
                            .font(.callout)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(14)
        }
    }

    private func icon(_ s: ValidationSeverity) -> String {
        switch s { case .error: "xmark.octagon.fill"; case .warning: "exclamationmark.triangle.fill"; case .info: "info.circle" }
    }
    private func color(_ s: ValidationSeverity) -> Color {
        switch s { case .error: .red; case .warning: .orange; case .info: .secondary }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Picker("Locale", selection: $locale) {
                ForEach(availableLocales) { Text("\($0.rawValue) · \($0.displayName)").tag($0) }
                Divider()
                ForEach(AppLocale.allCases.filter { !availableLocales.contains($0) }) { Text("\($0.rawValue) · \($0.displayName)").tag($0) }
            }
            .pickerStyle(.menu)
            .frame(minWidth: 200)
        }
        ToolbarItemGroup(placement: .primaryAction) {
            // Three labelled menus instead of ten icons: Write (drafts), Publish (App Store Connect), Baseline (what Apple holds).
            Menu {
                Button { showAssistant = true } label: { Label("Write this locale with AI…", systemImage: "sparkles") }
                    .disabled(!env.openRouterState.isUsable)
                Button { Task { await makeBetter() } } label: { Label("Make better (fix findings, fill the room)", systemImage: "wand.and.stars") }
                    .disabled(!env.openRouterState.isUsable || env.assistant.isBusy || fields.name.isEmpty)
                if beforeImprove != nil {
                    Button { if let b = beforeImprove { fields = b; beforeImprove = nil; resultMessage = (.info, "Restored the draft from before Make better.") } } label: { Label("Undo Make better", systemImage: "arrow.uturn.backward.circle") }
                }
                Divider()
                Button { showBatchWrite = true } label: { Label("Write all locales…", systemImage: "globe.badge.chevron.backward") }
                    .disabled(!env.openRouterState.isUsable || env.assistant.isBusy)
                Button { showWhatsNew = true } label: { Label("What's New for all locales…", systemImage: "text.badge.star") }
                    .disabled(!env.openRouterState.isUsable)
                Button { Task { await fillEmptyWhatsNew() } } label: { Label("Fill empty What's New (all locales)", systemImage: "text.badge.checkmark") }
                    .help("Locales without release notes get them from en-US (localized) or the default note in their language; Apple refuses to save a version with an empty field")
                Divider()
                Text("Drafts stay on this Mac until you publish.")
            } label: {
                Label("Write", systemImage: "sparkles")
            }
            .help("AI drafts: this locale, an improvement pass, all locales, release notes")

            Menu {
                Button { showApply = true } label: { Label("Apply this locale to App Store Connect…", systemImage: "paperplane") }
                    .disabled(!canApply)
                Button { showApplyAll = true } label: { Label("Apply all locales…", systemImage: "paperplane.circle") }
                    .disabled(!env.ascState.isUsable || env.metadataService.isBusy)
                Divider()
                Text(env.ascState.isUsable ? "Writes to the editable version; nothing is submitted for review." : "Connect App Store Connect first (sidebar → Connections).")
            } label: {
                Label("Publish", systemImage: "paperplane")
            }
            .help("Send drafts to App Store Connect (creates missing locales, copies screenshots)")

            Menu {
                Button {
                    Task {
                        await env.metadataService.pullSnapshots(for: app, context: context)
                        loadDraft(force: fields == .empty)
                    }
                } label: { Label("Pull from App Store Connect", systemImage: "square.and.arrow.down") }
                    .disabled(!env.ascState.isUsable || env.metadataService.isBusy)
                Button { showManualBaseline = true } label: { Label("Set baseline manually…", systemImage: "doc.on.clipboard") }
                Button { if let baseline { fields = baseline } } label: { Label("Reset draft to baseline", systemImage: "arrow.uturn.backward") }
                    .disabled(baseline == nil || changes.isEmpty)
                Divider()
                Text(baselineRecord.map { "Baseline: \($0.source == "asc" ? "App Store Connect" : "manual") · \($0.fetchedAt.relativeLabel)" } ?? "No baseline for \(locale.rawValue) yet")
            } label: {
                Label("Baseline", systemImage: "square.and.arrow.down")
            }
            .help("What Apple currently holds for this locale; the diff and Apply compare against it")

            if env.metadataService.isBusy || env.assistant.isBusy { ProgressView().controlSize(.small) }
        }
    }

    /// No App Store Connect snapshot for this locale: Apply compares against the live listing and creates the locale if Apple lacks it.
    private var isNewLocale: Bool { baselineRecord?.source != "asc" }
    private var canApply: Bool {
        env.ascState.isUsable && !MetadataValidator.hasErrors(issues) && !env.metadataService.isBusy && !fields.name.isEmpty
            && (isNewLocale || !changes.isEmpty)
    }
    private var applyHelp: String {
        if !env.ascState.isUsable { return "Connect App Store Connect (sidebar → Connections)" }
        if fields.name.isEmpty { return "The draft needs at least a name" }
        if isNewLocale { return "No baseline pulled for this locale: Apply re-reads App Store Connect, writes the draft, and creates the locale if Apple lacks it" }
        if changes.isEmpty { return "Nothing changed" }
        if MetadataValidator.hasErrors(issues) { return "Fix validation errors first" }
        return "Write the changed fields to App Store Connect"
    }

    // MARK: Draft persistence

    private func loadDraft(force: Bool = false) {
        if force || loadedLocale != locale {
            loadedLocale = locale
            fields = env.metadataService.draftFields(for: app, locale: locale)
            resultMessage = nil
        }
    }

    private func saveDraft(_ new: MetadataFields) {
        guard loadedLocale == locale else { return }
        env.metadataService.saveDraft(new, for: app, locale: locale, context: context)
    }

    // MARK: Apply sheet

    private var applySheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Apply to App Store Connect · \(locale.rawValue)").font(.headline)
            Text("The fields below will be written to the editable version of \(app.name). Apple keeps them as a draft until you submit the version; nothing goes live from here.")
                .font(.callout).foregroundStyle(.secondary)
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if isNewLocale {
                        Text("No baseline was pulled for \(locale.rawValue). On Apply the listing is read from App Store Connect first; only fields that differ are written. If the locale does not exist there yet it is created. These draft fields will be sent:")
                            .font(.callout).foregroundStyle(.secondary)
                        ForEach(MetadataField.allCases.filter { !fields[$0].isEmpty }) { field in
                            GroupBox(field.title) {
                                Text(fields[field]).font(.callout).textSelection(.enabled).lineLimit(field.isMultiline ? 6 : 2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    ForEach(changes) { c in
                        GroupBox(c.field.title) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(c.before.isEmpty ? "(empty)" : c.before).foregroundStyle(.secondary).strikethrough()
                                Text(c.after.isEmpty ? "(empty)" : c.after)
                            }
                            .font(.callout).textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .frame(minHeight: 160, maxHeight: 360)
            GroupBox {
                VStack(alignment: .leading, spacing: 6) {
                    if let v = ascVersions.first(where: \.isEditable) {
                        Label("Version v\(v.versionString) · \(v.state) — editable", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    } else if ascVersions.isEmpty {
                        Label("Reading versions…", systemImage: "clock")
                    } else {
                        Label("No editable version: the live one cannot take new metadata. Create the next version first.", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        HStack {
                            TextField("New version (e.g. 1.3.0)", text: $newVersionString).textFieldStyle(.roundedBorder).frame(width: 160)
                            Button("Create version") { Task { _ = await env.metadataService.createVersion(app: app, versionString: newVersionString); ascVersions = (try? await env.metadataService.versions(app: app)) ?? [] } }
                                .disabled(newVersionString.trimmingCharacters(in: .whitespaces).isEmpty || env.metadataService.isBusy)
                        }
                    }
                    if isNewLocale {
                        Toggle("Create this localization on App Store Connect and copy screenshots from", isOn: $applyCreateMissing).toggleStyle(.checkbox)
                        Picker("", selection: $applyCopyFrom) {
                            ForEach(app.snapshots.filter { $0.source == "asc" }.compactMap(\.locale).sorted { $0.rawValue < $1.rawValue }) { Text($0.rawValue).tag($0) }
                        }
                        .labelsHidden().frame(width: 110)
                    }
                }
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text("Before writing, the listing is re-read; if it changed since the baseline was pulled, the apply is refused and the baseline refreshed.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                if env.metadataService.isBusy, let p = env.metadataService.batchProgress { ProgressView().controlSize(.small); Text(p).font(.caption).foregroundStyle(.secondary) }
                Spacer()
                Button("Cancel") { showApply = false }.keyboardShortcut(.cancelAction)
                Button(isNewLocale ? "Apply (re-read first)" : "Apply \(changes.count) field(s)") { Task { await apply() } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(env.metadataService.isBusy || ascVersions.first(where: \.isEditable) == nil)
            }
        }
        .padding()
        .frame(width: 600)
        .task {
            ascVersions = (try? await env.metadataService.versions(app: app)) ?? []
            if let primary = app.snapshots.first(where: { $0.source == "asc" && $0.localeRaw == "en-US" })?.locale ?? app.snapshots.first(where: { $0.source == "asc" })?.locale { applyCopyFrom = primary }
        }
    }

    /// Appends the legal footer to every locale's draft (the current one through the editor so the change is visible).
    private func insertLegalFooterEverywhere() {
        var added = 0
        for l in availableLocales {
            if l == locale {
                var f = fields
                if env.metadataService.ensureLegalFooter(&f, app: app, locale: l) { fields = f; added += 1 }
            } else {
                var f = env.metadataService.draftFields(for: app, locale: l)
                if env.metadataService.ensureLegalFooter(&f, app: app, locale: l) { env.metadataService.saveDraft(f, for: app, locale: l, context: context); added += 1 }
            }
        }
        resultMessage = (.success, "Legal footer added to \(added) of \(availableLocales.count) locale(s); the rest already had it. Apply writes them to App Store Connect.")
    }

    private func fillEmptyWhatsNew() async {
        var filled = 0
        for l in availableLocales {
            var f = l == locale ? fields : env.metadataService.draftFields(for: app, locale: l)
            if await env.metadataService.ensureWhatsNew(&f, app: app, locale: l) != nil {
                if l == locale { fields = f } else { env.metadataService.saveDraft(f, for: app, locale: l, context: context) }
                filled += 1
            }
        }
        resultMessage = (.success, "What's New filled for \(filled) locale(s); the others already had notes. Apply writes them to the version.")
    }

    private func makeBetter() async {
        let brand = app.name.split(separator: ":").first.map { String($0).trimmingCharacters(in: .whitespaces) } ?? app.name
        let scoreBefore = rules.score
        guard let p = await env.assistant.improve(app: app, market: marketFor(locale), locale: locale, current: fields, brandName: brand, siblings: siblings) else {
            resultMessage = (.error, env.assistant.lastError ?? "No improvement returned.")
            return
        }
        beforeImprove = fields
        fields = p.fields
        let notes = p.repairs.isEmpty ? "" : " " + p.repairs.joined(separator: " ")
        resultMessage = (p.review.score >= scoreBefore ? .success : .info, "Improved: rule score \(scoreBefore) → \(p.review.score), covers \(p.coveredPhrases.count)/\(p.coveredPhrases.count + p.missedPhrases.count) priority phrases (\(env.assistant.lastCost ?? "")).\(notes) Undo restores the previous draft.")
    }

    private func apply() async {
        let options = MetadataService.ApplyOptions(createMissingLocalization: isNewLocale && applyCreateMissing, copyScreenshotsFrom: isNewLocale && applyCreateMissing ? applyCopyFrom : nil)
        let result = await env.metadataService.apply(app: app, locale: locale, draft: fields, context: context, options: options)
        showApply = false
        switch result {
        case .applied(let snapshot):
            fields = snapshot.fields
            resultMessage = (.success, "Applied. App Store Connect now holds the values shown in the editor (re-read after writing).")
        case .refused(let why):
            resultMessage = (.error, why)
        case .failed(let why):
            resultMessage = (.error, why)
        }
    }
}

/// Lets the user paste the current listing when App Store Connect is not connected.
struct ManualBaselineSheet: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let app: TrackedApp
    let locale: AppLocale
    @State private var fields = MetadataFields.empty

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current listing · \(locale.rawValue)").font(.headline)
            Text("Paste what is live on the App Store today. This baseline is for diffing only; applying to Apple requires an App Store Connect connection.")
                .font(.callout).foregroundStyle(.secondary)
            Form {
                TextField("Name", text: $fields.name)
                TextField("Subtitle", text: $fields.subtitle)
                TextField("Keywords", text: $fields.keywords)
                TextField("Promotional text", text: $fields.promotionalText)
                Section("Description") { TextEditor(text: $fields.description).frame(minHeight: 120) }
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save baseline") {
                    env.metadataService.setManualBaseline(for: app, locale: locale, fields: fields, context: context)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 560, height: 520)
        .onAppear { fields = app.snapshots.first { $0.localeRaw == locale.rawValue }?.fields ?? .empty }
    }
}
