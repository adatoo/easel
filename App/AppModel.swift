import Foundation
import Observation
import SwiftData
import UIKit
import WebKit

/// Where a tab's navigation can go.
enum Route: Hashable {
    case video(VideoInfo)
    case playlist(PlaylistInfo)
    case shelf(Shelf)
}

/// One of her own lists, shown in full.
enum Shelf: Hashable {
    case continueWatching, favourites, bookmarks, downloads, watched
}

/// The video loaded in the player.
struct NowPlaying: Identifiable {
    let id = UUID()
    let video: VideoInfo
    let streamURL: URL
    /// Where it picked up from, for the "Resumed from…" note.
    var resumedFrom: Double?

    var isOffline: Bool { streamURL.isFileURL }
}

/// A page of the Raw Umber website to show in a sheet.
struct WebsiteRequest: Identifiable {
    let id = UUID()
    let url: URL
}

/// The app's state: which tab, what's playing, and the site, downloads and player behind it all.
@MainActor
@Observable
final class AppModel {
    enum Tab: Hashable {
        case home, search, myEasel
    }

    var tab: Tab = .home
    var homePath: [Route] = []
    var searchPath: [Route] = []
    var myEaselPath: [Route] = []
    var showsAccount = false
    var website: WebsiteRequest?
    /// A message for when playing or downloading didn't work.
    var problem: String?

    let api = SiteAPI()
    let resolver = StreamResolver()
    let downloads = DownloadManager()
    let player = PlayerModel()

    private(set) var nowPlaying: NowPlaying?
    /// Whether the player fills the screen (otherwise it's the bar above the tabs).
    var playerExpanded = false
    /// The video whose stream is being found, for the spinner on its Play button.
    private(set) var startingSlug: String?
    /// Videos whose streams are being found for downloading.
    private(set) var preparingDownloads: Set<String> = []
    /// Goes up when her sign-in may have changed, so screens load again.
    private(set) var siteVersion = 0

    let context: ModelContext
    @ObservationIgnored private var playTask: Task<Void, Never>?
    @ObservationIgnored private var currentRecord: Video?
    @ObservationIgnored private var lastSaved = Date.distantPast

    init(context: ModelContext) {
        self.context = context
        player.onProgress = { [weak self] time, duration in
            self?.recordProgress(time: time, duration: duration)
        }
    }

    // MARK: - Getting around

    /// Pushes onto the tab that's showing.
    func show(_ route: Route) {
        switch tab {
        case .home: homePath.append(route)
        case .search: searchPath.append(route)
        case .myEasel: myEaselPath.append(route)
        }
    }

    func open(_ video: VideoInfo) {
        show(.video(video))
    }

    /// A tab bar button: switches tab, or goes back to the tab's first screen if it's showing.
    func select(_ newTab: Tab) {
        guard tab == newTab else {
            tab = newTab
            return
        }
        switch newTab {
        case .home: homePath = []
        case .search: searchPath = []
        case .myEasel: myEaselPath = []
        }
    }

    func openWebsite(_ url: URL) {
        website = WebsiteRequest(url: url)
    }

