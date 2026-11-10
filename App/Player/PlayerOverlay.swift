import SwiftData
import SwiftUI

/// The player, covering the app. On the iPad it's the video with big controls over it, which fade
/// after a few seconds; when the video is on the TV the iPad becomes a remote.
struct PlayerOverlay: View {
    let playing: NowPlaying

    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Query private var stored: [Video]

    @State private var controlsVisible = true
    @State private var hideTask: Task<Void, Never>?
    @State private var showResumeNote = true
    @State private var editingMark: Bookmark?
    @State private var noteText = ""
    @State private var toast: String?

    init(playing: NowPlaying) {
        self.playing = playing
        let slug = playing.video.slug
        _stored = Query(filter: #Predicate<Video> { $0.slug == slug })
    }

    private var player: PlayerModel { app.player }
    private var marks: [Bookmark] { stored.first?.sortedBookmarks ?? [] }

    var body: some View {
        ZStack {
            if player.isExternal {
                RemoteLayout(
                    playing: playing,
                    marks: marks,
                    onBookmark: addBookmark,
                    onEditNote: edit
                )
            } else {
                iPadLayout
            }
            if let toast {
                Text(toast)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, 24)
                    .frame(height: 52)
                    .background(Theme.raised, in: Capsule())
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 100)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(Color.black.ignoresSafeArea())
        .alert(
            noteTitle,
            isPresented: Binding(get: { editingMark != nil }, set: { if !$0 { editingMark = nil } })
        ) {
            TextField("e.g. mixing the shadow colour", text: $noteText)
            Button("Save") { saveNote() }
            Button("Delete bookmark", role: .destructive) { deleteMark() }
            Button("Cancel", role: .cancel) { editingMark = nil }
        }
        .onAppear { scheduleHide() }
        .onChange(of: player.isPlaying) { _, playing in
            if playing { scheduleHide() } else { show() }
        }
        .task(id: playing.id) {
            try? await Task.sleep(for: .seconds(8))
            withAnimation { showResumeNote = false }
        }
    }

    // MARK: - On the iPad

    private var iPadLayout: some View {
        ZStack {
            VideoSurface(player: player.player)
                .ignoresSafeArea()
                .onTapGesture { toggleControls() }

            if !player.isReady, !player.failed {
                ProgressView().tint(Theme.text).controlSize(.large)
            }
            if player.failed {
                failedMessage
            }

            if controlsVisible {
                ZStack {
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.7), Color.black.opacity(0.15),
                            Color.black.opacity(0.75),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                    .onTapGesture { toggleControls() }

                    VStack(spacing: 0) {
                        topBar
                        Spacer()
                        transport
                        Spacer()
                        bottomBar
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 20)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: controlsVisible)
    }

    private var topBar: some View {
        HStack(spacing: 16) {
            Button {
                app.minimisePlayer()
            } label: {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(CircleButtonStyle(size: 52, fill: Theme.raised.opacity(0.92)))
            .accessibilityLabel("Close player")

            VStack(alignment: .leading, spacing: 2) {
                Text(playing.video.displayTitle)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(Color(hex: 0xD9D3CA))
                    .lineLimit(1)
            }
            Spacer(minLength: 12)

            SpeedMenu(player: player, fill: Theme.raised.opacity(0.92))
                .simultaneousGesture(TapGesture().onEnded { scheduleHide() })
            if player.hasSubtitles {
                Button(player.subtitlesOn ? "Subtitles on" : "Subtitles") {
                    player.toggleSubtitles()
                    scheduleHide()
                }
                .buttonStyle(PillButtonStyle(kind: player.subtitlesOn ? .outline : .secondary))
            }
            if !playing.isOffline {
                DownloadControl(video: playing.video, style: .icon)
                    .background(Theme.raised.opacity(0.92), in: Circle())
            }
            Button {
                AirPlayPicker.shared.present()
            } label: {
                Label("Play on TV", systemImage: "tv")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.onAccent)
                    .padding(.horizontal, 20)
                    .frame(height: 52)
                    .background(Theme.text, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var transport: some View {
        HStack(spacing: 28) {
            SkipButton(seconds: -30, size: 76) { skip(-30) }
            SkipButton(seconds: -10, size: 96) { skip(-10) }
            PlayPauseButton(player: player, size: 128)
            SkipButton(seconds: 10, size: 96) { skip(10) }
            SkipButton(seconds: 30, size: 76) { skip(30) }
        }
    }

    private var bottomBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showResumeNote, let from = playing.resumedFrom {
                HStack(spacing: 14) {
                    Text("Resumed from \(Timecode.string(from))")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Button("Start over") {
                        player.seek(to: 0)
                        withAnimation { showResumeNote = false }
                    }
                    .buttonStyle(PillButtonStyle(kind: .secondary, height: 44, fontSize: 16))
                }
                .padding(.leading, 18)
                .padding(.trailing, 6)
                .frame(height: 56)
                .background(Color.black.opacity(0.6), in: Capsule())
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    Button {
                        addBookmark()
                    } label: {
                        Label("Bookmark this moment", systemImage: "bookmark.fill")
                    }
                    .buttonStyle(PillButtonStyle(kind: .primary))
                    ForEach(marks) { mark in
                        Button {
                            player.seek(to: mark.time)
                            scheduleHide()
                        } label: {
                            HStack(spacing: 10) {
                                Text(Timecode.string(mark.time))
                                    .fontWeight(.bold)
                                    .foregroundStyle(Theme.accent)
                                    .monospacedDigit()
                                Text(mark.note.isEmpty ? "Bookmark" : mark.note)
                            }
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Theme.text)
                            .padding(.horizontal, 18)
                            .frame(height: 52)
                            .background(Theme.raised.opacity(0.94), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Edit note") { edit(mark) }
                            Button("Delete bookmark", role: .destructive) {
                                context.delete(mark)
                                try? context.save()
                            }
                        }
                    }
                }
            }

            Scrubber(player: player, bookmarks: marks.map(\.time))
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0).onEnded { _ in scheduleHide() })

            HStack {
                Text(Timecode.string(player.currentTime))
                Spacer()
                Text("-" + Timecode.string(max(0, player.duration - player.currentTime)))
            }
            .font(.system(size: 17, weight: .semibold).monospacedDigit())
            .foregroundStyle(Theme.text)
        }
    }

    private var failedMessage: some View {
        VStack(spacing: 18) {
            Text("This video couldn't be played.")
                .font(.system(size: 22, weight: .bold))
            Text("Check the internet connection and try again.")
                .font(.system(size: 17))
                .foregroundStyle(Theme.secondary)
            Button("Close") { app.closePlayer() }
                .buttonStyle(PillButtonStyle(kind: .primary))
        }
        .foregroundStyle(Theme.text)
        .padding(40)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var subtitle: String {
        var parts: [String] = []
        if !playing.video.tutor.isEmpty { parts.append(playing.video.tutor) }
        if let series = stored.first?.seriesContext, series.partNumber > 0, series.partCount > 0 {
            parts.append("Part \(series.partNumber) of \(series.partCount)")
        }
        if playing.isOffline { parts.append("On this iPad") }
        return parts.joined(separator: " · ")
    }

    // MARK: - Showing and hiding the controls

    private func toggleControls() {
        if controlsVisible {
            hideTask?.cancel()
            controlsVisible = false
        } else {
            show()
        }
    }

    private func show() {
        controlsVisible = true
        scheduleHide()
    }

    private func scheduleHide() {
        hideTask?.cancel()
        guard player.isPlaying else { return }
        hideTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled, player.isPlaying, !player.isScrubbing, editingMark == nil
            else { return }
            controlsVisible = false
        }
    }

    private func skip(_ seconds: Double) {
        player.skip(by: seconds)
        scheduleHide()
    }

    // MARK: - Bookmarks

    private func addBookmark() {
        guard let mark = app.addBookmark() else { return }
        hideTask?.cancel()
        showToast("Bookmarked at \(Timecode.string(mark.time))")
        // Straight into adding a note; she can just tap Cancel.
        noteText = ""
        editingMark = mark
    }

    private func edit(_ mark: Bookmark) {
        hideTask?.cancel()
        noteText = mark.note
        editingMark = mark
    }

    private var noteTitle: String {
        guard let editingMark else { return "Note" }
        return "Note at \(Timecode.string(editingMark.time))"
    }

    private func saveNote() {
        editingMark?.note = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        editingMark = nil
        try? context.save()
        scheduleHide()
    }

    private func deleteMark() {
        if let editingMark { context.delete(editingMark) }
        editingMark = nil
        try? context.save()
        scheduleHide()
    }

    private func showToast(_ text: String) {
        withAnimation { toast = text }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            if toast == text { withAnimation { toast = nil } }
        }
    }
}

