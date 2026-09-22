import SwiftUI
import SwiftData
import ASOCore
import ASOProviders

/// Pushes every locale's draft to App Store Connect in one pass: creates missing localizations, copies screenshots
/// from the source locale, writes the fields, re-reads each one.
struct ApplyAllSheet: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let app: TrackedApp
    let locales: [AppLocale]

    @State private var selected: Set<AppLocale> = []
    @State private var copyFrom: AppLocale = .enUS
    @State private var copyScreenshots = true
    @State private var versions: [ASCMetadataProvider.VersionInfo] = []
    @State private var newVersion = ""
    @State private var results: [(AppLocale, String)] = []
    @State private var ran = false
    @State private var loading = true

    private var editable: ASCMetadataProvider.VersionInfo? { versions.first(where: \.isEditable) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Apply all locales to App Store Connect").font(.title3.weight(.semibold))
                    Text("Each locale's draft is written to the editable version. Missing localizations are created; screenshots are copied from the source locale so the new language is complete. Nothing is submitted for review.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(ran ? "Done" : "Cancel") { dismiss() }
            }
            GroupBox("Version") {
                HStack(spacing: 10) {
                    if loading { ProgressView().controlSize(.small); Text("Reading versions…").foregroundStyle(.secondary) }
                    else if let v = editable { Label("v\(v.versionString) · \(v.state) — editable", systemImage: "checkmark.circle.fill").foregroundStyle(.green) }
                    else {
                        Label("No editable version: the live one cannot take new metadata.", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        TextField("New version (e.g. 1.3.0)", text: $newVersion).textFieldStyle(.roundedBorder).frame(width: 160)
                        Button("Create version") { Task { await createVersion() } }.disabled(newVersion.trimmingCharacters(in: .whitespaces).isEmpty || env.metadataService.isBusy)
                    }
                    Spacer()
                    if !versions.isEmpty { Text(versions.map { "v\($0.versionString) \($0.state)" }.joined(separator: " · ")).font(.caption).foregroundStyle(.tertiary).lineLimit(1) }
                }
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            GroupBox("Locales (\(selected.count))") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), alignment: .leading)], alignment: .leading, spacing: 4) {
                    ForEach(locales) { l in
                        let hasDraft = app.drafts.contains { $0.localeRaw == l.rawValue }
                        let onASC = app.snapshots.contains { $0.localeRaw == l.rawValue && $0.source == "asc" }
                        Toggle(isOn: Binding(get: { selected.contains(l) }, set: { if $0 { selected.insert(l) } else { selected.remove(l) } })) {
                            HStack(spacing: 6) {
                                Text("\(l.rawValue) · \(l.displayName)")
                                Text(onASC ? "on App Store Connect" : "new localization").font(.caption).foregroundStyle(onASC ? Color.secondary : Color.orange)
                                if !hasDraft { Text("no draft").font(.caption).foregroundStyle(.red) }
                            }
                        }
                        .toggleStyle(.checkbox).font(.callout)
                        .disabled(!hasDraft)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 12) {
                Toggle("Copy screenshots to new localizations from", isOn: $copyScreenshots).toggleStyle(.checkbox)
                Picker("", selection: $copyFrom) {
                    ForEach(app.snapshots.filter { $0.source == "asc" }.compactMap(\.locale).sorted { $0.rawValue < $1.rawValue }) { Text($0.rawValue).tag($0) }
                }
                .labelsHidden().frame(width: 110).disabled(!copyScreenshots)
                Spacer()
                if env.metadataService.isBusy {
                    ProgressView().controlSize(.small)
                    Text(env.metadataService.batchProgress ?? "Working…").font(.callout).foregroundStyle(.secondary).lineLimit(1)
                } else {
                    Button {
                        Task {
                            ran = true
                            results = await env.metadataService.applyAll(app: app, locales: locales.filter { selected.contains($0) },
                                                                          options: .init(createMissingLocalization: true, copyScreenshotsFrom: copyScreenshots ? copyFrom : nil), context: context)
                        }
                    } label: { Label("Apply \(selected.count) locale(s)", systemImage: "paperplane") }
                    .buttonStyle(.borderedProminent)
                    .disabled(selected.isEmpty || editable == nil)
                }
            }
            if !results.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(results, id: \.0) { l, m in
                            HStack(alignment: .top, spacing: 8) {
                                Text(l.rawValue).font(.callout.weight(.semibold)).frame(width: 60, alignment: .leading)
                                Text(m).font(.callout).foregroundStyle(m.hasPrefix("Applied") ? Color.primary : Color.orange).textSelection(.enabled)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 100, maxHeight: 220)
            }
        }
        .padding(16)
        .frame(minWidth: 820, minHeight: 480)
        .task {
            if selected.isEmpty { selected = Set(locales.filter { l in app.drafts.contains { $0.localeRaw == l.rawValue } }) }
            if let primary = app.snapshots.first(where: { $0.source == "asc" && $0.localeRaw == "en-US" })?.locale ?? app.snapshots.first(where: { $0.source == "asc" })?.locale { copyFrom = primary }
            versions = (try? await env.metadataService.versions(app: app)) ?? []
            loading = false
        }
    }

    private func createVersion() async {
        _ = await env.metadataService.createVersion(app: app, versionString: newVersion.trimmingCharacters(in: .whitespaces))
        versions = (try? await env.metadataService.versions(app: app)) ?? []
    }
}

