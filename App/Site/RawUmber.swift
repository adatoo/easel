import Foundation

/// The rawumberstudios.com addresses Easel uses.
enum RawUmber {
    static let site = URL(string: "https://rawumberstudios.com")!
    /// Where the Website tab starts: the site's video playlists.
    static let home = URL(string: "https://rawumberstudios.com/n/playlists")!
    /// The endpoint the site's own search page calls, 25 results at a time.
    static let searchEndpoint = URL(string: "https://rawumberstudios.com/x/videosearch")!

    static func videoPage(_ slug: String) -> URL {
        site.appending(path: "n/videos").appending(path: slug)
    }

    static func thumbnail(_ fileName: String) -> URL? {
        guard !fileName.isEmpty else { return nil }
        return site.appending(path: "rus-videos/images/thumbnails").appending(path: fileName)
    }

    static func isSiteCookie(_ cookie: HTTPCookie) -> Bool {
        cookie.domain.hasSuffix("rawumberstudios.com")
    }
}
