import SwiftUI
import SwiftData
import ASOCore

enum WorkspaceSection: String, CaseIterable, Identifiable, Codable {
    case overview, keywords, research, competitors, metadata, reviews, changes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .keywords: "Keywords"
        case .research: "Research"
        case .competitors: "Competitors"
        case .metadata: "Metadata"
        case .reviews: "Reviews"
        case .changes: "Changes"
        }
    }

    var symbol: String {
        switch self {
        case .overview: "square.grid.2x2"
        case .keywords: "list.number"
        case .research: "sparkle.magnifyingglass"
        case .competitors: "person.2"
        case .metadata: "doc.text"
        case .reviews: "text.bubble"
        case .changes: "clock.arrow.circlepath"
        }
    }
}

/// What the sidebar list selects. The current app is chosen separately with the switcher at the top.
enum SidebarSelection: Hashable, Codable {
    case section(WorkspaceSection)
    case connections
    case ideas
    case training
}

struct ContentView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.modelContext) private var context
    @Query(sort: \TrackedApp.name) private var apps: [TrackedApp]

    @State private var selection: SidebarSelection? = .section(.keywords)
    @State private var currentAppID: PersistentIdentifier?
    @State private var showAddApp = false
    @State private var showShortcuts = false
    @State private var showRules = false
    @State private var didRunLaunchRefresh = false
    /// Last app and sidebar selection, restored on launch.
    @AppStorage("sidebarSelection") private var storedSelection: Data = Data()
    @State private var showUpdate = false
    @AppStorage("currentApp") private var storedAppID: Data = Data()

    private var currentApp: TrackedApp? {
        apps.first { $0.persistentModelID == currentAppID } ?? apps.first
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(apps: apps, currentApp: currentApp, selection: $selection, showAddApp: $showAddApp) { app in
                currentAppID = app.persistentModelID
                if selection == .connections || selection == nil { selection = .section(.keywords) }
            }
        } detail: {
            switch selection {
            case .connections:
                ConnectionsView()
            case .ideas:
                if Feature.appIdeas { IdeasView() } else { emptyDetail }
            case .training:
                if LabMode.isEnabled { TrainingView() } else { emptyDetail }
            case .section(let section):
                if let app = currentApp {
                    AppWorkspaceView(app: app, section: section)
                        .id(app.persistentModelID)
                } else {
                    emptyDetail
                }
            case nil:
                emptyDetail
            }
        }
        .sheet(isPresented: $showAddApp) {
            AddAppSheet { app in
                currentAppID = app.persistentModelID
                selection = .section(.keywords)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .addAppRequested)) { _ in showAddApp = true }
        .onReceive(NotificationCenter.default.publisher(for: .openConnectionsRequested)) { _ in selection = .connections }
        .onReceive(NotificationCenter.default.publisher(for: .showShortcutsRequested)) { _ in showShortcuts = true }
        .onOpenURL { url in
            // Any web page can open asoworkbench:// links, so commands run only in a developer Lab session.
            guard LabMode.isEnabled else { AppLog.write("[lab] ignored \(url.host ?? "?") command: Lab mode is off"); return }
            Task { await LabCommands.handle(url, env: env, context: context, apps: apps) }
        }
        .sheet(isPresented: $showShortcuts) { ShortcutsSheet() }
        .onReceive(NotificationCenter.default.publisher(for: .showRulesRequested)) { _ in showRules = true }
        .onReceive(NotificationCenter.default.publisher(for: .checkForUpdatesRequested)) { _ in
            showUpdate = true
            Task { await env.updates.check(userInitiated: true) }
        }
        .sheet(isPresented: $showUpdate) { UpdateSheet().environment(env) }
        .sheet(isPresented: $showRules) { RulesSheet() }
        .onChange(of: selection) { _, new in
            storedSelection = (try? JSONEncoder().encode(new)) ?? Data()
        }
        .onChange(of: currentAppID) { _, new in
            storedAppID = (try? JSONEncoder().encode(new)) ?? Data()
        }
        .task {
            restoreSelection()
            await env.verifyConfiguredConnections()
            await launchRefreshIfNeeded()
        }
    }

    private func restoreSelection() {
        if let saved = try? JSONDecoder().decode(SidebarSelection.self, from: storedSelection) {
            // A selection saved in a Lab session may point at something hidden in normal use.
            selection = (saved == .ideas && !Feature.appIdeas) || (saved == .training && !LabMode.isEnabled) ? .section(.keywords) : saved
        }
        if let id = try? JSONDecoder().decode(PersistentIdentifier?.self, from: storedAppID), apps.contains(where: { $0.persistentModelID == id }) {
            currentAppID = id
        }
    }

    private var emptyDetail: some View {
        ContentUnavailableView {
            if apps.isEmpty {
                // First launch: greet with the app's own icon.
                VStack(spacing: 10) {
                    Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 96, height: 96)
                    Text("Welcome to ASO Workbench").font(.title2.weight(.semibold))
                }
            } else {
                Label("No app selected", systemImage: "app.dashed")
            }
        } description: {
            Text(apps.isEmpty ? "Add an App Store app to start tracking keywords. Rank tracking works without any account; connect App Store Connect and Apple Ads whenever you like." : "Choose an app in the sidebar.")
        } actions: {
            HStack(spacing: 6) {
                Button("Add App…") { showAddApp = true }
                Keycap(keys: "⌘N")
            }
            Button("Connections") { selection = .connections }
        }
    }

    private func launchRefreshIfNeeded() async {
        guard !didRunLaunchRefresh, env.settings.autoMeasureOnLaunch else { return }
        didRunLaunchRefresh = true
        let stale = TrackingService.staleMarkets(in: apps, staleHours: env.settings.staleHours)
        guard !stale.isEmpty else { return }
        await env.tracking.measureAll(stale, context: context)
    }
}

