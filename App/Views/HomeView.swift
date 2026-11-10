import SwiftData
import SwiftUI

/// Home: pick up where she left off, then what's on and what's new.
struct HomeView: View {
    @Environment(AppModel.self) private var app

    @Query(
        filter: #Predicate<Video> { $0.lastWatched != nil },
        sort: [SortDescriptor(\Video.lastWatched, order: .reverse)]
    )
    private var watched: [Video]

    @Query(
        filter: #Predicate<Video> { $0.isFavourite },
        sort: [SortDescriptor(\Video.favouritedAt, order: .reverse)]
    )
    private var favourites: [Video]

    /// The first page of the site's list: coming live sessions, then the newest videos.
    @State private var latest: [VideoInfo] = []
    @State private var loadFailed = false

    var body: some View {
        let inProgress = watched.filter(\.showsInContinue)
        let upcoming = Array(latest.filter(\.isUpcoming).reversed())
        let newest = latest.filter { !$0.isUpcoming }

        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                header

                if app.api.hasLoadedSession, !app.api.session.loggedIn {
                    NoticeBar(
                        systemImage: "person.crop.circle.badge.exclamationmark",
                        text: "Sign in to Raw Umber to watch the videos in your subscription.",
                        buttonTitle: "Sign in"
                    ) {
                        app.openWebsite(RawUmber.signIn)
                    }
                }
                if loadFailed {
                    NoticeBar(
                        systemImage: "wifi.slash",
                        text: "Raw Umber can't be reached. Downloaded videos still play.",
                        buttonTitle: "Try again"
                    ) {
                        Task { await load() }
                    }
                }

                if let hero = inProgress.first {
                    ResumeHero(video: hero)
                }

                if inProgress.count > 1 {
                    RowSection("Continue watching", seeAll: { app.show(.shelf(.continueWatching)) }) {
                        ForEach(Array(inProgress.dropFirst().prefix(12))) { video in
                            VideoCard(
                                video.info,
                                subtitle: continueSubtitle(video),
                                removeTitle: "Remove from Continue watching",
                                onRemove: { withAnimation { VideoStore.removeFromContinue(video, in: app.context) } }
                            ) {
                                app.play(video.info, series: video.seriesContext)
                            }
                        }
                    }
                }

                if loadFailed, !app.downloads.downloads.isEmpty {
                    RowSection("On this iPad", seeAll: { app.show(.shelf(.downloads)) }) {
                        ForEach(app.downloads.downloads) { record in
                            VideoCard(record.info) { app.play(record.info) }
                        }
                    }
                }

                if !upcoming.isEmpty {
                    RowSection("Live this week") {
                        ForEach(upcoming, id: \.slug) { video in
                            VideoCard(video) { app.open(video) }
                        }
                    }
                }

                if !newest.isEmpty {
                    RowSection("New sessions") {
                        ForEach(newest, id: \.slug) { video in
                            VideoCard(video) { app.open(video) }
                        }
                    }
                }

                if !favourites.isEmpty {
                    RowSection("My favourites", seeAll: { app.show(.shelf(.favourites)) }) {
                        ForEach(Array(favourites.prefix(12))) { video in
                            VideoCard(video.info) { app.open(video.info) }
                        }
                    }
                }

                if !app.api.playlists.isEmpty {
                    RowSection("Playlists from Raw Umber") {
                        ForEach(app.api.playlists) { playlist in
                            PlaylistTile(playlist: playlist, width: 248)
                        }
                    }
                }

                if latest.isEmpty, !loadFailed {
                    ProgressView()
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                }
            }
            .padding(.bottom, 30)
        }
        .background(Theme.ground)
        .toolbar(.hidden, for: .navigationBar)
        .task(id: app.siteVersion) { await load() }
        .refreshable { await load() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "paintpalette.fill")
                .font(.system(size: 24))
                .foregroundStyle(Theme.accent)
            Text("Easel")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Theme.text)
            Spacer()
            AccountButton()
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.top, 14)
    }

    private func continueSubtitle(_ video: Video) -> String {
        var parts: [String] = []
        if !video.tutor.isEmpty { parts.append(video.tutor) }
        if let remaining = video.remainingText { parts.append(remaining) }
        return parts.joined(separator: " · ")
    }

    private func load() async {
        await app.api.refreshSession()
        do {
            latest = try await app.api.search(SearchQuery(), offset: 0).videos
            loadFailed = false
        } catch {
            loadFailed = !Task.isCancelled
        }
    }
}

