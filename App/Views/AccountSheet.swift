import SwiftUI
import WebKit

/// Signed in or not, download quality, and the way to the Raw Umber website.
struct AccountSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @AppStorage(DownloadQuality.defaultsKey) private var quality = DownloadQuality.full.rawValue
    @State private var confirmSignOut = false

    var body: some View {
        let session = app.api.session
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text("Account")
                    .font(.system(size: 28, weight: .bold))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(CircleButtonStyle(size: 48))
                .accessibilityLabel("Close")
            }

            HStack(spacing: 18) {
                Image(systemName: "person.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 68, height: 68)
                    .background(Theme.raised, in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.loggedIn ? "Signed in to Raw Umber" : "Not signed in")
                        .font(.system(size: 19, weight: .semibold))
                    Text(statusLine(session))
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.secondary)
                }
            }

            VStack(spacing: 0) {
                row {
                    Text("Download quality")
                    Spacer()
                    Picker("Download quality", selection: $quality) {
                        ForEach(DownloadQuality.allCases) { option in
                            Text(option.rawValue).tag(option.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
                divider
                Button {
                    dismiss()
                    app.tab = .myEasel
                    app.myEaselPath = [.shelf(.downloads)]
                } label: {
                    row {
                        Text("Downloads on this iPad")
                        Spacer()
                        Text(downloadsSummary)
                            .foregroundStyle(Theme.secondary)
                        Image(systemName: "chevron.right")
                            .foregroundStyle(Theme.secondary)
                    }
                }
                .buttonStyle(.plain)
                divider
                Button {
                    dismiss()
                    app.openWebsite(session.loggedIn ? RawUmber.account : RawUmber.front)
                } label: {
                    row(height: 84) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Open the Raw Umber website")
                            Text("Live sessions and chat, reference photos, your subscription")
                                .font(.system(size: 15))
                                .foregroundStyle(Theme.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(Theme.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .background(Theme.ground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            if session.loggedIn {
                Button("Sign out") { confirmSignOut = true }
                    .buttonStyle(PillButtonStyle(kind: .secondary, height: 60, fontSize: 18))
                    .frame(maxWidth: .infinity)
            } else {
                Button("Sign in") {
                    dismiss()
                    app.openWebsite(RawUmber.signIn)
                }
                .buttonStyle(PillButtonStyle(kind: .primary, height: 60, fontSize: 18))
                .frame(maxWidth: .infinity)
            }

            Spacer(minLength: 0)

            Text("Easel plays the videos in your own Raw Umber subscription. Signing in happens on Raw Umber's own page, shown inside Easel. Sign in with your email and password: Google sign-in doesn't work inside apps.")
                .font(.system(size: 15))
                .foregroundStyle(Theme.secondary)
        }
        .foregroundStyle(Theme.text)
        .font(.system(size: 18, weight: .medium))
        .padding(28)
        .background(Theme.surface)
        .presentationDetents([.large])
        .preferredColorScheme(.dark)
        .confirmationDialog("Sign out of Raw Umber?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) {
                Task {
                    await app.signOut()
                    dismiss()
                }
            }
        } message: {
            Text("Your favourites, bookmarks and downloads stay on this iPad.")
        }
    }

    private func statusLine(_ session: SiteSession) -> String {
        guard session.loggedIn else { return "Sign in to watch the videos in your subscription" }
        switch session.level.lowercased() {
        case "none", "": return session.subscribed ? "Subscriber" : "No subscription"
        default: return "\(session.level.capitalized) subscription"
        }
    }

    private var downloadsSummary: String {
        let count = app.downloads.downloads.count
        guard count > 0 else { return "None" }
        return "\(count == 1 ? "1 video" : "\(count) videos") · \(ByteText.string(app.downloads.totalBytes))"
    }

    private var divider: some View {
        Theme.line.opacity(0.6).frame(height: 1)
    }

    private func row<Content: View>(height: CGFloat = 68, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            content()
        }
        .padding(.horizontal, 20)
        .frame(minHeight: height)
        .contentShape(Rectangle())
    }
}

/// A page of the Raw Umber website: signing in, live sessions, extras. It shares its sign-in
/// with the rest of Easel.
struct WebsiteSheet: View {
    let request: WebsiteRequest

    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var app
    @State private var page = WebsitePage()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button("Done") { dismiss() }
                    .buttonStyle(PillButtonStyle(kind: .primary, height: 48, fontSize: 17))
                Button {
                    page.webView.goBack()
                } label: {
                    Image(systemName: "chevron.backward")
                }
                .buttonStyle(CircleButtonStyle(size: 48))
                .disabled(!page.canGoBack)
                .opacity(page.canGoBack ? 1 : 0.4)
                .accessibilityLabel("Back")
                Button {
                    page.webView.goForward()
                } label: {
                    Image(systemName: "chevron.forward")
                }
                .buttonStyle(CircleButtonStyle(size: 48))
                .disabled(!page.canGoForward)
                .opacity(page.canGoForward ? 1 : 0.4)
                .accessibilityLabel("Forward")
                Text(page.title.isEmpty ? "Raw Umber" : page.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                if page.isLoading {
                    ProgressView()
                } else {
                    Button {
                        page.webView.reload()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(CircleButtonStyle(size: 48))
                    .accessibilityLabel("Reload")
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Theme.bar)

            WebViewHost(webView: page.webView)
                .ignoresSafeArea(edges: .bottom)
        }
        .background(Theme.bar.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onAppear {
            page.onOpenVideo = { slug, title in
                app.openFromWebsite(slug: slug, title: title)
            }
            page.load(request.url)
        }
    }
}

/// The web view behind WebsiteSheet, and what the sheet's toolbar needs from it.
@MainActor
@Observable
final class WebsitePage: NSObject, WKUIDelegate, WKNavigationDelegate, WKScriptMessageHandler {
    let webView: WKWebView
    private(set) var canGoBack = false
    private(set) var canGoForward = false
    private(set) var isLoading = false
    private(set) var title = ""
    /// Called with (slug, title) when a video should open in Easel rather than on the website.
    @ObservationIgnored var onOpenVideo: ((String, String) -> Void)?
    /// The one video page this sheet may show (a live session, or a video she can't watch in Easel).
    @ObservationIgnored private var allowedSlug: String?
    @ObservationIgnored private var observations: [NSKeyValueObservation] = []

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.allowsInlineMediaPlayback = true
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.uiDelegate = self
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        // The site is designed light; keep it that way inside the dark app.
        webView.overrideUserInterfaceStyle = .light
        webView.isOpaque = true
        webView.backgroundColor = .white
        let content = webView.configuration.userContentController
        content.add(WeakScriptMessageHandler(self), name: "easelSheet")
        content.addUserScript(
            WKUserScript(source: SiteScripts.website, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        )
        observations = [
            webView.observe(\.canGoBack, options: [.initial, .new]) { [weak self] view, _ in
                MainActor.assumeIsolated { self?.canGoBack = view.canGoBack }
            },
            webView.observe(\.canGoForward, options: [.initial, .new]) { [weak self] view, _ in
                MainActor.assumeIsolated { self?.canGoForward = view.canGoForward }
            },
            webView.observe(\.isLoading, options: [.initial, .new]) { [weak self] view, _ in
                MainActor.assumeIsolated { self?.isLoading = view.isLoading }
            },
            webView.observe(\.title, options: [.initial, .new]) { [weak self] view, _ in
                MainActor.assumeIsolated { self?.title = view.title ?? "" }
            },
        ]
    }

    func load(_ url: URL) {
        guard webView.url == nil else { return }
        allowedSlug = RawUmber.videoSlug(from: url)
        if let allowedSlug,
           let data = try? JSONSerialization.data(withJSONObject: [allowedSlug]),
           let json = String(data: data, encoding: .utf8) {
            webView.configuration.userContentController.addUserScript(
                WKUserScript(
                    source: "window.__easelAllowedSlug = \(json)[0];",
                    injectionTime: .atDocumentStart,
                    forMainFrameOnly: true
                )
            )
        }
        webView.load(URLRequest(url: url))
    }

    /// Pages that load fully (rather than the site moving between its own pages) are checked here.
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction
    ) async -> WKNavigationActionPolicy {
        if navigationAction.targetFrame?.isMainFrame != false,
           let url = navigationAction.request.url,
           let slug = RawUmber.videoSlug(from: url),
           slug != allowedSlug {
            onOpenVideo?(slug, "")
            return .cancel
        }
        return .allow
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              (body["type"] as? String) == "openVideo",
              let slug = body["slug"] as? String, !slug.isEmpty
        else { return }
        onOpenVideo?(slug, (body["title"] as? String) ?? "")
    }

    /// Links that ask for a new window open in the same view.
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }
}
