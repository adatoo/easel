import Foundation
import Observation
import WebKit

/// Finds the stream for a video by loading its page (or its series' page) in a web view that is
/// in the window but out of sight, and reading what the site's own player was given. So Easel
/// only ever plays what the site set up for her account. Streams found are remembered until the
/// app closes.
@MainActor
@Observable
final class StreamResolver: NSObject {
    let webView: WKWebView

    /// Site video ID → stream.
    private(set) var streams: [Int: URL] = [:]

    @ObservationIgnored private var currentSlug: String?
    @ObservationIgnored private var loadedAt = Date.distantPast
    @ObservationIgnored private var isResolving = false

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: SiteScripts.streams, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        )
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.configuration.userContentController.add(
            WeakScriptMessageHandler(self), name: "easelStreams")
        #if DEBUG
            webView.isInspectable = true
        #endif
    }

    /// Starts loading a page ahead of time (when she opens a video's page), so Play is quick.
    func prepare(slug: String) {
        guard !isResolving else { return }
        load(slug: slug)
    }

    /// The stream for a video, or nil if the site gave its player none within the time allowed
    /// (she can't watch it, or there's no connection).
    func stream(for video: VideoInfo, seriesSlug: String? = nil) async -> URL? {
        if let url = streams[video.id] { return url }

        // One at a time: each needs the web view on its own page.
        while isResolving {
            try? await Task.sleep(for: .milliseconds(200))
            if Task.isCancelled { return nil }
            if let url = streams[video.id] { return url }
        }
        isResolving = true
        defer { isResolving = false }

        // A series page has a player for every part she can watch, so try that first if it's
        // already the page loaded.
        if let seriesSlug, currentSlug == seriesSlug,
            let url = await wait(for: video.id, seconds: 4)
        {
            return url
        }
        if Task.isCancelled { return nil }
        // Its own page. If that only just started loading (she opened the video's page a moment
        // ago), wait for it rather than starting again.
        let justStarted = currentSlug == video.slug && Date.now.timeIntervalSince(loadedAt) < 8
        if !justStarted { load(slug: video.slug, force: true) }
        return await wait(for: video.id, seconds: 15)
    }

    /// Forgets the streams found so far (after signing out).
    func reset() {
        streams = [:]
        currentSlug = nil
    }

    private func load(slug: String, force: Bool = false) {
        if !force, currentSlug == slug, Date.now.timeIntervalSince(loadedAt) < 60 { return }
        currentSlug = slug
        loadedAt = Date.now
        webView.load(URLRequest(url: RawUmber.videoPage(slug)))
    }

    private func wait(for id: Int, seconds: Double) async -> URL? {
        let deadline = Date.now.addingTimeInterval(seconds)
        while Date.now < deadline {
            if let url = streams[id] { return url }
            try? await Task.sleep(for: .milliseconds(200))
            if Task.isCancelled { return nil }
        }
        return streams[id]
    }
}

extension StreamResolver: WKScriptMessageHandler {
    func userContentController(
        _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
    ) {
        guard let body = message.body as? [String: Any],
            (body["type"] as? String) == "stream",
            let id = body["id"] as? Int,
            let string = body["url"] as? String,
            let url = URL(string: string)
        else { return }
        streams[id] = url
    }
}
