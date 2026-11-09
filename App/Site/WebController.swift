import Foundation
import Observation
import WebKit

/// The one web view Easel keeps for rawumberstudios.com, and what its page bridge reports.
///
/// It uses the default (persistent) website data store, so she signs in once and stays signed in.
@MainActor
@Observable
final class WebController: NSObject {
    let webView: WKWebView

    /// The video page showing now, if any.
    private(set) var pageVideo: VideoInfo?
    /// The stream the page's own player is using, once found.
    private(set) var streamURL: URL?
    private(set) var canGoBack = false
    private(set) var canGoForward = false
    private(set) var isLoading = false

    /// Called when a video page's stream is found.
    @ObservationIgnored var onStream: ((VideoInfo, URL) -> Void)?
    /// Called when play is pressed in the site's own player on a page Easel can play.
    @ObservationIgnored var onSitePlay: (() -> Void)?
    @ObservationIgnored private var observations: [NSKeyValueObservation] = []

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()

        let content = webView.configuration.userContentController
        content.add(WeakScriptMessageHandler(self), name: "easel")
        content.addUserScript(
            WKUserScript(source: EaselBridge.source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        )
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        #if DEBUG
        // Safari ▸ Develop ▸ (her iPad) shows this web view and the bridge's messages.
        webView.isInspectable = true
        #endif
        observeWebView()
        webView.load(URLRequest(url: RawUmber.home))
    }

    func open(_ url: URL) {
        webView.load(URLRequest(url: url))
    }

    func goHome() { open(RawUmber.home) }
    func goBack() { webView.goBack() }
    func goForward() { webView.goForward() }
    func reload() { webView.reload() }

    /// Pauses the site's own player so it doesn't play underneath Easel's.
    func pauseSitePlayer() {
        webView.evaluateJavaScript("window.__easelPause && window.__easelPause();", completionHandler: nil)
    }

    /// The site's cookies, so Easel's search and player act as her signed-in account.
    func siteCookies() async -> [HTTPCookie] {
        let cookies = await webView.configuration.websiteDataStore.httpCookieStore.allCookies()
        return cookies.filter(RawUmber.isSiteCookie)
    }

    private func observeWebView() {
        observations = [
            webView.observe(\.canGoBack, options: [.initial, .new]) { [weak self] webView, _ in
                MainActor.assumeIsolated { self?.canGoBack = webView.canGoBack }
            },
            webView.observe(\.canGoForward, options: [.initial, .new]) { [weak self] webView, _ in
                MainActor.assumeIsolated { self?.canGoForward = webView.canGoForward }
            },
            webView.observe(\.isLoading, options: [.initial, .new]) { [weak self] webView, _ in
                MainActor.assumeIsolated { self?.isLoading = webView.isLoading }
            },
        ]
    }
}

extension WebController: WKScriptMessageHandler {
    func userContentController(
        _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
    ) {
        guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
        switch type {
        case "page":
            streamURL = nil
            pageVideo = (body["video"] as? [String: Any]).flatMap(VideoInfo.init(bridge:))
        case "stream":
            guard let video = pageVideo,
                  (body["slug"] as? String) == video.slug,
                  let string = body["url"] as? String,
                  let url = URL(string: string)
            else { return }
            streamURL = url
            onStream?(video, url)
        case "play":
            guard (body["slug"] as? String) == pageVideo?.slug, streamURL != nil else {
                #if DEBUG
                print("[EaselBridge] play ignored: slug \(body["slug"] ?? "nil"), page \(pageVideo?.slug ?? "nil"), stream \(streamURL?.absoluteString ?? "nil")")
                #endif
                return
            }
            onSitePlay?()
        case "log":
            #if DEBUG
            print("[EaselBridge]", body["message"] as? String ?? "")
            #endif
        default:
            break
        }
    }
}

extension WebController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        // A new document: the bridge reports its page again once it has loaded.
        pageVideo = nil
        streamURL = nil
    }
}

extension WebController: WKUIDelegate {
    /// Links that ask for a new window open in the same web view.
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

/// WKUserContentController keeps its handlers alive; this stops it keeping WebController alive.
private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?

    init(_ target: WKScriptMessageHandler) {
        self.target = target
    }

    func userContentController(
        _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
    ) {
        target?.userContentController(userContentController, didReceive: message)
    }
}