/// While the video is on the TV, the iPad is a remote: very big buttons and the bookmarks.
private struct RemoteLayout: View {
    let playing: NowPlaying
    let marks: [Bookmark]
    let onBookmark: () -> Void
    let onEditNote: (Bookmark) -> Void

    @Environment(AppModel.self) private var app

    private var player: PlayerModel { app.player }

    var body: some View {
        VStack(spacing: 28) {
            HStack {
                Button {
                    app.minimisePlayer()
                } label: {
                    Label("Browse while it plays", systemImage: "chevron.down")
                }
                .buttonStyle(PillButtonStyle(kind: .secondary))
                Spacer()
                Button {
                    AirPlayPicker.shared.present()
                } label: {
                    Label(player.routeName ?? "TV", systemImage: "tv")
                }
                .buttonStyle(PillButtonStyle(kind: .outline))
            }

            HStack(alignment: .top, spacing: 40) {
                VStack(spacing: 0) {
                    HStack(spacing: 24) {
                        Thumbnail(url: playing.video.thumbnailURL, cornerRadius: 16)
                            .frame(width: 300)
                        VStack(alignment: .leading, spacing: 10) {
                            Text("PLAYING ON THE TV").eyebrow()
                            Text(playing.video.displayTitle)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(Theme.text)
                                .lineLimit(2)
                            if !playing.video.tutor.isEmpty {
                                Text(playing.video.tutor)
                                    .font(.system(size: 17))
                                    .foregroundStyle(Theme.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Spacer(minLength: 24)

                    VStack(spacing: 6) {
                        Scrubber(
                            player: player, bookmarks: marks.map(\.time), barHeight: 10, knob: 32,
                            track: Theme.line)
                        HStack {
                            Text(Timecode.string(player.currentTime)).foregroundStyle(Theme.text)
                            Spacer()
                            Text(
                                "-" + Timecode.string(max(0, player.duration - player.currentTime))
                            )
                            .foregroundStyle(Theme.secondary)
                        }
                        .font(.system(size: 18, weight: .semibold).monospacedDigit())
                    }

                    Spacer(minLength: 24)

                    HStack(spacing: 26) {
                        SkipButton(seconds: -30, size: 88, fill: Theme.raised) {
                            player.skip(by: -30)
                        }
                        SkipButton(seconds: -10, size: 112, fill: Theme.raised) {
                            player.skip(by: -10)
                        }
                        PlayPauseButton(player: player, size: 156)
                        SkipButton(seconds: 10, size: 112, fill: Theme.raised) {
                            player.skip(by: 10)
                        }
                        SkipButton(seconds: 30, size: 88, fill: Theme.raised) {
                            player.skip(by: 30)
                        }
                    }

                    Spacer(minLength: 24)

                    HStack(spacing: 12) {
                        SpeedMenu(player: player)
                        if player.hasSubtitles {
                            Button(player.subtitlesOn ? "Subtitles on" : "Subtitles") {
                                player.toggleSubtitles()
                            }
                            .buttonStyle(
                                PillButtonStyle(kind: player.subtitlesOn ? .outline : .secondary))
                        }
                        Spacer()
                        Button("Watch on the iPad instead") { AirPlayPicker.shared.present() }
                            .buttonStyle(PillButtonStyle(kind: .secondary))
                    }
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 8) {
                    Button(action: onBookmark) {
                        Label("Bookmark this moment", systemImage: "bookmark.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PillButtonStyle(kind: .primary, height: 68, fontSize: 19))

                    Text("Bookmarks")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(Theme.text)
                        .padding(.top, 14)

                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(marks) { mark in
                                HStack(spacing: 4) {
                                    Button {
                                        player.seek(to: mark.time)
                                    } label: {
                                        HStack(spacing: 14) {
                                            Text(Timecode.string(mark.time))
                                                .font(
                                                    .system(size: 18, weight: .bold)
                                                        .monospacedDigit()
                                                )
                                                .foregroundStyle(Theme.accent)
                                                .frame(width: 64, alignment: .leading)
                                            Text(mark.note.isEmpty ? "Bookmark" : mark.note)
                                                .font(.system(size: 17, weight: .medium))
                                                .foregroundStyle(Theme.text)
                                                .multilineTextAlignment(.leading)
                                            Spacer(minLength: 0)
                                        }
                                        .frame(minHeight: 72)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    Button {
                                        onEditNote(mark)
                                    } label: {
                                        Image(systemName: "square.and.pencil")
                                            .font(.system(size: 20))
                                            .foregroundStyle(Theme.secondary)
                                            .frame(width: 48, height: 48)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Edit note")
                                }
                                .overlay(alignment: .top) {
                                    Theme.line.opacity(0.6).frame(height: 1)
                                }
                            }
                        }
                    }

                    Text(
                        marks.isEmpty
                            ? "Bookmarks you add appear here."
                            : "Tap a bookmark to jump there on the TV."
                    )
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.secondary)
                }
                .padding(20)
                .frame(width: 340)
                .frame(maxHeight: .infinity, alignment: .top)
                .background(
                    Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.vertical, 24)
        .background(Theme.ground.ignoresSafeArea())
    }
}

/// The bar above the tabs while something is loaded but the player is shrunk.
struct MiniPlayer: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        let player = app.player
        if let playing = app.nowPlaying {
            VStack(spacing: 0) {
                ProgressLine(
                    fraction: player.duration > 0 ? player.currentTime / player.duration : 0,
                    height: 3,
                    track: Theme.line
                )
                HStack(spacing: 16) {
                    Button {
                        app.expandPlayer()
                    } label: {
                        HStack(spacing: 16) {
                            Thumbnail(url: playing.video.thumbnailURL, cornerRadius: 8)
                                .frame(width: 92)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(playing.video.displayTitle)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(Theme.text)
                                    .lineLimit(1)
                                if player.isExternal {
                                    Label(
                                        "Playing on \(player.routeName ?? "the TV")",
                                        systemImage: "tv"
                                    )
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Theme.accent)
                                } else {
                                    Text(playing.video.tutor)
                                        .font(.system(size: 14))
                                        .foregroundStyle(Theme.secondary)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open player for \(playing.video.displayTitle)")

                    Text(
                        "\(Timecode.string(player.currentTime)) / \(Timecode.string(player.duration))"
                    )
                    .font(.system(size: 15).monospacedDigit())
                    .foregroundStyle(Theme.secondary)
                    SkipButton(seconds: -10, size: 52, fill: Theme.line) { player.skip(by: -10) }
                    PlayPauseButton(player: player, size: 56)
                    Button {
                        app.closePlayer()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(
                        CircleButtonStyle(size: 48, fill: Color.clear, foreground: Theme.secondary)
                    )
                    .accessibilityLabel("Stop")
                }
                .padding(.leading, Theme.gutter)
                .padding(.trailing, 24)
                .frame(height: 72)
            }
            .background(Color(hex: 0x26211D))
            .overlay(alignment: .top) { Theme.line.frame(height: 1) }
        }
    }
}
