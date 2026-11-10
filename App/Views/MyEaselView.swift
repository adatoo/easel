import SwiftData
import SwiftUI

/// My Easel: her favourites, bookmarks, downloads and what she has watched.
struct MyEaselView: View {
    @Environment(AppModel.self) private var app

    @Query(
        filter: #Predicate<Video> { $0.isFavourite },
        sort: [SortDescriptor(\Video.favouritedAt, order: .reverse)]
    )
    private var favourites: [Video]

    @Query(
        filter: #Predicate<Video> { $0.lastWatched != nil },
        sort: [SortDescriptor(\Video.lastWatched, order: .reverse)]
    )
    private var watched: [Video]

    @Query(sort: [SortDescriptor(\Bookmark.createdAt, order: .reverse)])
    private var bookmarks: [Bookmark]

    var body: some View {
        let downloads = app.downloads
        let marks = bookmarks.filter { $0.video != nil }
        let nothingYet = favourites.isEmpty && watched.isEmpty && marks.isEmpty
            && downloads.downloads.isEmpty && downloads.activeDownloads.isEmpty

        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                HStack {
                    Text("My Easel")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(Theme.text)
                    Spacer()
                    AccountButton()
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.top, 20)

                if nothingYet {
                    ContentUnavailableView(
                        "Nothing here yet",
                        systemImage: "paintpalette",
                        description: Text("Videos you favourite, bookmark, download or watch will appear here.")
                    )
                    .padding(.top, 60)
                }

                if !favourites.isEmpty {
                    RowSection("Favourites", seeAll: { app.show(.shelf(.favourites)) }) {
                        ForEach(Array(favourites.prefix(12))) { video in
                            VideoCard(video.info) { app.open(video.info) }
                        }
                    }
                }

                if !marks.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(
                            title: "Bookmarks",
                            action: marks.count > 4 ? { app.show(.shelf(.bookmarks)) } : nil
                        )
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 20), GridItem(.flexible(), spacing: 20)], spacing: 12) {
                            ForEach(Array(marks.prefix(4))) { mark in
                                BookmarkRow(mark: mark) { app.play(mark) }
                            }
                        }
                    }
                    .padding(.horizontal, Theme.gutter)
                }

                if !downloads.downloads.isEmpty || !downloads.activeDownloads.isEmpty {
                    RowSection(
                        "Downloads",
                        note: "On this iPad, ready without internet",
                        seeAll: { app.show(.shelf(.downloads)) }
                    ) {
                        ForEach(downloads.activeDownloads, id: \.video.slug) { entry in
                            VideoCard(entry.video, subtitle: "Downloading · \(Int(entry.progress * 100))%") {
                                app.show(.shelf(.downloads))
                            }
                        }
                        ForEach(downloads.downloads) { record in
                            VideoCard(record.info, subtitle: [record.tutor, ByteText.string(record.bytes)].filter { !$0.isEmpty }.joined(separator: " · ")) {
                                app.play(record.info)
                            }
                        }
                    }
                }

                if !watched.isEmpty {
                    RowSection("Recently watched", seeAll: { app.show(.shelf(.watched)) }) {
                        ForEach(Array(watched.prefix(12))) { video in
                            VideoCard(
                                video.info,
                                subtitle: watchedSubtitle(video),
                                removeTitle: "Remove from Recently watched",
                                onRemove: { withAnimation { VideoStore.removeFromWatched(video, in: app.context) } }
                            ) {
                                app.open(video.info)
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 30)
        }
        .background(Theme.ground)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func watchedSubtitle(_ video: Video) -> String {
        var parts: [String] = []
        if !video.tutor.isEmpty { parts.append(video.tutor) }
        if let date = video.lastWatched { parts.append("watched \(VideoInfo.shortDate(date))") }
        return parts.joined(separator: " · ")
    }
}

/// One of her lists in full, with a way to remove things from it.
struct ShelfView: View {
    let shelf: Shelf

    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context

    @Query(
        filter: #Predicate<Video> { $0.isFavourite },
        sort: [SortDescriptor(\Video.favouritedAt, order: .reverse)]
    )
    private var favourites: [Video]

    @Query(
        filter: #Predicate<Video> { $0.lastWatched != nil },
        sort: [SortDescriptor(\Video.lastWatched, order: .reverse)]
    )
    private var watched: [Video]

    @Query(sort: [SortDescriptor(\Bookmark.createdAt, order: .reverse)])
    private var bookmarks: [Bookmark]

    @State private var isEditing = false
    @State private var confirmClear = false
    @State private var editingMark: Bookmark?
    @State private var noteText = ""

    private var title: String {
        switch shelf {
        case .continueWatching: return "Continue watching"
        case .favourites: return "Favourites"
        case .bookmarks: return "Bookmarks"
        case .downloads: return "Downloads"
        case .watched: return "Recently watched"
        }
    }

    private var videos: [Video] {
        switch shelf {
        case .continueWatching: return watched.filter(\.showsInContinue)
        case .favourites: return favourites
        case .watched: return watched
        case .bookmarks, .downloads: return []
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(Theme.text)
                    if shelf == .downloads, app.downloads.totalBytes > 0 {
                        Text(ByteText.string(app.downloads.totalBytes))
                            .font(.system(size: 18))
                            .foregroundStyle(Theme.secondary)
                    }
                    Spacer()
                    if canEdit {
                        if isEditing, shelf != .downloads, shelf != .bookmarks {
                            Button("Clear all", role: .destructive) { confirmClear = true }
                                .buttonStyle(PillButtonStyle(kind: .outline, height: 48, fontSize: 16))
                        }
                        Button(isEditing ? "Done" : "Remove…") {
                            withAnimation { isEditing.toggle() }
                        }
                        .buttonStyle(PillButtonStyle(kind: .secondary, height: 48, fontSize: 16))
                    }
                }
                .padding(.horizontal, Theme.gutter)

                switch shelf {
                case .bookmarks: bookmarkList
                case .downloads: downloadGrid
                default: videoGrid
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 30)
        }
        .background(Theme.ground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.ground, for: .navigationBar)
        .confirmationDialog("Clear \(title)?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear all", role: .destructive) { clearAll() }
        } message: {
            Text("Bookmarks, favourites and downloads are kept unless you're clearing them.")
        }
        .alert(
            "Note",
            isPresented: Binding(get: { editingMark != nil }, set: { if !$0 { editingMark = nil } })
        ) {
            TextField("e.g. mixing the shadow colour", text: $noteText)
            Button("Save") {
                editingMark?.note = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
                editingMark = nil
                try? context.save()
            }
            Button("Cancel", role: .cancel) { editingMark = nil }
        }
    }

    private var canEdit: Bool {
        switch shelf {
        case .bookmarks: return !bookmarks.isEmpty
        case .downloads: return !app.downloads.downloads.isEmpty
        default: return !videos.isEmpty
        }
    }

    // MARK: - Videos

    @ViewBuilder
    private var videoGrid: some View {
        if videos.isEmpty {
            ContentUnavailableView(emptyTitle, systemImage: "rectangle.stack")
                .padding(.top, 40)
        }
        VideoGrid {
            ForEach(videos) { video in
                VideoCard(
                    video.info,
                    width: nil,
                    subtitle: subtitle(video),
                    removeTitle: removeTitle,
                    onRemove: removeAction(for: video)
                ) {
                    if shelf == .continueWatching {
                        app.play(video.info, series: video.seriesContext)
                    } else {
                        app.open(video.info)
                    }
                }
                .overlay {
                    if isEditing {
                        RemoveCover { remove(video) }
                    }
                }
            }
        }
    }

    /// The card's own "⋯" remove, hidden while the big Remove buttons are showing.
    private func removeAction(for video: Video) -> (() -> Void)? {
        if isEditing { return nil }
        return { remove(video) }
    }

    private var removeTitle: String {
        switch shelf {
        case .continueWatching: return "Remove from Continue watching"
        case .favourites: return "Remove from Favourites"
        default: return "Remove from Recently watched"
        }
    }

    private var emptyTitle: String {
        switch shelf {
        case .continueWatching: return "Nothing in progress"
        case .favourites: return "No favourites yet"
        default: return "Nothing watched yet"
        }
    }

    private func subtitle(_ video: Video) -> String? {
        guard shelf == .continueWatching else { return nil }
        return [video.tutor, video.remainingText ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func remove(_ video: Video) {
        withAnimation {
            switch shelf {
            case .favourites:
                video.isFavourite = false
                video.favouritedAt = nil
            case .continueWatching:
                video.hiddenFromContinue = true
            default:
                video.lastWatched = nil
            }
            try? context.save()
        }
    }

    private func clearAll() {
        withAnimation {
            videos.forEach(remove)
            isEditing = false
        }
    }

    // MARK: - Bookmarks

    @ViewBuilder
    private var bookmarkList: some View {
        let marks = bookmarks.filter { $0.video != nil }
        if marks.isEmpty {
            ContentUnavailableView(
                "No bookmarks yet",
                systemImage: "bookmark",
                description: Text("Tap Bookmark in the player to mark a moment you want to come back to.")
            )
            .padding(.top, 40)
        }
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 20), GridItem(.flexible(), spacing: 20)], spacing: 12) {
            ForEach(marks) { mark in
                BookmarkRow(mark: mark) { app.play(mark) }
                    .overlay(alignment: .trailing) {
                        if isEditing {
                            HStack(spacing: 8) {
                                Button {
                                    noteText = mark.note
                                    editingMark = mark
                                } label: {
                                    Image(systemName: "square.and.pencil")
                                }
                                .buttonStyle(CircleButtonStyle(size: 48))
                                .accessibilityLabel("Edit note")
                                Button {
                                    withAnimation {
                                        context.delete(mark)
                                        try? context.save()
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(CircleButtonStyle(size: 48, fill: Color(hex: 0xB3261E)))
                                .accessibilityLabel("Delete bookmark")
                            }
                            .padding(.trailing, 12)
                        }
                    }
            }
        }
        .padding(.horizontal, Theme.gutter)
    }

    // MARK: - Downloads

    @ViewBuilder
    private var downloadGrid: some View {
        let downloads = app.downloads
        if let error = downloads.lastError {
            NoticeBar(systemImage: "exclamationmark.triangle", text: error, buttonTitle: "OK") {
                downloads.clearError()
            }
        }
        if downloads.downloads.isEmpty, downloads.activeDownloads.isEmpty {
            ContentUnavailableView(
                "No downloads",
                systemImage: "arrow.down.circle",
                description: Text("Tap Download on a video's page to watch it without internet.")
            )
            .padding(.top, 40)
        }
        VideoGrid {
            ForEach(downloads.activeDownloads, id: \.video.slug) { entry in
                VideoCard(entry.video, width: nil, subtitle: "Downloading · \(Int(entry.progress * 100))%") {}
                    .overlay {
                        RemoveCover(title: "Cancel") { downloads.cancel(entry.video.slug) }
                    }
            }
            ForEach(downloads.downloads) { record in
                VideoCard(record.info, width: nil, subtitle: ByteText.string(record.bytes)) {
                    app.play(record.info)
                }
                .overlay {
                    if isEditing {
                        RemoveCover { downloads.delete(record.slug) }
                    }
                }
            }
        }
    }
}