/// Release notes for every locale from one source text: translated and adapted by the writer model, saved into drafts.
struct WhatsNewSheet: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let app: TrackedApp
    let locales: [AppLocale]

    @State private var source = ""
    @State private var sourceLocale: AppLocale = .enUS
    @State private var selected: Set<AppLocale> = []
    @State private var results: [(AppLocale, String)] = []
    @State private var ran = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("What's New for every locale").font(.title3.weight(.semibold))
                    Text("Write the release notes once; each other locale gets a natural version in its language (not a word-for-word translation). Saved into the drafts' What's New field; Apply writes them to the version.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(ran ? "Done" : "Cancel") { dismiss() }
            }
            HStack {
                Picker("Source language", selection: $sourceLocale) { ForEach(locales) { Text($0.rawValue).tag($0) } }.frame(maxWidth: 220)
                Spacer()
            }
            TextEditor(text: $source).font(.body).frame(minHeight: 120)
            Text("\(source.count) / 4000").font(.caption).foregroundStyle(.secondary)
            GroupBox("Target locales (\(selected.count))") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), alignment: .leading)], alignment: .leading, spacing: 4) {
                    ForEach(locales.filter { $0 != sourceLocale }) { l in
                        Toggle("\(l.rawValue) · \(l.displayName)", isOn: Binding(get: { selected.contains(l) }, set: { if $0 { selected.insert(l) } else { selected.remove(l) } }))
                            .toggleStyle(.checkbox).font(.callout)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                if env.assistant.isBusy { ProgressView().controlSize(.small); Text(env.assistant.batchProgress ?? "Writing…").font(.callout).foregroundStyle(.secondary) }
                else {
                    Button {
                        Task {
                            ran = true
                            results = await env.assistant.writeWhatsNew(app: app, source: source, sourceLocale: sourceLocale, locales: locales.filter { selected.contains($0) },
                                                                        metadata: env.metadataService, context: context)
                        }
                    } label: { Label("Write \(selected.count) locale(s) (~$\(String(format: "%.3f", Double(selected.count) * 0.001)))", systemImage: "sparkles") }
                    .buttonStyle(.borderedProminent)
                    .disabled(source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selected.isEmpty)
                }
                Spacer()
            }
            if !results.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(results, id: \.0) { l, text in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(l.rawValue).font(.caption.weight(.semibold))
                                Text(text).font(.callout).textSelection(.enabled).lineLimit(4)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 100, maxHeight: 240)
            }
        }
        .padding(16)
        .frame(minWidth: 760, minHeight: 520)
        .onAppear {
            if locales.contains(.enUS) { sourceLocale = .enUS } else if let f = locales.first { sourceLocale = f }
            source = env.metadataService.draftFields(for: app, locale: sourceLocale).whatsNew
            if selected.isEmpty { selected = Set(locales.filter { $0 != sourceLocale }) }
        }
    }
}
