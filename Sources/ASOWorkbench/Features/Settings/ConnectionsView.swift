import SwiftUI

/// Sidebar → Connections. Same form as the Settings window, reachable where
/// people look for it first.
struct ConnectionsView: View {
    var body: some View {
        ConnectionsSettings(showIntro: true)
            .navigationTitle("Connections")
    }
}