/// The big "carry on with this" block at the top of Home.
private struct ResumeHero: View {
    let video: Video
    @Environment(AppModel.self) private var app

    var body: some View {
        let info = video.info
        HStack(alignment: .center, spacing: 44) {
            VStack(alignment: .leading, spacing: 14) {
                Text("CONTINUE WATCHING").eyebrow()
                Text(info.displayTitle)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
                Text(detail)
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.secondary)
                if let progress = video.progress {
                    ProgressLine(fraction: progress, height: 6, track: Theme.line)
                        .clipShape(Capsule())
                        .frame(maxWidth: 360)
                }
                HStack(spacing: 14) {
                    PlayButton(video: info, series: video.seriesContext, title: "Resume")
                    if let series = video.seriesContext {
                        Button(series.partCount > 0 ? "All \(series.partCount) parts" : "All parts") {
                            app.open(VideoInfo(id: 0, slug: series.slug, title: series.title, isSeries: true))
                        }
                        .buttonStyle(PillButtonStyle(kind: .secondary, height: 64, fontSize: 19))
                    } else {
                        Button("Details") { app.open(info) }
                            .buttonStyle(PillButtonStyle(kind: .secondary, height: 64, fontSize: 19))
                    }
                    Menu {
                        Button(role: .destructive) {
                            withAnimation { VideoStore.removeFromContinue(video, in: app.context) }
                        } label: {
                            Label("Remove from Continue watching", systemImage: "minus.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Theme.text)
                            .frame(width: 64, height: 64)
                            .background(Theme.raised, in: Circle())
                            .contentShape(Circle())
                    }
                    .accessibilityLabel("More options")
                }
                .padding(.top, 10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                app.play(info, series: video.seriesContext)
            } label: {
                Thumbnail(url: info.previewURL ?? info.thumbnailURL, cornerRadius: 20)
            }
            .buttonStyle(.plain)
            .containerRelativeFrame(.horizontal) { width, _ in min(540, width * 0.44) }
            .accessibilityLabel("Resume \(info.displayTitle)")
        }
        .padding(.horizontal, Theme.gutter)
    }

    private var detail: String {
        var parts: [String] = []
        if !video.tutor.isEmpty { parts.append(video.tutor) }
        if let series = video.seriesContext, series.partNumber > 0, series.partCount > 0 {
            parts.append("Part \(series.partNumber) of \(series.partCount)")
        }
        if let remaining = video.remainingText { parts.append(remaining) }
        return parts.joined(separator: " · ")
    }
}

/// The main Play button. It shows a spinner while the video's stream is being found.
struct PlayButton: View {
    let video: VideoInfo
    var series: SeriesContext?
    var title = "Play"
    var startAt: Double?

    @Environment(AppModel.self) private var app

    var body: some View {
        let starting = app.startingSlug == video.slug
        Button {
            app.play(video, series: series, at: startAt)
        } label: {
            HStack(spacing: 12) {
                if starting {
                    ProgressView().tint(Theme.onAccent)
                } else {
                    Image(systemName: "play.fill")
                }
                Text(starting ? "Starting…" : title)
            }
        }
        .buttonStyle(PillButtonStyle(kind: .primary, height: 64, fontSize: 21))
        .disabled(starting)
    }
}

/// The round button that opens the account sheet.
struct AccountButton: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        Button {
            app.showsAccount = true
        } label: {
            Image(systemName: "person.fill")
        }
        .buttonStyle(CircleButtonStyle(size: 48))
        .accessibilityLabel("Account")
    }
}

/// One of Raw Umber's playlists, as a tile.
struct PlaylistTile: View {
    let playlist: PlaylistInfo
    var width: CGFloat?
    @Environment(AppModel.self) private var app

    var body: some View {
        Button {
            app.show(.playlist(playlist))
        } label: {
            Text(playlist.name)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .frame(width: width, height: 88)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
