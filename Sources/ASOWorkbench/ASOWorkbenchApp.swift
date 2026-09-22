import SwiftUI
import SwiftData

@main
struct ASOWorkbenchApp: App {
    @State private var environment = AppEnvironment()

    var body: some Scene {
        // A single window: URL commands and Dock clicks reuse it instead of opening new ones.
        Window("ASO Workbench", id: "main") {
            ContentView()
                .environment(environment)
                .frame(minWidth: 980, minHeight: 620)
        }
        .modelContainer(environment.container)
        .defaultSize(width: 1240, height: 780)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") { post(.checkForUpdatesRequested) }
            }
            CommandGroup(replacing: .newItem) {
                Button("Add App…") { post(.addAppRequested) }
                    .keyboardShortcut("n", modifiers: .command)
                Button("Add Keywords…") { post(.addKeywordsRequested) }
                    .keyboardShortcut("k", modifiers: .command)
            }
            CommandGroup(after: .pasteboard) {
                Divider()
                Button("Remove Selected Keywords…") { post(.deleteSelectionRequested) }
                    .keyboardShortcut(.delete, modifiers: .command)
            }
            CommandMenu("Keywords") {
                Button("Measure This Market") { post(.measureRequested) }
                    .keyboardShortcut("r", modifiers: .command)
                Button("Measure Selected Keywords") { post(.measureSelectionRequested) }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                Button("Fetch Popularity") { post(.popularityRequested) }
                    .keyboardShortcut("p", modifiers: [.command, .shift])
                Divider()
                Button("Export CSV…") { post(.exportRequested) }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
            }
            CommandGroup(after: .sidebar) {
                Button("Toggle Inspector") { post(.toggleInspectorRequested) }
                    .keyboardShortcut("i", modifiers: [.command, .option])
            }
            CommandGroup(replacing: .help) {
                Button("ASO Rules") { post(.showRulesRequested) }
                Button("Keyboard Shortcuts") { post(.showShortcutsRequested) }
                    .keyboardShortcut("/", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environment(environment)
                .modelContainer(environment.container)
        }
    }
}

private func post(_ name: Notification.Name) {
    NotificationCenter.default.post(name: name, object: nil)
}

extension Notification.Name {
    static let addAppRequested = Notification.Name("ASOWorkbench.addAppRequested")
    static let openConnectionsRequested = Notification.Name("ASOWorkbench.openConnectionsRequested")
    static let addKeywordsRequested = Notification.Name("ASOWorkbench.addKeywordsRequested")
    static let deleteSelectionRequested = Notification.Name("ASOWorkbench.deleteSelectionRequested")
    static let measureRequested = Notification.Name("ASOWorkbench.measureRequested")
    static let measureSelectionRequested = Notification.Name("ASOWorkbench.measureSelectionRequested")
    static let popularityRequested = Notification.Name("ASOWorkbench.popularityRequested")
    static let exportRequested = Notification.Name("ASOWorkbench.exportRequested")
    static let toggleInspectorRequested = Notification.Name("ASOWorkbench.toggleInspectorRequested")
    static let showShortcutsRequested = Notification.Name("ASOWorkbench.showShortcutsRequested")
    static let showRulesRequested = Notification.Name("ASOWorkbench.showRulesRequested")
    static let checkForUpdatesRequested = Notification.Name("ASOWorkbench.checkForUpdatesRequested")
}
