import SwiftData
import SwiftUI

/// The page for one video or one series: what it is, a big Play, the parts, her bookmarks,
/// the site's extras and similar videos.
struct VideoDetailView: View {
    /// What the card she tapped knew; the full page loads on top of it.
    let video: VideoInfo

    @Environment(AppModel.self) private var app
    @Environment(\.openURL) private var openURL
    @Query private var library: [Video]

    @State private var page: VideoPage?
    @State private var failed = false
    @State private var showsFullSummary = false

    private var info: VideoInfo { page?.video ?? video }
    private var parts: [VideoInfo] { page?.parts ?? [] }
    private var isSeries: Bool { info.isSeries || !parts.isEmpty }

    var body: some View {
        let records = Dictionary(library.map { ($0.slug, $0) }, uniquingKeysWith: { first, _ in first })
        let marks = bookmarks(records)
        let extras = page?.extras ?? []
        let materials = page?.materials ?? []

        ScrollView {
            VStack(alignment: .leading, spacing: 34) {
                hero(records)

                if failed {
                    NoticeBar(
                        systemImage: "wifi.slash",
                        text: "This page couldn't be loaded from Raw Umber.",
                        buttonTitle: "Try again"
                    ) {
                        Task { await load() }
                    }
                }

                if isSeries {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 40) {
                            partsList(records).frame(minWidth: 520)
                            if !marks.isEmpty || !extras.isEmpty || !materials.isEmpty {
                                VStack(spacing: 20) {
                                    materialsCard(materials)
                                    bookmarksCard(marks)
                                    extrasCard(extras)
                                }
                                .frame(width: 340)
                                .padding(.top, 48)
                            }
                        }
                        VStack(alignment: .leading, spacing: 24) {
                            partsList(records)
                            materialsCard(materials)
                            bookmarksCard(marks)
                            extrasCard(extras)
                        }
                    }
                    .padding(.horizontal, Theme.gutter)
                } else if !marks.isEmpty || !extras.isEmpty || !materials.isEmpty {
                    HStack(alignment: .top, spacing: 20) {
                        materialsCard(materials)
                        if !marks.isEmpty || !extras.isEmpty {
                            VStack(spacing: 20) {
                                bookmarksCard(marks)
                                extrasCard(extras)
                            }
                        }
                    }
                    .padding(.horizontal, Theme.gutter)
                }

                if let related = page?.related, !related.isEmpty {
                    RowSection("More like this") {
                        ForEach(related, id: \.slug) { other in
                            VideoCard(other) { app.open(other) }
                        }
                    }
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 30)
        }
        .background(Theme.ground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.ground, for: .navigationBar)
        .task(id: "\(video.slug)#\(app.siteVersion)") { await load() }
    }

    // MARK: - Top of the page

    private func hero(_ records: [String: Video]) -> some View {
        HStack(alignment: .center, spacing: 40) {
            Thumbnail(url: info.previewURL ?? info.thumbnailURL, cornerRadius: 20)
                .containerRelativeFrame(.horizontal) { width, _ in min(540, width * 0.46) }

            VStack(alignment: .leading, spacing: 12) {
                if let eyebrowText {
                    Text(eyebrowText).eyebrow()
                }
                Text(info.displayTitle)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(3)
                    .minimumScaleFactor(0.75)
                if !metaText.isEmpty {
                    Text(metaText)
                        .font(.system(size: 17))
                        .foregroundStyle(Theme.secondary)
                }
                if !info.summary.isEmpty {
                    Text(info.summary)
                        .font(.system(size: 17))
                        .foregroundStyle(Color(hex: 0xD9D3CA))
                        .lineSpacing(4)
                        .lineLimit(showsFullSummary ? nil : 5)
                    if info.summary.count > 300 {
                        Button(showsFullSummary ? "Less" : "More") {
                            withAnimation { showsFullSummary.toggle() }
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(minHeight: 44)
                    }
                }
                actions(records)
                    .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Theme.gutter)
    }

    private var eyebrowText: String? {
        if isSeries {
            return parts.isEmpty ? "SERIES" : "SERIES · \(parts.count) PARTS"
        }
        if info.isUpcoming { return "LIVE SESSION" }
        if let kind = info.sessionKind { return "\(kind.uppercased()) SESSION" }
        return nil
    }

    private var metaText: String {
        var items: [String] = []
        if !info.tutor.isEmpty { items.append(info.tutor) }
        if !isSeries, !info.isUpcoming, let date = info.dateLive { items.append(VideoInfo.shortDate(date)) }
        if info.hasSubtitles { items.append("Subtitles") }
        return items.joined(separator: " · ")
    }

    @ViewBuilder
    private func actions(_ records: [String: Video]) -> some View {
        if info.isUpcoming {
            VStack(alignment: .leading, spacing: 14) {
                Text(info.liveBadge.map { "Live on \($0)" } ?? "Coming soon")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.text)
                websiteButton("Watch live on the Raw Umber website")
            }
        } else if isSeries {
            seriesActions(records)
        } else if !info.accessible {
            lockedActions
        } else {
            let record = records[info.slug]
            VStack(alignment: .leading, spacing: 12) {
                PlayButton(video: info, title: playTitle(record))
                HStack(spacing: 12) {
                    FavouriteButton(video: info, isFavourite: record?.isFavourite ?? false)
                    DownloadControl(video: info)
                }
            }
        }
    }

    @ViewBuilder
    private func seriesActions(_ records: [String: Video]) -> some View {
        let watchable = parts.filter(\.accessible)
        let toDownload = watchable.filter { !app.downloads.isDownloaded($0.slug) }
        VStack(alignment: .leading, spacing: 12) {
            if let target = resumeTarget(records) {
                HStack(spacing: 12) {
                    PlayButton(video: target.part, series: context(forPart: target.index), title: target.title)
                    if let trailer = page?.trailer, trailer.accessible {
                        Button("Trailer") {
                            app.play(trailer, series: context(forPart: -1))
                        }
                        .buttonStyle(PillButtonStyle(kind: .secondary, height: 64, fontSize: 18))
                    }
                }
            } else if page != nil {
                lockedActions
            }
            HStack(spacing: 12) {
                FavouriteButton(video: info, isFavourite: records[info.slug]?.isFavourite ?? false)
                if !toDownload.isEmpty {
                    Button {
                        app.downloadAll(toDownload, seriesSlug: info.slug)
                    } label: {
                        Label(
                            toDownload.count == watchable.count ? "Download all \(toDownload.count)" : "Download the other \(toDownload.count)",
                            systemImage: "arrow.down.to.line"
                        )
                    }
                    .buttonStyle(PillButtonStyle(kind: .secondary, height: 52, fontSize: 16))
                }
            }
        }
    }

    @ViewBuilder
    private var lockedActions: some View {
        VStack(alignment: .leading, spacing: 14) {
            if app.api.session.loggedIn {
                Label("This isn't included in your subscription.", systemImage: "lock.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.text)
                websiteButton("Open on the Raw Umber website")
            } else {
                Label("Sign in to Raw Umber to watch this.", systemImage: "lock.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Button("Sign in") { app.openWebsite(RawUmber.signIn) }
                    .buttonStyle(PillButtonStyle(kind: .primary, height: 56, fontSize: 19))
            }
        }
    }

    private func websiteButton(_ title: String) -> some View {
        Button {
            app.openWebsite(RawUmber.videoPage(info.slug))
        } label: {
            Label(title, systemImage: "arrow.up.right.square")
        }
        .buttonStyle(PillButtonStyle(kind: .secondary, height: 56, fontSize: 17))
    }

    private func playTitle(_ record: Video?) -> String {
        if let remaining = record?.remainingText { return "Resume · \(remaining)" }
        if record?.finished == true { return "Watch again" }
        return "Play"
    }

    /// Which part the big button plays: the one she's in the middle of, else the next unwatched.
    private func resumeTarget(_ records: [String: Video]) -> (part: VideoInfo, index: Int, title: String)? {
        let watchable = parts.enumerated().filter { $0.element.accessible }
        guard !watchable.isEmpty else { return nil }

        let inProgress = watchable
            .filter { records[$0.element.slug]?.isInProgress == true }
            .max { (records[$0.element.slug]?.lastWatched ?? .distantPast) < (records[$1.element.slug]?.lastWatched ?? .distantPast) }
        if let current = inProgress {
            return (current.element, current.offset, "Resume part \(current.offset + 1)")
        }
        if let next = watchable.first(where: { records[$0.element.slug]?.finished != true }) {
            let started = watchable.contains { records[$0.element.slug]?.finished == true }
            return (next.element, next.offset, started ? "Play part \(next.offset + 1)" : "Play part 1")
        }
        let first = watchable[0]
        return (first.element, first.offset, "Watch again")
    }

    private func context(forPart index: Int) -> SeriesContext {
        SeriesContext(slug: info.slug, title: info.title, partNumber: index + 1, partCount: parts.count)
    }

    // MARK: - Parts of a series

    private func partsList(_ records: [String: Video]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Parts")
                .padding(.leading, 10)
            if parts.isEmpty, page == nil, !failed {
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            }
            ForEach(Array(parts.enumerated()), id: \.element.slug) { index, part in
                partRow(part, index: index, record: records[part.slug])
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func partRow(_ part: VideoInfo, index: Int, record: Video?) -> some View {
        let starting = app.startingSlug == part.slug
        return HStack(spacing: 8) {
            Button {
                if part.accessible {
                    app.play(part, series: context(forPart: index))
                } else {
                    app.openWebsite(RawUmber.videoPage(part.slug))
                }
            } label: {
                HStack(spacing: 18) {
                    Thumbnail(url: part.thumbnailURL, cornerRadius: 10)
                        .overlay(alignment: .bottom) {
                            if let record, record.isInProgress, let progress = record.progress {
                                ProgressLine(fraction: progress, height: 6)
                            }
                        }
                        .overlay {
                            if starting {
                                ZStack {
                                    Color.black.opacity(0.5)
                                    ProgressView().tint(Theme.text)
                                }
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .frame(width: 168)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(index + 1) · \(part.displayTitle)")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Theme.text)
                            .multilineTextAlignment(.leading)
                        if !part.summary.isEmpty {
                            Text(part.summary)
                                .font(.system(size: 15))
                                .foregroundStyle(Theme.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                        Text(stateText(part, record: record))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(record?.isInProgress == true ? Theme.accent : Theme.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if part.accessible {
                DownloadControl(video: part, seriesSlug: info.slug, style: .icon)
            } else {
                Image(systemName: "lock.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.secondary)
                    .frame(width: 52, height: 52)
            }
        }
        .padding(10)
        .background(
            record?.isInProgress == true ? Theme.surface : Color.clear,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    private func stateText(_ part: VideoInfo, record: Video?) -> String {
        if !part.accessible { return "Not in your subscription" }
        if let remaining = record?.remainingText { return remaining }
        if record?.finished == true { return "Watched" }
        return "Not started"
    }

    // MARK: - Bookmarks and extras

    private func bookmarks(_ records: [String: Video]) -> [Bookmark] {
        ([info.slug] + parts.map(\.slug))
            .compactMap { records[$0] }
            .flatMap(\.sortedBookmarks)
    }

    @ViewBuilder
    private func bookmarksCard(_ marks: [Bookmark]) -> some View {
        if !marks.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Label("Your bookmarks", systemImage: "bookmark.fill")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .padding(.bottom, 12)
                ForEach(marks) { mark in
                    Button {
                        app.play(mark)
                    } label: {
                        HStack(spacing: 14) {
                            Text(Timecode.string(mark.time))
                                .font(.system(size: 17, weight: .bold).monospacedDigit())
                                .foregroundStyle(Theme.accent)
                                .frame(width: 62, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mark.note.isEmpty ? "Bookmark" : mark.note)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Theme.text)
                                    .multilineTextAlignment(.leading)
                                if isSeries, let title = mark.video?.info.displayTitle {
                                    Text(title)
                                        .font(.system(size: 14))
                                        .foregroundStyle(Theme.secondary)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(minHeight: 56)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: .top) { Theme.line.opacity(0.6).frame(height: 1) }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    /// What she'll need, from the video's own description.
    @ViewBuilder
    private func materialsCard(_ materials: [String]) -> some View {
        if !materials.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Label("Materials", systemImage: "paintbrush.pointed.fill")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .padding(.bottom, 4)
                ForEach(Array(materials.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 7, height: 7)
                            .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
                        Text(item)
                            .font(.system(size: 17))
                            .foregroundStyle(Theme.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    @ViewBuilder
    private func extrasCard(_ extras: [ExtraLink]) -> some View {
        if !extras.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("Extras")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .padding(.bottom, 12)
                ForEach(extras) { link in
                    Button {
                        if let slug = RawUmber.videoSlug(from: link.url) {
                            // Another Raw Umber video: its page in Easel, not on the website.
                            app.open(VideoInfo(id: 0, slug: slug, title: link.title))
                        } else if link.isFile {
                            openURL(link.url)
                        } else {
                            app.openWebsite(link.url)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Text(link.title)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Theme.text)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                            Image(systemName: RawUmber.videoSlug(from: link.url) == nil ? "arrow.up.right" : "play.rectangle")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.secondary)
                        }
                        .frame(minHeight: 52)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: .top) { Theme.line.opacity(0.6).frame(height: 1) }
                }
                Text(extras.allSatisfy { RawUmber.videoSlug(from: $0.url) != nil } ? "These open in Easel." : "Pages open the Raw Umber website.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.secondary)
                    .padding(.top, 12)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: - Loading

    private func load() async {
        do {
            let loaded = try await app.api.videoPage(slug: video.slug)
            page = loaded
            failed = false
            // Find the stream now, so Play is quick when she taps it.
            let series = loaded.video.isSeries || !loaded.parts.isEmpty
            let playable = series
                ? loaded.parts.contains(where: \.accessible)
                : loaded.video.accessible && !loaded.video.isUpcoming
            if playable, !app.downloads.isDownloaded(loaded.video.slug) {
                app.resolver.prepare(slug: loaded.video.slug)
            }
        } catch {
            failed = page == nil && !Task.isCancelled
        }
    }
}

/// Add to or remove from favourites, as a labelled button.
struct FavouriteButton: View {
    let video: VideoInfo
    let isFavourite: Bool
    @Environment(\.modelContext) private var context

    var body: some View {
        Button {
            VideoStore.toggleFavourite(video, in: context)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isFavourite ? "heart.fill" : "heart")
                    .foregroundStyle(isFavourite ? Theme.accent : Theme.text)
                Text(isFavourite ? "In favourites" : "Favourite")
            }
        }
        .buttonStyle(PillButtonStyle(kind: .secondary, height: 52, fontSize: 16))
    }
}
