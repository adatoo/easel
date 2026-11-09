import Foundation
import Observation

/// Which tab is showing, and the hand-off from a video page on the website to Easel's player.
@MainActor
@Observable
final class AppModel {
    enum Tab: Hashable {
        case library, favourites, continueWatching, website
    }

    var tab: Tab = .library
    var playRequest: PlayRequest?
    let web = WebController()

    /// The video to start as soon as its page's stream is found (set when she taps a card).
    @ObservationIgnored private var autoPlaySlug: String?

    init() {
        web.onStream = { [weak self] video, url in
            self?.streamFound(video: video, url: url)
        }
    }

    /// Opens a video's page in the Website tab and, by default, plays it once the stream is found.
    func open(_ video: VideoInfo, autoPlay: Bool = true) {
        tab = .website
        if web.pageVideo?.slug == video.slug, let url = web.streamURL {
            if autoPlay { play(video: web.pageVideo ?? video, url: url) }
            return
        }
        autoPlaySlug = autoPlay ? video.slug : nil
        web.open(RawUmber.videoPage(video.slug))
    }

    /// The big Watch button on a video page.
    func watchCurrentPage() {
        guard let video = web.pageVideo, let url = web.streamURL else { return }
        play(video: video, url: url)
    }

    private func streamFound(video: VideoInfo, url: URL) {
        guard autoPlaySlug == video.slug else { return }
        play(video: video, url: url)
    }

    private func play(video: VideoInfo, url: URL) {
        autoPlaySlug = nil
        web.pauseSitePlayer()
        playRequest = PlayRequest(video: video, streamURL: url)
    }
}

/// A video to open in the player, with the stream its page's own player was using.
struct PlayRequest: Identifiable {
    let id = UUID()
    let video: VideoInfo
    let streamURL: URL
}
