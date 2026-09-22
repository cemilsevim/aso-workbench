import SwiftUI
import AppKit
import ASOCore

/// What a new release brings and how to install it.
struct UpdateSheet: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch env.updates.lastResult {
            case .available(let r)?:
                HStack(alignment: .firstTextBaseline) {
                    Label("ASO Workbench \(r.version) is available", systemImage: "arrow.down.circle.fill").font(.title3.weight(.semibold)).foregroundStyle(.tint)
                    Spacer()
                    Text("You have \(AppInfo.version)").foregroundStyle(.secondary)
                }
                if let d = r.publishedAt { Text("Released \(d.formatted(date: .abbreviated, time: .omitted))").font(.caption).foregroundStyle(.secondary) }
                GroupBox("What's new") {
                    ScrollView {
                        Text((try? AttributedString(markdown: r.notes, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(r.notes))
                            .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 160, maxHeight: 300)
                }
                GroupBox("How to update") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("1. Download the .dmg, open it and drag **ASO Workbench** onto Applications, replacing the old copy. Quit the running app first.")
                        Text("2. Open it. Your keywords, history and keys stay in ~/Library/Application Support/ASO Workbench; a backup of the data is made automatically before the new version opens it.")
                        HStack(spacing: 6) {
                            Text("Built from source? Run")
                            Text("make update").font(.system(.body, design: .monospaced)).padding(.horizontal, 4).background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
                            Button("Copy") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString("git pull --ff-only && make install", forType: .string) }.controlSize(.small)
                        }
                    }
                    .font(.callout).frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack {
                    Button("Skip this version") { env.updates.skip(r); dismiss() }
                    Spacer()
                    Button("Later") { dismiss() }.keyboardShortcut(.cancelAction)
                    Button("Release page") { env.updates.open(r.pageURL) }
                    if let d = r.downloadURL { Button("Download") { env.updates.open(d); dismiss() }.keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent) }
                }
            case .upToDate(let v)?:
                Label("You're up to date", systemImage: "checkmark.seal.fill").font(.title3.weight(.semibold)).foregroundStyle(.green)
                Text("ASO Workbench \(v) is the newest release on \(AppInfo.repository).").foregroundStyle(.secondary)
                HStack { Spacer(); Button("OK") { dismiss() }.keyboardShortcut(.defaultAction) }
            case .failed(let m)?:
                Label("Couldn't check for updates", systemImage: "exclamationmark.triangle.fill").font(.title3.weight(.semibold)).foregroundStyle(.orange)
                Text(m).foregroundStyle(.secondary).textSelection(.enabled)
                HStack { Button("Open releases") { env.updates.open(AppInfo.repositoryURL.appendingPathComponent("releases")) }; Spacer(); Button("OK") { dismiss() }.keyboardShortcut(.defaultAction) }
            case nil:
                HStack { ProgressView().controlSize(.small); Text("Checking GitHub…") }
            }
        }
        .padding(20)
        .frame(width: 560)
    }
}
