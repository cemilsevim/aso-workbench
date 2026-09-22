import SwiftUI
import WebKit

/// Embedded sign-in for ads.apple.com. Cookies land in the shared default WebKit store,
/// which the hidden query web view uses afterwards. The app never sees the password.
struct AppleAdsSignInSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Sign in to Apple Ads").font(.headline)
                Spacer()
                Text("Sign in, wait for the campaign console to appear, then press Done.").font(.callout).foregroundStyle(.secondary)
                Button("Done") { onDone(); dismiss() }.keyboardShortcut(.defaultAction)
            }
            .padding(12)
            Divider()
            SignInWebView(url: AppleAdsSessionService.consoleURL)
        }
        .frame(width: 1000, height: 720)
    }
}

struct SignInWebView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.4 Safari/605.1.15"
        wv.load(URLRequest(url: url))
        return wv
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
