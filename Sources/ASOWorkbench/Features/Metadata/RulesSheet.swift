import SwiftUI
import ASOCore

/// Help → ASO Rules: the house rules the validator and the assistant follow.
struct RulesSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("ASO rules").font(.title3.weight(.semibold))
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            Text("These rules drive the rule score in Metadata and the AI proposals. They generalise the house ASO playbook (docs/Comics_AI_ASO.pdf).")
                .font(.callout).foregroundStyle(.secondary)
            ScrollView {
                Text(ASORules.summary)
                    .font(.callout)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .frame(width: 620, height: 520)
    }
}
