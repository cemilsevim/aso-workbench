import SwiftUI
import ASOCore

/// Small, reusable pieces. Everything uses system styles and semantic colours so
/// it follows the user's appearance and accessibility settings.

/// Shows where a number came from. Sits next to the value, never hidden in a tooltip alone.
struct SourceBadge: View {
    let origin: DataOrigin
    var detail: String? = nil
    /// Short form for table cells ("Apple" instead of "Apple (official) · …"); the full text goes to the tooltip.
    var compact = false

    private var compactLabel: String {
        switch origin {
        case .officialObserved: "Apple"
        case .publicSearchObserved: "Public"
        case .derived: "Derived"
        case .unavailable: "—"
        }
    }

    var body: some View {
        Text(compact ? compactLabel : (detail.map { "\(origin.label) · \($0)" } ?? origin.label))
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.quaternary, in: Capsule())
            .accessibilityLabel("Source: \(origin.label)\(detail.map { ", \($0)" } ?? "")")
    }
}

/// A single statistic with a title, used in the overview grid.
struct StatCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// Rank movement since the previous comparable measurement.
struct DeltaLabel: View {
    let delta: Int?

    var body: some View {
        if let delta, delta != 0 {
            Label {
                Text("\(abs(delta))").monospacedDigit()
            } icon: {
                Image(systemName: delta > 0 ? "arrow.up" : "arrow.down")
            }
            .font(.callout)
            .foregroundStyle(delta > 0 ? Color.green : Color.red)
            .labelStyle(.titleAndIcon)
            .accessibilityLabel(delta > 0 ? "Up \(delta)" : "Down \(abs(delta))")
        } else if delta == 0 {
            Text("=").foregroundStyle(.secondary)
        } else {
            Text("—").foregroundStyle(.tertiary).accessibilityLabel("No comparable previous measurement")
        }
    }
}

/// Colour bands. Popularity and rank: green is good. Difficulty: green is easy, red is hard.
enum ScoreBand {
    static func popularity(_ v: Int) -> Color { v >= 60 ? .green : v >= 35 ? .orange : .red }
    static func difficulty(_ v: Double) -> Color { v <= 35 ? .green : v <= 55 ? .orange : .red }
    static func rank(_ p: Int) -> Color? { p <= 10 ? .green : p <= 30 ? .orange : nil }
}

/// Rank cell: found → "#7", outside → "> 200", failed → warning icon.
struct RankLabel: View {
    let outcome: RankOutcome?

    var body: some View {
        switch outcome {
        case .found(let p, _):
            Text("#\(p)").monospacedDigit().fontWeight(p <= 10 ? .semibold : .regular)
                .foregroundStyle(ScoreBand.rank(p) ?? .primary)
        case .outsideObservedRange(let n):
            Text("> \(n)").monospacedDigit().foregroundStyle(.secondary)
        case .requestFailed:
            Label("Error", systemImage: "exclamationmark.triangle").foregroundStyle(.orange).labelStyle(.iconOnly)
        case .notChecked, nil:
            Text("—").foregroundStyle(.tertiary)
        }
    }
}

/// Inline status message (info / success / error) that stays visible until replaced.
struct InlineMessage: View {
    enum Kind { case info, success, error }
    let kind: Kind
    let text: String

    var body: some View {
        Label {
            Text(text).textSelection(.enabled)
        } icon: {
            Image(systemName: icon).foregroundStyle(color)
        }
        .font(.callout)
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var icon: String {
        switch kind {
        case .info: "info.circle"
        case .success: "checkmark.circle"
        case .error: "exclamationmark.triangle"
        }
    }
    private var color: Color {
        switch kind {
        case .info: .secondary
        case .success: .green
        case .error: .orange
        }
    }
}

struct ConnectionStateLabel: View {
    let state: ConnectionState

    var body: some View {
        switch state {
        case .notConfigured:
            Label("Not connected", systemImage: "circle.dashed").foregroundStyle(.secondary)
        case .configured:
            Label("Configured (not verified yet)", systemImage: "circle.fill").foregroundStyle(.orange)
        case .verified(let at, let detail):
            Label("Verified \(at.formatted(.relative(presentation: .named))) · \(detail)", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed(let message):
            Label(message, systemImage: "xmark.octagon.fill").foregroundStyle(.red)
        }
    }
}

struct AppIconView: View {
    let url: URL?
    var size: CGFloat = 28

    var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image.resizable().interpolation(.high)
            } else {
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous).fill(.quaternary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    }
}

extension Date {
    var relativeLabel: String { formatted(.relative(presentation: .named)) }
    var shortLabel: String { formatted(date: .abbreviated, time: .shortened) }
}
