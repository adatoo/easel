import Foundation
import Observation
import WebKit

enum SiteError: Error {
    /// The site couldn't be reached (usually no internet).
    case unreachable
    case http(Int)
    case badResponse
}

/// Easel's view of the site's data: search, playlists, video and series pages, and who is
/// signed in.
///
/// Requests run inside a web view that stays parked on a site page (it is in the window but
/// out of sight), using the same JSON endpoints the site's own pages use. That way they carry
/// her sign-in exactly as the site does, with nothing for Easel to manage.
@MainActor
@Observable
final class SiteAPI: NSObject {
    let webView: WKWebView

    private(set) var session = SiteSession()
    private(set) var playlists: [PlaylistInfo] = []
    /// False until the site has answered once, so "sign in" isn't shown while it's unknown.
    private(set) var hasLoadedSession = false

    static let pageSize = 25

    @ObservationIgnored private var pageReady = false
    @ObservationIgnored private var loadFailed = false

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        configuration.userContentController.addUserScript(
            WKUserScript(source: SiteScripts.api, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        )
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        #if DEBUG
        webView.isInspectable = true
        #endif
        webView.load(URLRequest(url: RawUmber.parked))
    }

    // MARK: - Requests

    /// Who is signed in, the tutors, and Raw Umber's playlists.
    func refreshSession() async {
        guard let result = try? await call("return await window.__easelAPI.bootstrap();") else { return }
        var updated = SiteSession()
        updated.loggedIn = (result["loggedIn"] as? Bool) ?? false
        updated.level = (result["level"] as? String) ?? "none"
        updated.subscribed = (result["subscribed"] as? Bool) ?? false
        updated.tutors = ((result["tutors"] as? [[String: Any]]) ?? []).compactMap { dict in
            guard let id = dict["id"] as? Int, let name = dict["name"] as? String else { return nil }
            return Tutor(id: id, name: name)
        }
        session = updated
        playlists = ((result["playlists"] as? [[String: Any]]) ?? []).compactMap(PlaylistInfo.init(site:))
        hasLoadedSession = true
    }

    func search(_ query: SearchQuery, offset: Int) async throws -> SearchPage {
        let result = try await call(
            "return await window.__easelAPI.search(json);",
            arguments: ["json": query.json(offset: offset, count: Self.pageSize)]
        )
        return SearchPage(videos: Self.videos(result["videos"]), count: (result["count"] as? Int) ?? 0)
    }

    func playlist(slug: String) async throws -> [VideoInfo] {
        let result = try await call("return await window.__easelAPI.playlist(slug);", arguments: ["slug": slug])
        return Self.videos(result["videos"])
    }

    func videoPage(slug: String) async throws -> VideoPage {
        let result = try await call("return await window.__easelAPI.video(slug);", arguments: ["slug": slug])
        guard let dict = result["video"] as? [String: Any], let video = VideoInfo(site: dict) else {
            throw SiteError.badResponse
        }
        var page = VideoPage(video: video)
        page.parts = Self.videos(result["parts"])
        page.trailer = (result["trailer"] as? [String: Any]).flatMap(VideoInfo.init(site:))
        page.related = Self.videos(result["related"])
        page.extras = ((result["extras"] as? [[String: Any]]) ?? []).compactMap { dict in
            guard let title = dict["title"] as? String,
                  let string = dict["url"] as? String,
                  let url = URL(string: string)
            else { return nil }
            return ExtraLink(title: title, url: url)
        }
        return page
    }

    /// Reloads the parked page: after signing in or out, so it picks up the change.
    func reload() async {
        pageReady = false
        loadFailed = false
        webView.load(URLRequest(url: RawUmber.parked))
        try? await waitUntilReady()
    }

    // MARK: - Running a request in the page

    private func call(_ body: String, arguments: [String: Any] = [:], retry: Bool = true) async throws -> [String: Any] {
        if loadFailed {
            loadFailed = false
            webView.load(URLRequest(url: RawUmber.parked))
        }
        try await waitUntilReady()

        var status = 0
        if let value = try? await webView.callAsyncJavaScript(body, arguments: arguments, in: nil, contentWorld: .page),
           let string = value as? String,
           let data = string.data(using: .utf8),
           let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            status = (object["status"] as? Int) ?? 0
            if status == 200 { return object }
        }

        // 404 usually means the site was redeployed since the page loaded; 0 that the request
        // or the script failed. Reload the page once and try again.
        if retry, status == 404 || status == 0 {
            await reload()
            return try await call(body, arguments: arguments, retry: false)
        }
        throw status == 0 ? SiteError.unreachable : SiteError.http(status)
    }

    private func waitUntilReady() async throws {
        var waited = 0
        while !pageReady {
            if loadFailed || waited >= 80 { throw SiteError.unreachable }   // 20 seconds
            try await Task.sleep(for: .milliseconds(250))
            waited += 1
        }
    }

    private static func videos(_ value: Any?) -> [VideoInfo] {
        var seen = Set<String>()
        return ((value as? [[String: Any]]) ?? [])
            .compactMap(VideoInfo.init(site:))
            .filter { seen.insert($0.slug).inserted }
    }
}

extension SiteAPI: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        pageReady = false
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        pageReady = true
        loadFailed = false
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        loadFailed = true
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        loadFailed = true
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        // iOS reclaimed the page's memory; load it again on the next request.
        pageReady = false
        loadFailed = true
    }
}
