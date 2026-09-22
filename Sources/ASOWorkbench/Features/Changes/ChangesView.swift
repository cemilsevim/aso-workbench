import SwiftUI
import SwiftData
import ASOCore

/// Timeline of releases, notes and applied metadata changes, each with the rank movement measured around it.
struct ChangesView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.modelContext) private var context
    let app: TrackedApp
    @State private var selected: TimelineItem?
    @State private var showAddNote = false
    @State private var noteTitle = ""
    @State private var noteDate = Date.now

    nonisolated struct TimelineItem: Identifiable, Hashable, Sendable {
        let id: String
        let date: Date
        let title: String
        let kind: String     // release · note · change
        let status: String?  // for changes
        let locale: String?
    }

    private var items: [TimelineItem] {
        let releases = app.releases.map { TimelineItem(id: "r-\($0.persistentModelID.hashValue)", date: $0.createdAt, title: $0.title, kind: $0.kind, status: nil, locale: $0.storefront) }
        let changes = app.changes.map { TimelineItem(id: "c-\($0.persistentModelID.hashValue)", date: $0.createdAt, title: $0.changes.map(\.field.title).joined(separator: ", "), kind: "change", status: $0.status, locale: $0.localeRaw) }
        return (releases + changes).sorted { $0.date > $1.date }
    }

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                HStack {
                    Text("Timeline").font(.headline)
                    Spacer()
                    Button { showAddNote = true } label: { Label("Add note", systemImage: "plus") }.controlSize(.small)
                        .help("Pin a date (e.g. “keywords changed”, “screenshots updated”) to compare ranks around it")
                }
                .padding(10)
                Divider()
                if items.isEmpty {
                    ContentUnavailableView("Nothing on the timeline yet", systemImage: "clock.arrow.circlepath",
                                           description: Text("Releases are detected from the App Store when you measure; metadata applied through this app is recorded here; notes you add count too."))
                } else {
                    List(items, selection: $selected) { e in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                kindLabel(e)
                                if let l = e.locale { Text(l).font(.caption).foregroundStyle(.secondary) }
                                Spacer()
                                Text(e.date.shortLabel).font(.caption).foregroundStyle(.secondary)
                            }
                            Text(e.title).font(.callout).lineLimit(2)
                        }
                        .padding(.vertical, 2)
                        .tag(e)
                    }
                }
            }
            .frame(minWidth: 280, idealWidth: 340, maxHeight: .infinity)

            Group {
                if let e = selected {
                    detail(e)
                } else {
                    ContentUnavailableView("Select a release or change", systemImage: "chart.line.uptrend.xyaxis",
                                           description: Text("Ranks measured before it are compared with the latest ones after it."))
                }
            }
            .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $showAddNote) { addNoteSheet }
    }

    @ViewBuilder
    private func kindLabel(_ e: TimelineItem) -> some View {
        switch e.kind {
        case "release": Label("Release", systemImage: "shippingbox.fill").foregroundStyle(.orange)
        case "note": Label("Note", systemImage: "pin.fill").foregroundStyle(.purple)
        default:
            switch e.status ?? "" {
            case "applied": Label("Applied", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            case "partial": Label("Partial", systemImage: "exclamationmark.circle.fill").foregroundStyle(.orange)
            default: Label("Failed", systemImage: "xmark.circle.fill").foregroundStyle(.red)
            }
        }
    }

    private func detail(_ e: TimelineItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
                HStack {
                    kindLabel(e)
                    Text("· \(e.title) · \(e.date.formatted(date: .abbreviated, time: .shortened))").foregroundStyle(.secondary)
                    Spacer()
                    if e.kind != "change" {
                        Button("Remove marker", role: .destructive) {
                            if let r = app.releases.first(where: { "r-\($0.persistentModelID.hashValue)" == e.id }) { context.delete(r); try? context.save(); selected = nil }
                        }
                        .controlSize(.small)
                    }
                }
                if e.kind == "change", let entry = app.changes.first(where: { "c-\($0.persistentModelID.hashValue)" == e.id }) {
                    if !entry.note.isEmpty { InlineMessage(kind: entry.status == "failed" ? .error : .info, text: entry.note) }
                    DisclosureGroup("Fields changed (\(entry.changes.count))") {
                    ForEach(entry.changes) { c in
                        GroupBox(c.field.title) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Before").font(.caption).foregroundStyle(.secondary)
                                Text(c.before.isEmpty ? "(empty)" : c.before).textSelection(.enabled)
                                Text("After").font(.caption).foregroundStyle(.secondary)
                                Text(c.after.isEmpty ? "(empty)" : c.after).textSelection(.enabled)
                                if c.field == .keywords {
                                    let d = MetadataDiff.keywordDelta(before: c.before, after: c.after)
                                    HStack(spacing: 12) {
                                        Text("+\(d.added.count) added").foregroundStyle(.green)
                                        Text("−\(d.removed.count) removed").foregroundStyle(.red)
                                        Text("\(d.kept.count) kept").foregroundStyle(.secondary)
                                    }.font(.caption)
                                }
                            }
                            .font(.callout)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    Text("Metadata written to App Store Connect is a draft until the version is approved and released; the release itself appears on this timeline when you measure after it. Read the effect from the release marker, not from the apply date.")
                        .font(.caption).foregroundStyle(.tertiary)
                    }
                }
                ImpactView(app: app, marker: Marker(date: e.date, title: e.title, kind: e.kind))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(16)
    }

    private var addNoteSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add a note marker").font(.headline)
            TextField("What changed (e.g. keywords updated, new screenshots)", text: $noteTitle).textFieldStyle(.roundedBorder)
            DatePicker("When", selection: $noteDate, in: ...Date.now)
            HStack {
                Spacer()
                Button("Cancel") { showAddNote = false }
                Button("Add") {
                    let m = ReleaseMarker(date: noteDate, kind: "note", title: noteTitle.trimmingCharacters(in: .whitespaces))
                    m.app = app
                    context.insert(m)
                    try? context.save()
                    noteTitle = ""
                    showAddNote = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(noteTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(16)
        .frame(width: 460)
    }
}