    /// A video link (or a video starting to play) in the website sheet: close the sheet and
    /// show the video's page in Easel.
    func openFromWebsite(slug: String, title: String) {
        website = nil
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            show(.video(VideoInfo(id: 0, slug: slug, title: title)))
        }
    }

    /// After the website sheet closes: she may have signed in, so check and reload.
    func websiteClosed() {
        Task {
            await api.reload()
            await api.refreshSession()
            siteVersion += 1
        }
    }

    func signOut() async {
        closePlayer()
        let store = WKWebsiteDataStore.default()
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        let records = await store.dataRecords(ofTypes: types)
        let ours = records.filter { $0.displayName.contains("rawumberstudios") }
        await store.removeData(ofTypes: types, for: ours)
        resolver.reset()
        await api.reload()
        await api.refreshSession()
        siteVersion += 1
    }

    // MARK: - Playing

    /// Plays a video: the copy on the iPad if it's downloaded, otherwise the stream the site
    /// gives her. Resumes where she stopped unless `time` says where to start.
    func play(_ video: VideoInfo, series: SeriesContext? = nil, at time: Double? = nil) {
        if let playing = nowPlaying, playing.video.slug == video.slug {
            if let time { player.seek(to: time) }
            player.play()
            expandPlayer()
            return
        }
        playTask?.cancel()
        problem = nil
        startingSlug = video.slug
        playTask = Task { [weak self] in
            guard let self else { return }
            var url = self.downloads.localURL(for: video.slug)
            if url == nil {
                url = await self.resolver.stream(for: video, seriesSlug: series?.slug)
            }
            guard !Task.isCancelled else { return }
            self.startingSlug = nil
            guard let url else {
                self.problem =
                    "“\(video.displayTitle)” couldn't be started. Check the internet connection, or open it on the Raw Umber website from the video's page."
                return
            }
            await self.start(video, url: url, series: series, at: time)
        }
    }

    private func start(_ video: VideoInfo, url: URL, series: SeriesContext?, at time: Double?) async
    {
        saveProgress()
        let record = VideoStore.upsert(video, in: context)
        if let series {
            record.seriesSlug = series.slug
            record.seriesTitle = series.title
            record.partNumber = series.partNumber
            record.partCount = series.partCount
        }
        record.lastWatched = Date.now
        record.hiddenFromContinue = false

        var startAt = time ?? 0
        if time == nil, !record.finished, record.lastPosition > 15,
            record.knownDuration == 0 || record.lastPosition < record.knownDuration - 30
        {
            startAt = record.lastPosition
        }
        try? context.save()

        let cookies = url.isFileURL ? [] : await RawUmber.cookies()
        currentRecord = record
        nowPlaying = NowPlaying(
            video: video, streamURL: url, resumedFrom: time == nil && startAt > 0 ? startAt : nil)
        player.load(
            url: url,
            cookies: cookies,
            title: video.displayTitle,
            artist: video.tutor,
            artworkURL: video.thumbnailURL,
            startAt: startAt
        )
        expandPlayer()
    }

    func expandPlayer() {
        playerExpanded = true
        UIApplication.shared.isIdleTimerDisabled = true
    }

    /// Shrinks the player to the bar above the tabs. On the TV the video carries on; on the iPad
    /// it pauses, since there would be nothing to see.
    func minimisePlayer() {
        if !player.isExternal {
            player.pause()
            UIApplication.shared.isIdleTimerDisabled = false
        }
        saveProgress()
        playerExpanded = false
    }

    /// Stops the video and puts the player away.
    func closePlayer() {
        playTask?.cancel()
        startingSlug = nil
        saveProgress()
        player.stop()
        nowPlaying = nil
        currentRecord = nil
        playerExpanded = false
        UIApplication.shared.isIdleTimerDisabled = false
    }

    private func recordProgress(time: Double, duration: Double) {
        guard let record = currentRecord, duration > 0 else { return }
        record.knownDuration = duration
        if time > duration - 20 {
            record.lastPosition = 0
            record.finished = true
        } else if time > 5 {
            record.lastPosition = time
            record.finished = false
        }
        if Date.now.timeIntervalSince(lastSaved) > 10 {
            lastSaved = Date.now
            try? context.save()
        }
    }

    private func saveProgress() {
        if currentRecord != nil, player.isReady, player.duration > 0 {
            recordProgress(time: player.currentTime, duration: player.duration)
        }
        lastSaved = Date.now
        try? context.save()
    }

    // MARK: - Bookmarks

    /// Bookmarks the moment that's playing.
    @discardableResult
    func addBookmark() -> Bookmark? {
        guard let record = currentRecord, nowPlaying != nil else { return nil }
        let mark = Bookmark(time: player.currentTime)
        context.insert(mark)
        mark.video = record
        try? context.save()
        return mark
    }

    /// Plays the video a bookmark belongs to, from the bookmark.
    func play(_ mark: Bookmark) {
        guard let video = mark.video else { return }
        play(video.info, series: video.seriesContext, at: mark.time)
    }

    // MARK: - Downloading

    func download(_ video: VideoInfo, seriesSlug: String? = nil) {
        Task { await fetchAndDownload(video, seriesSlug: seriesSlug) }
    }

    /// One after another, so each can find its stream in turn.
    func downloadAll(_ videos: [VideoInfo], seriesSlug: String) {
        Task {
            for video in videos {
                await fetchAndDownload(video, seriesSlug: seriesSlug)
            }
        }
    }

    private func fetchAndDownload(_ video: VideoInfo, seriesSlug: String?) async {
        let slug = video.slug
        guard !downloads.isDownloaded(slug), downloads.progress(for: slug) == nil,
            !preparingDownloads.contains(slug)
        else { return }
        preparingDownloads.insert(slug)
        let url = await resolver.stream(for: video, seriesSlug: seriesSlug)
        preparingDownloads.remove(slug)
        guard let url else {
            problem =
                "“\(video.displayTitle)” couldn't be downloaded. Check the internet connection and try again."
            return
        }
        let cookies = await RawUmber.cookies()
        downloads.download(video, from: url, cookies: cookies)
    }
}
