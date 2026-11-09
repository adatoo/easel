import Foundation
import Observation

/// Which tab is showing, and the hand-off from a video page on the website to Easel's player.
@MainActor
@Observable
final class AppModel {
    enum Tab: Hashable {
        case library, favourites, continueWatching, downloads, website
    }

    var tab: Tab = .library
    var playRequest: PlayRequest?
    let web = WebController()
    let downloads = DownloadManager()

    /// The video to start as soon as its page's stream is found (set when she taps a card).
    @ObservationIgnored private var autoPlaySlug: String?
    /// The tab she tapped a video in, to go back to when the player closes.
    @ObservationIgnored private var returnTab: Tab?

    init() {
        web.onStream = { [weak self] video, url in
            self?.streamFound(video: video, url: url)
        }
        // Play pressed in the site's own player opens Easel's player instead.
        web.onSitePlay = { [weak self] video, url in
            self?.playFromSite(video: video, url: url)
        }
    }

    /// Plays a video: the copy on the iPad if it's downloaded, otherwise opens its page in the
    /// Website tab and plays it once the stream is found.
    func open(_ video: VideoInfo, autoPlay: Bool = true) {
        if autoPlay, let local = downloads.localURL(for: video.slug) {
            autoPlaySlug = nil
            playRequest = PlayRequest(video: video, streamURL: local)
            return
        }
        if tab != .website { returnTab = tab }
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
        returnTab = nil
        guard let video = web.pageVideo, let url = web.streamURL else { return }
        play(video: video, url: downloads.localURL(for: video.slug) ?? url)
    }

    /// One of the site's players on the page (the video, a series trailer or an episode).
    func playFromSite(video: VideoInfo, url: URL) {
        returnTab = nil
        guard playRequest == nil else { return }
        play(video: video, url: downloads.localURL(for: video.slug) ?? url)
    }

    /// After the player closes: back to the tab she started in, if she came from a card.
    func playerClosed() {
        web.pauseSitePlayer()
        if let returnTab {
            tab = returnTab
            self.returnTab = nil
        }
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

    var isOffline: Bool { streamURL.isFileURL }
}
