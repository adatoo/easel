import Foundation
import WebKit

/// The rawumberstudios.com addresses Easel uses.
enum RawUmber {
    static let site = URL(string: "https://rawumberstudios.com")!
    /// The page the data web view stays parked on.
    static let parked = URL(string: "https://rawumberstudios.com/n/playlists")!
    static let front = URL(string: "https://rawumberstudios.com/n")!
    static let signIn = URL(string: "https://rawumberstudios.com/n/log-in")!
    static let account = URL(string: "https://rawumberstudios.com/n/my-account")!

    static func videoPage(_ slug: String) -> URL {
        site.appending(path: "n/videos").appending(path: slug)
    }

    /// The video a link points to, for both the site's current and older addresses
    /// (/n/videos/<slug> and /videos/<slug>/).
    static func videoSlug(from url: URL) -> String? {
        guard let host = url.host?.lowercased(), host.hasSuffix("rawumberstudios.com") else {
            return nil
        }
        let parts = url.path.split(separator: "/").map(String.init)
        if parts.count == 2, parts[0] == "videos" { return parts[1] }
        if parts.count == 3, parts[0] == "n", parts[1] == "videos" { return parts[2] }
        return nil
    }

    /// The small picture for cards.
    static func thumbnail(_ fileName: String) -> URL? {
        guard !fileName.isEmpty else { return nil }
        return site.appending(path: "rus-videos/images/thumbnails").appending(path: fileName)
    }

    /// The large picture for the top of a video's page.
    static func preview(_ fileName: String) -> URL? {
        guard !fileName.isEmpty else { return nil }
        return site.appending(path: "rus-videos/images/previews").appending(path: fileName)
    }

    /// The site's cookies from the web views' shared store, so the player and downloads act as
    /// her signed-in account.
    @MainActor
    static func cookies() async -> [HTTPCookie] {
        let all = await WKWebsiteDataStore.default().httpCookieStore.allCookies()
        return all.filter { $0.domain.hasSuffix("rawumberstudios.com") }
    }
}

/// WKUserContentController keeps its handlers alive; this stops it keeping their owner alive.
final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
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
