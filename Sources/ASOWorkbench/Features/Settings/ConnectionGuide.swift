import SwiftUI
import AppKit

/// How much a connection matters, shown next to its name.
enum ConnectionNeed {
    case recommended, optional, advanced

    var label: String {
        switch self {
        case .recommended: "Recommended"
        case .optional: "Optional"
        case .advanced: "Advanced · optional"
        }
    }
    var tint: Color {
        switch self {
        case .recommended: .blue
        case .optional: .secondary
        case .advanced: .orange
        }
    }
}

/// Section header: service name, how much it matters, current status.
struct ConnectionHeader<Status: View>: View {
    let title: String
    let systemImage: String
    let need: ConnectionNeed
    @ViewBuilder var status: Status

    var body: some View {
        HStack(spacing: 8) {
            Label(title, systemImage: systemImage).font(.headline)
            Text(need.label).font(.caption2.weight(.semibold)).padding(.horizontal, 7).padding(.vertical, 2)
                .background(need.tint.opacity(0.15), in: Capsule()).foregroundStyle(need.tint)
            Spacer()
            status.font(.caption)
        }
    }
}

/// What a key unlocks, why it is asked for, where data goes, and how to get it, shown above the fields.
struct ConnectionIntro: View {
    let unlocks: [String]
    let dataFlow: String
    let steps: [String]
    var link: (title: String, url: String)? = nil
    @State private var showSteps = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(unlocks, id: \.self) { u in
                Label(u, systemImage: "checkmark.circle").font(.callout).foregroundStyle(.primary)
            }
            Label(dataFlow, systemImage: "lock.shield").font(.caption).foregroundStyle(.secondary)
            DisclosureGroup(isExpanded: $showSteps) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(i + 1).").monospacedDigit().foregroundStyle(.secondary)
                            Text(.init(step)).textSelection(.enabled)
                        }
                        .font(.caption)
                    }
                    if let link, let url = URL(string: link.url) {
                        Button(link.title) { NSWorkspace.shared.open(url) }.controlSize(.small).padding(.top, 2)
                    }
                }
                .padding(.top, 4)
            } label: {
                Text("How to get it").font(.caption.weight(.semibold))
            }
        }
    }
}

/// The "works without keys" summary at the top of Connections.
struct ConnectionsOverview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ASO Workbench works without any key. Each connection below adds one thing; add only what you need.")
                .font(.callout)
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 4) {
                row("No key", "Rank tracking, autocomplete ideas, competitors, difficulty, ratings and reviews")
                row("Apple Ads API", "Apple's own search popularity and your campaign results")
                row("App Store Connect", "Pull your listing for every language and publish drafts back")
                row("OpenRouter", "AI writer, translations, brand / relevance checks")
                row("RevenueCat", "MRR and subscription numbers on Overview")
            }
            .font(.caption)
        }
    }

    private func row(_ a: String, _ b: String) -> some View {
        GridRow {
            Text(a).fontWeight(.semibold)
            Text(b).foregroundStyle(.secondary)
        }
    }
}
