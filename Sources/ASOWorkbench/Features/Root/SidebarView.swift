import SwiftUI
import SwiftData
import ASOCore

/// One app at a time. The switcher at the top changes the app; the list below navigates within it.
struct SidebarView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.modelContext) private var context
    let apps: [TrackedApp]
    let currentApp: TrackedApp?
    @Binding var selection: SidebarSelection?
    @Binding var showAddApp: Bool
    var onSwitch: (TrackedApp) -> Void
    @State private var appToDelete: TrackedApp?

    var body: some View {
        List(selection: $selection) {
            if currentApp != nil {
                Section {
                    ForEach(WorkspaceSection.allCases) { section in
                        Label(section.title, systemImage: section.symbol)
                            .tag(SidebarSelection.section(section))
                    }
                }
            }
            Section("Apple") {
                Label {
                    HStack {
                        Text("Connections")
                        Spacer()
                        connectionDots
                    }
                } icon: {
                    Image(systemName: "key")
                }
                .tag(SidebarSelection.connections)
            }
            if Feature.appIdeas {
                Section("Market") {
                    Label("App ideas", systemImage: "lightbulb")
                        .tag(SidebarSelection.ideas)
                }
            }
            if env.settings.showLab {
                Section("Lab") {
                    Label("Popularity model", systemImage: "brain")
                        .tag(SidebarSelection.training)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 210, ideal: 240)
        .safeAreaInset(edge: .top, spacing: 0) { switcher }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
            if let r = env.updates.available {
                Button { NotificationCenter.default.post(name: .checkForUpdatesRequested, object: nil) } label: {
                    Label("Update available · \(r.version)", systemImage: "arrow.down.circle.fill")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.tint)
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(.tint.opacity(0.08))
                .help("See what's new and how to install it")
            }
            Button { showAddApp = true } label: {
                Label("Add App", systemImage: "plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
            .padding(10)
            .background(.bar)
            }
        }
        .confirmationDialog("Remove \(appToDelete?.name ?? "app")?", isPresented: Binding(get: { appToDelete != nil }, set: { if !$0 { appToDelete = nil } }), titleVisibility: .visible) {
            Button("Remove and delete its history", role: .destructive) {
                if let app = appToDelete {
                    context.delete(app)
                    try? context.save()
                }
                appToDelete = nil
            }
        } message: {
            Text("All tracked keywords, rank history, drafts and change log for this app will be deleted. App Store Connect is not touched.")
        }
    }

    /// App switcher: a menu listing every tracked app. Click to change the workspace.
    @ViewBuilder
    private var switcher: some View {
        if let app = currentApp {
            Menu {
                ForEach(apps) { candidate in
                    Button {
                                onSwitch(candidate)
                    } label: {
                        if candidate.persistentModelID == app.persistentModelID {
                            Label(candidate.name, systemImage: "checkmark")
                        } else {
                            Text(candidate.name)
                        }
                    }
                }
                Divider()
                Button("Add App…") { showAddApp = true }
                Button("Remove \(app.name)…", role: .destructive) { appToDelete = app }
            } label: {
                HStack(spacing: 10) {
                    AppIconView(url: app.iconURL, size: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(app.name).font(.headline).lineLimit(1)
                        Text(apps.count > 1 ? "\(apps.count) apps · switch" : (app.primaryGenre ?? app.sellerName))
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.bar)
            .help("Switch app")
        }
    }

    /// Two small dots: App Store Connect and Apple Ads. Green = verified, orange = configured, grey = not connected.
    private var connectionDots: some View {
        HStack(spacing: 4) {
            Circle().fill(color(env.ascState)).frame(width: 7, height: 7)
            Circle().fill(color(env.adsState)).frame(width: 7, height: 7)
        }
        .help("App Store Connect · Apple Ads")
    }

    private func color(_ state: ConnectionState) -> Color {
        switch state {
        case .verified: .green
        case .configured: .orange
        case .failed: .red
        case .notConfigured: .secondary.opacity(0.4)
        }
    }
}