/// Covers a card with one big button while removing.
private struct RemoveCover: View {
    var title = "Remove"
    let action: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.45))
            Button(action: action) {
                Label(title, systemImage: "minus.circle.fill")
            }
            .buttonStyle(RemoveButtonStyle())
        }
        .transition(.opacity)
    }
}

private struct RemoveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .frame(height: 56)
            .background(Color(hex: 0xB3261E), in: Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// One of Raw Umber's playlists.
struct PlaylistView: View {
    let playlist: PlaylistInfo

    @Environment(AppModel.self) private var app
    @State private var videos: [VideoInfo] = []
    @State private var failed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("PLAYLIST FROM RAW UMBER").eyebrow()
                    Text(playlist.name)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(Theme.text)
                    if !playlist.about.isEmpty {
                        Text(playlist.about)
                            .font(.system(size: 17))
                            .foregroundStyle(Theme.secondary)
                            .frame(maxWidth: 760, alignment: .leading)
                    }
                }
                .padding(.horizontal, Theme.gutter)

                if failed {
                    NoticeBar(
                        systemImage: "wifi.slash",
                        text: "This playlist couldn't be loaded.",
                        buttonTitle: "Try again"
                    ) {
                        Task { await load() }
                    }
                } else if videos.isEmpty {
                    ProgressView()
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                }

                VideoGrid {
                    ForEach(videos, id: \.slug) { video in
                        VideoCard(video, width: nil) { app.open(video) }
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
        .task(id: app.siteVersion) { await load() }
    }

    private func load() async {
        do {
            videos = try await app.api.playlist(slug: playlist.slug)
            failed = false
        } catch {
            failed = videos.isEmpty && !Task.isCancelled
        }
    }
}
