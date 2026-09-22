import SwiftUI

/// A small key-cap badge such as ⌘K, used wherever a control has a shortcut worth showing.
struct Keycap: View {
    let keys: String

    var body: some View {
        Text(keys)
            .font(.caption2.weight(.medium).monospaced())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).stroke(.separator, lineWidth: 0.5))
            .accessibilityLabel("Shortcut \(keys)")
    }
}

/// One line of "keycap + verb" pairs, for footers and empty states.
struct ShortcutHints: View {
    let items: [(keys: String, label: String)]

    var body: some View {
        HStack(spacing: 14) {
            ForEach(items, id: \.keys) { item in
                HStack(spacing: 5) {
                    Keycap(keys: item.keys)
                    Text(item.label).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// The complete shortcut list (Help → Keyboard Shortcuts, ⌘/).
struct ShortcutsSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let groups: [(title: String, rows: [(String, String)])] = [
        ("Apps and keywords", [
            ("⌘N", "Add app (name, App Store link or ID)"),
            ("⌘K", "Add keywords to the current market"),
            ("⌘⌫", "Remove selected keywords (asks first)"),
            ("⌘A", "Select all keywords in the table"),
            ("⌘↩", "Add (inside the Add Keywords window)"),
        ]),
        ("Measuring", [
            ("⌘R", "Measure every keyword in the current market"),
            ("⇧⌘R", "Measure only the selected keywords"),
            ("⇧⌘P", "Fetch Apple popularity for the market"),
            ("⇧⌘E", "Export the table as CSV"),
        ]),
        ("Window", [
            ("⌥⌘I", "Show or hide the inspector"),
            ("⌃⌘S", "Show or hide the sidebar"),
            ("⌘,", "Settings"),
            ("⌘/", "This list"),
        ]),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Keyboard Shortcuts").font(.title3.weight(.semibold))
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            ForEach(groups, id: \.title) { group in
                VStack(alignment: .leading, spacing: 6) {
                    Text(group.title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    ForEach(group.rows, id: \.0) { row in
                        HStack(spacing: 10) {
                            Keycap(keys: row.0).frame(width: 52, alignment: .center)
                            Text(row.1).font(.callout)
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 440)
    }
}
