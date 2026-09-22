import SwiftUI
import SwiftData

struct AddKeywordsSheet: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let market: TrackedMarket
    @State private var text = ""
    @State private var measureAfter = true

    private var count: Int {
        Set(text.split(whereSeparator: { $0 == "\n" || $0 == "," }).map { TrackedKeyword.normalize(String($0)) }.filter { !$0.isEmpty }).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add keywords to \(market.title)").font(.headline)
            Text("One per line or comma separated. Duplicates (case-insensitive) are skipped.")
                .font(.callout).foregroundStyle(.secondary)
            TextEditor(text: $text)
                .font(.body.monospaced())
                .frame(minHeight: 220)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator))
            Toggle("Measure rank right after adding", isOn: $measureAfter)
            HStack {
                Text("\(count) keyword(s)").foregroundStyle(.secondary).font(.callout)
                Spacer()
                Keycap(keys: "esc")
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Keycap(keys: "⌘↩")
                Button("Add") {
                    let before = Set(market.keywords.map(\.persistentModelID))
                    env.catalog.addKeywords(text, to: market, context: context)
                    if measureAfter {
                        let fresh = market.sortedKeywords.filter { !before.contains($0.persistentModelID) }
                        env.tracking.measure(fresh, in: market, context: context)
                    }
                    dismiss()
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(count == 0)
            }
        }
        .padding()
        .frame(width: 480)
    }
}