/// Hosts the per-app sections and owns the market selection so it survives section switches.
struct AppWorkspaceView: View {
    @Bindable var app: TrackedApp
    let section: WorkspaceSection
    @State private var selectedMarketID: PersistentIdentifier?

    private var market: TrackedMarket? {
        app.sortedMarkets.first { $0.persistentModelID == selectedMarketID } ?? app.sortedMarkets.first
    }

    var body: some View {
        Group {
            switch section {
            case .overview: OverviewView(app: app, market: market)
            case .keywords: KeywordsView(app: app, market: market)
            case .research: ResearchView(app: app, market: market)
            case .competitors: CompetitorsView(app: app, market: market)
            case .metadata: MetadataView(app: app, market: market)
            case .reviews: ReviewsView(app: app)
            case .changes: ChangesView(app: app)
            }
        }
        .navigationTitle(app.name)
        .navigationSubtitle(section.title)
        .toolbar {
            if section != .changes {
                ToolbarItem(placement: .navigation) {
                    MarketPicker(app: app, selectedMarketID: $selectedMarketID)
                }
            }
        }
        .onAppear { if selectedMarketID == nil { selectedMarketID = app.sortedMarkets.first?.persistentModelID } }
    }
}

struct MarketPicker: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.modelContext) private var context
    let app: TrackedApp
    @Binding var selectedMarketID: PersistentIdentifier?
    @State private var showAddMarket = false

    private var current: TrackedMarket? {
        app.sortedMarkets.first { $0.persistentModelID == selectedMarketID } ?? app.sortedMarkets.first
    }

    var body: some View {
        // A plain toolbar menu: the hover and pressed highlight cover the whole control.
        Menu {
            ForEach(app.sortedMarkets) { market in
                Button {
                    selectedMarketID = market.persistentModelID
                } label: {
                    if market.persistentModelID == current?.persistentModelID {
                        Label(market.title, systemImage: "checkmark")
                    } else {
                        Text(market.title)
                    }
                }
            }
            Divider()
            Button("Add market…") { showAddMarket = true }
        } label: {
            Label(current?.title ?? "Add market", systemImage: "globe")
                .labelStyle(.titleAndIcon)
        }
        .help("Storefront and device being viewed")
        .sheet(isPresented: $showAddMarket) {
            AddMarketSheet(app: app) { market in selectedMarketID = market.persistentModelID }
        }
    }
}
